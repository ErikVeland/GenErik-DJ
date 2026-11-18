import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withBCD3000(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "bcd3000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "BCD3000 MIDI 1"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func bcdPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueBCD3000UsesStandardModeFactoryLifecycleAndKeeps2000Separate() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["BCD3000 MIDI 1"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 32 && data.outputs.count == 8)
    #expect(data.startup.count == 27 && data.shutdown.count == 25)
    #expect(data.startup.suffix(2) == [[0xB0, 99, 127], [0xB0, 100, 127]])
    #expect(data.shutdown == (1...25).map { [0xB0, UInt8($0), 0] })
    #expect(profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["Behringer BCD2000"], automaticOnly: true) == nil)
    let feedback = profile.feedback(destination: 20)
    #expect(feedback.first { $0.action == .cueA }?.message(value: 1) == [0xB0, 2, 127])
    #expect(feedback.first { $0.action == .cueB }?.message(value: 0) == [0xB0, 1, 0])
    #expect(feedback.first { $0.action == .playB }?.message(value: 1) == [0xB0, 10, 127])
    #expect(feedback.first { $0.action == .loopA }?.number == 21)
}

@Test @MainActor func controllerCatalogueBCD3000SeparatesCueSetPreviewAndOwnedHeldBends() {
    withBCD3000 { input in
        #expect(input.isInputActive(10))
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        bcdPacket(
            [
                0x90, 4, 127, 10, 127, 19, 127, 0x80, 19, 127, 0x90, 2, 127, 3, 127,
                0x80, 2, 127, 3, 127, 0x90, 35, 127, 36, 127,
            ], to: input)
        #expect(
            events.map { $0.0.action } == [
                .cueSetA, .cueSetB, .cuePreviewA, .cuePreviewA,
                .pitchBendDownA, .pitchBendUpA, .pitchBendDownA, .pitchBendUpA,
                .cueA, .cueB,
            ])
        #expect(events.map { $0.1 } == [1, 1, 1, 0, 1, 1, 0, 0, 1, 1])
    }
}

@Test @MainActor func controllerCatalogueBCD3000RetainsPitchPolarityPickupAndFactoryData4Meaning() {
    withBCD3000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { _ in 0.5 }
        input.onTargetAction = { events.append(($0, $1)) }
        bcdPacket([0xB0, 11, 127, 12, 127], to: input)
        #expect(events.isEmpty)
        bcdPacket([0xB0, 11, 64, 12, 64], to: input)
        #expect(events.count == 2 && events.allSatisfy { abs($0.1 - (1 - 64.0 / 127)) < 0.000001 })
        events.removeAll()
        bcdPacket([0xB0, 11, 0, 12, 0, 16, 64, 0x90, 17, 127, 25, 127, 15, 127, 23, 127], to: input)
        #expect(events.count == 2 && Set(events.map { $0.0.action }) == [.tempoA, .tempoB])
        #expect(events.allSatisfy { $0.1 == 1 })
    }
}

@Test @MainActor func controllerCatalogueBCD3000FactoryWheelsAndReloopKeepDeckTargets() {
    withBCD3000 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var actions: [ControllerActionTarget] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, _ in actions.append(target) }
        bcdPacket([0xB0, 19, 65, 18, 63, 0x90, 5, 127, 11, 127], to: input)
        #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 100 })
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(1))
        #expect(jogs.first { $0.0.deck == .b }?.1 == .relative(-1))
        #expect(actions == [.init(.reloopA, deck: .a), .init(.reloopB, deck: .b)])
    }
}
