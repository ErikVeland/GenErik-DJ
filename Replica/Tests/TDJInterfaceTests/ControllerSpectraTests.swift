import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSpectra(
    decks: [DeckID] = DeckID.allCases, startupSucceeds: Bool = true,
    _ body: (ControllerMIDIConnection, [[UInt8]]) -> Void
) {
    let suite = "spectra-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var sent: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { packet, _ in
            sent.append(packet); return startupSucceeds
        }, deckAvailability: { decks })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Midi Fighter Spectra",
            identity: .init(id: 10, device: 1, names: ["Midi Fighter Spectra"])),
        .init(
            id: 11, reference: 101, name: "Midi Fighter Spectra",
            identity: .init(id: 11, device: 2, names: ["Midi Fighter Spectra"])),
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "Midi Fighter Spectra",
            identity: .init(id: 20, device: 1, names: ["Midi Fighter Spectra"])),
        .init(
            id: 21, reference: 201, name: "Midi Fighter Spectra",
            identity: .init(id: 21, device: 2, names: ["Midi Fighter Spectra"])),
    ]
    input.reconcileFactoryProfiles()
    body(input, sent)
}

@MainActor private func spectraPacket(_ bytes: [UInt8], source: Int32 = 10, to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSpectraInitialisesTransientHotcueBankAndKeepsFamilyAliasesSeparate() {
    withSpectra { input, sent in
        #expect(input.isInputActive(10) && input.isInputActive(11))
        #expect(sent == [[0x93, 1, 127], [0x93, 1, 127]])
        #expect(
            ControllerFactoryProfile.matching(["Midi Fighter Spectra"])?.definition?.inputProtocol
                == .midiFighterSpectra)
        for name in ["Midi Fighter Classic", "Midi Fighter Twister", "Midi Fighter 3D", "Midi Fighter 64"] {
            #expect(ControllerFactoryProfile.matching([name])?.definition?.inputProtocol != .midiFighterSpectra)
        }
    }
    withSpectra(startupSucceeds: false) { input, _ in
        #expect(!input.isInputActive(10) && !input.isInputActive(11))
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        spectraPacket([0x92, 60, 127], to: input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueSpectraRoutesEightCuesThroughBothSelectorRowsAndFourDeckOptIn() {
    for decks in [DeckID.primary, DeckID.allCases] {
        withSpectra(decks: decks) { input, _ in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
            for base: UInt8 in [52, 84] {
                for (channel, deck) in DeckID.allCases.enumerated() {
                    spectraPacket([0x92, base + UInt8(channel), 127], to: input)
                    for (slot, note) in [60, 61, 62, 63, 56, 57, 58, 59].enumerated() {
                        events.removeAll()
                        spectraPacket([0x92, UInt8(note), 127, 0x82, UInt8(note), 127], to: input)
                        #expect(events.count == (decks.contains(deck) ? 1 : 0))
                        if decks.contains(deck) {
                            #expect(events.first?.deck == deck && events.first?.action.hotcueSlot == slot)
                        }
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueSpectraFilterOrderStaysFixedAndOtherLayersCannotTriggerCues() {
    withSpectra { input, _ in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        spectraPacket([0x92, 55, 127], to: input)
        for note: UInt8 in 36...39 { spectraPacket([0x92, note, 127, note, 0], to: input) }
        #expect(
            events == [
                .init(.filterToggleA, deck: .c), .init(.filterToggleA, deck: .a), .init(.filterToggleB, deck: .b),
                .init(.filterToggleB, deck: .d),
            ])
        events.removeAll()
        spectraPacket(
            [0x92, 48, 127, 64, 127, 68, 127, 80, 127, 92, 127, 96, 127, 0xB3, 60, 127, 0x90, 60, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueSpectraDeckAndBankBoundariesReleaseOnlyOwnedLearnedCueContacts() {
    withSpectra { input, _ in
        input.select(10)
        input.learning = .cuePreviewA
        spectraPacket([0x92, 60, 127, 60, 0], to: input)
        var events: [Double] = []
        input.onAction = { action, value in if action == .cuePreviewA { events.append(value) } }
        spectraPacket([0x92, 60, 127], to: input)
        spectraPacket([0x92, 53, 127], to: input)
        #expect(events == [1, 0])
        spectraPacket([0x92, 52, 127, 60, 127], to: input)
        spectraPacket([0x83, 1, 127, 0x93, 2, 127], to: input)
        #expect(events == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueSpectraKeepsSourceSelectionSeparateAndResetsOnReconnectAndOverload() {
    withSpectra { input, _ in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        spectraPacket([0x92, 55, 127, 60, 127, 60, 0], to: input)
        spectraPacket([0x92, 60, 127, 60, 0], source: 11, to: input)
        #expect(events == [.init(.hotcue1B, deck: .d), .init(.hotcue1A, deck: .a)])
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        events.removeAll()
        spectraPacket([0x92, 60, 127, 60, 0], to: input)
        #expect(events == [.init(.hotcue1A, deck: .a)])
        events.removeAll()
        #expect(input.receiveBytes([0x92, 55, 127, 60, 127], source: 10, limit: 1) == nil)
        #expect(events.isEmpty)
        #expect(input.status.contains("overload"))
    }
}
