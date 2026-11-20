import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withPMX20(
    decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "pmx20-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual PMX-20 input must not send setup or mode writes."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "PMX-20",
            identity: .init(id: id, device: UInt32(id), names: ["Gemini PMX20"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Gemini PMX20"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 152 && input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func pmx20Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCataloguePMX20OwnManualIdentityAndFortyOptionalNonPagingLights() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Gemini PMX20"])); let d = try #require(p.definition)
    #expect(
        d.isValid && !p.selectsAutomatically && d.role == "accessory" && d.inputs.count == 76 && d.outputs.count == 40)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.bankChanges?.count == 12)
    #expect(ControllerFactoryProfile.matching(["PMX-20"], automaticOnly: true) == nil)
    for other in ["Gemini PMX10", "PMX-10", "PMX10"] { #expect(ControllerFactoryProfile.matching([other]) != p) }
    for lamp in p.feedback(destination: 20) {
        #expect(lamp.channel < 4 && ((1...8).contains(lamp.number) || [35, 50].contains(lamp.number)))
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 1])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
    try withPMX20 { _ in }
}

@Test @MainActor func controllerCataloguePMX20EveryReversedHotCueAndBothReleaseForms() throws {
    try withPMX20 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (index, deck) in DeckID.allCases.enumerated() {
            let ch = UInt8(index)
            for slot: UInt8 in 0..<8 {
                let n = 8 - slot
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll();
                    pmx20Packet([0x90 + ch, n, 127, n, 127, off + ch, n, off == 0x80 ? 127 : 0], input)
                    #expect(
                        events.count == 1 && events.first?.action.hotcueSlot == Int(slot) && events.first?.deck == deck)
                }
            }
        }
    }
}

@Test @MainActor func controllerCataloguePMX20AllMixerControlsPFLAndLoopEncoderKeepTheirDecks() throws {
    try withPMX20 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (index, deck) in DeckID.allCases.enumerated() {
            let ch = UInt8(index)
            for (n, action): (UInt8, ControllerAction) in [
                (49, .levelA), (51, .filterKnobA), (52, .lowA), (53, .midA), (54, .highA), (55, .gainA),
            ] {
                events.removeAll(); pmx20Packet([0xB0 + ch, n, 0], input); #expect(events.isEmpty)
                pmx20Packet([0xB0 + ch, n, 64], input); pmx20Packet([0xB0 + ch, n, 127], input)
                #expect(
                    events.count == 2 && events.last?.0 == .init(action.assigned(to: deck), deck: deck)
                        && events.last?.1 == 1)
            }
            for (n, action): (UInt8, ControllerAction) in [(50, .cueA), (35, .loopA)] {
                events.removeAll(); pmx20Packet([0x90 + ch, n, 127, n, 127, n, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            events.removeAll(); pmx20Packet([0xB0 + ch, 36, 65], input); pmx20Packet([0xB0 + ch, 36, 63], input)
            #expect(
                events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126]
                    && events.allSatisfy { $0.0 == .init(ControllerAction.loopSizeA.assigned(to: deck), deck: deck) })
        }
        for (n, action): (UInt8, ControllerAction) in [(96, .crossfader), (80, .master), (84, .monitor), (83, .cueMix)]
        {
            events.removeAll(); pmx20Packet([0xB4, n, 0], input); #expect(events.isEmpty)
            pmx20Packet([0xB4, n, 64], input); pmx20Packet([0xB4, n, 127], input)
            #expect(events.count == 2 && events.last?.0.action == action && events.last?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCataloguePMX20AgreedLoadsDirectoryAndRepeatedNativeBack() throws {
    try withPMX20 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        pmx20Packet([0x94, 64, 127, 64, 0, 65, 127, 65, 0, 66, 127, 66, 0, 67, 127, 67, 127, 67, 0], input)
        #expect(
            events == [
                .init(.loadA, deck: .a), .init(.loadB, deck: .b), .init(.openGroup), .init(.browsePreviousGroup),
                .init(.browsePreviousGroup),
            ])
    }
}

@Test @MainActor func controllerCataloguePMX20ModeAndFocusRearmOnlyOwnedDecksAndSources() throws {
    try withPMX20 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        pmx20Packet([0x90, 8, 127, 0x91, 8, 127, 0x92, 8, 127], input)
        pmx20Packet([0x90, 8, 127], input, source: 11); events.removeAll()
        pmx20Packet([0x90, 33, 127, 33, 0, 9, 127, 9, 0, 34, 127, 34, 0, 8, 127, 0x91, 8, 127], input)
        #expect(events == [.init(.hotcue1A, deck: .a)])
        events.removeAll(); pmx20Packet([0x90, 8, 127], input, source: 11); #expect(events.isEmpty)
        pmx20Packet([0x92, 64, 127, 64, 0, 8, 127, 0x90, 8, 127, 0x91, 8, 127], input)
        #expect(events == [.init(.hotcue1A, deck: .c), .init(.hotcue1A, deck: .a)])
    }
}

@Test @MainActor func controllerCataloguePMX20CDRequiresOptInAndDisputedControlsStayInactive() throws {
    try withPMX20(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in [2, 3] {
            pmx20Packet([0x90 + ch, 8, 127, 8, 0, 35, 127, 35, 0, 50, 127, 50, 0, 0xB0 + ch, 36, 65, 49, 64], input)
        }
        for ch: UInt8 in 0..<4 {
            for n: UInt8 in [9, 10, 11, 12, 13, 14, 15, 32, 38, 40, 56] {
                pmx20Packet([0x90 + ch, n, 127, n, 0], input)
            }
        }
        pmx20Packet(
            [
                0x94, 68, 127, 68, 0, 69, 127, 69, 0, 70, 127, 70, 0, 88, 127, 89, 127, 0xB4, 66, 65, 81, 127, 82, 127,
                0xB5, 66, 65,
            ], input)
        #expect(events.isEmpty)
    }
}
