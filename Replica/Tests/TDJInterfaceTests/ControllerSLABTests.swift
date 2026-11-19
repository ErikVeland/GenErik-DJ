import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSLAB(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "slab-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "SLAB",
            identity: .init(id: id, device: UInt32(id), names: ["SLAB"]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func slabPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSLABAllEightPagesKeepPhysicalPadOrderAndBothReleaseForms() throws {
    try withSLAB { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        let physical: [UInt8] = [12, 13, 14, 15, 8, 9, 10, 11, 4, 5, 6, 7, 0, 1, 2, 3]
        let cues: [ControllerAction] = [
            .hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A, .hotcue5A, .hotcue6A, .hotcue7A, .hotcue8A,
        ]
        let transport: [ControllerAction] = [
            .playA, .cuePreviewA, .syncA, .keylockA, .cueA, .loopA, .loadA, .tempoResetA,
        ]
        for page in 0..<8 {
            let decks: [DeckID] = page % 2 == 0 ? [.a, .b] : [.c, .d]
            for (position, base) in physical.enumerated() {
                let deck = decks[position / 8], slot = position % 8, number = base + UInt8(page * 16)
                let action: ControllerAction
                let argument: Double?
                switch page / 2 {
                case 0: action = cues[slot]; argument = nil
                case 1: action = .toggleFixedLoopA; argument = [0.25, 0.5, 1, 2, 4, 8, 16, 32][slot]
                case 2: action = .fixedJumpA; argument = [-1, 1, -2, 2, -4, 4, -8, 8][slot]
                default: action = transport[slot]; argument = nil
                }
                for velocity: UInt8 in [1, 127] {
                    for off: UInt8 in [0x87, 0x97] {
                        events.removeAll()
                        slabPacket(
                            [0x97, number, velocity, number, velocity, off, number, off == 0x87 ? 127 : 0], to: input)
                        #expect(events.count == (action.isMomentary ? 2 : 1))
                        #expect(
                            events.allSatisfy {
                                $0.0 == .init(action.assigned(to: deck), deck: deck, argument: argument)
                            })
                        #expect(events.first?.1 ?? 0 > 0)
                        if action.isMomentary { #expect(events.last?.1 == 0) }
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueSLABShiftTransitionsRetireCueAndGateUnsupportedAlternateReleases() throws {
    try withSLAB { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { action, value in if !action.isJog { events.append((action, value)) } }
        slabPacket([0x97, 109, 127, 0x90, 70, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewA])
        #expect(events.map(\.1) == [1, 0])
        events.removeAll()
        slabPacket([0x98, 109, 0, 12, 127, 12, 0, 0x97, 12, 127, 12, 0, 0x90, 94, 127, 94, 0], to: input)
        #expect(events.isEmpty)
        slabPacket([0x80, 70, 127, 0x97, 109, 127, 109, 0], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewA])
        #expect(events.map(\.1) == [1, 0])
        events.removeAll()
        slabPacket([0x97, 12, 127, 0x90, 70, 127, 70, 0, 0x97, 12, 127, 12, 0], to: input)
        #expect(events.map(\.0) == [.hotcue1A, .hotcue1A])
    }
}

@Test @MainActor func controllerCatalogueSLABPagePressReleasesOldHoldsAndItsReleaseKeepsNewCueHeld() throws {
    for pageButton: UInt8 in [83, 84, 85, 86] {
        try withSLAB { input in
            var events: [(ControllerAction, Double)] = []
            input.onAction = { action, value in
                if action == .cuePreviewA || action == .cuePreviewB { events.append((action, value)) }
            }
            slabPacket([0x97, 109, 127, 0x96, pageButton, 127], to: input)
            #expect(events.map(\.1) == [1, 0])
            slabPacket([0x97, 101, 127, 0x96, pageButton, 0], to: input)
            #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewA, .cuePreviewB])
            #expect(events.map(\.1) == [1, 0, 1])
            slabPacket([0x87, 101, 127], to: input)
            #expect(events.map(\.1) == [1, 0, 1, 0])
        }
    }
    try withSLAB { input in
        var values: [Double] = []
        input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
        slabPacket([0x97, 109, 127], to: input)
        slabPacket([0x97, 109, 127], to: input, source: 11)
        slabPacket([0x96, 85, 127], to: input)
        #expect(values == [1])
        slabPacket([0x87, 109, 127], to: input, source: 11)
        #expect(values == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueSLABEncodersStripAndBrowserKeepPublishedChannelsAndDirections() throws {
    try withSLAB { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (number, action, deck): (UInt8, ControllerAction, DeckID) in [
            (16, .levelA, .a), (17, .filterKnobA, .a), (18, .filterKnobB, .b), (19, .levelB, .b),
        ] {
            events.removeAll()
            slabPacket([0xB0, number, 0, number, 64], to: input)
            #expect(events.isEmpty)
            slabPacket([0xB0, number, 1], to: input)
            slabPacket([0xB0, number, 65], to: input)
            #expect(events.map(\.1) == [0.5 + 1.0 / 127, 0.5 - 1.0 / 127])
            #expect(events.allSatisfy { $0.0 == .init(action, deck: deck) })
        }
        events.removeAll()
        slabPacket([0xB0, 60, 1], to: input)
        slabPacket([0xB0, 60, 65], to: input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        #expect(events.allSatisfy { $0.0.action == .browse })
        events.removeAll()
        slabPacket([0x90, 100, 127, 100, 0, 101, 127, 101, 0, 98, 127, 98, 0, 94, 127, 94, 0], to: input)
        #expect(events.map { $0.0.action } == [.browsePrevious, .browseNext, .openGroup, .playA])
        events.removeAll()
        slabPacket([0xB6, 46, 127], to: input)
        #expect(events.isEmpty)
        slabPacket([0xB6, 14, 64, 46, 0], to: input)
        #expect(events.last?.1 == 8192.0 / 16383)
        slabPacket([0xB6, 14, 127, 46, 127], to: input)
        #expect(events.last?.1 == 1)
        #expect(events.allSatisfy { $0.0.action == .crossfader })
    }
}

@Test @MainActor func controllerCatalogueSLABHiddenDecksAlternatePadsAndAftertouchStayInactive() throws {
    try withSLAB(decks: DeckID.primary) { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for page in [1, 3, 5, 7] {
            for slot: UInt8 in 0..<16 {
                slabPacket([0x97, UInt8(page * 16) + slot, 127, UInt8(page * 16) + slot, 0], to: input)
            }
        }
        for note: UInt8 in 0..<128 {
            slabPacket([0x98, note, 127, note, 0, 0xA7, note, 127], to: input)
        }
        slabPacket([0xB0, 20, 1, 21, 1, 22, 1, 23, 1, 61, 1, 0xB6, 16, 64, 48, 0, 15, 64, 47, 0], to: input)
        slabPacket([0x90, 95, 127, 95, 0, 81, 127, 81, 0, 82, 127, 82, 0, 92, 127, 92, 0], to: input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueSLABNeedsNoOutputAndReconnectClearsSourceShiftAndHolds() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["SLAB"], automaticOnly: true))
    #expect(profile.definition?.inputs.count == 139 && profile.definition?.role == "accessory")
    #expect(profile.definition?.startup.isEmpty == true && profile.definition?.shutdown.isEmpty == true)
    #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.audioOutput == nil)
    try withSLAB { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { events.append(action) } }
        slabPacket([0x90, 70, 127], to: input)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        events.removeAll()
        slabPacket([0x97, 12, 127, 12, 0], to: input)
        #expect(events == [.hotcue1A])
    }
}
