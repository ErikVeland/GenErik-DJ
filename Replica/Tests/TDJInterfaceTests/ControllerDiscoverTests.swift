import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDiscover(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "discover-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Ion Discover DJ"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func discoverPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDiscoverKeepsOriginalAndProSeparate() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["ION Discover DJ"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 25 && data.outputs.count == 6)
    #expect(data.startup.count == 9 && data.shutdown.count == 9)
    #expect(data.startup.last == [0x90, 0x48, 127])
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["Ion Discover DJ Pro"], automaticOnly: true) != profile)
    #expect(
        !data.inputs.contains {
            [.midA, .midB, .cueA, .cueB, .pitchBendDownA, .pitchBendDownB, .pitchBendUpA, .pitchBendUpB].contains(
                $0.action)
        })
}

@Test @MainActor func controllerCatalogueDiscoverTempoButtonsActOncePerFreshPress() {
    withDiscover { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        discoverPacket([0x90, 0x43, 127, 0x43, 127, 0x44, 127, 0x45, 127, 0x46, 127], to: input)
        #expect(events.map { $0.0.action } == [.tempoDownA, .tempoUpA, .tempoDownB, .tempoUpB])
        discoverPacket([0x80, 0x43, 64, 0x44, 0, 0x90, 0x43, 127, 0x44, 127], to: input)
        #expect(events.map { $0.0.action }.suffix(2) == [.tempoDownA, .tempoUpA])
        #expect(events.allSatisfy { $0.1 == 1 })
    }
}

@Test @MainActor func controllerCatalogueDiscoverKeepsCueTouchJogsAndUnsupportedButtonsDistinct() {
    withDiscover { input in
        var events: [(ControllerActionTarget, Double)] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.onJogAction = { jogs.append(($0, $1)) }
        discoverPacket(
            [0x90, 0x3B, 127, 0x4A, 127, 0x3B, 0, 0x42, 127, 0x80, 0x42, 127, 0x90, 0x4B, 127, 0x34, 127], to: input)
        #expect(
            events.map { $0.0.action } == [
                .cuePreviewA, .playA, .cuePreviewA, .cuePreviewB, .cuePreviewB, .loadA, .loadB,
            ])
        events.removeAll()
        discoverPacket([0x90, 0x4D, 127, 0x4E, 127, 0xB0, 0x19, 3, 0x18, 127], to: input)
        #expect(events.map { $0.0.action } == [.jogTouchA, .jogTouchB])
        #expect(jogs.map { $0.0.argument } == [518.4, 518.4])
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(3))
        #expect(jogs.first { $0.0.deck == .b }?.1 == .relative(-1))
        discoverPacket([0x80, 0x4D, 127, 0x90, 0x4E, 0], to: input)
        #expect(events.suffix(2).map { $0.1 } == [0, 0])
        events.removeAll()
        discoverPacket([0x90, 0x33, 127, 0x3C, 127, 0x48, 127, 0x4F, 127, 0x91, 0x4A, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueDiscoverRestoresPhysicalVolumeAndTwoBandEQ() {
    withDiscover { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        discoverPacket([0xB0, 8, 1, 9, 2, 20, 3, 21, 4, 16, 5, 17, 6, 23, 7, 10, 0], to: input)
        #expect(
            Set(events.map { $0.0.action }) == [.levelA, .levelB, .lowA, .lowB, .highA, .highB, .master, .crossfader])
        #expect(events.first { $0.0.action == .crossfader }?.1 == 1)
        input.currentTargetValue = { $0.action == .levelA ? 0.5 : nil }
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = [
            .init(
                id: 10, reference: 100, name: "Ion Discover DJ",
                identity: .init(id: 10, device: 1, names: ["Ion Discover DJ"]))
        ]
        input.reconcileFactoryProfiles()
        events.removeAll()
        discoverPacket([0xB0, 8, 0], to: input)
        #expect(events.isEmpty)
        discoverPacket([0xB0, 8, 64], to: input)
        #expect(events.last?.0.action == .levelA)
    }
}

@Test @MainActor func controllerCatalogueDiscoverRejectsNonPressNativeTempoSteps() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    for value in [0.0, -1, 2, Double.nan, Double.infinity] {
        model.applyController(.tempoUpA, value: value)
        model.applyController(.tempoDownB, value: value)
    }
    #expect(model.playbackSnapshot?.masterBPM == 120)
    #expect(ControllerAction.tempoUpA.isButton && !ControllerAction.tempoUpA.isMomentary)
    #expect(!ControllerAction.tempoUpA.supportsFeedback)
    #expect(ControllerAction.tempoDownA.assigned(to: .d) == .tempoDownB)
}
