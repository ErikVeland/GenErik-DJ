import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withLegacyDock(
    _ name: String, decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "legacy-dock-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("A manual dock profile must not write hardware state.")
            return false
        }, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name,
            identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    for source: Int32 in [10, 11] {
        input.select(source)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    }
    #expect(input.bindingCount == 42)
    try body(input)
}

@MainActor private func legacyDockPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueLegacyDockIonCueAndBendKeepBothReleaseFormsAndSourceOwnership() throws {
    try withLegacyDock("ION iDJ2GO") { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (deck, numbers) in [(DeckID.a, [UInt8(51), 67, 68]), (.b, [60, 69, 70])] {
            for (number, action) in zip(numbers, [ControllerAction.cuePreviewA, .pitchBendDownA, .pitchBendUpA]) {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    legacyDockPacket([0x90, number, 127, number, 127, off, number, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [1, 0])
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
            }
        }
        events.removeAll()
        legacyDockPacket([0x90, 51, 127], input)
        legacyDockPacket([0x90, 51, 127], input, source: 11)
        legacyDockPacket([0x80, 51, 127], input)
        #expect(events.map(\.1) == [1])
        legacyDockPacket([0x90, 51, 0], input, source: 11)
        #expect(events.map(\.1) == [1, 0])
        events.removeAll()
        legacyDockPacket([0x90, 67, 127], input)
        input.stop()
        #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueLegacyDockPhilipsKeepsSeparateCueSetGotoAndNoteChannels() throws {
    try withLegacyDock("Philips M1X DJ") { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for (channel, deck): (UInt8, DeckID) in [(1, .a), (2, .b)] {
            for (number, action): (UInt8, ControllerAction) in [
                (1, .playA), (3, .cueSetA), (2, .cueGotoA), (5, .syncA), (10, .cueA),
            ] {
                events.removeAll()
                legacyDockPacket([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
                legacyDockPacket([0x90 + channel, number, 127, 0x80 + channel, number, 64], input)
                #expect(events.count == 2)
            }
        }
        #expect(!events.contains { $0.action == .cuePreviewA || $0.action == .cuePreviewB })
    }
}

@Test @MainActor func controllerCatalogueLegacyDockAbsoluteMixersRetainPickupAndSourcePolarity() throws {
    for (name, rows): (String, [(UInt8, UInt8, ControllerAction, Bool)]) in [
        (
            "ION iDJ2GO",
            [
                (0, 8, .levelA, false), (0, 9, .levelB, false), (0, 6, .tempoA, true),
                (0, 7, .tempoB, true), (0, 10, .crossfader, true), (0, 23, .master, false), (0, 5, .monitor, false),
            ]
        ),
        (
            "Philips M1X DJ",
            [
                (0, 2, .levelA, false), (0, 3, .levelB, false), (0, 1, .crossfader, false),
                (1, 7, .tempoA, false), (2, 7, .tempoB, false), (1, 5, .highA, false), (1, 6, .midA, false),
                (1, 4, .lowA, false), (2, 5, .highB, false), (2, 6, .midB, false), (2, 4, .lowB, false),
            ]
        ),
    ] {
        try withLegacyDock(name) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerAction, Double)] = []
            input.onAction = { action, value in if !action.isJog { events.append((action, value)) } }
            for (channel, number, action, inverted) in rows {
                events.removeAll()
                legacyDockPacket([0xB0 + channel, number, 0], input)
                #expect(events.isEmpty)
                legacyDockPacket([0xB0 + channel, number, 64], input)
                legacyDockPacket([0xB0 + channel, number, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == action })
                #expect(events.last?.1 == (inverted ? 0 : 1))
            }
        }
    }
}

@Test @MainActor func controllerCatalogueLegacyDockUnqualifiedModesOutputsAndSiblingAliasesStayInactive() throws {
    for (name, bytes): (String, [UInt8]) in [
        ("ION iDJ2GO", [0xB0, 24, 1, 25, 127, 26, 1, 0x90, 80, 127, 80, 0, 81, 127, 81, 0, 0x91, 59, 127, 59, 0]),
        (
            "Philips M1X DJ",
            [0x91, 4, 127, 4, 0, 8, 127, 8, 0, 11, 127, 11, 0, 0xB1, 3, 65, 0xB2, 3, 63, 0x90, 1, 127, 1, 0]
        ),
    ] {
        try withLegacyDock(name, decks: [.a]) { input in
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            legacyDockPacket(bytes + [0xF8, 0xFA, 0xFC], input)
            legacyDockPacket(
                name == "ION iDJ2GO" ? [0x90, 66, 127, 60, 127, 60, 0] : [0x92, 1, 127, 3, 127, 3, 0], input)
            #expect(actions.isEmpty)
        }
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        #expect(!profile.selectsAutomatically && profile.definition?.audioOutput == nil)
        #expect(
            profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true
                && profile.definition?.shutdown.isEmpty == true)
        for sibling in ["Numark DJ2GO", "iDJ Live II", "M1X-DJ Bluetooth"] {
            #expect(ControllerFactoryProfile.matching([sibling]) != profile)
        }
    }
}
