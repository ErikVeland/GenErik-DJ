import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withAPCMiniOriginal(
    decks: [DeckID] = DeckID.allCases,
    sender: @escaping ([UInt8], Int32) -> Bool = { _, _ in true },
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "apc-mini-original-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: sender, deckAvailability: { decks },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "APC MINI",
            identity: .init(id: id, device: UInt32(id), names: ["APC MINI"]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id), name: "APC MINI",
            identity: .init(id: id, device: UInt32(id - 10), names: ["APC MINI"]))
    }
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func apcMiniOriginalPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

private func apcMiniOriginalNumber(_ side: Int, _ row: Int, _ column: Int) -> UInt8 {
    UInt8(8 * (4 * (side / 2) + row) + 4 * (side % 2) + column)
}

@Test @MainActor func controllerCatalogueAPCMiniOriginalNineFadersKeepPickupTargetsAndSourceIsolation() throws {
    try withAPCMiniOriginal { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for column in 0..<9 {
            let n = UInt8(48 + column); events.removeAll()
            let deck: DeckID? = column == 8 ? nil : DeckID.allCases[column % 4]
            let action: ControllerAction =
                column == 8
                ? .master
                : column < 4
                    ? ControllerAction.levelA.assigned(to: deck!) : ControllerAction.filterKnobA.assigned(to: deck!)
            apcMiniOriginalPacket([0xB0, n, 0], input); #expect(events.isEmpty)
            apcMiniOriginalPacket([0xB0, n, 64], input); apcMiniOriginalPacket([0xB0, n, 127], input)
            #expect(events.count == 2 && events.last?.0 == .init(action, deck: deck) && events.last?.1 == 1)
        }
        events.removeAll(); apcMiniOriginalPacket([0xB0, 48, 0], input, source: 11); #expect(events.isEmpty)
        apcMiniOriginalPacket([0xB0, 48, 64], input, source: 11)
        apcMiniOriginalPacket([0x90, 98, 127, 0x80, 98, 127], input)
        events.removeAll(); apcMiniOriginalPacket([0xB0, 48, 0], input, source: 11)
        #expect(events.count == 1 && events.last?.1 == 0)
        apcMiniOriginalPacket([0xB0, 48, 0], input); #expect(events.count == 1)
    }
}

@Test @MainActor func controllerCatalogueAPCMiniOriginalShiftRetiresOnlyItsSourceAndGuardsNormalActions() throws {
    try withAPCMiniOriginal { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        apcMiniOriginalPacket([0x90, 1, 127], input); apcMiniOriginalPacket([0x90, 1, 127], input, source: 11)
        apcMiniOriginalPacket([0x90, 98, 127, 0, 127, 1, 127, 16, 127, 0xB0, 48, 127], input)
        #expect(events.count == 1 && events.first?.0.action == .cuePreviewA)
        apcMiniOriginalPacket([0x80, 1, 127], input, source: 11); #expect(events.map(\.1) == [1, 0])
        apcMiniOriginalPacket([0x90, 98, 0, 1, 127, 1, 0], input); #expect(events.map(\.1) == [1, 0, 1, 0])
        events.removeAll(); apcMiniOriginalPacket([0x90, 1, 1, 98, 127], input)
        #expect(events.map(\.1) == [1.0 / 127, 0])
    }
}

@Test @MainActor func controllerCatalogueAPCMiniOriginalCanUseInputWithoutOutputOrStartupWrites() throws {
    let suite = "apc-mini-unpaired-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Unexpected unpaired write"); return true
        }, factoryInputConnector: { _ in true })
    input.sources = [
        .init(id: 10, reference: 10, name: "APC MINI", identity: .init(id: 10, device: 10, names: ["APC MINI"]))
    ]
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10))
    var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
    apcMiniOriginalPacket([0x90, 0, 127, 0, 0], input); #expect(events == [.init(.playA, deck: .a)])
}

@Test @MainActor func controllerCatalogueAPCMiniOriginalAll64OwnGridTargets() throws {
    try withAPCMiniOriginal { input in
        #expect(input.isInputActive(10) && input.isInputActive(11))
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (side, deck) in DeckID.allCases.enumerated() {
            for (row, column, action): (Int, Int, ControllerAction) in [
                (0, 0, .playA), (0, 2, .syncA), (0, 3, .loadA), (1, 0, .cueA), (1, 1, .loopInA), (1, 2, .loopOutA),
                (1, 3, .reloopA),
            ] {
                let n = apcMiniOriginalNumber(side, row, column); events.removeAll()
                apcMiniOriginalPacket([0x90, n, 127, n, 127, n, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
            for slot in 0..<8 {
                let n = apcMiniOriginalNumber(side, 2 + slot / 4, slot % 4); events.removeAll()
                apcMiniOriginalPacket([0x90, n, 127, n, 127, 0x80, n, 127], input)
                #expect(events.count == 1 && events.first?.action.hotcueSlot == slot && events.first?.deck == deck)
            }
        }
        events.removeAll()
        apcMiniOriginalPacket([0xB0, 104, 127, 0x90, 64, 127, 82, 127, 0x91, 0, 127, 0xA0, 0, 127], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAPCMiniOriginalCueBothReleaseFormsSourcesAndStop() throws {
    try withAPCMiniOriginal { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target, value)) }
        }
        for (side, deck) in DeckID.allCases.enumerated() {
            let n = apcMiniOriginalNumber(side, 0, 1)
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    apcMiniOriginalPacket([0x90, n, velocity, n, 127], input)
                    apcMiniOriginalPacket([0x90, n, 127], input, source: 11)
                    apcMiniOriginalPacket([off, n, off == 0x80 ? 127 : 0], input)
                    #expect(events.count == 1)
                    apcMiniOriginalPacket([off, n, off == 0x80 ? 127 : 0], input, source: 11)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
        events.removeAll(); apcMiniOriginalPacket([0x90, 1, 127], input); input.stop()
        #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueAPCMiniOriginalUpperDecksRequireOptIn() throws {
    try withAPCMiniOriginal(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for side in 2..<4 {
            for row in 0..<4 {
                for column in 0..<4 {
                    let n = apcMiniOriginalNumber(side, row, column);
                    apcMiniOriginalPacket([0x90, n, 127, n, 0], input)
                }
            }
        }
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAPCMiniOriginalOwnColoursIdentityAndTemporarySetup() throws {
    let p = try #require(ControllerFactoryProfile.matching(["APC MINI"])); let d = try #require(p.definition)
    #expect(
        d.isValid && p.selectsAutomatically && d.inputs.count == 74 && d.outputs.count == 52 && d.audioOutput == nil)
    #expect(d.startup.isEmpty && d.startupAbort == nil && d.shutdown == (0..<64).map { [0x90, UInt8($0), 0] })
    for lamp in p.feedback(destination: 20) {
        let on: UInt8 =
            [.cuePreviewA, .cuePreviewB].contains(lamp.action)
            ? 3 : [.syncA, .syncB].contains(lamp.action) || lamp.action.hotcueSlot != nil ? 5 : 1
        #expect(
            lamp.message(value: 1) == [0x90, lamp.number, on] && lamp.message(value: 0) == [0x90, lamp.number, 0])
    }
    for other in ["APC mini mk2", "APC mini MK 2 (Control)", "APC40", "APC20", "APC64"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    var packets: [Int32: [[UInt8]]] = [:]
    try withAPCMiniOriginal(sender: { bytes, id in
        packets[id, default: []].append(bytes); return true
    }) { input in
        #expect(packets.isEmpty)
        packets.removeAll(); input.stop()
        #expect(packets[20] == d.shutdown && packets[21] == d.shutdown)
    }
}
