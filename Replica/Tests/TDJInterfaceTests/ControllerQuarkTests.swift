import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withQuark(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    rethrows
{
    let suite = "quark-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("QUARK input must not change hardware settings."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Akiyama QUARK",
            identity: .init(id: id, device: UInt32(id), names: ["Akiyama QUARK"]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func quarkPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueQuarkOriginalIdentityAndFortyFourNormalLamps() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Akiyama QUARK"])); let d = try #require(p.definition)
    #expect(d.isValid && p.selectsAutomatically && d.inputs.count == 164 && d.outputs.count == 44)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["Akiyama QUARC"]) == p)
    #expect(ControllerFactoryProfile.matching(["QUARK SC"]) != p)
    for lamp in p.feedback(destination: 20) {
        #expect(lamp.channel < 4 && [23, 26, 29, 32, 35, 38, 44, 52, 53, 54, 60].contains(lamp.number))
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
    withQuark { _ in }
}

@Test @MainActor func controllerCatalogueQuarkTransportAndManualLoopsRearmOnlyOnExplicitRelease() {
    withQuark { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for (action, n): (ControllerAction, UInt8) in [
                (.playA, 52), (.syncA, 54), (.cueA, 60), (.loadA, 59), (.loopInA, 47), (.loopOutA, 48), (.reloopA, 49),
                (.loopA, 44),
            ] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll(); quarkPacket([0x90 + ch, n + 64, 127, n + 64, 0], input); #expect(events.isEmpty)
                    quarkPacket(
                        [0x90 + ch, n, 127, n, 127, off + ch, n + 64, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0],
                        input)
                    #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueQuarkCueBendsKeepBothReleaseFormsAndEveryPositiveVelocity() {
    withQuark { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for (action, n): (ControllerAction, UInt8) in [
                (.cuePreviewA, 53), (.pitchBendDownA, 50), (.pitchBendUpA, 51),
            ] {
                for velocity: UInt8 in [1, 64, 127] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll(); quarkPacket([0x90 + ch, n, velocity, n, 127, 63, 127, 63, 0], input)
                        #expect(events.map(\.1) == [Double(velocity) / 127])
                        quarkPacket([off + ch, n + 64, off == 0x80 ? 127 : 0], input)
                        #expect(
                            events.map(\.1) == [Double(velocity) / 127, 0]
                                && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueQuarkSixNormalHotCuesBlockAlternatePadsAndShiftedClears() {
    withQuark { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for (slot, n) in [UInt8(23), 26, 29, 32, 35, 38].enumerated() {
                events.removeAll()
                for other in [n + 1, n + 2, n + 64, n + 65, n + 66] {
                    quarkPacket([0x90 + ch, other, 127, other, 0], input)
                }
                #expect(events.isEmpty)
                quarkPacket([0x90 + ch, n, 127, n, 127, 0x80 + ch, n + 64, 127, 0x90 + ch, n, 1, n, 0], input)
                #expect(events.count == 2 && events.allSatisfy { $0.deck == deck && $0.action.hotcueSlot == slot })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueQuarkMixerPickupLoopSizeAndGlobalBrowseKeepTypedTargets() throws {
    try withQuark { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let p = try #require(ControllerFactoryProfile.matching(["QUARK"]))
        let mixer = p.bindings(source: 10).filter { $0.kind == .control && $0.encoding == .absolute };
        #expect(mixer.count == 22)
        for binding in mixer {
            events.removeAll(); quarkPacket([0xB0 + binding.channel, binding.number, 0], input); #expect(events.isEmpty)
            quarkPacket([0xB0 + binding.channel, binding.number, 64], input);
            quarkPacket([0xB0 + binding.channel, binding.number, 127], input)
            #expect(events.count == 2 && events.allSatisfy { $0.0 == binding.target } && events.last?.1 == 1)
        }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            events.removeAll(); quarkPacket([0xB0 + ch, 44, 64], input); #expect(events.isEmpty)
            quarkPacket([0xB0 + ch, 44, 67], input); quarkPacket([0xB0 + ch, 44, 49], input)
            #expect(
                events.map(\.1) == [0.5 + 3.0 / 126, 0.5 - 15.0 / 126]
                    && events.allSatisfy { $0.0 == .init(.loopSizeA.assigned(to: deck), deck: deck) })
        }
        events.removeAll(); quarkPacket([0xB4, 2, 65], input); quarkPacket([0x94, 2, 127, 2, 127, 2, 0], input)
        #expect(events.map { $0.0.action } == [.browse, .openGroup])
        events.removeAll();
        for ch: UInt8 in 0..<4 {
            quarkPacket(
                [
                    0xB0 + ch, 56, 127, 57, 65, 73, 127, 74, 127, 75, 127, 76, 127, 108, 65, 123, 127, 0x90 + ch, 55,
                    127, 63, 127, 63, 0, 0xE0 + ch, 0, 0,
                ], input)
        }
        quarkPacket([0xB4, 65, 127, 66, 65, 68, 127, 0x94, 3, 127, 5, 127, 6, 127], input); #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueQuarkDeckModeCleanupPreservesOtherSourceCueAndCDOptIn() {
    withQuark { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        quarkPacket([0x90, 53, 127, 0x92, 53, 127, 0x91, 53, 127], input);
        quarkPacket([0x90, 53, 127], input, source: 11); events.removeAll()
        quarkPacket([0x90, 7, 127], input)
        #expect(events.map { $0.0 } == [.init(.cuePreviewA, deck: .c)] && events.map(\.1) == [0])
        events.removeAll(); quarkPacket([0x91, 42, 127], input)
        #expect(events.map { $0.0 } == [.init(.cuePreviewB, deck: .b)] && events.map(\.1) == [0])
        events.removeAll(); quarkPacket([0x90, 53, 0], input, source: 11)
        #expect(events.map { $0.0 } == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
    }
    withQuark(decks: [.a, .b]) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        quarkPacket([0x92, 52, 127, 53, 127, 23, 127, 0xB2, 59, 64], input); #expect(events.isEmpty)
    }
}
