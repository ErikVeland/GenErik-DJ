import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withAPC20(
    decks: [DeckID] = DeckID.allCases, paired: Bool = true,
    sender: @escaping ([UInt8], Int32) -> Bool = { _, _ in true },
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "apc20-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: sender, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "APC20",
            identity: .init(id: id, device: UInt32(id), names: ["Akai APC20"]))
    }
    if paired {
        input.destinations = [20, 21].map { id in
            .init(
                id: id, reference: UInt32(id), name: "APC20",
                identity: .init(id: id, device: UInt32(id - 10), names: ["Akai APC20"]))
        }
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) == paired && input.isInputActive(11) == paired)
    try body(input)
}

@MainActor private func apc20Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueAPC20OwnPairedModeIdentityAndObservedLampValues() throws {
    let p = try #require(ControllerFactoryProfile.matching(["APC20"])); let d = try #require(p.definition)
    #expect(d.isValid && p.selectsAutomatically && d.requiresPairedSetup && d.role == "accessory")
    #expect(d.inputs.count == 63 && d.outputs.count == 48 && d.audioOutput == nil)
    #expect(d.startup == [[0xF0, 0x47, 0x7F, 0x7B, 0x60, 0, 4, 0x42, 8, 2, 1, 0xF7]])
    #expect(d.shutdown == [[0xF0, 0x47, 0x7F, 0x7B, 0x60, 0, 4, 0x40, 8, 2, 1, 0xF7]] && d.startupAbort == d.shutdown)
    for other in ["APC40", "APC40 mkII", "APC64", "APC MINI", "APC mini mk2"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    for lamp in p.feedback(destination: 20) {
        let on: UInt8 = [.cuePreviewA, .cuePreviewB].contains(lamp.action) ? 3 : 1
        #expect(lamp.channel < 8 && (lamp.number == 49 || (53...57).contains(lamp.number)))
        #expect(
            lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, on]
                && lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
}

@Test @MainActor func controllerCatalogueAPC20AllFortyPadsAndSoftCueKeepTheirColumnPair() throws {
    try withAPC20 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (bank, deck) in DeckID.allCases.enumerated() {
            let ch = UInt8(2 * bank)
            for slot in 0..<8 {
                let status = 0x90 + ch + UInt8(slot % 2); let n = UInt8(53 + slot / 2); events.removeAll()
                apc20Packet([status, n, 127, n, 127, status - 16, n, 127], input)
                #expect(events.count == 1 && events.first?.0.deck == deck && events.first?.0.action.hotcueSlot == slot)
            }
            events.removeAll(); apc20Packet([0x90 + ch, 57, 127, 57, 127, 57, 0], input)
            #expect(
                events.count == 1 && events.first?.0 == .init(ControllerAction.playA.assigned(to: deck), deck: deck))
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll();
                    apc20Packet(
                        [0x91 + ch, 57, velocity, 57, velocity, off + ch + 1, 57, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueAPC20NineFadersAndEightPFLButtonsKeepTargetsAndPickup() throws {
    try withAPC20 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for ch: UInt8 in 0..<8 {
            let deck = DeckID.allCases[Int(ch / 2)]
            let action = (ch % 2 == 0 ? ControllerAction.levelA : .filterKnobA).assigned(to: deck)
            events.removeAll(); apc20Packet([0xB0 + ch, 7, 0], input); #expect(events.isEmpty)
            apc20Packet([0xB0 + ch, 7, 64], input); apc20Packet([0xB0 + ch, 7, 127], input)
            #expect(events.count == 2 && events.last?.0 == .init(action, deck: deck) && events.last?.1 == 1)
            events.removeAll(); apc20Packet([0x90 + ch, 49, 127, 49, 127, 49, 0], input)
            #expect(events.count == 1 && events.first?.0 == .init(ControllerAction.cueA.assigned(to: deck), deck: deck))
        }
        events.removeAll(); apc20Packet([0xB0, 14, 0], input); #expect(events.isEmpty)
        apc20Packet([0xB0, 14, 64], input); apc20Packet([0xB0, 14, 127], input)
        #expect(events.count == 2 && events.last?.0.action == .master && events.last?.1 == 1)
        events.removeAll(); apc20Packet([0xB0, 7, 0], input, source: 11); #expect(events.isEmpty)
        apc20Packet([0xB0, 7, 0], input); #expect(events.count == 1 && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueAPC20ShiftRetiresOnlyItsSourceAndRearmsMasterPickup() throws {
    try withAPC20 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        apc20Packet([0xB0, 14, 64], input); apc20Packet([0xB0, 14, 127], input)
        events.removeAll(); apc20Packet([0x91, 57, 127], input); apc20Packet([0x91, 57, 127], input, source: 11)
        apc20Packet([0x90, 81, 127, 57, 127, 0xB0, 14, 0, 47, 1, 0x94, 51, 127], input)
        #expect(events.count == 1 && events.first?.0.action == .cuePreviewA)
        apc20Packet([0x81, 57, 127], input, source: 11); #expect(events.map(\.1) == [1, 0])
        apc20Packet([0x80, 81, 127, 0xB0, 14, 0], input); #expect(events.count == 2)
        apc20Packet([0xB0, 14, 64], input); #expect(events.last?.0.action == .master)
        events.removeAll(); apc20Packet([0x91, 57, 1, 0x90, 81, 1], input)
        #expect(events.map(\.1) == [1.0 / 127, 0])
    }
}

@Test @MainActor func controllerCatalogueAPC20StrictEncoderAndRepeatedNavigationPulses() throws {
    try withAPC20 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        apc20Packet([0xB0, 47, 1], input); apc20Packet([0xB0, 47, 127], input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126] && events.allSatisfy { $0.0.action == .browse })
        events.removeAll(); apc20Packet([0xB0, 47, 0, 47, 2, 47, 126, 0xB1, 47, 1], input); #expect(events.isEmpty)
        for (ch, action): (UInt8, ControllerAction) in [
            (4, .browsePreviousGroup), (5, .browseNextGroup), (6, .browsePrevious), (7, .browseNext),
        ] {
            events.removeAll(); apc20Packet([0x90 + ch, 51, 127, 51, 127, 0x80 + ch, 51, 127], input)
            #expect(events.count == 2 && events.allSatisfy { $0.0.action == action })
        }
    }
}

@Test @MainActor func controllerCatalogueAPC20CDOptInAndUnimplementedInputsStayInactive() throws {
    try withAPC20(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 4..<8 {
            for n: UInt8 in 53...57 { apc20Packet([0x90 + ch, n, 127, n, 0], input) }
            apc20Packet([0x90 + ch, 49, 127, 49, 0, 0xB0 + ch, 7, 127], input)
        }
        apc20Packet(
            [0x90, 48, 127, 50, 127, 52, 127, 80, 127, 82, 127, 0x98, 53, 127, 0xE0, 0, 64, 0xA0, 53, 127], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAPC20PairedStartupAbortAndDefaultExitAreBounded() throws {
    let d = try #require(ControllerFactoryProfile.matching(["APC20"])?.definition)
    var packets: [Int32: [[UInt8]]] = [:]
    try withAPC20(sender: { bytes, id in
        packets[id, default: []].append(bytes); return true
    }) { input in
        #expect(packets[20] == d.startup && packets[21] == d.startup)
        var cues: [Double] = [];
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { cues.append(value) } }
        apc20Packet([0x91, 57, 127], input); packets.removeAll(); input.stop()
        #expect(cues == [1, 0] && packets[20] == d.shutdown && packets[21] == d.shutdown)
    }
    try withAPC20(
        paired: false,
        sender: { _, _ in
            Issue.record("Unpaired APC20 write"); return true
        }
    ) { input in
        apc20Packet([0x91, 57, 127], input); #expect(!input.isInputActive(10))
    }
    let suite = "apc20-failure-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            writes.append(bytes); return bytes != d.startup.first
        }, factoryInputConnector: { _ in true })
    input.sources = [.init(id: 10, reference: 10, name: "APC20", identity: .init(id: 10, device: 1, names: ["APC20"]))]
    input.destinations = [
        .init(id: 20, reference: 20, name: "APC20", identity: .init(id: 20, device: 1, names: ["APC20"]))
    ]
    input.reconcileFactoryProfiles();
    #expect(!input.isInputActive(10) && writes.first == d.startup.first && writes.last == d.shutdown.first)
}
