import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withJockeyRemix(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "jockey-remix-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual Jockey input must not write a hardware mode."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Jockey 3 Remix",
            identity: .init(id: id, device: UInt32(id), names: ["Reloop Jockey 3 Remix"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10))
    let p = try #require(ControllerFactoryProfile.matching(["Reloop Jockey 3 Remix"]))
    input.select(10); input.applyFactoryProfile(p); #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func jockeyPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueJockeyRemixOwnIdentityAndNormalStaticLamps() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Jockey 3 Remix"])); let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.inputs.count == 144 && d.outputs.count == 32)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["Jockey 3 Remix"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["Reloop Jockey 3 ME"]) != p)
    for lamp in p.feedback(destination: 20) {
        #expect(lamp.channel < 4 && ([23, 25, 26, 28].contains(lamp.number) || (11...14).contains(lamp.number)))
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
    try withJockeyRemix { _ in }
}

@Test @MainActor func controllerCatalogueJockeyRemixCueBendsAndShiftedReleasesAcrossFourDecks() throws {
    try withJockeyRemix { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for (action, n, release): (ControllerAction, UInt8, UInt8) in [
                (.cuePreviewA, 25, 88), (.pitchBendDownA, 41, 104), (.pitchBendUpA, 42, 105),
            ] {
                for velocity: UInt8 in [1, 64, 127] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        jockeyPacket([0x90 + ch, n, velocity, n, 127, off + ch, release, off == 0x80 ? 127 : 0], input)
                        #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                        #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueJockeyRemixNormalButtonsHotCueClearGuardsAndKeylock() throws {
    try withJockeyRemix { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for (action, n, release): (ControllerAction, UInt8, UInt8) in [
                (.playA, 26, 89), (.syncA, 23, 86), (.cueA, 28, 91), (.loadA, 27, 90), (.keylockA, 87, 24),
                (.loopA, 43, 106), (.reloopA, 44, 107),
            ] {
                events.removeAll(); jockeyPacket([0x90 + ch, release, 127, release, 0], input); #expect(events.isEmpty)
                jockeyPacket([0x90 + ch, n, 127, n, 127, release, 0, n, 1, n, 0], input)
                #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
            }
            for slot: UInt8 in 0..<4 {
                events.removeAll(); jockeyPacket([0x90 + ch, 74 + slot, 127, 74 + slot, 0], input);
                #expect(events.isEmpty)
                jockeyPacket(
                    [
                        0x90 + ch, 11 + slot, 127, 11 + slot, 127, 0x80 + ch, 74 + slot, 127, 0x90 + ch, 11 + slot, 1,
                        11 + slot, 0,
                    ], input)
                #expect(events.count == 2 && events.allSatisfy { $0.deck == deck && $0.action.hotcueSlot == Int(slot) })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueJockeyRemixAllMixerControlsUsePickupAndNoEndstopNotes() throws {
    try withJockeyRemix { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let p = try #require(ControllerFactoryProfile.matching(["Jockey 3 Remix"]))
        let mixer = p.bindings(source: 10).filter { $0.kind == .control && $0.encoding == .absolute }
        #expect(mixer.count == 26)
        for binding in mixer {
            events.removeAll(); jockeyPacket([0x90 + binding.channel, binding.number, 127, binding.number, 0], input);
            #expect(events.isEmpty)
            jockeyPacket([0xB0 + binding.channel, binding.number, 0], input); #expect(events.isEmpty)
            jockeyPacket([0xB0 + binding.channel, binding.number, 64], input)
            jockeyPacket([0xB0 + binding.channel, binding.number, 127], input)
            #expect(events.count == 2 && events.allSatisfy { $0.0 == binding.target } && events.last?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCatalogueJockeyRemixSelectorsReleaseOnlyTheirSourceAndDeckPair() throws {
    try withJockeyRemix { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        jockeyPacket([0x90, 25, 127, 0x91, 25, 127, 0x92, 25, 127, 0x93, 25, 127], input); events.removeAll()
        jockeyPacket([0x90, 60, 127], input, source: 11); #expect(events.isEmpty)
        jockeyPacket([0x90, 60, 127], input)
        #expect(
            events.count == 2 && Set(events.compactMap { $0.0.deck }) == Set([.a, .c])
                && events.allSatisfy { $0.1 == 0 })
        events.removeAll(); jockeyPacket([0x90, 63, 127], input)
        #expect(events.count == 2 && Set(events.compactMap { $0.0.deck }) == Set([.b, .d]))
        jockeyPacket([0x90, 25, 127], input); events.removeAll(); jockeyPacket([0x90, 19, 127], input)
        #expect(events.count == 1 && events.first?.0.deck == .a && events.first?.1 == 0)
    }
    try withJockeyRemix(decks: [.a, .b]) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        jockeyPacket([0x92, 26, 127, 11, 127, 0x93, 25, 127, 0xB2, 49, 64], input); #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueJockeyRemixRelativeLoopsBrowseAndUnqualifiedWires() throws {
    try withJockeyRemix { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            events.removeAll(); jockeyPacket([0xB0 + ch, 43, 64], input); #expect(events.isEmpty)
            jockeyPacket([0xB0 + ch, 43, 67], input); jockeyPacket([0xB0 + ch, 43, 49], input)
            #expect(events.map(\.1) == [0.5 + 3.0 / 126, 0.5 - 15.0 / 126])
            #expect(events.allSatisfy { $0.0 == .init(.loopSizeA.assigned(to: deck), deck: deck) })
        }
        events.removeAll(); jockeyPacket([0xB0, 53, 65], input); jockeyPacket([0x90, 116, 127, 116, 0], input)
        #expect(events.map { $0.0.action } == [.browse, .openGroup])
        events.removeAll()
        for ch: UInt8 in 0..<4 {
            jockeyPacket(
                [
                    0xE0 + ch, 0, 0, 0xB0 + ch, 34, 65, 38, 65, 40, 65, 44, 65, 113, 127, 116, 65, 0x90 + ch, 24, 127,
                    24, 0, 39, 127, 39, 0, 52, 127, 52, 0,
                ], input)
        }
        for ch: UInt8 in 4..<16 { jockeyPacket([0x90 + ch, 25, 127, 26, 127, 0xB0 + ch, 49, 64], input) }
        #expect(events.isEmpty)
    }
}
