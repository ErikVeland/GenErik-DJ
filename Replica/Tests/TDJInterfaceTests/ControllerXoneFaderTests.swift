import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withXoneFaders(
    _ name: String, decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "xone-faders-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("A manual fader subset must not write hardware settings.")
            return false
        }, deckAvailability: { decks })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func xoneFaderPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueXoneFadersKeepDistinctCCLayoutsAndFourDeckGating() throws {
    for (name, numbers) in [("Xone:PX5", [UInt8(0), 1, 2, 3]), ("Xone:24C", [UInt8(5), 6])] {
        for decks in [DeckID.primary, DeckID.allCases] {
            try withXoneFaders(name, decks: decks) { input in
                input.currentTargetValue = { _ in 0.5 }
                var events: [(ControllerActionTarget, Double)] = []
                input.onTargetAction = { events.append(($0, $1)) }
                for (number, deck) in zip(numbers, DeckID.allCases) {
                    events.removeAll()
                    xoneFaderPacket([0xBF, number, 0], input)
                    #expect(events.isEmpty)
                    xoneFaderPacket([0xBF, number, 64], input)
                    xoneFaderPacket([0xBF, number, 127], input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(ControllerAction.levelA.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                }
                events.removeAll()
                xoneFaderPacket([0xBF, 4, 64], input)
                xoneFaderPacket([0xBF, 4, 0], input)
                #expect(events.map(\.0.action) == [.crossfader, .crossfader] && events.last?.1 == 0)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueXoneFadersIgnoreOtherMixerWiresAndUnqualifiedButtons() throws {
    for (name, inactive) in [("Xone:PX5", [UInt8(5), 6, 7]), ("Xone:24C", [UInt8(0), 1, 2, 3, 7])] {
        try withXoneFaders(name) { input in
            var actions: [ControllerAction] = []
            input.onAction = { action, value in if !(action.isJog && value == 0.5) { actions.append(action) } }
            for number in inactive { xoneFaderPacket([0xBF, number, 127], input) }
            for number: UInt8 in 0..<40 { xoneFaderPacket([0x9F, number, 127, number, 0], input) }
            xoneFaderPacket([0xB0, 4, 127, 5, 127, 6, 127], input)
            input.stop()
            #expect(actions.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueXoneFadersRemainManualWithoutHardwareOrAudioWrites() throws {
    for (name, count) in [("Xone:PX5", 5), ("Xone:24C", 3)] {
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        let data = try #require(profile.definition)
        #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput && data.inputs.count == count)
        #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty && data.audioOutput == nil)
        #expect(AudioOutputDevice(name: name, wired: true).automaticSplitOutputName == nil)
        for other in ["Xone:96", "Xone:23C", "Xone:92", name + " clone"] {
            #expect(ControllerFactoryProfile.matching([other]) != profile)
        }
    }
}
