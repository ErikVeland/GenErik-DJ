import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withKDJ500(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "kdj500-manual-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "KDJ500"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func kdj500Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test func controllerCatalogueKDJ500KeepsTranslatedConnectionManualAndSourceLifecycleEmpty() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["KDJ500"]))
    #expect(ControllerFactoryProfile.matching(["KDJ500"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["Kontrol One"]) != profile)
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 27 && data.outputs.isEmpty)
    #expect(data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(!data.inputs.contains { [.jogTouchA, .jogTouchB].contains($0.action) || $0.action.hotcueSlot != nil })
}

@Test @MainActor func controllerCatalogueKDJ500StrictWheelAndBrowserDirectionsIgnoreAllOtherValues() throws {
    try withKDJ500 { input in
        var jogs: [(ControllerAction, ControllerMIDIValue)] = []
        var events: [(ControllerAction, Double)] = []
        input.onJogAction = { jogs.append(($0.action, $1)) }
        input.onTargetAction = { events.append(($0.action, $1)) }
        for raw: UInt8 in [0, 2, 63, 64, 65, 126] {
            kdj500Packet([0xB0, 40, raw, 44, raw, 42, raw, 46, raw], to: input)
        }
        #expect(jogs.isEmpty && events.isEmpty)
        kdj500Packet([0xB0, 40, 127, 44, 1, 42, 127, 46, 127], to: input)
        #expect(jogs.contains { $0.0 == .wheelJogA && $0.1 == .relative(1) })
        #expect(jogs.contains { $0.0 == .wheelJogB && $0.1 == .relative(-1) })
        #expect(events.count == 1 && events.first?.0 == .browse)
        #expect(abs((events.first?.1 ?? -1) - (0.5 + 2.0 / 126)) < 0.0000001)
    }
}

@Test @MainActor func controllerCatalogueKDJ500NativeCueLoadAndFixedLoopKeepTargetsAndPressOwnership() throws {
    try withKDJ500 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        kdj500Packet([0x90, 14, 127, 14, 0, 36, 127, 0x80, 36, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewA, .cuePreviewB, .cuePreviewB])
        #expect(events.map { $0.1 } == [1, 0, 1, 0])
        events.removeAll()
        kdj500Packet([0x90, 20, 127, 20, 127, 40, 127, 3, 127, 25, 127], to: input)
        #expect(events.map { $0.0.action } == [.loadA, .loadB, .toggleFixedLoopA, .toggleFixedLoopB])
        #expect(events.suffix(2).map { $0.0.argument } == [8, 8])
        #expect(events.map { $0.0.deck } == [.a, .b, .a, .b])
    }
}

@Test @MainActor func controllerCatalogueKDJ500MixerPitchPolarityAndForeignInputsStayDistinct() throws {
    try withKDJ500 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        kdj500Packet(
            [0xB0, 1, 127, 2, 64, 3, 64, 4, 64, 5, 127, 6, 64, 7, 64, 8, 64, 9, 0, 10, 127, 11, 127, 12, 127, 13, 0],
            to: input)
        #expect(
            Set(events.map { $0.0.action }) == [
                .gainA, .highA, .midA, .lowA, .gainB, .highB, .midB, .lowB, .tempoA, .tempoB, .levelA, .levelB,
                .crossfader,
            ])
        #expect(events.first { $0.0.action == .tempoA }?.1 == 1)
        #expect(events.first { $0.0.action == .tempoB }?.1 == 0)
        let count = events.count
        kdj500Packet([0x91, 20, 127], to: input)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 20, value: 127), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 20, value: 127), source: 11)
        input.flushPendingActions()
        #expect(events.count == count)
    }
}
