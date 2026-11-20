import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let seratoPioneerNames = ["DDJ-1000SRT", "DDJ-SZ2", "DDJ-SZ", "XDJ-RX2"]

@MainActor private func withSeratoPioneer(_ name: String, body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "serato-pioneer-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func seratoPioneerPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerSeratoPioneerMatchesExactModelsAndKeepsLegacyRXManual() throws {
    for name in seratoPioneerNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(!profile.isPlayer)
    }
    let original = try #require(ControllerFactoryProfile.matching(["XDJ-RX"]))
    #expect(ControllerFactoryProfile.matching(["XDJ-RX"], automaticOnly: true) == original)
    #expect(original.feedback(destination: 20).count == 24)
    let bindings = original.bindings(source: 10)
    #expect(bindings.contains { $0.action == .loadA && $0.number == 81 })
    #expect(bindings.filter { $0.action.hotcueSlot != nil && $0.releaseOnly != true }.count == 16)
    let legacy = try #require(ControllerFactoryProfile.matching(["XDJ-RX legacy 7-bit"]))
    #expect(!legacy.selectsAutomatically && legacy.feedback(destination: 20).isEmpty)
    for name in ["DDJ-SZ3", "DDJ-1000SRT clone", "XDJ-RX4"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
}

@Test @MainActor func controllerSeratoPioneerRoutesEachDeckAndItsDistinctPadChannels() {
    for name in seratoPioneerNames {
        withSeratoPioneer(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            for (channel, deck) in zip(UInt8(0)..<4, DeckID.allCases) {
                let club = name == "XDJ-RX2"
                let pad = club ? 5 + channel : 7 + channel
                seratoPioneerPacket([0x90 | channel, club ? 0 : 11, 127, 0x90 | pad, 7, 127], to: input)
                seratoPioneerPacket(club ? [0x90 | channel, 81, 127] : [0x96, 70 + channel, 127], to: input)
                let actions: [ControllerAction] =
                    deck.leftSide ? [.playA, .hotcue8A, .loadA] : [.playB, .hotcue8B, .loadB]
                #expect(Array(targets.suffix(3)) == actions.map { .init($0, deck: deck) })
            }
            #expect(targets.count == 12)
        }
    }
}

@Test @MainActor func controllerSeratoPioneerKeepsSRTLoopAndJumpMessagesDistinct() {
    withSeratoPioneer("DDJ-1000SRT") { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        seratoPioneerPacket([0x90, 20, 127, 94, 127, 95, 127, 18, 127, 19, 127, 16, 127, 17, 127], to: input)
        #expect(
            targets == [
                .init(.loopA, deck: .a, argument: 4), .init(.jumpBackA, deck: .a), .init(.jumpForwardA, deck: .a),
                .init(.loopDownA, deck: .a), .init(.loopUpA, deck: .a), .init(.loopInA, deck: .a),
                .init(.loopOutA, deck: .a),
            ])
    }
}

@Test @MainActor func controllerSeratoPioneerKeepsOldRXSpeedPacketsSeparateFromRX2Detents() throws {
    let old = try #require(ControllerFactoryProfile.matching(["XDJ-RX"]))
    let newer = try #require(ControllerFactoryProfile.matching(["XDJ-RX2"]))
    let oldJog = try #require(old.bindings(source: 10).first { $0.action == .jogA })
    let newJog = try #require(newer.bindings(source: 10).first { $0.action == .jogA })
    #expect(oldJog.number == 16 && oldJog.mode == .cdjPlatterSpeed)
    #expect(newJog.number == 34 && newJog.mode == .binaryOffset)
    #expect(!newer.bindings(source: 10).contains { $0.action == .jogA && $0.number == 16 })
    withSeratoPioneer("XDJ-RX2") { input in
        var values: [Double] = []
        input.onTargetAction = { target, value in if target.action == .jogA { values.append(value) } }
        seratoPioneerPacket([0xB0, 16, 127, 34, 65], to: input)
        input.flushPendingActions()
        #expect(values == [0.625])
    }
}

@Test @MainActor func controllerSeratoPioneerOriginalRXPartialRecipeUsesItsFourPadAndSpeedTable() throws {
    try withSeratoPioneer("XDJ-RX legacy 7-bit") { input in
        #expect(!input.isInputActive(10))
        let profile = try #require(ControllerFactoryProfile.matching(["XDJ-RX legacy 7-bit"]))
        input.select(10)
        input.applyFactoryProfile(profile)
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        seratoPioneerPacket([0x91, 27, 127, 0xB1, 16, 64], to: input)
        input.flushPendingActions()
        #expect(received.map(\.0) == [.init(.hotcue4B, deck: .b), .init(.jogB, deck: .b)])
        #expect(received.last?.1 == 0.5)
    }
}

@Test @MainActor func controllerSeratoPioneerFourBeatToggleKeepsSyncAndExitsOnTheSecondPress() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .b)
    await model.flushWrites()
    model.setLoopSize(8, deck: .b)
    let sync = try #require(model.playbackSnapshot?.b.synced)
    withSeratoPioneer("DDJ-1000SRT") { input in
        input.onTargetAction = { target, value in
            model.applyController(target.action, value: value, targetDeck: target.deck, argument: target.argument)
        }
        seratoPioneerPacket([0x91, 20, 127], to: input)
        #expect(model.performance.loopBeats(for: .b) == 4)
        #expect(model.playbackSnapshot?.b.loopEnabled == true)
        seratoPioneerPacket([0x81, 20, 0, 0x91, 20, 127], to: input)
        #expect(model.playbackSnapshot?.b.loopEnabled == false)
        #expect(model.playbackSnapshot?.b.synced == sync)
        model.applyController(.loopA, value: 1, targetDeck: .b, argument: 3)
        #expect(model.playbackSnapshot?.b.loopEnabled == false)
        #expect(model.performance.loopBeats(for: .b) == 4)
    }
}

@Test @MainActor func controllerSeratoPioneerSRTUsesOwnConsecutivePadChannelsWithoutDDJ1000Aliases() throws {
    withSeratoPioneer("DDJ-1000SRT") { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        for (channel, deck) in zip(UInt8(7)...10, DeckID.allCases) {
            for slot: UInt8 in 0..<8 {
                targets.removeAll()
                seratoPioneerPacket([0x90 + channel, slot, 127, slot, 0], to: input)
                #expect(targets.count == 1)
                #expect(targets.first?.action.hotcueSlot == Int(slot))
                #expect(targets.first?.deck == deck)
            }
        }
        targets.removeAll()
        for channel: UInt8 in 11..<16 {
            for slot: UInt8 in 0..<8 {
                seratoPioneerPacket([0x90 + channel, slot, 127, slot, 0], to: input)
            }
        }
        #expect(targets.isEmpty)
    }
    let bindings = ControllerFactoryProfile.ddj1000.bindings(source: 10)
    #expect(bindings.contains { $0.action == .hotcue1B && $0.targetDeck == .b && $0.channel == 9 && $0.releaseOnly != true })
    #expect(bindings.contains { $0.action == .hotcue1A && $0.targetDeck == .c && $0.channel == 11 && $0.releaseOnly != true })
}
