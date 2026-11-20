import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withLaunchpadS(
    decks: [DeckID] = DeckID.allCases,
    sender: @escaping ([UInt8], Int32) -> Bool = { _, _ in true },
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "launchpad-s-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: sender, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Launchpad S",
            identity: .init(id: id, device: UInt32(id), names: ["Launchpad S"]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Launchpad S",
            identity: .init(id: id, device: UInt32(id - 10), names: ["Launchpad S"]))
    }
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func launchpadSPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

private func launchpadSNumber(_ side: Int, _ row: Int, _ column: Int) -> UInt8 {
    UInt8(16 * (7 - 4 * (side / 2) - row) + 4 * (side % 2) + column)
}

@Test @MainActor func controllerCatalogueLaunchpadSAll64OwnGridTargets() throws {
    try withLaunchpadS { input in
        #expect(input.isInputActive(10) && input.isInputActive(11))
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (side, deck) in DeckID.allCases.enumerated() {
            for (row, column, action): (Int, Int, ControllerAction) in [
                (0, 0, .playA), (0, 2, .syncA), (0, 3, .loadA), (1, 0, .cueA), (1, 1, .loopInA), (1, 2, .loopOutA),
                (1, 3, .reloopA),
            ] {
                let n = launchpadSNumber(side, row, column); events.removeAll()
                launchpadSPacket([0x90, n, 127, n, 127, n, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
            for slot in 0..<8 {
                let n = launchpadSNumber(side, 2 + slot / 4, slot % 4); events.removeAll()
                launchpadSPacket([0x90, n, 127, n, 127, 0x80, n, 127], input)
                #expect(events.count == 1 && events.first?.action.hotcueSlot == slot && events.first?.deck == deck)
            }
        }
        events.removeAll()
        launchpadSPacket([0xB0, 104, 127, 0x90, 8, 127, 24, 127, 0x91, 0, 127, 0xA0, 0, 127], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueLaunchpadSCueBothReleaseFormsSourcesAndStop() throws {
    try withLaunchpadS { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target, value)) }
        }
        for (side, deck) in DeckID.allCases.enumerated() {
            let n = launchpadSNumber(side, 0, 1)
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    launchpadSPacket([0x90, n, velocity, n, 127], input)
                    launchpadSPacket([0x90, n, 127], input, source: 11)
                    launchpadSPacket([off, n, off == 0x80 ? 127 : 0], input)
                    #expect(events.count == 1)
                    launchpadSPacket([off, n, off == 0x80 ? 127 : 0], input, source: 11)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
        events.removeAll(); launchpadSPacket([0x90, 113, 127], input); input.stop()
        #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueLaunchpadSUpperDecksRequireOptIn() throws {
    try withLaunchpadS(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for side in 2..<4 {
            for row in 0..<4 {
                for column in 0..<4 {
                    let n = launchpadSNumber(side, row, column); launchpadSPacket([0x90, n, 127, n, 0], input)
                }
            }
        }
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueLaunchpadSOwnColoursIdentityAndTemporarySetup() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Launchpad S"])); let d = try #require(p.definition)
    #expect(
        d.isValid && p.selectsAutomatically && d.inputs.count == 64 && d.outputs.count == 52 && d.audioOutput == nil)
    #expect(
        d.startup == [[0xB0, 0, 0], [0xB0, 0, 1], [0xB0, 0, 32]] && d.shutdown == [[0xB0, 0, 0]]
            && d.startupAbort == d.shutdown)
    for lamp in p.feedback(destination: 20) {
        let on: UInt8 =
            [.cuePreviewA, .cuePreviewB].contains(lamp.action)
            ? 15 : [.syncA, .syncB].contains(lamp.action) || lamp.action.hotcueSlot != nil ? 63 : 60
        #expect(
            lamp.message(value: 1) == [0x90, lamp.number, on] && lamp.message(value: 0) == [0x90, lamp.number, 12])
    }
    for other in ["Launchpad", "Launchpad Mini", "Launchpad MK2", "Launchpad X", "Launchpad Pro", "Launchpad Pro MK3"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    var packets: [Int32: [[UInt8]]] = [:]
    try withLaunchpadS(sender: { bytes, id in
        packets[id, default: []].append(bytes); return true
    }) { input in
        #expect(packets[20] == d.startup && packets[21] == d.startup)
        packets.removeAll(); input.stop()
        #expect(packets[20] == d.shutdown && packets[21] == d.shutdown)
    }
}

@Test @MainActor func controllerCatalogueLaunchpadSFailedOrMissingOutputCannotActivateInput() throws {
    let d = try #require(ControllerFactoryProfile.matching(["Launchpad S"])?.definition)
    for failure in 0..<3 {
        var packets: [[UInt8]] = []
        try withLaunchpadS(sender: { bytes, id in
            guard id == 20 else { return false }
            let index = packets.count; packets.append(bytes); return index != failure
        }) { input in
            #expect(!input.isInputActive(10))
            #expect(packets == Array(d.startup.prefix(failure + 1)) + [[0xB0, 0, 0]])
        }
    }
    let suite = "launchpad-s-unpaired-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Unpaired output write"); return true
        }, factoryInputConnector: { _ in true })
    input.sources = [
        .init(id: 10, reference: 10, name: "Launchpad S", identity: .init(id: 10, device: 10, names: ["Launchpad S"]))
    ]
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10))
}
