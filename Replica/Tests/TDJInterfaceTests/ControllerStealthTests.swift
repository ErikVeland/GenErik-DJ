import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withStealth(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "stealth-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Stealth Control"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func stealthPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueStealthKeepsItsOwnIdentityAndNoInheritedLightsOrScratch() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Stealth Control"], automaticOnly: true))
    for name in ["Total Control", "Omni Control"] { #expect(profile != ControllerFactoryProfile.matching([name])) }
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 42 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(
        !data.inputs.contains {
            $0.action == .jogTouchA || $0.action == .jogTouchB || $0.action == .jogA || $0.action == .jogB
        })
    #expect(!profile.hasAutomaticSplitOutput)
    withStealth { input in #expect(input.isInputActive(10)) }
}

@Test @MainActor func controllerCatalogueStealthUsesFactoryCueNotesAndBothReleaseForms() {
    withStealth { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        stealthPacket(
            [0x90, 67, 127, 51, 127, 51, 0, 68, 127, 0x80, 68, 127, 0x90, 76, 127, 75, 127, 52, 127], to: input)
        #expect(
            events.map(\.0) == [.playA, .cuePreviewA, .cuePreviewA, .cuePreviewB, .cuePreviewB, .playB, .loadA, .loadB])
        #expect(events.map(\.1) == [1, 1, 0, 1, 0, 1, 1, 1])
        events.removeAll()
        stealthPacket([0x91, 67, 127, 51, 127, 0x90, 59, 127, 60, 127, 72, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueStealthKeepsManufacturerJogOrderSignedCountsAndInvertedSliders() {
    withStealth { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        stealthPacket([0xB0, 24, 1], to: input)
        #expect(events.last?.0 == .wheelJogA && (events.last?.1 ?? 0) > 0.5)
        stealthPacket([0xB0, 25, 127], to: input)
        #expect(events.last?.0 == .wheelJogB && (events.last?.1 ?? 1) < 0.5)
        stealthPacket([0xB0, 26, 127], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        stealthPacket([0xB0, 11, 0], to: input)
        #expect(events.last?.0 == .tempoA && events.last?.1 == 1)
        stealthPacket([0xB0, 12, 127], to: input)
        #expect(events.last?.0 == .tempoB && events.last?.1 == 0)
        stealthPacket([0xB0, 10, 0], to: input)
        #expect(events.last?.0 == .crossfader && events.last?.1 == 1)
        events.removeAll()
        stealthPacket([0xB0, 13, 127, 16, 127, 18, 127, 20, 127, 8, 127], to: input)
        #expect(Set(events.map(\.0)) == Set([.gainA, .highA, .midA, .lowA, .levelA]))
    }
}
