import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withVCI300(_ name: String = "VCI-300", _ body: (ControllerMIDIConnection) throws -> Void)
    rethrows
{
    let suite = "vci300-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func vciPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueVCI300KeepsModelBoundaryAndDirectionSpecificFeedback() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["VCI-300"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 61 && data.outputs.count == 24)
    #expect(data.startup.count == 5 && data.shutdown.count == 5)
    #expect(ControllerFactoryProfile.matching(["VCI-300MKII"], automaticOnly: true) != profile)
    #expect(data.outputs.first { $0.action == .playA }?.number == 114)
    #expect(data.outputs.first { $0.action == .cueB }?.number == 49)
    withVCI300 { input in
        #expect(input.isInputActive(10))
        var actions: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in actions.append(target) }
        vciPacket(
            [
                0x90, 37, 127, 56, 127, 54, 127, 54, 0, 82, 127, 73, 127,
                77, 127, 78, 127, 79, 127, 80, 127,
            ], to: input)
        #expect(
            actions == [
                .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.cueA, deck: .a),
                .init(.loadB, deck: .b), .init(.browsePrevious), .init(.browseNext),
                .init(.browsePreviousGroup), .init(.browseNextGroup),
            ])
    }
}

@Test @MainActor func controllerCatalogueVCI300IndependentCountersRetain1600CountScaleAndResetOnReconnect() {
    withVCI300 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        vciPacket([0xB0, 28, 127, 60, 127, 29, 0, 61, 1, 28, 0, 60, 0, 29, 0, 61, 0], to: input)
        #expect(jogs.count == 2)
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(1))
        #expect(jogs.first { $0.0.deck == .b }?.1 == .relative(-1))
        #expect(jogs.allSatisfy { $0.0.argument == 1600 })
        jogs.removeAll()
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        vciPacket([0xB0, 60, 1, 28, 40, 60, 1], to: input)
        #expect(jogs.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueVCI300ComposedModifiersKeepBothHoldsUntilFinalRelease() {
    for order: [UInt8] in [[49, 82], [82, 49]] {
        withVCI300 { input in
            var jogs: [ControllerActionTarget] = []
            var actions: [(ControllerActionTarget, Double)] = []
            input.onJogAction = { target, _ in jogs.append(target) }
            input.onTargetAction = { target, value in if !target.action.isJog { actions.append((target, value)) } }
            vciPacket(
                [
                    0x90, 83, 127, 0xB0, 28, 1, 0x90, order[0], 127, order[1], 127, 0x80, 83, 0, order[0], 0,
                    0xB0, 28, 0, 60, 10, 28, 0, 60, 11,
                ], to: input)
            #expect(jogs.isEmpty)
            #expect(actions.filter { $0.0.action == .jogTouchA }.map(\.1) == [1, 0])
            vciPacket([0x80, order[1], 0, 0xB0, 60, 12, 28, 0, 60, 100, 28, 0, 60, 101], to: input)
            #expect(jogs == [.init(.jogA, deck: .a, argument: 1600)])
        }
    }
}

@Test @MainActor func controllerCatalogueVCI300ShiftIsLocalAndHeldCueReleasesAcrossLayerChange() {
    withVCI300 { input in
        var actions: [(ControllerActionTarget, Double)] = []
        var jogs: [ControllerActionTarget] = []
        input.onTargetAction = { actions.append(($0, $1)) }
        input.onJogAction = { target, _ in jogs.append(target) }
        vciPacket(
            [
                0x90, 36, 127, 49, 127, 37, 127, 56, 127, 38, 127, 0x80, 36, 0,
                0xB0, 29, 0, 61, 50, 29, 0, 61, 51,
            ], to: input)
        #expect(actions.filter { $0.0.action == .cuePreviewA }.map(\.1) == [1, 0])
        #expect(!actions.contains { $0.0.action == .playA || $0.0.action == .keylockA })
        #expect(actions.contains { $0.0.action == .playB })
        #expect(actions.contains { $0.0.action == .tempoResetA })
        #expect(jogs == [.init(.jogB, deck: .b, argument: 1600)])
    }
}

@Test @MainActor func controllerCatalogueVCI300TempoPickupUsesExactCentreAndRearmsAfterShift() {
    withVCI300 { input in
        var tempos: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { tempos.append(value) } }
        vciPacket([0xB0, 13, 127, 45, 96], to: input)
        #expect(tempos.isEmpty)
        vciPacket([0xB0, 13, 64, 45, 0], to: input)
        vciPacket([0xB0, 13, 127, 45, 96], to: input)
        #expect(tempos == [0.5, 1])
        vciPacket([0x90, 49, 127, 0xB0, 13, 0, 45, 0, 0x80, 49, 0, 0xB0, 45, 0, 13, 0, 45, 0], to: input)
        #expect(tempos == [0.5, 1])
        vciPacket([0xB0, 13, 64, 45, 0], to: input)
        #expect(tempos == [0.5, 1, 0.5])
    }
}

@Test func controllerCatalogueVCI300CounterRequiresExplicitLowByte() throws {
    let data = try JSONSerialization.data(withJSONObject: [
        "schemaVersion": 1,
        "profiles": [
            [
                "id": "fixture", "aliases": ["fixture"],
                "inputs": [
                    [
                        "action": "jogA", "kind": "control", "channel": 0, "number": 28,
                        "encoding": "cyclic14BitJog", "inverted": false, "argument": 1600,
                    ]
                ],
                "outputs": [], "startup": [], "shutdown": [], "autoSelect": true,
                "scope": "fixture", "source": "fixture",
            ]
        ],
    ])
    #expect(throws: Error.self) { try ControllerProfileCatalogue.decode(data) }
}

@Test(arguments: ["VCI-300", "VCI-300MKII"]) @MainActor
func controllerCatalogueVCI300NativeTouchStopsWithTheWheelAndPreservesSync(_ name: String) async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    let suite = "vci300-playback-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.onJogAction = { model.applyControllerJog($0, motion: $1) }
    input.onTargetAction = { target, value in
        model.applyController(target.action, value: value, targetDeck: target.deck, argument: target.argument)
    }
    input.sources = [
        .init(
            id: 10, reference: 100, name: name,
            identity: .init(id: 10, device: 1, names: [name]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: name,
            identity: .init(id: 20, device: 1, names: [name]))
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    let sync = model.playbackSnapshot?.a.synced
    vciPacket([0x90, 83, 127, 0xB0, 28, 0, 60, 0, 28, 0, 60, 16], to: input)
    try await Task.sleep(for: .milliseconds(80))
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    let first = try #require(model.playbackSnapshot?.a.sourceFrame)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -100) - first) <= 1)
    vciPacket([0x80, 83, 0], to: input)
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.synced == sync)
}

@Test @MainActor func controllerCatalogueVCI300MKIIDistinctIdentityRetainsHeldCueAndReconnectCleanup() throws {
    let original = try #require(ControllerFactoryProfile.matching(["VCI-300"], automaticOnly: true))
    let mkii = try #require(ControllerFactoryProfile.matching(["VCI-300 MKII"], automaticOnly: true))
    #expect(mkii != original && mkii.definition?.inputs.count == 61 && mkii.definition?.outputs.count == 24)
    #expect(mkii.definition?.audioOutput == nil)
    for alias in ["VCI-300MKII", "VCI-300 MKII", "VCI-300MK2", "Vestax VCI-300 MKII"] {
        #expect(ControllerFactoryProfile.matching([alias], automaticOnly: true) == mkii)
    }
    withVCI300("VCI-300MKII") { input in
        #expect(input.isInputActive(10) && mkii.bindings(source: 10).count == 61)
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (number, deck): (UInt8, DeckID) in [(36, .a), (55, .b)] {
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                vciPacket([0x90, number, 127, number, 127, off, number, off == 0x80 ? 127 : 0], to: input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
        }
        events.removeAll()
        vciPacket([0x90, 36, 127, 55, 127], to: input)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        #expect(events.map(\.1) == [1, 1, 0, 0])
        input.sources = sources
        input.reconcileFactoryProfiles()
        events.removeAll()
        vciPacket([0x90, 36, 127, 36, 0], to: input)
        #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueVCI300MKIIPairedCountersAndPitchRetainIndependentNativeCodecs() {
    withVCI300("VCI-300MKII") { input in
        input.currentTargetValue = { _ in 0.5 }
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var tempos: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, value in
            if target.action == .tempoA || target.action == .tempoB { tempos.append((target, value)) }
        }
        vciPacket([0xB0, 28, 127, 60, 127, 29, 0, 61, 1, 28, 0, 60, 0, 29, 0, 61, 0], to: input)
        #expect(jogs.count == 2)
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(1))
        #expect(jogs.first { $0.0.deck == .b }?.1 == .relative(-1))
        #expect(jogs.allSatisfy { $0.0.argument == 1600 })
        vciPacket([0xB0, 13, 64, 45, 0, 19, 64, 51, 0], to: input)
        vciPacket([0xB0, 13, 127, 45, 96, 19, 0, 51, 0], to: input)
        #expect(tempos.count == 4)
        #expect(tempos.last { $0.0.deck == .a }?.1 == 1)
        #expect(tempos.last { $0.0.deck == .b }?.1 == 0)
    }
}
