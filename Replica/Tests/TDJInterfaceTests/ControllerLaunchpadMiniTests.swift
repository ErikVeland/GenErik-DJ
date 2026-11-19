import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalMini(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "original-mini-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Launchpad Mini",
            identity: .init(id: 10, device: 1, names: ["Launchpad Mini"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "Launchpad Mini",
            identity: .init(id: 20, device: 1, names: ["Launchpad Mini"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func miniPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalMiniKeepsEveryPlayAndCueOnPageA() {
    for decks in [DeckID.primary, DeckID.allCases] {
        withOriginalMini(decks: decks) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            for row: UInt8 in 0..<4 {
                miniPacket([0x90, row * 32, 127, row * 32, 0], to: input)
                for slot: UInt8 in 0..<8 {
                    let number = row * 32 + 16 + slot
                    miniPacket([0x90, number, 127, 0x80, number, 127], to: input)
                }
            }
            #expect(events.count == decks.count * 9)
            #expect(events.map(\.deck) == decks.flatMap { Array(repeating: Optional($0), count: 9) })
            #expect(
                events.filter { $0.action.hotcueSlot != nil }.map { $0.action.hotcueSlot }
                    == decks.flatMap { _ in (0..<8).map(Optional.init) })
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalMiniGuardsAllPagesAndShiftWithoutCrossKindCollisions() {
    withOriginalMini { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        for page: UInt8 in [24, 40, 56, 72, 88, 104, 120] {
            miniPacket([0x90, page, 127, page, 0, 16, 127, 16, 0, 0, 127, 0, 0], to: input)
        }
        #expect(actions.isEmpty)
        miniPacket([0x90, 8, 127, 8, 0, 0xB0, 111, 127, 0x90, 16, 127, 16, 0, 0, 127, 0, 0], to: input)
        #expect(actions == [.playA])
        miniPacket([0xB0, 111, 0, 104, 127, 0x90, 16, 127, 16, 0], to: input)
        #expect(actions == [.playA, .hotcue1A])
        actions.removeAll()
        miniPacket([0x90, 2, 127, 3, 127, 7, 127, 0x91, 16, 127], to: input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueOriginalMiniLibraryLoadsStayOnPageHAndRespectDeckAvailability() {
    for decks in [DeckID.primary, DeckID.allCases] {
        withOriginalMini(decks: decks) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            miniPacket([0x90, 37, 127, 37, 0, 38, 127, 38, 0], to: input)
            #expect(events.isEmpty)
            miniPacket([0x90, 120, 127, 120, 0], to: input)
            for note: UInt8 in [37, 39, 69, 71, 38, 70, 33, 65, 49] {
                miniPacket([0x90, note, 127, note, 0], to: input)
            }
            #expect(events.filter { [.loadA, .loadB].contains($0.action) }.map(\.deck) == decks.map(Optional.init))
            #expect(
                events.suffix(5).map(\.action) == [
                    .browsePrevious, .browseNext, .browsePreviousGroup, .browseNextGroup, .openGroup,
                ])
            events.removeAll()
            miniPacket([0x90, 6, 127, 22, 127, 54, 127, 86, 127, 102, 127], to: input)
            #expect(events.isEmpty)
            miniPacket([0x90, 8, 127, 8, 0, 37, 127, 38, 127], to: input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalMiniResetNeedsOutputAndDoesNotSelectSiblingModels() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Launchpad Mini"], automaticOnly: true))
    #expect(profile.definition?.startup == [[0xB0, 0, 0], [0xB0, 104, 3]])
    for name in ["Launchpad", "Launchpad MK2", "Launchpad Mini MK3", "Launchpad X", "Launchpad Pro"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
    withOriginalMini { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        miniPacket([0x90, 120, 127, 120, 0], to: input)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        miniPacket([0x90, 16, 127, 16, 0], to: input)
        #expect(actions == [.hotcue1A])
        input.destinations = []
        input.reconcileFactoryProfiles()
        #expect(!input.isInputActive(10))
    }
}

@Test @MainActor func controllerCatalogueOriginalMiniKeepsSourcePagesSeparateAndRejectsFailedSetup() {
    withOriginalMini { input in
        input.sources.append(
            .init(
                id: 11, reference: 101, name: "Launchpad Mini",
                identity: .init(id: 11, device: 2, names: ["Launchpad Mini"])))
        input.destinations.append(
            .init(
                id: 21, reference: 201, name: "Launchpad Mini",
                identity: .init(id: 21, device: 2, names: ["Launchpad Mini"])))
        input.reconcileFactoryProfiles()
        #expect(input.isInputActive(11))
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        miniPacket([0x90, 120, 127, 120, 0], to: input)
        input.receiveBytes([0x90, 16, 127, 16, 0], source: 11)
        input.flushPendingActions()
        miniPacket([0x90, 16, 127, 16, 0], to: input)
        #expect(actions == [.hotcue1A])
    }
    let suite = "mini-setup-failure-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in false })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Launchpad Mini",
            identity: .init(id: 10, device: 1, names: ["Launchpad Mini"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "Launchpad Mini",
            identity: .init(id: 20, device: 1, names: ["Launchpad Mini"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
}
