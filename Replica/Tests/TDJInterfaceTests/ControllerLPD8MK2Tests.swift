import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withLPD8MK2(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "lpd8-mk2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "LPD8 MK2",
            identity: .init(id: id, device: UInt32(id), names: ["LPD8 MK2"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11) && writes == 0)
    let p = try #require(ControllerFactoryProfile.matching(["LPD8 MK2"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 32 && writes == 0)
    try body(input)
}

@MainActor private func lpd8MK2Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueLPD8MK2RequiresOwnManualPresetAndSendsNothing() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Akai LPD8 MK2"]))
    let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.role == "accessory" && d.inputs.count == 16)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    for other in ["LPD8", "Akai LPD8", "LPD8 Wireless", "MPD218"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withLPD8MK2 { _ in }
}

@Test @MainActor func controllerCatalogueLPD8MK2AllPadsKeepRowsSourcesAndBothReleaseForms() throws {
    try withLPD8MK2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (bank, deck) in [DeckID.a, .b].enumerated() {
            for slot in 0..<4 {
                let n = UInt8(36 + 4 * bank + slot)
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    lpd8MK2Packet([0x90, n, 127, n, 127, off, n, off == 0x80 ? 127 : 0, 0x90, n, 127, n, 0], input)
                    #expect(
                        events.count == 2 && events.allSatisfy { $0.0.deck == deck && $0.0.action.hotcueSlot == slot })
                }
            }
        }
        events.removeAll()
        lpd8MK2Packet([0x90, 36, 127], input)
        lpd8MK2Packet([0x90, 36, 127, 36, 0], input, source: 11)
        lpd8MK2Packet([0x90, 36, 127], input)
        #expect(events.count == 2)
        lpd8MK2Packet([0x80, 36, 127], input)
    }
}

@Test @MainActor func controllerCatalogueLPD8MK2AllKnobsUseIndependentPickupAndRejectUnmappedInputs() throws {
    try withLPD8MK2 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (bank, deck) in [DeckID.a, .b].enumerated() {
            for (column, action) in [ControllerAction.gainA, .highA, .midA, .lowA].enumerated() {
                let n = UInt8(36 + 4 * bank + column)
                events.removeAll()
                lpd8MK2Packet([0xB0, n, 0], input); #expect(events.isEmpty)
                lpd8MK2Packet([0xB0, n, 64], input)
                lpd8MK2Packet([0xB0, n, 127], input)
                #expect(
                    events.count == 2 && events.last?.0 == .init(action.assigned(to: deck), deck: deck)
                        && events.last?.1 == 1)
            }
        }
        events.removeAll()
        lpd8MK2Packet([0xB0, 36, 0], input, source: 11); #expect(events.isEmpty)
        lpd8MK2Packet([0xB0, 36, 0], input); #expect(events.count == 1 && events.last?.1 == 0)
        events.removeAll()
        lpd8MK2Packet(
            [
                0x91, 36, 127, 0x81, 36, 127, 0x99, 36, 127, 0x89, 36, 127, 0x90, 35, 127, 44, 127, 0xB0, 70, 127, 0xB1,
                36, 64, 0xA0, 36, 127, 0xD0, 127, 0xC0, 0,
            ], input)
        #expect(events.isEmpty)
    }
}
