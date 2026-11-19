import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withTwitch(
    decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "twitch-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "Twitch",
            identity: .init(id: id, device: UInt32(id), names: ["Twitch"]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id + 200), name: "Twitch",
            identity: .init(id: id, device: UInt32(id - 10), names: ["Twitch"]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func twitchPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueTwitchUsesOnlyBasicPagesAndStaticLampMemory() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Twitch"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 139 && data.outputs.count == 44 && data.audioOutput == nil)
    #expect(data.requiresPairedSetup && data.startup == [[0xB7, 0, 0]])
    #expect(data.shutdown.count == 45 && data.shutdown.last == [0xB7, 0, 0])
    for lamp in profile.feedback(destination: 20) {
        let on: UInt8 =
            lamp.action == .playA || lamp.action == .playB
            ? 127 : lamp.action == .syncA || lamp.action == .syncB ? 16 : 79
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, on])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
        #expect((7...10).contains(lamp.channel))
    }
    for sibling in ["Novation Dicer", "Launchpad", "Twitch clone"] {
        #expect(ControllerFactoryProfile.matching([sibling], automaticOnly: true) != profile)
    }
}

@Test @MainActor func controllerCatalogueTwitchNeedsPairedOutputAndSuccessfulResetBeforeInput() {
    for paired in [false, true] {
        let suite = "twitch-failure-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var packets: [[UInt8]] = []
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { bytes, id in
                #expect(id == 20); packets.append(bytes); return false
            }, factoryInputConnector: { _ in true })
        input.sources = [
            .init(id: 10, reference: 100, name: "Twitch", identity: .init(id: 10, device: 1, names: ["Twitch"]))
        ]
        if paired {
            input.destinations = [
                .init(id: 20, reference: 200, name: "Twitch", identity: .init(id: 20, device: 1, names: ["Twitch"]))
            ]
        }
        input.reconcileFactoryProfiles()
        #expect(!input.isInputActive(10))
        var actions: [ControllerAction] = []
        input.onTargetAction = nil
        input.onAction = { action, _ in actions.append(action) }
        twitchPacket([0x97, 23, 127, 23, 0], input)
        #expect(actions.isEmpty)
        #expect(packets == (paired ? [[0xB7, 0, 0]] : []))
    }
}

@Test @MainActor func controllerCatalogueTwitchLoadsFollowIndependentSourceBanksAndResetAfterReconnect() throws {
    try withTwitch { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in
            if target.action == .loadA || target.action == .loadB { targets.append(target) }
        }
        twitchPacket([0x97, 82, 127, 82, 0, 83, 127, 83, 0, 0, 127, 0, 127, 82, 127, 82, 0, 83, 127, 83, 0], input)
        #expect(targets.map(\.deck) == [.a, .b, .c, .b])
        twitchPacket([0x97, 82, 127, 82, 0], input, source: 11)
        twitchPacket([0x98, 0, 127, 0, 0, 0x97, 83, 127, 83, 0], input)
        #expect(targets.suffix(2).map(\.deck) == [.a, .d])
        for off: UInt8 in [0x87, 0x97] {
            twitchPacket([off, 0, off == 0x87 ? 127 : 0, 0x97, 0, 127, 82, 127, 82, 0], input)
        }
        #expect(targets.suffix(2).map(\.deck) == [.a, .c])
        let saved = input.sources
        input.sources = saved.filter { $0.id != 10 }; input.reconcileFactoryProfiles()
        input.sources = saved; input.reconcileFactoryProfiles()
        twitchPacket([0x97, 82, 127, 82, 0, 83, 127, 83, 0], input)
        #expect(targets.suffix(2).map(\.deck) == [.a, .b])
    }
    try withTwitch(decks: DeckID.primary) { input in
        var loads: [ControllerAction] = []
        input.onAction = { action, _ in if action == .loadA || action == .loadB { loads.append(action) } }
        twitchPacket([0x97, 0, 127, 0, 0, 82, 127, 82, 0, 0x98, 0, 127, 0, 0, 0x97, 83, 127, 83, 0], input)
        #expect(loads.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueTwitchTransportPadsAndRelativeTempoUseExplicitDeckChannels() throws {
    try withTwitch { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (side, deck) in DeckID.allCases.enumerated() {
            let note: UInt8 = 0x97 + UInt8(side)
            for (number, action): (UInt8, ControllerAction) in [
                (23, .playA), (16, .syncA), (18, .jumpBackA), (19, .jumpForwardA), (3, .tempoResetA),
                (10, .filterToggleA),
            ] {
                events.removeAll()
                twitchPacket([note, number, 127, number, 127, number, 0], input)
                #expect(events.map(\.0.action) == [action.assigned(to: deck)] && events.first?.0.deck == deck)
            }
            for off: UInt8 in [note, note - 16] {
                events.removeAll()
                twitchPacket([note, 22, 127, 22, 127, off, 22, off == note ? 0 : 127], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
            for slot: UInt8 in 0..<8 {
                events.removeAll()
                twitchPacket([note, 96 + slot, 127, 96 + slot, 0, 112 + slot, 127, 112 + slot, 0], input)
                #expect(events.count == 2 && events.first?.0.action.hotcueSlot == Int(slot))
                #expect(events.last?.0.argument == [0.25, 0.5, 1, 2, 4, 8, 16, 32][Int(slot)])
            }
            events.removeAll()
            twitchPacket([note + 32, 3, 1], input)
            twitchPacket([note + 32, 3, 127], input)
            #expect(events.map(\.1) == [0.5 + 1.0 / 127, 0.5 - 1.0 / 127])
        }
    }
}

@Test @MainActor func controllerCatalogueTwitchStripAcceptsEveryPositivePositionAndGatesFlingAfterRelease() throws {
    try withTwitch { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        var contacts: [Double] = []
        input.onTargetAction = { target, value in
            if target.action == .jogTouchA && target.deck == .a { contacts.append(value) }
        }
        for contact: UInt8 in [1, 64, 127] {
            twitchPacket([0xB7, 53, 1], input)
            #expect(jogs.isEmpty)
            twitchPacket([0x97, 71, contact, 0xB7, 53, 1], input)
            #expect(jogs.map(\.1) == [.relative(1)] && jogs.first?.0.argument == 127)
            twitchPacket([0x97, 71, 0], input)
            jogs.removeAll()
            twitchPacket([0xB7, 53, 1], input)
            #expect(jogs.isEmpty)
        }
        #expect(
            contacts.count == 6
                && contacts.enumerated().allSatisfy { $0.offset.isMultiple(of: 2) ? $0.element > 0 : $0.element == 0 })
        twitchPacket([0x97, 71, 1, 0xB7, 53, 127], input)
        #expect(jogs.last?.1 == .relative(-1))
        jogs.removeAll()
        twitchPacket([0xB7, 53, 1], input, source: 11)
        #expect(jogs.isEmpty)
        twitchPacket([0x97, 0, 127, 0, 0], input)
        #expect(contacts.last == 0)
        jogs.removeAll()
        twitchPacket([0xB7, 53, 1], input)
        #expect(jogs.isEmpty)
        var seeks: [Double] = []
        input.onTargetAction = { target, value in if target.action == .seekA { seeks.append(value) } }
        for value: UInt8 in [0, 64, 127] { twitchPacket([0xB7, 52, value], input) }
        #expect(seeks == [0, 64.0 / 127, 1])
    }
}

@Test @MainActor func controllerCatalogueTwitchComposesShiftAndRetiresContactsOnPadAndBankChanges() throws {
    try withTwitch { input in
        var cues: [Double] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { cues.append(value) }
        }
        twitchPacket([0x97, 22, 127, 56, 127, 56, 0], input)
        #expect(cues == [1, 0])
        twitchPacket([0x97, 22, 127, 17, 127, 0x98, 17, 127], input)
        #expect(cues == [1, 0, 1, 0])
        var actions: [ControllerAction] = []
        input.onTargetAction = nil
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        twitchPacket([0x87, 17, 127, 0xB7, 85, 1], input)
        #expect(actions == [.browseGroups])
        actions.removeAll()
        twitchPacket([0x88, 17, 127, 0xB7, 85, 1, 0x97, 85, 127, 85, 0, 86, 127, 86, 0], input)
        #expect(actions == [.browse, .openGroup, .openGroup])
        actions.removeAll()
        twitchPacket([0x97, 80, 127, 81, 127, 84, 127, 104, 127, 120, 127, 0xB7, 6, 1, 0, 111], input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueTwitchMixerPickupAndStopCleanupStayBounded() throws {
    try withTwitch { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (side, deck) in DeckID.allCases.enumerated() {
            for number: UInt8 in [7, 9, 70, 71, 72] {
                events.removeAll()
                let control: UInt8 = 0xB7 + UInt8(side)
                twitchPacket([control, number, 0], input)
                #expect(events.isEmpty)
                twitchPacket([control, number, 64], input)
                twitchPacket([control, number, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0.deck == deck } && events.last?.1 == 1)
            }
        }
        var cues: [Double] = []
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { cues.append(value) } }
        twitchPacket([0x97, 22, 127], input)
        input.stop()
        #expect(cues == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueTwitchCleanupClearsOnlySelectedLampsAndRestoresBasicMode() throws {
    let suite = "twitch-cleanup-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, id in
            #expect(id == 20); packets.append(bytes); return true
        }, factoryInputConnector: { _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "Twitch", identity: .init(id: 10, device: 1, names: ["Twitch"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "Twitch", identity: .init(id: 20, device: 1, names: ["Twitch"]))
    ]
    input.reconcileFactoryProfiles()
    let data = try #require(ControllerFactoryProfile.matching(["Twitch"])?.definition)
    #expect(packets == data.startup)
    packets.removeAll()
    input.stop()
    #expect(packets == data.shutdown)
    #expect(!packets.contains([0xB7, 0, 112]) && !packets.contains([0x97, 9, 127]))
}
