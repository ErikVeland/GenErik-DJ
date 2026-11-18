import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withV10(
    _ name: String, decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "djm-v10-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    #expect(input.bindingCount == (name.hasSuffix("-LF") ? 9 : 24))
    try body(input)
}

@MainActor private func v10Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueV10BothModelsKeepQualifiedStripsPickupAndDeckOptIn() throws {
    for name in ["DJM-V10", "DJM-V10-LF"] {
        for decks in [DeckID.primary, DeckID.allCases] {
            try withV10(name, decks: decks) { input in
                input.currentTargetValue = { _ in 0.5 }
                var events: [(ControllerActionTarget, Double)] = []
                input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
                for (index, deck) in DeckID.allCases.enumerated() {
                    var wires: [(UInt8, ControllerAction)] = [
                        (UInt8([1, 6, 12, 80][index]), .gainA), (UInt8(17 + index), .levelA),
                    ]
                    if name == "DJM-V10" {
                        wires += [(UInt8([2, 7, 14, 81][index]), .highA), (UInt8([4, 9, 21, 82][index]), .lowA)]
                    }
                    for (number, action) in wires {
                        events.removeAll()
                        v10Packet([0xB0, number, 0], input)
                        #expect(events.isEmpty)
                        v10Packet([0xB0, number, 64], input)
                        v10Packet([0xB0, number, 127], input)
                        #expect(events.count == (decks.contains(deck) ? 2 : 0))
                        #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                        if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                    }
                }
                var globals: [(UInt8, ControllerAction)] = [(24, .master)]
                if name == "DJM-V10" { globals += [(26, .monitor), (27, .cueMix), (11, .crossfader)] }
                for (number, action) in globals {
                    events.removeAll()
                    v10Packet([0xB0, number, 64], input)
                    v10Packet([0xB0, number, 0], input)
                    #expect(events.map(\.0.action) == [action, action] && events.map(\.1) == [64.0 / 127, 0])
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueV10CueAUsesExplicitToggleStateWithoutLFOrSourceInheritance() throws {
    for name in ["DJM-V10", "DJM-V10-LF"] {
        try withV10(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                events.removeAll()
                for value: UInt8 in [0, 127, 127, 0] { v10Packet([0x90, UInt8(7 + index), value], input) }
                if name.hasSuffix("-LF") {
                    #expect(events.isEmpty)
                } else {
                    #expect(events.map(\.1) == [0, 1, 1, 0])
                    #expect(
                        events.allSatisfy { $0.0 == .init(ControllerAction.cueStateA.assigned(to: deck), deck: deck) })
                }
            }
            events.removeAll()
            v10Packet([0x90, 7, 127, 0xB0, 17, 64], input, source: 11)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueV10SixChannelFourBandAndModeDependentControlsRemainInactive() throws {
    for name in ["DJM-V10", "DJM-V10-LF"] {
        try withV10(name) { input in
            input.currentTargetValue = { _ in 0.5 }
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            var controls: [UInt8] = [
                3, 8, 15, 92, 28, 29, 16, 93, 32, 33, 34, 35, 36, 37, 38, 44, 70, 71, 72, 73, 74, 75, 96, 119, 48, 56,
                49, 60, 52, 89, 63, 90, 109, 110, 5, 10, 22, 83, 101, 118, 39, 40, 41,
            ]
            if name.hasSuffix("-LF") { controls += [2, 7, 14, 81, 4, 9, 21, 82, 26, 27, 11] }
            for number in controls { v10Packet([0xB0, number, 64, number, 127, number, 0], input) }
            for number: UInt8 in [11, 12, 13, 14, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 118] {
                v10Packet([0x90, number, 127, number, 0], input)
            }
            v10Packet([0xB1, 17, 64, 0x91, 7, 127, 0xF8, 0xFA, 0xFC], input)
            #expect(actions.isEmpty)
        }
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        #expect(!profile.selectsAutomatically && profile.definition?.role == "accessory")
        #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true)
        #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
        #expect(ControllerFactoryProfile.matching([name.hasSuffix("-LF") ? "DJM-V10" : "DJM-V10-LF"]) != profile)
        #expect(ControllerFactoryProfile.matching(["DJM-V5"]) != profile)
    }
}
