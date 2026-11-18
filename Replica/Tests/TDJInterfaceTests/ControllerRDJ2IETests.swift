import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRDJ2IE(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "rdj2-ie-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DIGITALJOCKEY2"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func rdj2IEPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRDJ2IEKeepsEditionIdentityAndDocumentedSplitAudio() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DIGITALJOCKEY2"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 77 && data.outputs.count == 12)
    #expect(data.startup.count == 32 && data.shutdown.count == 32)
    #expect(profile.hasAutomaticSplitOutput)
    for name in [
        "Reloop Digital Jockey 2 Controller Edition", "Reloop Digital Jockey 2 Master Edition", "Reloop Jockey 3 ME",
    ] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
    #expect(
        ControllerFactoryProfile.matching(
            ["DIGITALJOCKEY2", "Reloop Digital Jockey 2 Master Edition"], automaticOnly: true) == nil)
    #expect(data.inputs.compactMap(\.targetDeck).allSatisfy { $0 == .a || $0 == .b })
}

@Test @MainActor func controllerCatalogueRDJ2IEReleasesShiftedCueBendAndLoadWithoutEject() {
    withRDJ2IE { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rdj2IEPacket([0x90, 24, 127, 3, 127, 19, 127, 54, 127, 49, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .pitchBendDownA, .loadA])
        rdj2IEPacket([0x90, 54, 0, 33, 0, 49, 0, 24, 127, 19, 127], to: input)
        #expect(events.map { $0.0.action }.suffix(4) == [.cuePreviewA, .pitchBendDownA, .cuePreviewA, .loadA])
        #expect(events.filter { $0.1 == 0 }.map { $0.0.action } == [.cuePreviewA, .pitchBendDownA])
        events.removeAll()
        rdj2IEPacket([0x90, 84, 127, 64, 127, 79, 127, 114, 0, 94, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewB, .pitchBendUpB, .loadB, .cuePreviewB, .pitchBendUpB])
    }
}

@Test @MainActor func controllerCatalogueRDJ2IEKeepsZeroNeutralAndMeasuredCountScratch() {
    withRDJ2IE { input in
        var touches: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .jogTouchA { touches.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        rdj2IEPacket([0xB0, 11, 0, 11, 64, 41, 65, 101, 65, 0x90, 29, 126], to: input)
        #expect(touches.isEmpty && jogs.isEmpty)
        rdj2IEPacket([0x90, 29, 127, 0xB0, 11, 66, 11, 63], to: input)
        #expect(touches == [1])
        #expect(jogs.first?.0 == .init(.jogA, deck: .a, argument: 148))
        #expect(jogs.first?.1 == .relative(1))
        rdj2IEPacket([0x80, 29, 127, 0x90, 89, 127, 0xB0, 71, 65], to: input)
        #expect(touches == [1, 0])
        #expect(jogs.last?.0 == .init(.jogB, deck: .b, argument: 148))
    }
}

@Test @MainActor func controllerCatalogueRDJ2IEPitchAndMixerRetainFactoryWireChannelsAndPickup() {
    withRDJ2IE { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { events.append(($0, $1)) }
        rdj2IEPacket([0xE0, 0, 0], to: input)
        #expect(events.isEmpty)
        rdj2IEPacket([0xE0, 0, 64], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 0.5)
        rdj2IEPacket([0xE0, 127, 127, 0xE1, 0, 0], to: input)
        #expect(events.first { $0.0.action == .tempoB }?.1 == 1)
        #expect(events.last { $0.0.action == .tempoA }?.1 == 0)
        events.removeAll()
        rdj2IEPacket(
            [0xB0, 2, 1, 3, 2, 4, 3, 5, 4, 6, 5, 62, 6, 63, 7, 64, 8, 65, 9, 66, 10, 15, 11, 16, 12, 17, 13, 18, 14],
            to: input)
        #expect(
            Set(events.map { $0.0.action }) == [
                .gainA, .highA, .midA, .lowA, .levelA, .gainB, .highB, .midB, .lowB, .levelB, .master, .monitor,
                .cueMix, .crossfader,
            ])
    }
}

@Test @MainActor func controllerCatalogueRDJ2IELoopsAndShiftFilterUseTheirOwnAddresses() {
    withRDJ2IE { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rdj2IEPacket([0x90, 15, 127, 16, 127, 17, 127, 18, 127, 75, 127, 76, 127, 77, 127, 78, 127], to: input)
        #expect(
            events.map { $0.0.action } == [
                .loopInA, .loopOutA, .loopEnableA, .loopA, .loopInB, .loopOutB, .loopEnableB, .loopB,
            ])
        events.removeAll()
        rdj2IEPacket([0x90, 45, 127, 46, 127, 47, 127, 48, 127, 23, 127, 83, 127, 27, 127, 87, 127], to: input)
        #expect(events.isEmpty)
        rdj2IEPacket([0xB0, 40, 65, 99, 63, 33, 127, 93, 0, 0x90, 50, 127, 110, 127], to: input)
        #expect(
            Set(events.map { $0.0.action }) == [
                .loopSizeA, .loopSizeB, .filterKnobA, .filterKnobB, .filterToggleA, .filterToggleB,
            ])
        events.removeAll()
        rdj2IEPacket([0xB0, 40, 64, 99, 0], to: input)
        #expect(events.isEmpty)
    }
}
