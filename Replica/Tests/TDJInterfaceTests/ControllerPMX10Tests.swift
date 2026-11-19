import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withPMX10(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "pmx10-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual PMX-10 input must not send setup or mode writes."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "PMX-10",
            identity: .init(id: id, device: UInt32(id), names: ["Gemini PMX10"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Gemini PMX10"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 80 && input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func pmx10Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCataloguePMX10OwnManualIdentityAndNineteenQualifiedLights() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Gemini PMX10"])); let d = try #require(p.definition)
    #expect(
        d.isValid && !p.selectsAutomatically && d.role == "accessory" && d.inputs.count == 40 && d.outputs.count == 19)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.bankChanges?.count == 4)
    #expect(ControllerFactoryProfile.matching(["PMX-10"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["Gemini PMX20"]) != p)
    for lamp in p.feedback(destination: 20) {
        #expect(
            lamp.channel < 2
                && ((1...8).contains(lamp.number) || lamp.number == 35 || (lamp.channel == 1 && lamp.number == 50)))
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 1])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
    try withPMX10 { _ in }
}

@Test @MainActor func controllerCataloguePMX10EveryReversedHotCuePFLAndLoopBothReleaseForms() throws {
    try withPMX10 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            for slot: UInt8 in 0..<8 {
                let n = 8 - slot
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll();
                    pmx10Packet([0x90 + ch, n, 1, n, 127, off + ch, n, off == 0x80 ? 127 : 0], input)
                    #expect(
                        events.count == 1 && events.first?.action.hotcueSlot == Int(slot) && events.first?.deck == deck)
                }
            }
            for (n, action): (UInt8, ControllerAction) in [(50, .cueA), (35, .loopA)] {
                events.removeAll(); pmx10Packet([0x90 + ch, n, 127, n, 127, n, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
        }
    }
}

@Test @MainActor func controllerCataloguePMX10AllSixteenMixerControlsKeepPickupAndTargets() throws {
    try withPMX10 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let p = try #require(ControllerFactoryProfile.matching(["Gemini PMX10"]))
        for binding in p.bindings(source: 10).filter({ $0.kind == .control }) {
            events.removeAll(); pmx10Packet([0xB0 + binding.channel, binding.number, 0], input); #expect(events.isEmpty)
            pmx10Packet([0xB0 + binding.channel, binding.number, 64], input)
            pmx10Packet([0xB0 + binding.channel, binding.number, 127], input)
            #expect(events.count == 2 && events.allSatisfy { $0.0 == binding.target } && events.last?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCataloguePMX10LoadDirectoryAndModeCleanupStaySourceOwned() throws {
    try withPMX10 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        pmx10Packet([0x94, 64, 127, 64, 0, 65, 127, 65, 0, 66, 127, 66, 0, 67, 127, 67, 127, 67, 0], input)
        #expect(
            events == [
                .init(.loadA, deck: .a), .init(.loadB, deck: .b), .init(.openGroup), .init(.browsePreviousGroup),
                .init(.browsePreviousGroup),
            ])
        pmx10Packet([0x90, 8, 127, 0x91, 8, 127], input)
        pmx10Packet([0x90, 8, 127], input, source: 11); events.removeAll()
        pmx10Packet([0x90, 33, 127, 33, 0, 9, 127, 9, 0, 34, 127, 34, 0, 8, 127, 0x91, 8, 127], input)
        #expect(events == [.init(.hotcue1A, deck: .a)])
        events.removeAll(); pmx10Packet([0x90, 8, 127], input, source: 11); #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCataloguePMX10UnqualifiedEncodersOtherModesAndOtherModelChannelsStayInactive() throws {
    try withPMX10 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 0..<2 {
            pmx10Packet([0xB0 + ch, 36, 65, 37, 127, 39, 127, 64, 127, 65, 127, 66, 127], input)
            for n: UInt8 in [9, 10, 11, 12, 13, 14, 15, 32, 38, 40, 56, 64] {
                pmx10Packet([0x90 + ch, n, 127, n, 0], input)
            }
        }
        for ch: UInt8 in [2, 3] { pmx10Packet([0x90 + ch, 8, 127, 35, 127, 50, 127, 0xB0 + ch, 49, 64], input) }
        pmx10Packet([0x94, 68, 127, 69, 127, 70, 127, 0xB4, 66, 65, 81, 127, 82, 127, 113, 127, 114, 127], input)
        #expect(events.isEmpty)
    }
}
