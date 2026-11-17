import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRDJ2Controller(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "rdj2-controller-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DIGITAL JOCKEY"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func rdj2ControllerPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRDJ2ControllerKeepsIdentityWithoutTouchOrAudio() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DIGITAL JOCKEY"], automaticOnly: true))
    #expect(
        profile
            == ControllerFactoryProfile.matching(["Reloop Digital Jockey 2 Controller Edition"], automaticOnly: true))
    #expect(profile != ControllerFactoryProfile.matching(["DIGITALJOCKEY2"], automaticOnly: true))
    #expect(
        ControllerFactoryProfile.matching(
            ["DIGITAL JOCKEY", "Reloop Digital Jockey 2 Master Edition"], automaticOnly: true) == nil)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 45 && data.outputs.count == 10)
    #expect(data.startup.count == 30 && data.shutdown.count == 30)
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(!data.inputs.contains { $0.action == .jogTouchA || $0.action == .jogTouchB })
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewB })
    #expect(cue.message(value: 1) == [0x90, 84, 127])
    #expect(cue.message(value: 0) == [0x90, 84, 0])
}

@Test @MainActor func controllerCatalogueRDJ2ControllerKeepsHeldCueBendAndOneLoadPerPress() {
    withRDJ2Controller { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rdj2ControllerPacket([0x90, 24, 127, 3, 127, 19, 127, 19, 127, 0x80, 24, 127, 3, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .pitchBendDownA, .loadA, .cuePreviewA, .pitchBendDownA])
        #expect(events.suffix(2).allSatisfy { $0.1 == 0 })
        events.removeAll()
        rdj2ControllerPacket([0x90, 84, 127, 64, 127, 79, 127, 0x80, 84, 0, 64, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewB, .pitchBendUpB, .loadB, .cuePreviewB, .pitchBendUpB])
    }
}

@Test @MainActor func controllerCatalogueRDJ2ControllerKeepsSignedWheelsAndIgnoresEmptyTouchHandlers() {
    withRDJ2Controller { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var events: [ControllerActionTarget] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, _ in events.append(target) }
        rdj2ControllerPacket(
            [0xB0, 11, 64, 71, 64, 0x90, 29, 127, 89, 127, 27, 127, 87, 127, 26, 127, 86, 127], to: input)
        #expect(jogs.isEmpty && events.isEmpty)
        rdj2ControllerPacket([0xB0, 11, 65], to: input)
        #expect(jogs.last?.0.action == .wheelJogA && jogs.last?.1 == .relative(1))
        rdj2ControllerPacket([0xB0, 71, 63], to: input)
        #expect(jogs.last?.0.action == .wheelJogB && jogs.last?.1 == .relative(-1))
        rdj2ControllerPacket([0xB0, 11, 0], to: input)
        #expect(jogs.last?.1 == .relative(-64))
    }
}

@Test @MainActor func controllerCatalogueRDJ2ControllerKeepsFullPitchLowBitsPickupAndChannels() {
    withRDJ2Controller { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { events.append(($0, $1)) }
        rdj2ControllerPacket([0xE0, 0, 0], to: input)
        #expect(events.isEmpty)
        rdj2ControllerPacket([0xE0, 0, 64], to: input)
        let centre = events.last?.1 ?? -1
        #expect(abs(centre - 0.5) < 0.0001)
        rdj2ControllerPacket([0xE0, 1, 64], to: input)
        #expect((events.last?.1 ?? 1) < centre)
        rdj2ControllerPacket([0xE0, 127, 127, 0xE1, 0, 0], to: input)
        #expect(events.last { $0.0.action == .tempoA }?.1 == 0)
        #expect(events.last { $0.0.action == .tempoB }?.1 == 1)
        let count = events.count
        rdj2ControllerPacket([0xE2, 0, 0], to: input)
        #expect(events.count == count)
    }
}

@Test @MainActor func controllerCatalogueRDJ2ControllerKeepsLoopsMixerAndStrictEncoders() {
    withRDJ2Controller { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        rdj2ControllerPacket([0x90, 15, 127, 16, 127, 17, 127, 18, 127, 75, 127, 76, 127, 77, 127, 78, 127], to: input)
        #expect(
            events.map(\.action) == [
                .loopInA, .loopOutA, .loopEnableA, .loopA, .loopInB, .loopOutB, .loopEnableB, .loopB,
            ])
        events.removeAll()
        rdj2ControllerPacket([0xB0, 10, 64, 69, 0, 19, 0, 19, 64], to: input)
        #expect(events.isEmpty)
        rdj2ControllerPacket([0xB0, 10, 65, 69, 63, 19, 65], to: input)
        #expect(Set(events.map(\.action)) == [.loopSizeA, .loopSizeB, .browse])
        events.removeAll()
        rdj2ControllerPacket(
            [0xB0, 2, 1, 3, 2, 4, 3, 5, 4, 6, 5, 62, 6, 63, 7, 64, 8, 65, 9, 66, 10, 15, 11, 16, 12, 17, 13, 18, 14],
            to: input)
        #expect(
            Set(events.map(\.action)) == [
                .gainA, .highA, .midA, .lowA, .levelA, .gainB, .highB, .midB, .lowB, .levelB, .master, .monitor,
                .cueMix, .crossfader,
            ])
    }
}
