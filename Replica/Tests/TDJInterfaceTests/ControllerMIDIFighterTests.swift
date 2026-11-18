import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMIDIFighter(
    _ name: String, decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "midi-fighter-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func fighterPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMIDIFighterModelsKeepTheirOwnIdentityAndInputOnlyLifecycle() throws {
    for (name, count) in [("Midi Fighter Classic", 16), ("Midi Fighter Twister", 29)] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == count && data.role == "accessory")
        #expect(
            data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty && !profile.hasAutomaticSplitOutput)
        for other in [
            "Midi Fighter Spectra", "Midi Fighter 3D", "Midi Fighter 64",
            name.hasSuffix("Classic") ? "Midi Fighter Twister" : "Midi Fighter Classic",
        ] {
            #expect(ControllerFactoryProfile.matching([other], automaticOnly: true) != profile)
        }
    }
}

@Test @MainActor func controllerCatalogueMIDIFighterClassicRoutesEveryDefaultPadAndBothReleaseForms() {
    let rows: [(DeckID, UInt8)] = [(.c, 48), (.a, 44), (.b, 40), (.d, 36)]
    for decks in [DeckID.primary, DeckID.allCases] {
        withMIDIFighter("Midi Fighter Classic", decks: decks) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            for (_, base) in rows {
                for offset: UInt8 in 0..<4 {
                    let note = base + offset
                    fighterPacket([0x92, note, 125, note, 0, note, 127, 0x82, note, 125], to: input)
                }
            }
            let active = rows.map(\.0).filter { decks.contains($0) }
            #expect(events.map(\.deck) == active.flatMap { Array(repeating: Optional($0), count: 8) })
            #expect(
                events.map { $0.action.hotcueSlot }
                    == active.flatMap { _ in [0, 0, 1, 1, 2, 2, 3, 3].map { Optional($0) } })
            events.removeAll()
            fighterPacket([0x90, 44, 127, 0xB2, 44, 127, 0x92, 0, 127, 4, 127, 64, 127], to: input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueMIDIFighterTwisterKeepsAllSixteenNormalMixerKnobs() {
    withMIDIFighter("Midi Fighter Twister") { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        let controls: [(UInt8, ControllerAction)] = [
            (0, .gainA), (1, .highA), (5, .midA), (9, .lowA), (8, .levelA), (13, .filterKnobA), (4, .tempoA),
            (3, .gainB), (2, .highB), (6, .midB), (10, .lowB), (11, .levelB), (14, .filterKnobB), (7, .tempoB),
            (12, .crossfader), (15, .master),
        ]
        for (number, action) in controls {
            for raw: UInt8 in [0, 64, 127] {
                events.removeAll()
                fighterPacket([0xB0, number, raw], to: input)
                #expect(events.count == 1 && events.first?.0.action == action)
                let value = Double(raw) / 127
                #expect(events.first?.1 == ([ControllerAction.tempoA, .tempoB].contains(action) ? 1 - value : value))
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMIDIFighterTwisterKeepsCCButtonsAndIndependentShiftedHeadphoneOwnership() {
    withMIDIFighter("Midi Fighter Twister") { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in events.append(action) }
        fighterPacket([0xB1, 8, 127, 8, 0, 8, 127, 4, 127, 13, 127], to: input)
        #expect(events == [.cueA, .cueA, .tempoResetA, .filterToggleA])
        events.removeAll()
        fighterPacket([0xB3, 10, 127, 13, 127, 10, 0, 0xB0, 15, 127, 12, 127], to: input)
        #expect(events == [.monitor])
        events.removeAll()
        fighterPacket([0xB3, 13, 0, 0xB0, 15, 127], to: input)
        #expect(events == [.master])
        events.removeAll()
        fighterPacket([0x91, 8, 127, 0xB0, 16, 127, 32, 127, 0xB3, 8, 127, 0x92, 48, 127], to: input)
        #expect(events.isEmpty)
    }
}
