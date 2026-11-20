import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOrbit(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "orbit-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Numark ORBIT",
            identity: .init(id: id, device: UInt32(id), names: ["Numark ORBIT"]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0)
    try body(input)
}
@MainActor private func orbitPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOrbitFactoryIdentityAndNoStoredSettingOrFeedbackWrites() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Numark ORBIT"])); let d = try #require(p.definition)
    #expect(d.isValid && p.selectsAutomatically && d.role == "accessory" && d.inputProtocol == .orbit)
    #expect(
        d.inputs.count == 64 && d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["USB Audio Device"]) != p)
    try withOrbit { _ in }
}

@Test @MainActor func controllerCatalogueOrbitAllFourBanksAndEightHotCuesUseExplicitNativeTargets() throws {
    try withOrbit { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (index, deck) in DeckID.allCases.enumerated() {
            let channel = UInt8(index)
            for slot in 0..<8 {
                events.removeAll(); let n = UInt8(36 + slot)
                orbitPacket([0x90 + channel, n, 127, n, 127, 0x80 + channel, n, 127], input)
                #expect(events.count == 1 && events.first?.0.deck == deck && events.first?.0.action.hotcueSlot == slot)
            }
            for (wire, action): (UInt8, ControllerAction) in [
                (44, .playA), (46, .syncA), (47, .loadA), (48, .loopInA), (49, .loopOutA), (50, .reloopA),
                (51, .keylockA),
            ] {
                events.removeAll(); orbitPacket([0x90 + channel, wire, 127, wire, 127, wire, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for off: UInt8 in [0x80 + channel, 0x90 + channel] {
                events.removeAll();
                orbitPacket([0x90 + channel, 45, 127, 45, 127, off, 45, off < 0x90 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueOrbitChangedBankRetiresOnlyItsSourceAndLateReleasesKeepFreshCue() throws {
    try withOrbit { input in
        var events: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target.deck, value)) }
        }
        orbitPacket([0x90, 45, 127], input); orbitPacket([0x90, 45, 127], input, source: 11)
        orbitPacket([0x91, 45, 127], input); #expect(events.map(\.1) == [1, 1] && events.last?.0 == .b)
        orbitPacket([0x80, 45, 127], input, source: 11); #expect(events.last?.0 == .a && events.last?.1 == 0)
        orbitPacket([0x80, 45, 127, 0x91, 45, 127], input); #expect(events.count == 3)
        orbitPacket([0x81, 45, 127], input); #expect(events.count == 4 && events.last?.0 == .b && events.last?.1 == 0)
        events.removeAll(); orbitPacket([0x90, 45, 127], input)
        orbitPacket([0x91, 44, 127, 44, 0], input); #expect(events.map(\.1) == [1, 0])
        orbitPacket([0x90, 45, 127], input); #expect(events.map(\.1) == [1, 0, 1])
        input.stop(); #expect(events.map(\.1) == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueOrbitRejectsCustomNotesKnobsMotionAndForeignChannels() throws {
    try withOrbit { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        orbitPacket(
            [
                0x90, 0, 127, 35, 127, 52, 127, 127, 127, 0x94, 36, 127, 45, 127, 0xB0, 1, 64, 4, 0, 9, 127, 10, 64,
                0xB3, 16, 127, 0xE0, 0, 64,
            ], input)
        #expect(events.isEmpty)
    }
}
