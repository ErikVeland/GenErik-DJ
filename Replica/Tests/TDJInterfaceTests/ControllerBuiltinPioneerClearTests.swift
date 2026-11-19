import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let builtinClearNames = ["DDJ-FLX4", "DDJ-400", "DDJ-FLX2"]

@MainActor private func withBuiltinClear(
    _ name: String, _ body: (ControllerMIDIConnection, ControllerFactoryProfile) throws -> Void
) throws {
    let suite = "builtin-clear-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Input-only built-in clear checks must not send hardware packets."); return false
        })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    try #require(input.isInputActive(10) && input.isInputActive(11))
    try body(input, #require(ControllerFactoryProfile.matching([name], automaticOnly: true)))
}

@MainActor private func builtinClearPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: builtinClearNames) @MainActor
func controllerBuiltinPioneerClearKeepsOwnChannelsSlotsAndExistingFeedback(name: String) throws {
    try withBuiltinClear(name) { _, p in
        let bindings = p.bindings(source: 10)
        #expect(bindings.count == ["DDJ-FLX4": 120, "DDJ-400": 119, "DDJ-FLX2": 105][name])
        let clears = bindings.filter { $0.action.clearHotcueSlot != nil && $0.releaseOnly != true }
        #expect(clears.count == 16)
        for deck in DeckID.primary {
            let own = clears.filter { $0.action.deck == deck }
            #expect(own.map(\.number) == Array(UInt8(0)...7))
            #expect(own.allSatisfy { $0.channel == (deck == .a ? 8 : 10) && $0.layerIndependent == true })
        }
        #expect(
            bindings.filter {
                $0.releaseOnly == true && ($0.action.hotcueSlot != nil || $0.action.clearHotcueSlot != nil)
            }.count == 32)
        let feedback = p.feedback(destination: 20)
        #expect(feedback.count == 22 && !feedback.contains { $0.action.clearHotcueSlot != nil })
    }
}

@Test(arguments: builtinClearNames) @MainActor
func controllerBuiltinPioneerClearOpcodesWorkWithEitherShiftStateAndBothReleaseForms(name: String) throws {
    try withBuiltinClear(name) { input, p in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for shift: UInt8 in [0, 127] {
            builtinClearPacket([0x90, 63, shift], input)
            for b in p.bindings(source: 10) where b.action.clearHotcueSlot != nil && b.releaseOnly != true {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    builtinClearPacket(
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

@Test(arguments: builtinClearNames) @MainActor
func controllerBuiltinPioneerClearBothCrossChannelNegativesRearmTheirOwnRole(name: String) throws {
    try withBuiltinClear(name) { input, p in
        let bindings = p.bindings(source: 10)
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for clear in bindings where clear.action.clearHotcueSlot != nil && clear.releaseOnly != true {
            let cue = try #require(
                bindings.first {
                    $0.action.hotcueSlot == clear.action.clearHotcueSlot && $0.action.deck == clear.action.deck
                        && $0.releaseOnly != true
                })
            for off: UInt8 in [0x80, 0x90] {
                let value: UInt8 = off == 0x80 ? 127 : 0
                events.removeAll()
                builtinClearPacket(
                    [
                        0x90 + cue.channel, cue.number, 127, off + clear.channel, clear.number, value,
                        0x90 + cue.channel, cue.number, 127, cue.number, 0,
                    ], input)
                #expect(events == [cue.target, cue.target])
                events.removeAll()
                builtinClearPacket(
                    [
                        0x90 + clear.channel, clear.number, 127, off + cue.channel, cue.number, value,
                        0x90 + clear.channel, clear.number, 127, clear.number, 0,
                    ], input)
                #expect(events == [clear.target, clear.target])
            }
        }
    }
}

@Test(arguments: builtinClearNames) @MainActor
func controllerBuiltinPioneerClearOtherSourceAndGroupCannotRearmAnOwnedPress(name: String) throws {
    try withBuiltinClear(name) { input, _ in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        builtinClearPacket([0x98, 0, 127], input)
        builtinClearPacket([0x87, 0, 127], input, source: 11)
        input.receive(.init(kind: .note, group: 1, channel: 7, number: 0, value: 0, isNoteOff: true), source: 10)
        builtinClearPacket([0x98, 0, 127], input)
        #expect(events.map(\.action) == [.clearHotcue1A])
        builtinClearPacket([0x87, 0, 127, 0x98, 0, 127, 0, 0], input)
        #expect(events.map(\.action) == [.clearHotcue1A, .clearHotcue1A])
    }
}

@Test(arguments: builtinClearNames) @MainActor
func controllerBuiltinPioneerClearOtherPadModesStayInactive(name: String) throws {
    try withBuiltinClear(name) { input, _ in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in [7, 8, 9, 10] {
            for number: UInt8 in 8..<128 { builtinClearPacket([0x90 + channel, number, 127, number, 0], input) }
        }
        #expect(events.isEmpty)
    }
}

@Test @MainActor
func controllerBuiltinPioneerClearREV5NormalRightPadsNeverUseLeftShiftChannel() throws {
    try withBuiltinClear("DDJ-REV5") { input, p in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for slot: UInt8 in 0..<8 {
            builtinClearPacket([0x99, slot, 127, slot, 0], input)
        }
        #expect(events.map(\.action.hotcueSlot) == Array(0..<8).map { Optional($0) })
        #expect(events.allSatisfy { $0.action.deck == .b })
        events.removeAll()
        for slot: UInt8 in 0..<8 {
            builtinClearPacket([0x98, slot, 127, slot, 0], input)
        }
        #expect(!events.contains { $0.action.deck == .b })
        let lamps = p.feedback(destination: 20).filter { $0.action.hotcueSlot != nil && $0.action.deck == .b }
        #expect(lamps.count == 8)
        #expect(lamps.allSatisfy { $0.channel == 9 })
        #expect(lamps.map { $0.message(value: 1) } == (UInt8(0)..<8).map { [0x99, $0, 127] })
    }
}
