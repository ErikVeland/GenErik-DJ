import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withUMixControl2(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "umix-control2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "U-MIX CONTROL 2"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func umixControl2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueUMixControl2KeepsNonTouchIdentityAndBoundedFactoryLights() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["U-MIX CONTROL 2"], automaticOnly: true))
    #expect(profile != ControllerFactoryProfile.matching(["U-Mix Control Pro 2"]))
    #expect(profile != ControllerFactoryProfile.matching(["U-Mix Control Pro"]))
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 96 && data.outputs.count == 28)
    #expect(data.startup.count == 31 && data.shutdown.count == 31)
    #expect(!data.inputs.contains { [.jogTouchA, .jogTouchB, .jogA, .jogB, .monitor, .cueMix].contains($0.action) })
    #expect(data.inputs.filter { $0.action.isJog }.allSatisfy { $0.argument == nil })
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .hotcue6A })
    #expect(cue.message(value: 1) == [0x90, 26, 127] && cue.message(value: 0) == [0x90, 26, 0])
}

@Test @MainActor func controllerCatalogueUMixControl2NonTouchWheelsCentredPitchAndBrowserUseFactoryFormats() {
    withUMixControl2 { input in
        var jogs: [(ControllerAction, ControllerMIDIValue)] = []
        var events: [(ControllerAction, Double)] = []
        input.onJogAction = { jogs.append(($0.action, $1)) }
        input.onTargetAction = { events.append(($0.action, $1)) }
        umixControl2Packet([0xB0, 22, 65, 0xB1, 22, 63, 0xB2, 4, 64], to: input)
        #expect(jogs.contains { $0.0 == .wheelJogA && $0.1 == .relative(1) })
        #expect(jogs.contains { $0.0 == .wheelJogB && $0.1 == .relative(-1) })
        #expect(events.first?.0 == .browse && (events.first?.1 ?? 1) < 0.5)
        umixControl2Packet([0xE0, 0, 0, 0xE1, 127, 127], to: input)
        #expect(events.contains { $0.0 == .tempoA && $0.1 == 1 })
        #expect(events.contains { $0.0 == .tempoB && $0.1 == 0 })
        umixControl2Packet([0xE0, 0, 64], to: input)
        #expect(events.last?.0 == .tempoA && events.last?.1 == 0.5)
        let count = jogs.count
        umixControl2Packet([0x90, 22, 127, 7, 127, 0xB0, 23, 65], to: input)
        #expect(jogs.count == count)
    }
}

@Test @MainActor func controllerCatalogueUMixControl2ShiftedAliasesReleaseCueBendsAndExplicitDeleteClearsPad() {
    withUMixControl2 { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        umixControl2Packet([0x90, 1, 127, 4, 127, 26, 127, 0x92, 2, 127], to: input)
        umixControl2Packet([0x93, 1, 127, 4, 127, 26, 127, 127, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .pitchBendDownA, .hotcue6A, .clearHotcue6A])
        umixControl2Packet([0x83, 1, 127, 4, 127, 26, 127, 127, 127], to: input)
        #expect(events.suffix(2).map(\.0) == [.cuePreviewA, .pitchBendDownA])
        #expect(events.suffix(2).allSatisfy { $0.1 == 0 })
        umixControl2Packet([0x92, 2, 0, 0x90, 26, 127], to: input)
        #expect(events.last?.0 == .hotcue6A)
    }
}

@Test @MainActor func controllerCatalogueUMixControl2FactoryLoopsLoadAndAllSixCuesKeepNormalMeaning() {
    withUMixControl2 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        umixControl2Packet([0x92, 5, 127, 6, 127, 0x90, 13, 127, 0x91, 13, 127], to: input)
        #expect(targets.map(\.action) == [.loadA, .loadB, .loopA, .loopB])
        targets.removeAll()
        umixControl2Packet([0x90, 10, 127, 11, 127, 12, 127, 24, 127, 25, 127, 26, 127], to: input)
        #expect(targets.map { $0.action.hotcueSlot } == [0, 1, 2, 3, 4, 5])
        targets.removeAll()
        umixControl2Packet([0xB0, 13, 127, 0xB1, 13, 1], to: input)
        #expect(Set(targets.map(\.action)) == [.loopSizeA, .loopSizeB])
    }
}

@Test @MainActor func controllerCatalogueUMixControl2UnverifiedKillFXAndForeignInputsStayInactive() {
    withUMixControl2 { input in
        var events = 0
        input.onTargetAction = { _, _ in events += 1 }
        umixControl2Packet([0x90, 18, 127, 19, 127, 20, 127, 14, 127, 0xB2, 5, 127], to: input)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 2, value: 127), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 2, value: 127), source: 11)
        input.flushPendingActions()
        #expect(events == 0)
    }
}

@Test @MainActor func controllerCatalogueUMixControl2ShiftedButtonReleasesRearmPlayAndGlobalLoad() {
    withUMixControl2 { input in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        umixControl2Packet([0x90, 2, 127, 0x92, 5, 127, 2, 127], to: input)
        umixControl2Packet([0x83, 2, 127, 0x85, 5, 127, 0x92, 2, 0], to: input)
        umixControl2Packet([0x90, 2, 127, 0x92, 5, 127], to: input)
        #expect(actions == [.playA, .loadA, .playA, .loadA])
    }
}
