import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withVCI400(
    fourDecks: Bool = true, _ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void
) rethrows {
    let suite = "vci400-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        },
        deckAvailability: { fourDecks ? DeckID.allCases : [.a, .b] })
    let name = "VCI-400"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func vci400Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueVCI400KeepsDirectFourTargetLoadAndSeparateEGEFirmware() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["VCI-400"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 136 && data.outputs.count == 16)
    #expect(data.startup.count == 16 && data.shutdown.count == 16)
    #expect(!data.outputs.contains { $0.action.hotcueSlot != nil })
    for name in ["VCI-400 EGE", "Vestax VCI-400 Ean Golden Edition", "VCI-400 MK2"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
    withVCI400 { input, packets in
        #expect(input.isInputActive(10))
        #expect(packets.count == 16)
        for channel: UInt8 in 2...5 {
            #expect(
                packets.filter { $0[0] == 0x90 + channel } == [
                    [0x90 + channel, 22, 0], [0x90 + channel, 23, 0],
                    [0x90 + channel, 24, 0], [0x90 + channel, 21, 127],
                ])
        }
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        vci400Packet([0x92, 2, 127, 0x93, 2, 127, 0x94, 2, 127, 0x95, 2, 127], to: input)
        #expect(
            targets == [
                .init(.loadA, deck: .a), .init(.loadB, deck: .b),
                .init(.loadA, deck: .c), .init(.loadB, deck: .d),
            ])
    }
    withVCI400(fourDecks: false) { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        vci400Packet([0x94, 2, 127, 0x95, 2, 127, 0x92, 2, 127], to: input)
        #expect(targets == [.init(.loadA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueVCI400SharedPadsRequireTheirOwnDeckMode() {
    withVCI400 { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        vci400Packet(
            [
                0x92, 7, 127, 7, 0, 22, 127, 7, 127, 7, 0,
                23, 127, 8, 127, 8, 0, 24, 127, 9, 127, 9, 0,
                0x93, 7, 127,
            ], to: input)
        #expect(
            targets == [
                .init(.hotcue1A, deck: .a), .init(.fixedLoopA, deck: .a, argument: 0.125),
                .init(.hotcue1B, deck: .b),
            ])
        targets.removeAll()
        vci400Packet(
            [
                0x92, 21, 127, 7, 127, 7, 0, 0x90, 1, 127,
                0x92, 7, 127, 7, 0, 22, 127, 14, 127,
            ], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a), .init(.fixedLoopA, deck: .a, argument: 16)])
    }
}

@Test @MainActor func controllerCatalogueVCI400LastPadRetainsPublishedDeckDDispatch() {
    withVCI400 { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        vci400Packet([0x95, 14, 127, 14, 0, 22, 127, 14, 127], to: input)
        #expect(targets == [.init(.hotcue8B, deck: .d), .init(.fixedLoopB, deck: .d, argument: 16)])
    }
}

@Test @MainActor func controllerCatalogueVCI400BankLossReleasesOnlyItsSideWithoutClearingGlobalShift() {
    for release: UInt8 in [0x92, 0x82] {
        withVCI400 { input, _ in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { events.append(($0, $1)) }
            vci400Packet(
                [
                    0x92, 25, 127, 39, 127, 0x93, 25, 127, 0x90, 1, 127,
                    release, 34, 0,
                ], to: input)
            #expect(events.filter { $0.0.action == .cuePreviewA }.map(\.1) == [1, 0])
            #expect(events.filter { $0.0.action == .jogTouchA }.map(\.1) == [1, 0])
            #expect(events.filter { $0.0.action == .cuePreviewB }.map(\.1) == [1])
            vci400Packet([0x94, 2, 127, 2, 0, 0x80, 1, 0, 0x94, 2, 127], to: input)
            #expect(events.filter { $0.0.action == .loadA }.map(\.0) == [.init(.loadA, deck: .c)])
        }
    }
}

@Test @MainActor func controllerCatalogueVCI400BankPickupDiscardsOnlyItsSidesPitchPair() {
    withVCI400 { input, _ in
        var targets: [ControllerActionTarget] = []
        input.currentTargetValue = { [.tempoA, .tempoB].contains($0.action) ? 0.5 : nil }
        input.onTargetAction = { target, _ in if [.tempoA, .tempoB].contains(target.action) { targets.append(target) } }
        vci400Packet([0xB2, 18, 64, 50, 0, 0xB3, 18, 64, 50, 0], to: input)
        vci400Packet([0xB2, 18, 100, 0xB3, 18, 100], to: input)
        targets.removeAll()
        vci400Packet([0x94, 34, 127, 0xB2, 50, 127, 0xB3, 50, 127], to: input)
        #expect(targets == [.init(.tempoB, deck: .b)])
        vci400Packet([0xB2, 18, 127, 50, 127], to: input)
        #expect(targets.count == 1)
        vci400Packet([0xB2, 18, 64, 50, 0], to: input)
        #expect(targets.last == .init(.tempoA, deck: .a))
    }
}

@Test @MainActor func controllerCatalogueVCI400LoopEncoderKeepsSingleInvertedStepsAnd4096CountJogs() {
    withVCI400 { input, _ in
        var sizes: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .loopSizeA { sizes.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        vci400Packet(
            [
                0xB2, 6, 65, 6, 127, 6, 63, 6, 0, 6, 64, 19, 66,
                0xB5, 19, 63,
            ], to: input)
        #expect(sizes == [0.5 - 1.0 / 126, 0.5 - 1.0 / 126, 0.5 + 1.0 / 126, 0.5 + 1.0 / 126])
        #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 4096 })
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(2))
        #expect(jogs.first { $0.0.deck == .d }?.1 == .relative(-1))
        sizes.removeAll()
        vci400Packet([0x90, 1, 127, 0xB2, 6, 65], to: input)
        #expect(sizes.isEmpty)
    }
}

@Test func controllerCatalogueVCI400LifecycleRemainsBoundedAcrossStartupAndShutdown() throws {
    for (startup, shutdown, valid) in [(16, 16, true), (32, 32, true), (32, 33, false), (65, 0, false)] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "fixture", "aliases": ["fixture"],
                    "inputs": [
                        [
                            "action": "playA", "kind": "note", "channel": 0,
                            "number": 0, "encoding": "absolute", "inverted": false,
                        ]
                    ],
                    "outputs": [], "startup": Array(repeating: [0x90, 21, 127], count: startup),
                    "shutdown": Array(repeating: [0x90, 21, 0], count: shutdown),
                    "autoSelect": true, "scope": "fixture", "source": "fixture",
                ]
            ],
        ])
        if valid {
            #expect(throws: Never.self) { try ControllerProfileCatalogue.decode(data) }
        } else {
            #expect(throws: Error.self) { try ControllerProfileCatalogue.decode(data) }
        }
    }
}

@Test @MainActor func controllerCatalogueVCI400NativeFixedLoopsAndBankScratchReleaseKeepSync() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    let suite = "vci400-native-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "VCI-400"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    input.onJogAction = { model.applyControllerJog($0, motion: $1) }
    input.onTargetAction = { target, value in
        model.applyController(target.action, value: value, targetDeck: target.deck, argument: target.argument)
    }
    let sync = model.playbackSnapshot?.a.synced
    vci400Packet([0x92, 22, 127, 12, 127, 12, 0, 12, 127], to: input)
    #expect(model.performance.loopBeats(for: .a) == 4)
    #expect(model.playbackSnapshot?.a.loopEnabled == true)
    vci400Packet([0x92, 20, 127, 39, 127, 0xB2, 19, 80], to: input)
    try await Task.sleep(for: .milliseconds(80))
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.touchActive == true)
    vci400Packet([0x92, 34, 0], to: input)
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.synced == sync)
}
