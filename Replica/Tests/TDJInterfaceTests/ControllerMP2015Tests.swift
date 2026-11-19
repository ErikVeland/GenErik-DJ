import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMP2015(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "mp2015-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "MP2015", identity: .init(id: 10, device: 1, names: ["MP2015"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["MP2015"])))
    #expect(input.isInputActive(10) && input.bindingCount == 27)
    try body(input)
}

@MainActor private func mp2015Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMP2015RoutesEveryManufacturerStripAndGlobalWithFourDeckOptIn() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withMP2015(decks: decks) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                let addresses: [[UInt8]] = [
                    [1, 3, 5, 7, 4], [8, 11, 13, 15, 12], [16, 18, 20, 22, 19], [23, 25, 27, 29, 26],
                ]
                let actions: [ControllerAction] = [.gainA, .highA, .midA, .lowA, .levelA]
                for (number, action) in zip(addresses[index], actions) {
                    events.removeAll()
                    mp2015Packet([0xB0, number, 64], to: input)
                    mp2015Packet([0xB0, number, 127], to: input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if decks.contains(deck) { #expect(events.map(\.1) == [64.0 / 127, 1]) }
                }
            }
            for (number, action): (UInt8, ControllerAction) in [(39, .master), (41, .monitor), (43, .cueMix)] {
                events.removeAll()
                mp2015Packet([0xB0, number, 64], to: input)
                mp2015Packet([0xB0, number, 0], to: input)
                #expect(events.map { $0.0.action } == [action, action])
                #expect(events.map(\.1) == [64.0 / 127, 0])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMP2015KeepsPFLNotesSeparateFromCCAndSettingsAndOtherChannels() throws {
    try withMP2015 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for (number, deck): (UInt8, DeckID) in [(19, .a), (20, .b), (17, .c), (11, .d)] {
            events.removeAll()
            mp2015Packet([0x90, number, 127, number, 127, 0x80, number, 127], to: input)
            #expect(events == [.init(ControllerAction.cueA.assigned(to: deck), deck: deck)])
            mp2015Packet([0x90, number, 127, number, 0], to: input)
            #expect(events.count == 2)
        }
        events.removeAll()
        for number: UInt8 in [
            2, 6, 9, 10, 14, 17, 21, 24, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38, 40, 42, 44, 45, 57, 66, 79, 80, 82, 84,
            90, 92,
        ] {
            mp2015Packet([0xB0, number, 127, number, 0], to: input)
        }
        mp2015Packet(
            [0x90, 1, 127, 2, 127, 3, 127, 9, 127, 23, 127, 0xB1, 1, 127, 0x91, 19, 127, 0xE0, 127, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMP2015OptionalLightsUseManufacturerNoteOnThresholdWithoutSetupWrites() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Rane MP2015"]))
    #expect(!profile.selectsAutomatically && profile.definition?.role == "accessory")
    #expect(profile.definition?.startup.isEmpty == true && profile.definition?.shutdown.isEmpty == true)
    #expect(profile.definition?.audioOutput == nil)
    let lights = profile.feedback(destination: 20)
    #expect(lights.count == 4 && Set(lights.map(\.number)) == Set([19, 20, 17, 11]))
    for light in lights {
        #expect(light.kind == .note && light.channel == 0)
        #expect(light.message(value: 0) == [0x90, light.number, 0])
        #expect(light.message(value: 1) == [0x90, light.number, 127])
    }
    for name in ["MP2014", "MP2016", "RANE FOUR"] { #expect(ControllerFactoryProfile.matching([name]) != profile) }
}
