import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let reviewedClearNames = [
    "Hercules DJControl Compact",
    "Hercules DJControl Inpulse 200",
    "Hercules DJControl Inpulse 300",
    "Hercules DJControl MIX",
    "Hercules DJControl Starlight",
    "Korg KAOSS DJ",
    "MixVibes U-Mix Control 2",
    "MixVibes U-Mix Control Pro 2",
    "Novation Dicer",
    "Reloop Beatmix 2/4 MK2",
    "Stanton DJC.4",
    "Vestax VCI-100MKII",
    "Korg KAOSS DJ (Audioless)",
]

@MainActor private func withReviewedClear(
    _ name: String, _ body: (ControllerMIDIConnection, ControllerFactoryProfile) throws -> Void
) throws {
    let suite = "reviewed-clear-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual clear-input checks must not send hardware packets."); return false
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    let p = try #require(ControllerFactoryProfile.allCases.first { $0.rawValue == name })
    try #require(p.definition?.requiresPairedSetup == false)
    input.select(10); input.applyFactoryProfile(p)
    #expect(input.bindingCount == p.bindings(source: 10).count)
    try body(input, p)
}

@MainActor private func reviewedClearPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: reviewedClearNames) @MainActor
func controllerCatalogueReviewedClearDedicatedOpcodesWorkWithEitherShiftState(name: String) throws {
    try withReviewedClear(name) { input, p in
        let bindings = p.bindings(source: 10); let clears = bindings.filter { $0.action.clearHotcueSlot != nil && $0.releaseOnly != true }
        #expect(
            !clears.isEmpty
                && clears.allSatisfy { $0.kind == .note && !$0.action.isMomentary && !$0.action.supportsFeedback })
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for shiftValue: UInt8 in [0, 127] {
            for shift in bindings where shift.action == .shift {
                reviewedClearPacket(
                    [(shift.kind == .note ? 0x90 : 0xB0) + shift.channel, shift.number, shiftValue], input)
            }
            for b in clears {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    reviewedClearPacket(
                        [
                            0x90 + b.channel, b.number, 127, b.number, 127, off + b.channel, b.number,
                            off == 0x80 ? 127 : 0, 0x90 + b.channel, b.number, 1, b.number, 0,
                        ], input)
                    #expect(events == Array(repeating: b.target, count: 2))
                }
            }
        }
    }
}

@Test(arguments: reviewedClearNames) @MainActor
func controllerCatalogueReviewedClearNegativeAliasesStillRearmTheirOwnCue(name: String) throws {
    try withReviewedClear(name) { input, p in
        let bindings = p.bindings(source: 10)
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for clear in bindings where clear.action.clearHotcueSlot != nil && clear.releaseOnly != true {
            let cue = try #require(
                bindings.first {
                    $0.action.hotcueSlot == clear.action.clearHotcueSlot && $0.targetDeck == clear.targetDeck
                        && $0.releaseOnly != true && $0.shifted != true && $0.kind == .note
                })
            events.removeAll()
            reviewedClearPacket(
                [
                    0x90 + cue.channel, cue.number, 127, 0x90 + clear.channel, clear.number, 127, clear.number, 0,
                    0x90 + cue.channel, cue.number, 127, cue.number, 0,
                ], input)
            #expect(events == [cue.target, clear.target, cue.target])
        }
    }
}

@Test(arguments: reviewedClearNames) @MainActor
func controllerCatalogueReviewedClearForeignSourcesAndGroupsCannotDelete(name: String) throws {
    try withReviewedClear(name) { input, p in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for b in p.bindings(source: 10) where b.action.clearHotcueSlot != nil && b.releaseOnly != true {
            reviewedClearPacket([0x90 + b.channel, b.number, 127, b.number, 0], input, source: 999)
            input.receive(.init(kind: .note, group: 1, channel: b.channel, number: b.number, value: 127), source: 10)
            input.flushPendingActions()
        }
        #expect(events.isEmpty)
    }
}

private let reviewedPairNames = ["Pioneer DDJ-SB3", "Reloop Terminal Mix 2/4", "Hercules DJControl Jogvision", "Denon MC4000", "Reloop NEON", "DDJ-FLX10", "DDJ-1000", "Pioneer DDJ-200", "Pioneer DDJ-RB", "Pioneer DDJ-SX", "Pioneer DDJ-RX", "Pioneer DDJ-RZ", "Pioneer DDJ-RZX"]

@Test(arguments: reviewedPairNames) @MainActor
func controllerCatalogueReviewedPairDedicatedOpcodesWorkWithEitherShiftState(name: String) throws {
    try withReviewedClear(name) { input, p in
        let bindings = p.bindings(source: 10);
        let clears = bindings.filter { $0.action.clearHotcueSlot != nil && $0.releaseOnly != true }
        #expect(
            !clears.isEmpty
                && clears.allSatisfy { $0.kind == .note && !$0.action.isMomentary && !$0.action.supportsFeedback })
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for shiftValue: UInt8 in [0, 127] {
            for shift in bindings where shift.action == .shift {
                reviewedClearPacket(
                    [(shift.kind == .note ? 0x90 : 0xB0) + shift.channel, shift.number, shiftValue], input)
            }
            for b in clears {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    reviewedClearPacket(
                        [
                            0x90 + b.channel, b.number, 127, b.number, 127, off + b.channel, b.number,
                            off == 0x80 ? 127 : 0, 0x90 + b.channel, b.number, 1, b.number, 0,
                        ], input)
                    #expect(events == Array(repeating: b.target, count: 2))
                }
            }
        }
    }
}

@Test(arguments: reviewedPairNames) @MainActor
func controllerCatalogueReviewedPairBothNegativeWiresRearmOnlyTheirOwnRole(name: String) throws {
    try withReviewedClear(name) { input, p in
        let bindings = p.bindings(source: 10)
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for clear in bindings where clear.action.clearHotcueSlot != nil && clear.releaseOnly != true {
            let cue = try #require(
                bindings.first {
                    $0.action.hotcueSlot == clear.action.clearHotcueSlot && $0.targetDeck == clear.targetDeck
                        && $0.releaseOnly != true && $0.shifted != true && $0.kind == .note
                })
            for off: UInt8 in [0x80, 0x90] {
                let value: UInt8 = off == 0x80 ? 127 : 0
                events.removeAll()
                reviewedClearPacket(
                    [
                        0x90 + cue.channel, cue.number, 127,
                        off + clear.channel, clear.number, value,
                        0x90 + cue.channel, cue.number, 127, cue.number, 0,
                    ], input)
                #expect(events == [cue.target, cue.target])
                events.removeAll()
                reviewedClearPacket(
                    [
                        0x90 + clear.channel, clear.number, 127,
                        off + cue.channel, cue.number, value,
                        0x90 + clear.channel, clear.number, 127, clear.number, 0,
                    ], input)
                #expect(events == [clear.target, clear.target])
            }
        }
    }
}

@Test(arguments: reviewedPairNames) @MainActor
func controllerCatalogueReviewedPairForeignSourcesAndGroupsCannotDelete(name: String) throws {
    try withReviewedClear(name) { input, p in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for b in p.bindings(source: 10) where b.action.clearHotcueSlot != nil && b.releaseOnly != true {
            reviewedClearPacket([0x90 + b.channel, b.number, 127, b.number, 0], input, source: 999)
            input.receive(.init(kind: .note, group: 1, channel: b.channel, number: b.number, value: 127), source: 10)
            input.flushPendingActions()
        }
        #expect(events.isEmpty)
    }
}

@Test(arguments: reviewedClearNames) @MainActor
func controllerCatalogueReviewedClearBothNegativeWiresRearmOnlyTheirOwnRole(name: String) throws {
    try withReviewedClear(name) { input, p in
        let bindings = p.bindings(source: 10)
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for clear in bindings where clear.action.clearHotcueSlot != nil && clear.releaseOnly != true {
            let cue = try #require(
                bindings.first {
                    $0.action.hotcueSlot == clear.action.clearHotcueSlot && $0.targetDeck == clear.targetDeck
                        && $0.releaseOnly != true && $0.shifted != true && $0.kind == .note
                })
            for off: UInt8 in [0x80, 0x90] {
                let value: UInt8 = off == 0x80 ? 127 : 0
                events.removeAll()
                reviewedClearPacket(
                    [
                        0x90 + cue.channel, cue.number, 127,
                        off + clear.channel, clear.number, value,
                        0x90 + cue.channel, cue.number, 127, cue.number, 0,
                    ], input)
                #expect(events == [cue.target, cue.target])
                events.removeAll()
                reviewedClearPacket(
                    [
                        0x90 + clear.channel, clear.number, 127,
                        off + cue.channel, cue.number, value,
                        0x90 + clear.channel, clear.number, 127, clear.number, 0,
                    ], input)
                #expect(events == [clear.target, clear.target])
            }
        }
    }
}

@Test(arguments: ["DDJ-FLX10", "DDJ-1000"]) @MainActor
func controllerCatalogueReviewedPairFactoryPagesAndCapacityRemainBounded(name: String) throws {
    let suite = "four-deck-clear-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in
            Issue.record("Input-only clear checks must not send packets."); return false
        }, deckAvailability: { DeckID.primary })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    var events: [ControllerActionTarget] = []
    input.onTargetAction = { target, _ in events.append(target) }
    for channel: UInt8 in [11, 12, 13, 14] {
        for number: UInt8 in 0..<8 {
            reviewedClearPacket([0x90 + channel, number, 127, number, 0], input)
        }
    }
    #expect(events.isEmpty)
    for channel: UInt8 in [7, 8, 9, 10, 11, 12, 13, 14] {
        for number: UInt8 in 8..<128 {
            reviewedClearPacket([0x90 + channel, number, 127, number, 0], input)
        }
    }
    #expect(events.isEmpty)
    reviewedClearPacket([0x98, 0, 127, 0, 0, 0x9A, 7, 127, 7, 0], input)
    #expect(events == [.init(.clearHotcue1A, deck: .a), .init(.clearHotcue8B, deck: .b)])
}

@Test(arguments: ["Pioneer DDJ-200", "Pioneer DDJ-RB"]) @MainActor
func controllerCatalogueReviewedPairEntryKeepsOtherPadsAndChannelsInactive(name: String) throws {
    try withReviewedClear(name) { input, p in
        let bindings = p.bindings(source: 10)
        let pads = bindings.filter { $0.action.hotcueSlot != nil || $0.action.clearHotcueSlot != nil }
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 7..<16 {
            for number: UInt8 in 0..<128 {
                if pads.contains(where: { $0.channel == channel && $0.number == number }) { continue }
                reviewedClearPacket([0x90 + channel, number, 127, number, 0], input)
            }
        }
        #expect(events.isEmpty)
        #expect(pads.filter { $0.action.clearHotcueSlot != nil && $0.releaseOnly != true }.count == 16)
        #expect(p.feedback(destination: 20).count == 22)
        #expect(!p.feedback(destination: 20).contains { $0.action.clearHotcueSlot != nil })
    }
}

@Test(arguments: ["Pioneer DDJ-SX", "Pioneer DDJ-RX", "Pioneer DDJ-RZ", "Pioneer DDJ-RZX"]) @MainActor
func controllerCatalogueReviewedPairOlderPioneerCapacityAndOtherModesStayInactive(name: String) throws {
    let suite = "older-pioneer-clear-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in
            Issue.record("Input-only clear checks must not send packets."); return false
        }, deckAvailability: { DeckID.primary })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    var events: [ControllerActionTarget] = []
    input.onTargetAction = { target, _ in events.append(target) }
    for channel: UInt8 in 9...10 {
        for number: UInt8 in 0..<16 {
            reviewedClearPacket([0x90 + channel, number, 127, number, 0], input)
        }
    }
    #expect(events.isEmpty)
    for channel: UInt8 in 7...10 {
        for number: UInt8 in 16..<128 {
            reviewedClearPacket([0x90 + channel, number, 127, number, 0], input)
        }
    }
    #expect(events.isEmpty)
    reviewedClearPacket([0x97, 8, 127, 8, 0, 0x98, 15, 127, 15, 0], input)
    #expect(events == [.init(.clearHotcue1A, deck: .a), .init(.clearHotcue8B, deck: .b)])
}
