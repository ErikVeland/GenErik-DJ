import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let apc64Reply: [UInt8] = [0xF0, 0x7E, 0, 6, 2, 0x47, 0x53, 0, 0x19, 1, 1, 0, 14, 0, 0xF7]
private func apc64ModeReport(_ mode: UInt8) -> [UInt8] { [0xF0, 0x47, 0, 0x53, 0x19, 0, 1, mode, 0xF7] }

@MainActor private func withAPC64(
    decks: [DeckID] = DeckID.allCases, paired: Bool = true, ready: Bool = true,
    sender: @escaping ([UInt8], Int32) -> Bool = { _, _ in true },
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "apc64-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: sender, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "APC64",
            identity: .init(id: id, device: UInt32(id), names: ["APC64"], portNames: ["APC64 DAW (APC64)"]))
    }
    if paired {
        input.destinations = [20, 21].map { id in
            .init(
                id: id, reference: UInt32(id), name: "APC64",
                identity: .init(id: id, device: UInt32(id - 10), names: ["APC64"], portNames: ["APC64 DAW (APC64)"]))
        }
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    if ready && paired {
        for source: Int32 in [10, 11] { input.receiveBytes(apc64Reply, source: source); input.flushPendingActions() }
        #expect(input.isInputActive(10) && input.isInputActive(11))
    }
    try body(input)
}

@MainActor private func apc64Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueAPC64OwnIdentityChannelsColoursAndSchema() throws {
    let p = try #require(ControllerFactoryProfile.matching(["APC64"])); let d = try #require(p.definition)
    #expect(d.isValid && p.selectsAutomatically && d.inputProtocol == .apc64 && d.requiresPairedSetup)
    #expect(d.inputs.count == 73 && d.outputs.count == 52 && d.audioOutput == nil)
    for other in ["APC64 Notes (APC64)", "MIDIIN2 (APC64)", "APC MINI", "APC mini mk2", "APC20", "APC40"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    for lamp in p.feedback(destination: 20) {
        let on: UInt8 =
            [.cuePreviewA, .cuePreviewB].contains(lamp.action)
            ? 5 : [.syncA, .syncB].contains(lamp.action) || lamp.action.hotcueSlot != nil ? 13 : 21
        #expect(
            lamp.channel == 6 && lamp.message(value: 1) == [0x96, lamp.number, on]
                && lamp.message(value: 0) == [0x96, lamp.number, 0])
    }
    let base: [String: Any] = [
        "id": "APC64 abort fixture", "aliases": ["APC64 abort fixture"], "source": "fixture", "scope": "fixture",
        "autoSelect": true, "role": "accessory", "inputProtocol": "apc64",
        "startup": d.startup, "shutdown": d.shutdown, "startupAbort": d.startupAbort!, "outputs": [],
        "inputs": [
            ["action": "playA", "kind": "note", "channel": 6, "number": 0, "encoding": "absolute", "inverted": false]
        ],
    ]
    for (key, value): (String, Any) in [("role", "player"), ("autoSelect", false), ("startup", []), ("shutdown", [])] {
        var invalid = base; invalid[key] = value
        #expect(throws: (any Error).self) {
            try ControllerProfileCatalogue.decode(
                JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [invalid]]))
        }
    }
}

@Test @MainActor func controllerCatalogueAPC64All64PadsAndCueReleaseFormsKeepOwnTargets() throws {
    try withAPC64 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            let base = UInt8(32 * (side / 2) + 4 * (side % 2))
            for (offset, action): (UInt8, ControllerAction) in [
                (0, .playA), (2, .syncA), (3, .loadA), (8, .cueA), (9, .loopInA), (10, .loopOutA), (11, .reloopA),
            ] {
                let n = base + offset; events.removeAll(); apc64Packet([0x96, n, 127, n, 127, n, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for slot in 0..<8 {
                let n = base + 16 + UInt8(8 * (slot / 4) + slot % 4); events.removeAll()
                apc64Packet([0x96, n, 127, n, 127, 0x86, n, 127], input)
                #expect(events.count == 1 && events.first?.0.deck == deck && events.first?.0.action.hotcueSlot == slot)
            }
            let n = base + 1
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x86, 0x96] {
                    events.removeAll(); apc64Packet([0x96, n, velocity, n, 127, off, n, off == 0x86 ? 127 : 0], input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueAPC64Eight14BitStripsKeepPickupTargetsAndSourceIsolation() throws {
    try withAPC64 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for column: UInt8 in 0..<8 {
            let deck = DeckID.allCases[Int(column % 4)]
            let action = (column < 4 ? ControllerAction.levelA : .filterKnobA).assigned(to: deck)
            events.removeAll(); apc64Packet([0xE0 + column, 0, 0], input); #expect(events.isEmpty)
            apc64Packet([0xE0 + column, 0, 64], input); apc64Packet([0xE0 + column, 127, 127], input)
            #expect(
                events.count == 2 && events.first?.1 == 8192.0 / 16383 && events.last?.0 == .init(action, deck: deck)
                    && events.last?.1 == 1)
        }
        events.removeAll(); apc64Packet([0xE0, 0, 0], input, source: 11); #expect(events.isEmpty)
        apc64Packet([0xE0, 0, 64], input, source: 11)
        apc64Packet(apc64ModeReport(2), input); apc64Packet(apc64ModeReport(0), input)
        events.removeAll(); apc64Packet([0xE0, 0, 0], input, source: 11);
        #expect(events.count == 1 && events.last?.1 == 0)
        apc64Packet([0xE0, 0, 0], input); #expect(events.count == 1)
    }
}

@Test @MainActor func controllerCatalogueAPC64ModeLossRetiresOnlyItsSourceAndRequiresSuccessfulReturn() throws {
    var failReturn = false
    try withAPC64(sender: { bytes, id in
        !(failReturn && id == 20 && bytes == ControllerAPC64Decoder.dawRequest(active: true))
    }) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        apc64Packet([0x96, 1, 1], input); apc64Packet([0x96, 1, 127], input, source: 11)
        apc64Packet(apc64ModeReport(0), input); #expect(events.count == 1)
        apc64Packet(apc64ModeReport(2), input)
        #expect(
            !input.isInputActive(10) && input.isInputActive(11) && !input.factoryOutputIsReady(20)
                && input.factoryOutputIsReady(21))
        #expect(events.count == 1)
        apc64Packet([0x96, 0, 127, 1, 127, 0xE0, 127, 127], input); #expect(events.count == 1)
        apc64Packet([0x86, 1, 127], input, source: 11); #expect(events.map(\.1) == [1.0 / 127, 0])
        apc64Packet(apc64ModeReport(0), input); #expect(input.isInputActive(10) && input.factoryOutputIsReady(20))
        apc64Packet([0x96, 1, 127], input); apc64Packet(apc64ModeReport(9), input)
        #expect(events.suffix(2).map(\.1) == [1, 0])
        failReturn = true; apc64Packet(apc64ModeReport(0), input); #expect(!input.isInputActive(10))
    }
}

@Test @MainActor func controllerCatalogueAPC64PairedIdentityStartupAndEveryFailureStayClosed() throws {
    let d = try #require(ControllerFactoryProfile.matching(["APC64"])?.definition)
    var packets: [Int32: [[UInt8]]] = [:]
    try withAPC64(
        ready: false,
        sender: { bytes, id in
            packets[id, default: []].append(bytes); return true
        }
    ) { input in
        #expect(packets[20] == d.startup && packets[21] == d.startup)
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        var other = apc64Reply; other[6] = 0x4F
        apc64Packet(other + [0x96, 0, 127], input); #expect(!input.isInputActive(10) && events.isEmpty)
        apc64Packet(Array(apc64Reply.prefix(7)), input); #expect(!input.isInputActive(10))
        apc64Packet(Array(apc64Reply.dropFirst(7)), input)
        #expect(
            input.isInputActive(10) && !input.isInputActive(11)
                && packets[20]?.last == ControllerAPC64Decoder.dawRequest(active: true))
    }
    for failure in 0..<3 {
        var seen: [[UInt8]] = []
        try withAPC64(
            ready: false,
            sender: { bytes, id in
                guard id == 20 else { return true }; let index = seen.count; seen.append(bytes); return index != failure
            }
        ) { input in
            #expect(!input.isInputActive(10) && seen.starts(with: Array(d.startup.prefix(failure + 1))))
            #expect(seen.dropFirst(failure + 1).contains(ControllerAPC64Decoder.dawRequest(active: false)))
        }
    }
    try withAPC64(
        ready: false, sender: { bytes, id in !(id == 20 && bytes == ControllerAPC64Decoder.dawRequest(active: true)) }
    ) { input in
        apc64Packet(apc64Reply, input); #expect(!input.isInputActive(10))
    }
    try withAPC64(
        paired: false, ready: false,
        sender: { _, _ in
            Issue.record("Unpaired APC64 write"); return true
        }
    ) { input in
        apc64Packet(apc64Reply + [0x96, 0, 127], input); #expect(!input.isInputActive(10))
    }
}

@Test @MainActor func controllerCatalogueAPC64StopClearsOnlyMappedGridLampsThenExitsDAW() throws {
    var packets: [Int32: [[UInt8]]] = [:]
    try withAPC64(sender: { bytes, id in
        packets[id, default: []].append(bytes); return true
    }) { input in
        var cues: [Double] = [];
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { cues.append(value) } }
        apc64Packet([0x96, 1, 127], input); packets.removeAll(); input.stop()
        let d = try #require(ControllerFactoryProfile.matching(["APC64"])?.definition)
        #expect(cues == [1, 0] && packets[20] == d.shutdown && packets[21] == d.shutdown)
        #expect(d.shutdown.count == 53 && d.shutdown.last == ControllerAPC64Decoder.dawRequest(active: false))
        #expect(d.shutdown.dropLast().allSatisfy { $0.count == 3 && $0[0] == 0x96 && $0[1] < 64 && $0[2] == 0 })
    }
}

@Test @MainActor func controllerCatalogueAPC64ShutdownFailureStillAttemptsDAWExit() throws {
    let d = try #require(ControllerFactoryProfile.matching(["APC64"])?.definition)
    for failure in d.shutdown.indices {
        var stopping = false
        var packets: [[UInt8]] = []
        try withAPC64(sender: { bytes, id in
            guard id == 20 && stopping else { return true }
            let index = packets.count; packets.append(bytes); return index != failure
        }) { input in
            stopping = true; input.stop()
            let expected = Array(d.shutdown.prefix(failure + 1)) + [ControllerAPC64Decoder.dawRequest(active: false)]
            #expect(packets == expected)
            #expect(!input.isInputActive(10) && !input.isInputActive(11))
        }
    }
}

@Test @MainActor func controllerCatalogueAPC64CDOptInShiftCleanupAndUnknownTrafficStayBounded() throws {
    try withAPC64(decks: DeckID.primary) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for n: UInt8 in 32..<64 { apc64Packet([0x96, n, 127, n, 0], input) }
        for ch: UInt8 in [2, 3, 6, 7] { apc64Packet([0xE0 + ch, 0, 64], input) }
        apc64Packet([0x90, 0, 127, 82, 127, 0x99, 36, 127, 0xB0, 48, 127, 0xA6, 0, 127], input)
        #expect(events.isEmpty)
        apc64Packet([0x96, 1, 1], input); apc64Packet([0x90, 120, 127, 0x96, 0, 127, 1, 127, 0xE0, 127, 127], input)
        #expect(events.map(\.1) == [1.0 / 127, 0])
        apc64Packet([0x80, 120, 127, 0x96, 0, 127, 0, 0], input)
        #expect(events.last?.0.action == .playA)
    }
}
