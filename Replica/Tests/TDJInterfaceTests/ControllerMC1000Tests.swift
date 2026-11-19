import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMC1000(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "mc1000-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "MC-1000",
            identity: .init(id: id, device: UInt32(id), names: ["MC-1000"]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0)
    try body(input)
}
@MainActor private func mc1000Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}
private let mc1000Buttons: [(UInt8, ControllerAction)] = [
    (14, .playA), (15, .syncA), (1, .hotcue1A), (2, .hotcue2A), (3, .hotcue3A), (10, .loopA), (12, .tempoUpA),
    (13, .tempoDownA),
]

@Test @MainActor func controllerCatalogueMC1000KeepsAutomaticNativeCoreSeparateFromLoadBanksAndAudio() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Zomo MC-1000"], automaticOnly: true));
    let d = try #require(p.definition)
    #expect(d.inputs.count == 138 && d.inputs.filter { $0.releaseOnly == true }.count == 96)
    #expect(d.role == "accessory" && d.inputProtocol == .mc1000 && !d.requiresPairedSetup && d.audioOutput == nil)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty)
    #expect(ControllerFactoryProfile.matching(["MC-1000 clone"], automaticOnly: true) != p)
    #expect(!d.inputs.contains { $0.action == .loadA || $0.action == .loadB || $0.action.isMomentary })
}

@Test @MainActor func controllerCatalogueMC1000NativeButtonsUseExactFourDeckTargets() throws {
    try withMC1000() { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (channel, deck) in DeckID.allCases.enumerated() {
            for (number, action) in mc1000Buttons {
                events.removeAll(); mc1000Packet([0x90 + UInt8(channel), number, 127, number, 127, number, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMC1000EveryNormalShiftAndCrossBankReleaseRearmsWithoutAnotherAction() throws {
    try withMC1000() { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (channel, deck) in DeckID.allCases.enumerated() {
            let wire = UInt8(channel)
            for (number, action) in mc1000Buttons {
                for releaseChannel in [wire, wire ^ 2] {
                    for releaseNumber in [number, number + 63] {
                        for off: UInt8 in [0x80 + releaseChannel, 0x90 + releaseChannel] {
                            events.removeAll(); mc1000Packet([0x90 + wire, number, 127], input)
                            mc1000Packet([off, releaseNumber, off < 0x90 ? 127 : 0], input)
                            mc1000Packet([0x90 + wire, number, 127, number, 0], input)
                            #expect(
                                events == [
                                    .init(action.assigned(to: deck), deck: deck),
                                    .init(action.assigned(to: deck), deck: deck),
                                ])
                        }
                    }
                }
                events.removeAll(); mc1000Packet([0x90 + wire, number + 63, 127, number + 63, 0], input);
                #expect(events.isEmpty)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMC1000SideContextResetRetainsOtherSideAndSourcePickup() throws {
    try withMC1000() { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for source: Int32 in [10, 11] {
            mc1000Packet([0xB0, 5, 64], input, source: source); mc1000Packet([0xB0, 5, 127], input, source: source)
        }
        mc1000Packet([0xB1, 5, 64], input); mc1000Packet([0xB1, 5, 127], input)
        events.removeAll(); mc1000Packet([0xB2, 5, 127], input); #expect(events.isEmpty)
        mc1000Packet([0xB2, 5, 64], input); #expect(events == [.init(.filterKnobA, deck: .c)])
        events.removeAll(); mc1000Packet([0xB0, 5, 127], input); #expect(events.isEmpty)
        mc1000Packet([0xB1, 5, 0], input); #expect(events == [.init(.filterKnobB, deck: .b)])
        events.removeAll(); mc1000Packet([0xB0, 5, 0], input, source: 11);
        #expect(events == [.init(.filterKnobA, deck: .a)])
        events.removeAll(); mc1000Packet([0xB0, 5, 64], input); mc1000Packet([0xB0, 5, 127], input)
        events.removeAll(); mc1000Packet([0xB0, 68, 0, 5, 127], input); #expect(events.isEmpty)
        mc1000Packet([0xB0, 5, 64], input); #expect(events == [.init(.filterKnobA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueMC1000GlobalNavigationCannotResetTheActiveOtherDeckBank() throws {
    try withMC1000() { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        mc1000Packet([0xB2, 5, 64], input); events.removeAll()
        mc1000Packet([0xB0, 35, 65], input); mc1000Packet([0xB0, 35, 63], input);
        mc1000Packet([0x90, 34, 127, 34, 0], input)
        #expect(events.map(\.0.action) == [.browse, .browse, .openGroup])
        #expect(events.prefix(2).map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        events.removeAll(); mc1000Packet([0xB2, 5, 127], input);
        #expect(events.count == 1 && events.first?.0.deck == .c)
    }
}

@Test @MainActor func controllerCatalogueMC1000LoopSizeStrictStepsAndUnqualifiedInputsStayBounded() throws {
    try withMC1000() { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (channel, deck) in DeckID.allCases.enumerated() {
            let wire = UInt8(channel); events.removeAll()
            mc1000Packet([0xB0 + wire, 33, 0, 33, 1, 33, 64, 33, 127], input); #expect(events.isEmpty)
            mc1000Packet([0xB0 + wire, 33, 65], input); mc1000Packet([0xB0 + wire, 33, 63], input)
            #expect(
                events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126]
                    && events.allSatisfy { $0.0 == .init(ControllerAction.loopSizeA.assigned(to: deck), deck: deck) })
        }
        events.removeAll()
        for wire: UInt8 in [4, 5, 6, 7, 8, 9, 10, 11] {
            mc1000Packet([0x90 + wire, 14, 127, 14, 0, 0xB0 + wire, 5, 64], input)
        }
        mc1000Packet([0x90, 9, 127, 9, 0, 25, 127, 25, 0, 0xB0, 1, 127, 4, 127, 34, 65], input); #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMC1000KeepsFourDeckOptInAndContextStateAcrossOnlyItsOwnInput() throws {
    try withMC1000(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        mc1000Packet([0x92, 14, 127, 14, 0, 0x93, 15, 127, 15, 0, 0x90, 14, 127, 14, 0], input)
        #expect(events == [.init(.playA, deck: .a)])
        input.stop(); #expect(!input.isInputActive(10))
    }
}
