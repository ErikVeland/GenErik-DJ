import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withVCI100MK2(
    fourDecks: Bool = true, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "vci100mk2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { fourDecks ? DeckID.allCases : [.a, .b] })
    let name = "VCI-100MKII"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func vci100Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueVCI100MK2KeepsSeparateFourTargetCoreAndBoundedCleanup() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["VCI-100MKII"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 126 && data.outputs.count == 28)
    #expect(data.bankChanges?.count == 4)
    #expect(data.startup.isEmpty && data.shutdown.count == 16)
    #expect(ControllerFactoryProfile.matching(["VCI-100"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["VCI-100MKIII"], automaticOnly: true) == nil)
    withVCI100MK2 { input in
        #expect(input.isInputActive(10))
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        vci100Packet([0x90, 34, 127, 0x91, 34, 127, 0x92, 34, 127, 0x93, 34, 127], to: input)
        #expect(
            targets == [
                .init(.playA, deck: .a), .init(.playB, deck: .b),
                .init(.playA, deck: .c), .init(.playB, deck: .d),
            ])
    }
    withVCI100MK2(fourDecks: false) { input in
        var decks: [DeckID?] = []
        input.onTargetAction = { target, _ in decks.append(target.deck) }
        vci100Packet([0x90, 34, 127, 0x92, 34, 127, 0x93, 34, 127], to: input)
        #expect(decks == [.a])
    }
}

@Test @MainActor func controllerCatalogueVCI100MK2UsesExplicitSixteenOffsetPairsAnd2400CountJogs() {
    withVCI100MK2 { input in
        var tempos: [DeckID: Double] = [:]
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in
            if [.tempoA, .tempoB].contains(target.action), let deck = target.deck { tempos[deck] = value }
        }
        input.onJogAction = { jogs.append(($0, $1)) }
        vci100Packet(
            [
                0xB0, 27, 64, 43, 0, 0xB1, 17, 0, 33, 0,
                0xB2, 27, 127, 43, 127, 0xB3, 17, 64, 33, 1,
            ], to: input)
        #expect(tempos == [.a: 0.5, .b: 0, .c: 16383.0 / 16384, .d: 8193.0 / 16384])
        vci100Packet([0xB0, 16, 65, 0xB3, 16, 63], to: input)
        #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 2400 })
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(1))
        #expect(jogs.first { $0.0.deck == .d }?.1 == .relative(-1))
    }
}

@Test @MainActor func controllerCatalogueVCI100MK2MixerPairsDoNotUseTheStandardLowByteOffset() {
    withVCI100MK2 { input in
        var amounts: [ControllerActionTarget: Double] = [:]
        input.onTargetAction = { amounts[$0] = $1 }
        vci100Packet(
            [
                0xB4, 16, 127, 32, 127, 0xB0, 28, 64, 44, 0,
                0xB1, 22, 0, 38, 0,
            ], to: input)
        #expect(amounts[.init(.crossfader)] == 1)
        #expect(amounts[.init(.levelA, deck: .a)] == 8192.0 / 16383)
        #expect(amounts[.init(.levelB, deck: .b)] == 0)
        vci100Packet([0xB4, 48, 0, 0xB0, 60, 127, 0xB1, 54, 127], to: input)
        #expect(amounts[.init(.crossfader)] == 1)
        #expect(amounts[.init(.levelA, deck: .a)] == 8192.0 / 16383)
        #expect(amounts[.init(.levelB, deck: .b)] == 0)
    }
}

@Test @MainActor func controllerCatalogueVCI100MK2BankReleasesOnlyItsSideAndKeepsPhysicalShift() {
    withVCI100MK2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { [.tempoA, .tempoB].contains($0.action) ? 0.5 : nil }
        input.onTargetAction = { events.append(($0, $1)) }
        vci100Packet([0x90, 35, 127, 0x91, 35, 127, 0x94, 36, 127, 0x90, 53, 127], to: input)
        #expect(events.filter { $0.0.action == .cuePreviewA }.map(\.1) == [1, 0])
        #expect(events.filter { $0.0.action == .cuePreviewB }.map(\.1) == [1])
        vci100Packet([0x92, 55, 127, 34, 127, 0xB2, 27, 10], to: input)
        #expect(events.contains { $0.0 == .init(.loadA, deck: .c) })
        #expect(!events.contains { $0.0 == .init(.playA, deck: .c) })
        vci100Packet([0x84, 36, 0, 0xB2, 43, 0, 27, 127, 43, 127], to: input)
        #expect(!events.contains { $0.0.action == .tempoA })
        vci100Packet([0xB2, 27, 64, 43, 0], to: input)
        #expect(events.last?.0 == .init(.tempoA, deck: .c) && events.last?.1 == 0.5)
        vci100Packet([0x81, 35, 0], to: input)
        #expect(events.last?.0.action == .cuePreviewB && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueVCI100MK2ShiftedReleasesRearmButtonsWithoutAlternateActions() {
    for release: UInt8 in [0x90, 0x80] {
        withVCI100MK2 { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { events.append(($0, $1)) }
            vci100Packet(
                [
                    0x90, 35, 127, 34, 127, 42, 127, 0x94, 36, 127,
                    0x90, 67, 127, 66, 127, 74, 127, release, 67, 0, 66, 0, 74, 0,
                    0x84, 36, 0, 0x90, 34, 127, 42, 127,
                ], to: input)
            #expect(events.filter { $0.0.action == .cuePreviewA }.map(\.1) == [1, 0])
            #expect(events.filter { $0.0.action == .playA }.count == 2)
            #expect(events.filter { $0.0.action == .hotcue1A }.count == 2)
            #expect(events.count == 6)
        }
    }
}

@Test @MainActor func controllerCatalogueVCI100MK2EitherPhysicalShiftGuardsLoopSizeUntilBothRelease() {
    withVCI100MK2 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        vci100Packet([0x94, 36, 127, 52, 127, 0x84, 36, 0, 0x90, 51, 127, 51, 0, 34, 127], to: input)
        #expect(events == [.init(.playA, deck: .a)])
        vci100Packet([0x84, 52, 0, 0x90, 51, 127, 0x94, 55, 127, 56, 127], to: input)
        #expect(events.suffix(3) == [.init(.loopDownA, deck: .a), .init(.browsePrevious), .init(.browseNext)])
    }
}

@Test @MainActor func controllerCatalogueVCI100MK2NativeScratchUsesPublishedResolutionAndRetainsSync() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.configureControllerMIDI()
    model.controllerInput.sources = [
        .init(
            id: 10, reference: 100, name: "VCI-100MKII",
            identity: .init(id: 10, device: 1, names: ["VCI-100MKII"]))
    ]
    model.controllerInput.reconcileFactoryProfiles()
    #expect(model.controllerInput.isInputActive(10))
    let sync = model.playbackSnapshot?.a.synced
    vci100Packet([0x90, 59, 127, 0xB0, 16, 80], to: model.controllerInput)
    try await Task.sleep(for: .milliseconds(80))
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    let first = try #require(model.playbackSnapshot?.a.sourceFrame)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -100) - first) <= 1)
    vci100Packet([0x90, 52, 127], to: model.controllerInput)
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.synced == sync)
}
