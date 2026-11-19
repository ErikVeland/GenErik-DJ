import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJMTour1(
    availability: @escaping () -> [DeckID] = { DeckID.allCases }, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "tour1-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: availability, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "DJM-TOUR1",
            identity: .init(id: id, device: UInt32(id), names: ["DJM-TOUR1"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["DJM-TOUR1"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0); try body(input)
}
@MainActor private func tour1Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJMTour1KeepsIndependentManualPrimaryBusWithoutOutputOrAudioWrites() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Pioneer DJ DJM-TOUR1"]));
    let d = try #require(p.definition)
    #expect(
        !p.selectsAutomatically && d.inputs.count == 32 && d.bankChanges?.count == 24 && d.outputs.isEmpty
            && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["DJM-TOUR1"], automaticOnly: true) == nil)
    for name in ["CDJ-TOUR1", "DJM-900NXS2", "DJM-2000NXS", "DJM-V5", "DJM-TOUR1 clone"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
}

@Test @MainActor func controllerCatalogueDJMTour1EveryStripAndPrimaryGlobalKeepsSevenBitPickup() throws {
    try withDJMTour1 { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { events.append(($0, $1)) }
        let strips: [(DeckID, [UInt8])] = [
            (.a, [1, 2, 3, 4, 5, 17]), (.b, [6, 7, 8, 9, 10, 18]), (.c, [12, 14, 15, 21, 22, 19]),
            (.d, [80, 81, 92, 82, 83, 20]),
        ]
        for (deck, numbers) in strips {
            for (number, action) in zip(numbers, [ControllerAction.gainA, .highA, .midA, .lowA, .filterKnobA, .levelA])
            {
                events.removeAll(); tour1Packet([0xB0, number, 0], input); #expect(events.isEmpty)
                tour1Packet([0xB0, number, 64], input); tour1Packet([0xB0, number, 127], input)
                #expect(
                    events.count == 2 && events.last?.1 == 1
                        && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
        for (number, action): (UInt8, ControllerAction) in [
            (24, .master), (26, .monitor), (27, .cueMix), (11, .crossfader),
        ] {
            events.removeAll(); tour1Packet([0xB0, number, 0], input); #expect(events.isEmpty)
            tour1Packet([0xB0, number, 64], input); tour1Packet([0xB0, number, 127], input)
            #expect(events.count == 2 && events.last?.1 == 1 && events.allSatisfy { $0.0.action == action })
        }
    }
}

@Test @MainActor func controllerCatalogueDJMTour1PrimaryCCPFLIsDirectStateAndSecondHeadphonesStayInactive() throws {
    try withDJMTour1 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (index, deck) in DeckID.allCases.enumerated() {
            events.removeAll(); let number = UInt8(70 + index)
            tour1Packet([0xB0, number, 127], input); tour1Packet([0xB0, number, 127], input);
            tour1Packet([0xB0, number, 0], input)
            #expect(
                events.map(\.1) == [1, 1, 0]
                    && events.allSatisfy { $0.0 == .init(ControllerAction.cueStateA.assigned(to: deck), deck: deck) })
        }
        events.removeAll();
        tour1Packet(
            [
                0x90, 1, 127, 2, 127, 3, 127, 4, 127, 5, 127, 6, 127, 7, 127, 8, 127, 0xB0, 126, 127, 127, 127, 114,
                127, 74, 127, 115, 127, 0xB1, 70, 127, 1, 64,
            ], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueDJMTour1EveryInputSelectorResetsOnlyItsSourceAndStripOnNewSelection() throws {
    try withDJMTour1 { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [ControllerActionTarget] = [];
        input.onTargetAction = { target, _ in events.append(target) }
        let rows: [(DeckID, UInt8, [UInt8])] = [
            (.a, 1, [0x35, 0x42, 0x32, 0x33, 0x34, 0x43]), (.b, 6, [0x39, 0x44, 0x36, 0x37, 0x38, 0x45]),
            (.c, 12, [0x3D, 0x46, 0x3A, 0x3B, 0x3C, 0x47]), (.d, 80, [0x41, 0x48, 0x3E, 0x3F, 0x40, 0x49]),
        ]
        for (deck, gain, selectors) in rows {
            let otherGain: UInt8 = deck == .a ? 6 : 1
            tour1Packet([0xB0, gain, 64], input, source: 11); tour1Packet([0xB0, otherGain, 64], input)
            for selector in selectors {
                tour1Packet([0xB0, gain, 64], input); tour1Packet([0xB0, gain, 127], input); events.removeAll()
                tour1Packet([0x90, selector, 0], input); tour1Packet([0xB0, gain, 0], input); #expect(events.count == 1)
                tour1Packet([0xB0, gain, 127], input); events.removeAll()
                tour1Packet([0x90, selector, 127], input); tour1Packet([0xB0, gain, 0], input); #expect(events.isEmpty)
                tour1Packet([0xB0, gain, 127], input, source: 11); #expect(events.count == 1)
                tour1Packet([0xB0, otherGain, 127], input); #expect(events.count == 2)
                events.removeAll(); tour1Packet([0xB0, gain, 64], input);
                #expect(events == [.init(ControllerAction.gainA.assigned(to: deck), deck: deck)])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDJMTour1KeepsCDOptInAndStrictManualChannel() throws {
    var available: [DeckID] = [.a, .b]
    try withDJMTour1(availability: { available }) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        tour1Packet([0xB0, 72, 127, 73, 127, 0xB1, 70, 127], input); #expect(events.isEmpty)
        available = DeckID.allCases; tour1Packet([0xB0, 72, 127, 73, 127], input)
        #expect(events == [.init(.cueStateA, deck: .c), .init(.cueStateB, deck: .d)])
    }
}
