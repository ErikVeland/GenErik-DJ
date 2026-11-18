import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withS11(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "djm-s11-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DJM-S11"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func s11Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJMS11KeepsManualMixerIdentityAndNoLifecycleInference() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJM-S11"]))
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 16 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(data.inputs.allSatisfy { $0.kind == .control && $0.encoding == .paired14Bit })
    for name in ["DJM-S9", "DJM-S7", "DJM-S5", "DJM-A9"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}

@Test @MainActor func controllerCatalogueDJMS11KeepsBothMixerTargetsAndExactFourteenBitPairs() throws {
    try withS11 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        let profile = try #require(ControllerFactoryProfile.matching(["DJM-S11"]))
        for binding in profile.bindings(source: 10) {
            let low = try #require(binding.lowNumber)
            events.removeAll()
            s11Packet([0xB0 + binding.channel, binding.number, 127, low, 127], to: input)
            #expect(events.last?.0 == binding.target && events.last?.1 == 1)
            s11Packet([0xB0 + binding.channel, binding.number, 0, low, 0], to: input)
            #expect(events.last?.0 == binding.target && events.last?.1 == 0)
        }
    }
}

@Test @MainActor func controllerCatalogueDJMS11LeavesAmbiguousBrowserFaderStartsAndSharedModesInactive() throws {
    try withS11 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        s11Packet(
            [
                0xB2, 4, 127, 36, 127, 0xB6, 64, 1, 100, 127, 0x90, 81, 127, 82, 127, 83, 127, 102, 127, 0x96, 65, 127,
                104, 127, 99, 127, 107, 127, 0x97, 0, 127,
            ], to: input)
        #expect(events.isEmpty)
        s11Packet([0xB0, 19, 127, 51, 127], to: input)
        #expect(events.last == .init(.levelA, deck: .a))
        events.removeAll()
        s11Packet([0xB1, 19, 127, 51, 127], to: input)
        #expect(events.last == .init(.levelB, deck: .b))
    }
}
