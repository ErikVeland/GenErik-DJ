import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withAIR(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original-air-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Hercules DJControl AIR"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func airPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueAIRKeepsFactoryLifecycleAndHardwareGainSeparate() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Hercules DJControl AIR"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 43 && data.outputs.count == 8)
    #expect(data.startup == [[0xB0, 127, 0], [0x90, 59, 127], [0x90, 60, 127], [0x90, 45, 127]])
    #expect(data.shutdown == [[0xB0, 127, 0]] && profile.hasAutomaticSplitOutput)
    #expect(
        ControllerFactoryProfile.matching(["Hercules DJControl AIR", "DJControl AIR Plus"], automaticOnly: true) == nil)
    withAIR { input in
        #expect(input.isInputActive(10))
        var actions: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in actions.append(target) }
        airPacket([0x90, 59, 127, 60, 127, 0xB0, 63, 127], to: input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAIRPitchConsumesFreshBooleanLowBitsAndRetainsPickup() {
    withAIR { input in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        airPacket([0xB0, 88, 127, 52, 0, 88, 0], to: input)
        #expect(values.isEmpty)
        airPacket([0xB0, 52, 64, 88, 0], to: input)
        #expect(values == [1 - 128.0 / 255])
        airPacket([0xB0, 52, 64, 88, 1], to: input)
        #expect(values.last == 1 - 129.0 / 255)
        airPacket([0xB0, 52, 64, 88, 127], to: input)
        #expect(values.last == 1 - 129.0 / 255)
        let count = values.count
        airPacket([0xB0, 88, 0], to: input)
        #expect(values.count == count)
        airPacket([0xB0, 52, 127, 88, 127], to: input)
        #expect(values.last == 0)
        airPacket([0xB0, 52, 0, 88, 0], to: input)
        #expect(values.last == 1)
    }
}

@Test func controllerCatalogueAIRPitchCodecRequiresFactorySevenBitPairs() {
    var state = ControllerMIDIValueState()
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append([0x90, 52, 64, 0xB0, 88, 1]) {
        #expect(state.decode(message, encoding: .airTempo, number: 52, lowNumber: 88) == nil)
    }
    #expect(ControllerMIDIEncoding.airTempo.isPairedCC && !ControllerMIDIEncoding.airTempo.isRelative)
    #expect(!ControllerMIDIEncoding.airTempo.supportsLearning)
}

@Test @MainActor func controllerCatalogueAIRKeepsPressureJogsAndNativeHeldBendsSeparate() {
    withAIR { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var events: [(ControllerAction, Double)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { events.append(($0.action, $1)) }
        airPacket([0xB0, 50, 1, 48, 3], to: input)
        #expect(jogs.count == 1 && jogs[0].0.action == .wheelJogA && jogs[0].1 == .relative(3))
        airPacket(
            [
                0x90, 22, 127, 0xB0, 50, 64, 0x80, 22, 127, 0xB0, 50, 1,
                0x90, 13, 127, 14, 127, 0x80, 13, 127, 14, 127,
            ], to: input)
        #expect(jogs.count == 2 && jogs[1].0.action == .jogA && jogs[1].1 == .relative(-64))
        #expect(jogs.allSatisfy { $0.0.argument == 128 })
        #expect(
            events.map { $0.0 } == [
                .jogTouchA, .jogTouchA, .pitchBendDownA, .pitchBendUpA,
                .pitchBendDownA, .pitchBendUpA,
            ])
        #expect(events.map { $0.1 } == [1, 0, 1, 1, 0, 0])
    }
}

@Test @MainActor func controllerCatalogueAIRLoopPressureReportsDoNotRetriggerOrInvokeFXAndSamples() {
    withAIR { input in
        var actions: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in actions.append(target) }
        airPacket([0x90, 9, 1, 9, 64, 9, 127, 9, 0, 9, 1, 10, 1, 11, 1, 12, 1, 31, 127], to: input)
        #expect(
            actions == [
                .init(.loopInA, deck: .a), .init(.loopInA, deck: .a), .init(.loopOutA, deck: .a),
                .init(.loopUpA, deck: .a), .init(.reloopA, deck: .a), .init(.loopInB, deck: .b),
            ])
        actions.removeAll()
        airPacket([0x90, 1, 127, 2, 127, 3, 127, 4, 127, 5, 127, 23, 127, 27, 127], to: input)
        #expect(actions.isEmpty)
    }
}
