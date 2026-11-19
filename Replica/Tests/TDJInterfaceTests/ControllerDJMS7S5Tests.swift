import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withScratchMixer(_ model: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "scratch-mixer-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DJM-" + model
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func scratchMixerPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJMS7S5KeepIndependentManualIdentities() throws {
    for (name, count) in [("S7", 20), ("S5", 23)] {
        let profile = try #require(ControllerFactoryProfile.matching(["DJM-" + name]))
        #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
        let data = try #require(profile.definition)
        #expect(data.inputs.count == count && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
        for other in ["S11", "S9", "A9", name == "S7" ? "S5" : "S7"] {
            #expect(ControllerFactoryProfile.matching(["DJM-" + other]) != profile)
        }
    }
}

@Test @MainActor func controllerCatalogueDJMS7S5KeepAllSixteenVerifiedPairs() throws {
    for name in ["S7", "S5"] {
        try withScratchMixer(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { events.append(($0, $1)) }
            let profile = try #require(ControllerFactoryProfile.matching(["DJM-" + name]))
            let pairs = profile.bindings(source: 10).filter { $0.encoding == .paired14Bit }
            #expect(pairs.count == 16)
            for binding in pairs {
                let low = try #require(binding.lowNumber)
                events.removeAll()
                scratchMixerPacket([0xB0 + binding.channel, binding.number, 127, low, 127], to: input)
                #expect(events.last?.0 == binding.target && events.last?.1 == 1)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJMS7S5ShiftedLoadCannotTriggerOrLeaveNormalLoadHeld() throws {
    for name in ["S7", "S5"] {
        try withScratchMixer(name) { input in
            var events: [ControllerAction] = []
            input.onAction = { action, _ in events.append(action) }
            scratchMixerPacket([0x90, 71, 127, 0x91, 71, 127], to: input)
            #expect(events.isEmpty)
            scratchMixerPacket([0x90, 70, 127, 0x80, 71, 127, 0x90, 70, 127, 0x91, 70, 127, 71, 0, 70, 127], to: input)
            #expect(events == [.loadA, .loadA, .loadB, .loadB])
        }
    }
}

@Test @MainActor func controllerCatalogueDJMS5AloneUsesItsConsistentBrowserChannelAndShiftedRelease() throws {
    try withScratchMixer("S5") { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        scratchMixerPacket([0xB6, 64, 3], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 + 3.0 / 126)
        scratchMixerPacket([0xB6, 64, 127], to: input)
        #expect(events.last?.1 == 0.5 - 1.0 / 126)
        events.removeAll()
        scratchMixerPacket([0x96, 65, 127, 0x86, 66, 127, 0x96, 65, 127], to: input)
        #expect(events.map(\.0) == [.openGroup, .openGroup])
        events.removeAll()
        scratchMixerPacket([0xB0, 64, 1, 0xB6, 100, 1, 80, 1, 0x97, 0, 127], to: input)
        #expect(events.isEmpty)
    }
    try withScratchMixer("S7") { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in events.append(action) }
        scratchMixerPacket([0xB6, 64, 1, 0xB0, 64, 1, 0x96, 65, 127], to: input)
        #expect(events.isEmpty)
    }
}
