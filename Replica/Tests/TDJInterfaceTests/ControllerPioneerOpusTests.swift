import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOpus(
    decks: @escaping () -> [DeckID] = { DeckID.allCases },
    body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "opus-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: decks)
    input.sources = [
        .init(id: 10, reference: 100, name: "OPUS-QUAD", identity: .init(id: 10, device: 1, names: ["OPUS-QUAD"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func opusPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerPioneerOpusMatchesOnlyThePublishedModelAndKeepsOutputLimits() throws {
    for name in ["OPUS-QUAD", "Pioneer OPUS-QUAD", "Pioneer DJ OPUS-QUAD"] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.definition?.startup.isEmpty == true)
        #expect(profile.definition?.shutdown.isEmpty == true)
        #expect(!profile.isPlayer)
        #expect(profile.feedback(destination: 20).count == 12)
        #expect(!profile.bindings(source: 10).contains { $0.action.hotcueSlot != nil && $0.channel >= 4 })
    }
    for name in ["OPUS-QUAD clone", "OPUS-DUO"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
}

@Test @MainActor func controllerPioneerOpusRoutesDistinctHotCuesLoadsAndLoopButtonsToEveryDeck() {
    withOpus { input in
        var received: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in received.append(target) }
        for (channel, deck) in zip(UInt8(0)..<4, DeckID.allCases) {
            for number: UInt8 in [0, 81, 8, 27, 67, 68, 69, 44, 45] {
                opusPacket([0x90 | channel, number, 127], to: input)
            }
            let actions: [ControllerAction] =
                deck.leftSide
                ? [.playA, .loadA, .hotcue1A, .hotcue8A, .loopA, .reloopA, .fixedLoopA, .jumpForwardA, .jumpBackA]
                : [.playB, .loadB, .hotcue1B, .hotcue8B, .loopB, .reloopB, .fixedLoopB, .jumpForwardB, .jumpBackB]
            #expect(
                Array(received.suffix(9))
                    == actions.map { .init($0, deck: deck, argument: $0 == .fixedLoopA || $0 == .fixedLoopB ? 4 : nil) }
            )
        }
        #expect(received.count == 36)
    }
}

@Test @MainActor func controllerPioneerOpusKeepsSignedLoopEncoderCountsAndButtonOrder() {
    withOpus { input in
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        opusPacket([0xB1, 46, 3, 46, 126, 46, 0, 0x91, 67, 127], to: input)
        #expect(
            received.map(\.0) == [.init(.loopSizeB, deck: .b), .init(.loopSizeB, deck: .b), .init(.loopB, deck: .b)])
        #expect(received.map { Int((($0.1 - 0.5) * 126).rounded()) } == [3, -2, 63])
        input.flushPendingActions()
        #expect(received.count == 3)
    }
}

@Test @MainActor func controllerPioneerOpusBlocksInactiveEncodersAndRetainsJogRelease() {
    var decks = DeckID.allCases
    withOpus(decks: { decks }) { input in
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        opusPacket([0x92, 32, 127], to: input)
        decks = DeckID.primary
        opusPacket([0xB2, 46, 30, 0x92, 67, 127, 0x82, 32, 0], to: input)
        input.flushPendingActions()
        #expect(received.map(\.0) == [.init(.jogTouchA, deck: .c), .init(.jogTouchA, deck: .c)])
        #expect(received.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerPioneerOpusUsesItsShiftJogAndNeedleReleaseEncoding() {
    withOpus { input in
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        opusPacket([0xB1, 41, 65, 28, 127, 28, 0], to: input)
        input.flushPendingActions()
        #expect(Set(received.map(\.0)) == Set([.init(.jogB, deck: .b), .init(.seekB, deck: .b)]))
        #expect(received.first { $0.0.action == .jogB }?.1 == 0.625)
        #expect(received.first { $0.0.action == .seekB }?.1 == 1)
    }
}

@Test @MainActor func controllerPioneerOpusLoopEncoderChangesNativeSizeWithoutChangingSync() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    model.load(trackID: try #require(model.library.tracks.first).id, deck: .b)
    await model.flushWrites()
    model.setLoopSize(4, deck: .b)
    let sync = try #require(model.playbackSnapshot?.b.synced)
    withOpus { input in
        input.onTargetAction = { target, value in
            model.applyController(target.action, value: value, targetDeck: target.deck, argument: target.argument)
        }
        opusPacket([0xB1, 46, 2, 46, 127, 0x91, 67, 127], to: input)
        #expect(model.performance.loopBeats(for: .b) == 8)
        #expect(model.playbackSnapshot?.b.loopEnabled == true)
        #expect(model.playbackSnapshot?.b.synced == sync)
        opusPacket([0xB1, 46, 30], to: input)
        #expect(model.performance.loopBeats(for: .b) == PerformancePreparation.loopSizes.last)
        opusPacket([0xB1, 46, 98], to: input)
        #expect(model.performance.loopBeats(for: .b) == PerformancePreparation.loopSizes.first)
        #expect(model.playbackSnapshot?.b.synced == sync)
    }
}
