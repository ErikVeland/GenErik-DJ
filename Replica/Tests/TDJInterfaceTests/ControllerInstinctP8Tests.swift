import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private final class P8Packets {
    var values: [(Int32, [UInt8])] = []
}

@MainActor private func withInstinctP8(
    decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection, P8Packets) throws -> Void
) throws {
    let suite = "instinct-p8-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let packets = P8Packets()
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, id in
            packets.values.append((id, bytes)); return true
        }, deckAvailability: { decks })
    let name = "DJControl Instinct P8"
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id + 200), name: name,
            identity: .init(id: id, device: UInt32(id - 10), names: [name]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input, packets)
}

@MainActor private func p8Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueInstinctP8HasItsOwnFactoryIdentityAndBoundedLampPalette() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJControl Instinct P8"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 86 && data.outputs.count == 22 && data.audioOutput == nil)
    #expect(data.startup.count == 22 && data.startup == data.shutdown)
    let lights = profile.feedback(destination: 20)
    for light in lights {
        #expect(light.message(value: 0) == [0x90, light.number, 0])
        #expect(light.message(value: 1) == [0x90, light.number, light.action.hotcueSlot == nil ? 127 : 125])
    }
    #expect(Set(data.startup) == Set(lights.compactMap { $0.message(value: 0) }))
    for sibling in [
        "DJControl Instinct", "DJ Control Instinct", "DJControl Instinct iPad Edition", "Universal DJ", "DJControlWave",
    ] {
        #expect(ControllerFactoryProfile.matching([sibling], automaticOnly: true) != profile)
    }
}

@Test @MainActor func controllerCatalogueInstinctP8TransportKeepsAlternateReleasesAndSourceOwnership() throws {
    try withInstinctP8 { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (base, deck) in [(UInt8(0), DeckID.a), (48, .b)] {
            for note in [base + 33, base + 35] {
                events.removeAll()
                p8Packet([0x90, note, 127, note, 127, note, 0], input)
                #expect(events.count == 1 && events.first?.0.deck == deck)
            }
            for release in [base + 34, base + 37] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    p8Packet([0x90, base + 34, 127, base + 34, 127, off, release, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
        events.removeAll()
        p8Packet([0x90, 95, 127, 95, 0, 96, 127, 96, 0, 91, 127, 91, 0, 92, 127, 92, 0], input)
        #expect(events.map(\.0.action) == [.loadA, .loadB, .cueA, .cueB])
        events.removeAll()
        p8Packet([0x90, 34, 127], input)
        p8Packet([0x90, 34, 127], input, source: 11)
        p8Packet([0x80, 37, 127], input)
        #expect(events.map(\.1) == [1])
        p8Packet([0x80, 37, 127], input, source: 11)
        #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueInstinctP8JogStreamsRequireTheirOwnContactAndKeep256Counts() throws {
    try withInstinctP8 { input, _ in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        for (side, deck) in DeckID.primary.enumerated() {
            let touch = UInt8(97 + side)
            for number in [UInt8(105 + 2 * side), UInt8(106 + 2 * side)] {
                jogs.removeAll()
                p8Packet([0xB0, number, 1], input)
                #expect(jogs.isEmpty)
                p8Packet([0x90, touch, 127], input)
                for value: UInt8 in [1, 63, 64, 127] { p8Packet([0xB0, number, value], input) }
                #expect(jogs.map(\.1) == [.relative(1), .relative(63), .relative(-64), .relative(-1)])
                #expect(jogs.allSatisfy { $0.0.deck == deck && $0.0.argument == 256 })
                jogs.removeAll()
                p8Packet([0xB0, number, 1], input, source: 11)
                #expect(jogs.isEmpty)
                p8Packet([0x80, touch, 127], input)
                jogs.removeAll()
                p8Packet([0xB0, number, 1], input)
                #expect(jogs.isEmpty)
            }
            jogs.removeAll()
            for value: UInt8 in [1, 127, 64] { p8Packet([0xB0, UInt8(48 + 2 * side), value], input) }
            #expect(jogs.map(\.1) == [.relative(1), .relative(-1), .relative(-64)])
            #expect(
                jogs.allSatisfy {
                    $0.0 == .init(ControllerAction.wheelJogA.assigned(to: deck), deck: deck, argument: 256)
                })
        }
    }
}

@Test @MainActor func controllerCatalogueInstinctP8MixerTargetsRespectPickupPolarityAndCDOptIn() throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withInstinctP8(decks: decks) { input, _ in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (deck, numbers): (DeckID, [UInt8]) in [
                (.a, [64, 68, 70, 72]), (.b, [66, 80, 82, 84]), (.c, [65, 69, 71, 73]), (.d, [67, 81, 83, 85]),
            ] {
                let shift: UInt8 = (deck == .a || deck == .c) ? 99 : 47
                p8Packet([0x90, shift, (deck == .c || deck == .d) ? 127 : 0], input)
                for (index, number) in numbers.enumerated() {
                    events.removeAll()
                    let inverted = index > 0
                    p8Packet([0xB0, number, inverted ? 127 : 0], input)
                    #expect(events.isEmpty)
                    p8Packet([0xB0, number, 64], input)
                    p8Packet([0xB0, number, inverted ? 0 : 127], input)
                    #expect(events.count == (decks.contains(deck) ? 2 : 0))
                    #expect(events.allSatisfy { $0.0.deck == deck })
                    if decks.contains(deck) {
                        #expect(events.first?.1 == (inverted ? 1 - 64.0 / 127 : 64.0 / 127) && events.last?.1 == 1)
                    }
                }
            }
            events.removeAll()
            p8Packet([0xB0, 86, 0], input)
            #expect(events.isEmpty)
            p8Packet([0xB0, 86, 64], input)
            p8Packet([0xB0, 86, 127], input)
            #expect(events.map(\.0.action) == [.crossfader, .crossfader] && events.last?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCatalogueInstinctP8AllCueAndLoopPagesUseExplicitNativeFunctions() throws {
    try withInstinctP8 { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for side in 0..<2 {
            for slot in 0..<4 {
                let number = UInt8(1 + 48 * side + slot)
                events.removeAll()
                p8Packet([0x90, number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0.action.hotcueSlot == slot)
                #expect(events.first?.0.deck == DeckID.primary[side])
            }
            for (index, action) in [ControllerAction.loopInA, .loopOutA, .loopDownA, .loopUpA].enumerated() {
                events.removeAll()
                let number = UInt8(29 + index + 48 * side)
                p8Packet([0x90, number, 127, number, 0], input)
                #expect(events.map(\.0.action) == [action.assigned(to: DeckID.primary[side])])
            }
            events.removeAll()
            p8Packet([0x90, UInt8(87 + side), 127, UInt8(87 + side), 0], input)
            #expect(events.map(\.0.action) == [ControllerAction.loopA.assigned(to: DeckID.primary[side])])
            for number: UInt8 in (side == 0 ? [52, 87, 89, 97] : [54, 99, 101, 103]) {
                events.removeAll()
                for value: UInt8 in [0, 1, 127] { p8Packet([0xB0, number, value], input) }
                #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
                #expect(
                    events.allSatisfy { $0.0.action == ControllerAction.loopSizeA.assigned(to: DeckID.primary[side]) })
            }
        }
        events.removeAll()
        p8Packet([0xB0, 56, 1], input)
        p8Packet([0xB0, 56, 127], input)
        p8Packet([0x90, 43, 127, 43, 0], input)
        #expect(events.map(\.0.action) == [.browse, .browse, .openGroup])
        input.currentTargetValue = { _ in 0.5 }
        for number: UInt8 in [49, 51] {
            p8Packet([0x90, number == 49 ? 99 : 47, 127], input)
            events.removeAll()
            p8Packet([0xB0, number, 1], input)
            #expect(events.last?.1 == 0.5 + 1.0 / 1024)
            p8Packet([0xB0, number, 127], input)
            #expect(events.last?.1 == 0.5 - 1.0 / 1024)
        }
        events.removeAll()
        p8Packet([0xB0, 57, 1], input)
        #expect(events.last?.0.action == .master && events.last?.1 == 0.5 + 1.0 / 127)
    }
}

@Test @MainActor func controllerCatalogueInstinctP8ShiftAndModeChangesRetireOnlyTheirOwnedContacts() throws {
    for value: UInt8 in [0, 127] {
        try withInstinctP8 { input, _ in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in
                if target.action == .cuePreviewA || target.action == .cuePreviewB { events.append((target, value)) }
            }
            p8Packet([0x90, 34, 127, 82, 127, 99, value], input)
            #expect(events.filter { $0.0.deck == .a }.map(\.1) == [1, 0])
            #expect(events.filter { $0.0.deck == .b }.map(\.1) == [1])
            p8Packet([0x90, 48, 127, 48, 0], input)
            #expect(events.filter { $0.0.deck == .b }.map(\.1) == [1, 0])
            events.removeAll()
            p8Packet([0x90, 37, 127, 37, 0, 85, 127, 85, 0], input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueInstinctP8DisconnectClearsOnlyItsOwnReviewedLightsAndContacts() throws {
    try withInstinctP8 { input, packets in
        let data = try #require(ControllerFactoryProfile.matching(["DJControl Instinct P8"])?.definition)
        #expect(packets.values.count == 44)
        #expect(packets.values.filter { $0.0 == 20 }.map(\.1) == data.startup)
        let count = packets.values.count
        input.reconcileFactoryProfiles()
        #expect(packets.values.count == count)
        var values: [Double] = []
        input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
        p8Packet([0x90, 34, 127], input)
        p8Packet([0x90, 34, 127], input, source: 11)
        packets.values.removeAll()
        input.sources.removeAll { $0.id == 10 }
        input.reconcileFactoryProfiles()
        #expect(values == [1])
        #expect(packets.values.allSatisfy { $0.0 == 20 })
        #expect(packets.values.map(\.1) == data.shutdown)
        input.stop()
        #expect(values == [1, 0])
    }
}
