import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withKeyLab(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "keylab-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "KeyLab 88", identity: .init(id: 10, device: 1, names: ["KeyLab 88"])),
        .init(id: 11, reference: 101, name: "KeyLab 88", identity: .init(id: 11, device: 2, names: ["KeyLab 88"])),
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func keyLabPacket(
    _ bytes: [UInt8], source: Int32 = 10, time: UInt64 = 1, to input: ControllerMIDIConnection
) {
    input.receiveBytes(bytes, source: source, timestamp: time)
    input.flushPendingActions()
}

@MainActor private func selectKeyLab(_ deck: DeckID, input: ControllerMIDIConnection) {
    let number: UInt8 = deck.leftSide ? 118 : 119
    keyLabPacket([0xB0, number, 127], time: 1, to: input)
    keyLabPacket([0xB0, number, 0], time: deck == .c || deck == .d ? 275_000_001 : 2, to: input)
}

@Test @MainActor func controllerCatalogueKeyLabQualifiesOnlyOriginal88AndKeepsInputOnlyLifecycle() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["KeyLab 88"], automaticOnly: true))
    #expect(profile.rawValue == "Arturia KeyLab 88 Mk 1" && profile.definition?.inputs.count == 83)
    #expect(
        profile.definition?.outputs.isEmpty == true && profile.definition?.startup.isEmpty == true
            && profile.definition?.shutdown.isEmpty == true)
    #expect(ControllerFactoryProfile.matching(["Arturia KeyLab Mk 1", "KeyLab 88"]) == profile)
    for name in [
        "Arturia KeyLab Mk 1", "KeyLab Mk 1", "KeyLab 25", "KeyLab 49", "KeyLab 61", "KeyLab Essential",
        "KeyLab 88 mkII", "KeyLab Mk3",
    ] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
    #expect(ControllerFactoryProfile.matching(["KeyLab 88", "Arturia KeyLab 88 mkII"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueKeyLabRoutesAllMMCPulsesAfterTimedDeckSelection() {
    for decks in [DeckID.primary, DeckID.allCases] {
        withKeyLab(decks: decks) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in events.append((target, value)) }
            let commands: [(UInt8, ControllerAction)] = [
                (1, .cuePreviewA), (2, .playA), (4, .jumpForwardA), (5, .jumpBackA), (55, .reloopA),
            ]
            for deck in DeckID.allCases {
                selectKeyLab(deck, input: input)
                for (command, action) in commands {
                    events.removeAll()
                    keyLabPacket([0xF0, 0x7F, 0x7F, 6, command, 0xF7], to: input)
                    let count = decks.contains(deck) ? (action.isMomentary ? 2 : 1) : 0
                    #expect(
                        events.map(\.0) == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: count))
                    if count == 2 { #expect(events.map(\.1) == [1, 0]) }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueKeyLabKeepsFixedCABDFadersAndSelectedKnobsSeparate() throws {
    try withKeyLab { input in
        let definition = try #require(ControllerFactoryProfile.matching(["KeyLab 88"])?.definition)
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for deck in DeckID.allCases {
            selectKeyLab(deck, input: input)
            for number: UInt8 in [74, 71, 76, 77, 93] {
                events.removeAll()
                keyLabPacket([0xB0, number, 127], to: input)
                let row = try #require(
                    definition.inputs.first {
                        $0.kind == .control && $0.channel == UInt8(DeckID.allCases.firstIndex(of: deck)!)
                            && $0.number == number
                    })
                #expect(events.count == 1 && events.first?.0 == row.binding(source: 10).target && events.first?.1 == 1)
            }
        }
        for row in definition.inputs.filter({ $0.channel == 4 }) {
            for raw: UInt8 in [0, 64, 127] {
                events.removeAll()
                keyLabPacket([0xB0, row.number, raw], to: input)
                #expect(events.count == 1 && events.first?.0 == row.binding(source: 10).target)
                if [.tempoA, .tempoB].contains(row.action) {
                    #expect(events.first?.1 == (raw == 64 ? 0.5 : raw == 0 ? 1 : 0))
                } else {
                    #expect(events.first?.1 == Double(raw) / 127)
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueKeyLabKeepsBothCueLayoutsAndBlocksSamplerAndKeyboardTraffic() {
    withKeyLab { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for deck in DeckID.allCases {
            selectKeyLab(deck, input: input)
            for (layout, numbers): (UInt8, [UInt8]) in [
                (22, [44, 45, 46, 47, 40, 41, 42, 43]), (23, [48, 49, 50, 51, 44, 45, 46, 47]),
            ] {
                keyLabPacket([0xB0, layout, 127, layout, 0], to: input)
                events.removeAll()
                for number in numbers { keyLabPacket([0x99, number, 127, 0x89, number, 127], to: input) }
                #expect(events.map(\.deck) == Array(repeating: Optional(deck), count: 8))
                #expect(events.map { $0.action.hotcueSlot } == (0..<8).map(Optional.init))
            }
            events.removeAll()
            keyLabPacket(
                [0xB0, 24, 0, 0x99, 48, 127, 44, 127, 0x90, 2, 127, 48, 127, 0xB0, 1, 127, 2, 127, 0xB4, 73, 127],
                to: input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueKeyLabLayerChangeReleasesLearnedPadCueWithoutLosingRearm() {
    withKeyLab { input in
        input.select(10)
        input.learning = .cuePreviewA
        keyLabPacket([0x99, 44, 127, 44, 0], to: input)
        var values: [Double] = []
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        keyLabPacket([0x99, 44, 127], to: input)
        keyLabPacket([0xB0, 24, 0], to: input)
        #expect(values == [1, 0])
        keyLabPacket([0xB0, 22, 0, 0x99, 44, 127, 44, 0], to: input)
        #expect(values == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueKeyLabKeepsSourcesIndependentAndResetsReconnectAndExpandedOverload() {
    withKeyLab { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        selectKeyLab(.b, input: input)
        keyLabPacket([0xF0, 0x7F, 0x7F, 6, 2, 0xF7], to: input)
        keyLabPacket([0xF0, 0x7F, 0x7F, 6, 2, 0xF7], source: 11, to: input)
        #expect(events == [.init(.playB, deck: .b), .init(.playA, deck: .a)])
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        events.removeAll()
        keyLabPacket([0xF0, 0x7F, 0x7F, 6, 2, 0xF7], to: input)
        #expect(events == [.init(.playA, deck: .a)])
        events.removeAll()
        #expect(input.receiveBytes([0xF0, 0x7F, 0x7F, 6, 2, 0xF7], source: 10, limit: 1) == nil)
        #expect(events.isEmpty && input.status.contains("overload"))
    }
}
