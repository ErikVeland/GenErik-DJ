import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withAPCMiniMK2(
    decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "apc-mini-mk2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let name = "APC mini mk2"
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name,
            identity: .init(id: id, device: UInt32(id), names: [name], portNames: ["APC mini MK 2 (Control)"]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name,
            identity: .init(id: id, device: UInt32(id - 10), names: [name], portNames: ["APC mini MK 2 (Control)"]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func apcMiniMK2Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueAPCMiniMK2RoutesItsIndependentSessionGrid() throws {
    try withAPCMiniMK2 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for (side, deck) in DeckID.allCases.enumerated() {
            let base = UInt8(4 * (side % 2) + 32 * (side / 2))
            for (offset, action): (UInt8, ControllerAction) in [
                (0, .playA), (2, .syncA), (3, .loadA), (8, .cueA), (9, .loopInA), (10, .loopOutA), (11, .reloopA),
            ] {
                events.removeAll();
                apcMiniMK2Packet([0x90, base + offset, 127, base + offset, 127, base + offset, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
            for slot in 0..<8 {
                let number = base + 16 + UInt8(8 * (slot / 4) + slot % 4)
                events.removeAll(); apcMiniMK2Packet([0x90, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.action.hotcueSlot == slot && events.first?.deck == deck)
            }
        }
        events.removeAll()
        apcMiniMK2Packet([0x99, 0, 127, 0, 0, 0x96, 0, 127, 0, 0, 0x91, 0, 127, 0xB0, 0, 127], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAPCMiniMK2CueContactsAndShiftStaySourceOwned() throws {
    try withAPCMiniMK2 { input in
        var values: [Double] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        for off: UInt8 in [0x80, 0x90] {
            values.removeAll()
            apcMiniMK2Packet([0x90, 1, 1, 1, 127], input)
            apcMiniMK2Packet([0x90, 1, 64], input, source: 11)
            apcMiniMK2Packet([off, 1, off == 0x80 ? 127 : 0], input)
            #expect(values == [1.0 / 127])
            apcMiniMK2Packet([off, 1, off == 0x80 ? 127 : 0], input, source: 11)
            #expect(values == [1.0 / 127, 0])
        }
        values.removeAll()
        apcMiniMK2Packet([0x90, 1, 127], input)
        apcMiniMK2Packet([0x90, 1, 127], input, source: 11)
        apcMiniMK2Packet([0x90, 122, 127], input)
        #expect(values == [1])
        apcMiniMK2Packet([0x90, 122, 127], input, source: 11)
        #expect(values == [1, 0])
        var actions: [ControllerAction] = []
        input.onTargetAction = nil; input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        apcMiniMK2Packet([0x90, 0, 127, 0, 0, 16, 127, 16, 0], input)
        #expect(actions.isEmpty)
        apcMiniMK2Packet([0x80, 122, 127, 0x90, 0, 127, 0, 0], input)
        #expect(actions == [.playA])
    }
}

@Test @MainActor func controllerCatalogueAPCMiniMK2NineFadersKeepPickupAndExplicitTargets() throws {
    try withAPCMiniMK2 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for shifted in [false, true] {
            apcMiniMK2Packet([0x90, 122, shifted ? 127 : 0], input)
            for number: UInt8 in 48...56 {
                events.removeAll(); apcMiniMK2Packet([0xB0, number, 0], input)
                if !shifted || number < 56 {
                    #expect(events.isEmpty)
                } else {
                    #expect(events.count == 1 && events.first?.0.action == .master && events.first?.1 == 0)
                }
                events.removeAll()
                apcMiniMK2Packet([0xB0, number, 64], input); apcMiniMK2Packet([0xB0, number, 127], input)
                #expect(events.count == 2 && events.last?.1 == 1)
                if number < 56 {
                    let deck = DeckID.allCases[Int(number - 48) % 4]
                    let action: ControllerAction = number < 52 ? .levelA : .gainA
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                } else {
                    #expect(events.allSatisfy { $0.0.action == .master })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueAPCMiniMK2HidesCDWithoutFourDeckOptIn() throws {
    try withAPCMiniMK2(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        apcMiniMK2Packet(
            [0x90, 32, 127, 32, 0, 36, 127, 36, 0, 48, 127, 48, 0, 0xB0, 50, 0, 50, 64, 50, 127, 54, 64, 54, 127], input
        )
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAPCMiniMK2RetainsDistinctIdentityPortsAndFullBrightnessFeedback() throws {
    let name = "APC mini mk2"
    let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 74 && data.outputs.count == 52 && data.audioOutput == nil && data.requiresPairedSetup)
    for sibling in ["APC mini", "APC40 MKII", "APC64", "APC mini mk2 clone"] {
        #expect(ControllerFactoryProfile.matching([sibling], automaticOnly: true) != profile)
    }
    func endpoint(_ id: Int32, _ port: String) -> ControllerFactoryEndpoint {
        .init(id: id, device: 1, names: [name], portNames: [port])
    }
    for bad in ["APC mini MK 2 (Notes)", "MIDI 2", "APC mini"] {
        #expect(
            ControllerFactorySession.discover(
                sources: [endpoint(10, bad)], destinations: [endpoint(20, "APC mini MK 2 (Control)")], disabled: []
            ).isEmpty)
    }
    for lamp in profile.feedback(destination: 20) {
        #expect(lamp.channel == 6 && lamp.number < 64)
        #expect(lamp.message(value: 0) == [0x96, lamp.number, 0])
        let on: UInt8 =
            lamp.action == .cuePreviewA || lamp.action == .cuePreviewB
            ? 5
            : lamp.action == .syncA || lamp.action == .syncB || lamp.action.hotcueSlot != nil ? 45 : 19
        #expect(lamp.message(value: 1) == [0x96, lamp.number, on])
    }
}

@Test @MainActor func controllerCatalogueAPCMiniMK2SetupFailureClearsTheGridWithoutActivatingInput() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["APC mini mk2"]))
    let data = try #require(profile.definition)
    for failure in 0..<2 {
        let suite = "apc-mini-failure-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var packets: [[UInt8]] = []
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { bytes, _ in
                let index = packets.count; packets.append(bytes); return index != failure
            }, factoryInputConnector: { _ in true })
        let name = "APC mini mk2"; let port = "APC mini MK 2 (Control)"
        input.sources = [
            .init(
                id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name], portNames: [port])
            )
        ]
        input.destinations = [
            .init(
                id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name], portNames: [port])
            )
        ]
        input.reconcileFactoryProfiles()
        #expect(!input.isInputActive(10))
        #expect(packets == Array(data.startup.prefix(failure + 1)) + (data.startupAbort ?? []))
    }
}

@Test @MainActor func controllerCatalogueAPCMiniMK2StopReleasesCueAndClearsOnlyTheRGBGrid() throws {
    let suite = "apc-mini-stop-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        }, factoryInputConnector: { _ in true })
    let name = "APC mini mk2"; let port = "APC mini MK 2 (Control)"
    input.sources = [
        .init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name], portNames: [port]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name], portNames: [port]))
    ]
    input.reconcileFactoryProfiles()
    let data = try #require(ControllerFactoryProfile.matching([name])?.definition)
    #expect(packets == data.startup)
    var values: [Double] = []; input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
    apcMiniMK2Packet([0x90, 1, 127], input)
    packets.removeAll(); input.stop()
    #expect(values == [1, 0] && packets == data.shutdown)
    #expect(packets == [[240, 71, 127, 79, 36, 0, 8, 0, 63, 0, 0, 0, 0, 0, 0, 247]])
}
