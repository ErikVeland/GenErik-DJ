import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalUMixPro(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original-umix-pro-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "U-MIX CONTROL PRO"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func originalUMixProPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test func controllerCatalogueOriginalUMixProHasSeparateIdentitySplitAudioAndDefaultCalibration() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["U-MIX CONTROL PRO"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 91 && data.outputs.count == 28)
    #expect(data.startup.count == 31 && data.shutdown.count == 31)
    #expect(profile.hasAutomaticSplitOutput)
    #expect(data.inputs.filter { $0.action.isJog }.allSatisfy { $0.argument == nil })
    #expect(data.startup.contains([0x90, 7, 127]) && data.shutdown.contains([0x90, 7, 0]))
    #expect(ControllerFactoryProfile.matching(["U-MIX CONTROL PRO 2"], automaticOnly: true) != profile)
    #expect(ControllerFactoryProfile.matching(["U-MIX CONTROL 2"], automaticOnly: true) != profile)
    #expect(ControllerFactoryProfile.matching(["U-MIX CONTROL PRO", "U-MIX CONTROL PRO2"], automaticOnly: true) == nil)
    #expect(!data.inputs.contains { $0.action == .monitor })
}

@Test @MainActor func controllerCatalogueOriginalUMixProFactoryCCLoadAcceptsFirstPressAndShiftedReleaseRearmsIt() {
    withOriginalUMixPro { input in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        originalUMixProPacket([0xB2, 5, 127, 5, 127], to: input)
        #expect(actions == [.loadA])
        originalUMixProPacket([0x92, 2, 127, 0xB5, 5, 127, 5, 0, 0x92, 2, 0, 0xB2, 5, 127], to: input)
        #expect(actions == [.loadA, .loadA])
        originalUMixProPacket([0x92, 5, 127, 6, 127], to: input)
        #expect(actions == [.loadA, .loadA, .loadB])
    }
}

@Test @MainActor func controllerCatalogueOriginalUMixProTouchAndRimStaySeparateAcrossShiftRelease() {
    withOriginalUMixPro { input in
        var events: [(ControllerAction, Double)] = []
        var jogs: [(ControllerAction, ControllerMIDIValue)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        input.onJogAction = { jogs.append(($0.action, $1)) }
        originalUMixProPacket([0x90, 22, 126, 0xB0, 22, 65], to: input)
        #expect(events.isEmpty && jogs.isEmpty)
        originalUMixProPacket([0x90, 22, 127, 0xB0, 22, 66, 23, 63], to: input)
        #expect(events.map(\.0) == [.jogTouchA])
        #expect(jogs.contains { $0.0 == .jogA && $0.1 == .relative(2) })
        #expect(jogs.contains { $0.0 == .wheelJogA && $0.1 == .relative(-1) })
        originalUMixProPacket([0x92, 2, 127, 0x83, 22, 127], to: input)
        #expect(events.last?.0 == .jogTouchA && events.last?.1 == 0)
        let count = jogs.count
        originalUMixProPacket([0xB3, 22, 65], to: input)
        #expect(jogs.count == count)
    }
}

@Test @MainActor func controllerCatalogueOriginalUMixProCueAndMonitorBlendRetainFactoryOwnership() {
    withOriginalUMixPro { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        originalUMixProPacket([0x90, 1, 127, 0x91, 1, 127, 0x90, 1, 0, 0x81, 1, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewB, .cuePreviewA, .cuePreviewB])
        #expect(events.map(\.1) == [1, 1, 0, 0])
        originalUMixProPacket([0xB2, 7, 127], to: input)
        #expect(events.last?.0 == .cueMix && events.last?.1 == 1)
        let count = events.count
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 2, value: 127), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 2, value: 127), source: 11)
        input.flushPendingActions()
        #expect(events.count == count)
    }
}
