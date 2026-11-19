import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let audiophonyFactoryNames = ["Audiophony DJAZZ", "Audiophony DJAM", "Audiophony DJAM (CTRL MIDI mixer)"]

@MainActor private func withAudiophonyFactory(
    _ name: String, decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
)
    throws
{
    let suite = "audiophonyFactory-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Default AudiophonyFactory input must not configure hardware."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: name.contains("DJAZZ") ? "DJAZZ" : "DJAM",
            identity: .init(id: id, device: UInt32(id), names: [name.contains("DJAZZ") ? "DJAZZ" : "DJAM"]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11))
    if name.contains("CTRL MIDI") {
        let p = try #require(ControllerFactoryProfile.matching([name]))
        input.select(10); input.applyFactoryProfile(p)
        #expect(input.bindingCount == 213)
    }
    try body(input)
}

@MainActor private func audiophonyFactoryPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10)
{
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: audiophonyFactoryNames) @MainActor
func controllerCatalogueAudiophonyFactoryOwnDefaultIdentityAndNormalLamps(name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(
        d.isValid && p.rawValue == name && p.selectsAutomatically == !name.contains("CTRL MIDI")
            && d.inputs.count == (name == "Audiophony DJAM" ? 157 : name.contains("CTRL MIDI") ? 213 : 211)
            && d.outputs.count == (name == "Audiophony DJAM" ? 32 : 36))
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == (name.contains("CTRL MIDI") ? nil : p))
    #expect(ControllerFactoryProfile.matching([name.contains("DJAZZ") ? "DJAM" : "DJAZZ"]) != p)
    for lamp in p.feedback(destination: 20) {
        #expect(lamp.channel < 4 && [8, 9, 10, 11, 16, 18, 23, 24, 28].contains(lamp.number))
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
    try withAudiophonyFactory(name) { _ in }
}

@Test(arguments: audiophonyFactoryNames) @MainActor
func controllerCatalogueAudiophonyFactoryNormalTransportAndLoadsRearmThroughShiftReleases(name: String) throws {
    try withAudiophonyFactory(name) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for (action, n): (ControllerAction, UInt8) in [
                (.playA, 24), (.syncA, 18), (.keylockA, 16), (.cueA, 28), (.loadA, 34 + ch % 2), (.loopInA, 4),
                (.loopOutA, 5), (.reloopA, 6), (.loopA, 1),
            ] {
                if name == "Audiophony DJAM" && action == .cueA { continue }
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll(); audiophonyFactoryPacket([0x90 + ch, n + 50, 127, n + 50, 0], input);
                    #expect(events.isEmpty)
                    audiophonyFactoryPacket(
                        [0x90 + ch, n, 127, n, 127, off + ch, n + 50, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0],
                        input)
                    #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                }
            }
        }
    }
}

@Test(arguments: audiophonyFactoryNames) @MainActor
func controllerCatalogueAudiophonyFactoryCueBendsAndContactKeepAllVelocitiesAndReleaseForms(name: String) throws {
    try withAudiophonyFactory(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for (action, n): (ControllerAction, UInt8) in [
                (.cuePreviewA, 23), (.pitchBendDownA, 19), (.pitchBendUpA, 20), (.jogTouchA, 38),
            ] {
                for velocity: UInt8 in [1, 64, 127] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        audiophonyFactoryPacket(
                            [0x90 + ch, n, velocity, n, 127, off + ch, n + 50, off == 0x80 ? 127 : 0], input)
                        #expect(
                            events.map(\.1) == [Double(velocity) / 127, 0]
                                && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    }
                }
            }
        }
    }
}

@Test(arguments: audiophonyFactoryNames) @MainActor
func controllerCatalogueAudiophonyFactoryHotCuesAndShiftedFixedJumpsRemainSeparate(name: String) throws {
    try withAudiophonyFactory(name) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            for slot: UInt8 in 0..<4 {
                events.removeAll();
                audiophonyFactoryPacket(
                    [
                        0x90 + ch, 8 + slot, 127, 8 + slot, 127, 0x80 + ch, 58 + slot, 127, 0x90 + ch, 8 + slot, 1,
                        8 + slot, 0,
                    ], input)
                #expect(events.count == 2 && events.allSatisfy { $0.deck == deck && $0.action.hotcueSlot == Int(slot) })
                events.removeAll();
                audiophonyFactoryPacket(
                    [0x90 + ch, 58 + slot, 127, 58 + slot, 127, 8 + slot, 0, 58 + slot, 1, 58 + slot, 0], input)
                if slot < 2 {
                    #expect(
                        events
                            == Array(
                                repeating: .init(
                                    .fixedJumpA.assigned(to: deck), deck: deck, argument: slot == 0 ? -4 : 4), count: 2)
                    )
                } else {
                    #expect(events.isEmpty)
                }
            }
        }
    }
}

@Test(arguments: audiophonyFactoryNames) @MainActor
func controllerCatalogueAudiophonyFactoryMixerShiftFilterAndResolvedGlobalControlsKeepPickup(name: String) throws {
    if name == "Audiophony DJAM" { return }
    try withAudiophonyFactory(name) { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let p = try #require(ControllerFactoryProfile.matching([name]))
        for shifted in [false, true] {
            audiophonyFactoryPacket([0x90, 45, shifted ? 127 : 0], input)
            let controls = p.bindings(source: 10).filter {
                $0.kind == .control && $0.mode == .absolute
                    && $0.targetDeck != nil
                    && (shifted ? [33, 34, 36, 37].contains($0.number) : [3, 4, 5, 6, 7].contains($0.number))
            }
            #expect(controls.count == (shifted ? 16 : 20))
            for b in controls {
                events.removeAll(); audiophonyFactoryPacket([0xB0 + b.channel, b.number, 0], input);
                #expect(events.isEmpty)
                audiophonyFactoryPacket([0xB0 + b.channel, b.number, 64], input);
                audiophonyFactoryPacket([0xB0 + b.channel, b.number, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == b.target } && events.last?.1 == 1)
            }
            events.removeAll()
            for ch: UInt8 in 0..<4 {
                audiophonyFactoryPacket([0xB0 + ch, shifted ? 5 : 36, 127, shifted ? 6 : 36, 64], input)
            }
            #expect(events.isEmpty)
        }
        audiophonyFactoryPacket([0x90, 45, 0], input); events.removeAll();
        audiophonyFactoryPacket([0xB0, 5, 0], input); #expect(events.isEmpty)
        audiophonyFactoryPacket([0xB0, 5, 64], input);
        #expect(events.count == 1 && events[0].0 == .init(.midA, deck: .a))
        for (normal, shifted, action): (UInt8, UInt8, ControllerAction) in [
            (16, 46, .crossfader), (19, 49, .cueMix), (20, 50, .monitor),
        ] {
            events.removeAll(); audiophonyFactoryPacket([0xB0, normal, 0], input); #expect(events.isEmpty)
            audiophonyFactoryPacket([0xB0, normal, 64], input); audiophonyFactoryPacket([0xB0, normal, 127], input)
            #expect(events.count == 2 && events.allSatisfy { $0.0 == .init(action) })
            audiophonyFactoryPacket([0x90, 45, 127], input); events.removeAll()
            audiophonyFactoryPacket([0xB0, shifted, 0], input); audiophonyFactoryPacket([0xB0, shifted, 64], input);
            audiophonyFactoryPacket([0xB0, shifted, 127], input)
            let observed = events.map(\.1); #expect(observed == [64.0 / 127, 1]);
            #expect(events.allSatisfy { $0.0 == .init(action) })
            audiophonyFactoryPacket([0x90, 45, 0], input)
        }
    }
}

@Test(arguments: audiophonyFactoryNames) @MainActor
func controllerCatalogueAudiophonyFactoryCalibratedJogAndInvertedPitchAreShiftGuarded(name: String) throws {
    try withAudiophonyFactory(name) { input in
        input.currentTargetValue = { _ in 0.5 }
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []; input.onJogAction = { jogs.append(($0, $1)) }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b), (2, .c), (3, .d)] {
            jogs.removeAll(); audiophonyFactoryPacket([0xB0 + ch, 2, 64], input); #expect(jogs.isEmpty)
            audiophonyFactoryPacket([0xB0 + ch, 2, 65], input); audiophonyFactoryPacket([0xB0 + ch, 2, 63], input)
            #expect(
                jogs.map(\.1) == [.relative(1), .relative(-1)]
                    && jogs.allSatisfy {
                        $0.0
                            == .init(.jogA.assigned(to: deck), deck: deck, argument: name.contains("DJAZZ") ? 150 : 800)
                    })
            events.removeAll(); audiophonyFactoryPacket([0xE0 + ch, 0, 0], input); #expect(events.isEmpty)
            audiophonyFactoryPacket([0xE0 + ch, 0, 64], input); audiophonyFactoryPacket([0xE0 + ch, 127, 127], input)
            #expect(
                events.count == 2 && events.allSatisfy { $0.0 == .init(.tempoA.assigned(to: deck), deck: deck) }
                    && events.last?.1 == 0)
        }
        audiophonyFactoryPacket([0x90, 45, 127], input); events.removeAll(); jogs.removeAll()
        for ch: UInt8 in 0..<4 {
            audiophonyFactoryPacket([0xB0 + ch, 1, 65, 2, 65, 32, 65, 31, 65, 0xE0 + ch, 0, 64], input)
        }
        #expect(events.isEmpty && jogs.isEmpty)
        audiophonyFactoryPacket([0x90, 45, 0], input)
    }
}

@Test(arguments: audiophonyFactoryNames) @MainActor
func controllerCatalogueAudiophonyFactoryBrowseUsesFactoryRelativeFormatAndPushReleaseAlias(name: String) throws {
    if name == "Audiophony DJAM" { return }
    try withAudiophonyFactory(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (n, action): (UInt8, ControllerAction) in [(14, .browse), (44, .browseGroups)] {
            events.removeAll(); audiophonyFactoryPacket([0xB0, n, 64], input); #expect(events.isEmpty)
            audiophonyFactoryPacket([0xB0, n, 65], input); audiophonyFactoryPacket([0xB0, n, 63], input)
            #expect(events.map(\.0) == [.init(action), .init(action)] && events[0].1 > 0.5 && events[1].1 < 0.5)
        }
        events.removeAll();
        audiophonyFactoryPacket([0x90, 89, 127, 89, 0, 39, 127, 39, 127, 0x80, 89, 127, 0x90, 39, 1, 39, 0], input)
        #expect(events.map(\.0) == [.init(.openGroup), .init(.openGroup)])
    }
}

@Test(arguments: audiophonyFactoryNames) @MainActor
func controllerCatalogueAudiophonyFactoryDeckCleanupPreservesOtherSourceAndCDOptIn(name: String) throws {
    try withAudiophonyFactory(name) { input in
        var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { if !$0.action.isJog { events.append(($0, $1)) } }
        audiophonyFactoryPacket([0x90, 23, 127, 0x92, 23, 127, 0x91, 23, 127], input);
        audiophonyFactoryPacket([0x90, 23, 127], input, source: 11);
        events.removeAll()
        audiophonyFactoryPacket([0x90, 67, 127, 67, 0], input)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .c)] && events.map(\.1) == [0])
        events.removeAll(); audiophonyFactoryPacket([0x91, 17, 127, 17, 0], input)
        #expect(events.map(\.0) == [.init(.cuePreviewB, deck: .b)] && events.map(\.1) == [0])
        events.removeAll(); audiophonyFactoryPacket([0x80, 23, 127], input, source: 11)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
    }
    try withAudiophonyFactory(name, decks: [.a, .b]) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        audiophonyFactoryPacket([0x92, 24, 127, 23, 127, 8, 127, 34, 127, 0xB2, 7, 64, 2, 65], input);
        #expect(events.isEmpty)
    }
}

@Test(arguments: audiophonyFactoryNames) @MainActor
func controllerCatalogueAudiophonyFactoryUnqualifiedPresetsAndFunctionsStayInactive(name: String) throws {
    try withAudiophonyFactory(name) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 4..<16 {
            audiophonyFactoryPacket(
                [0x90 + ch, 24, 127, 23, 127, 8, 127, 34, 127, 0xB0 + ch, 7, 64, 2, 65, 0xE0 + ch, 0, 64], input)
        }
        for ch: UInt8 in 0..<4 {
            audiophonyFactoryPacket(
                [
                    0x90 + ch, 2, 127, 3, 127, 7, 127, 12, 127, 13, 127, 14, 127, 15, 127, 21, 127, 22, 127, 25, 127,
                    26, 127, 27, 127, 60, 127, 61, 127, 72, 127, 77, 127, 0xB0 + ch, 8, 65, 9, 127, 10, 127, 11, 127,
                    32, 65, 35, 127,
                ], input)
        }
        audiophonyFactoryPacket([0xB0, 13, 127, 15, 65, 17, 127, 18, 127, 43, 127, 45, 65, 47, 127, 48, 127], input)
        audiophonyFactoryPacket([0x90, 24, 127], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 24, value: 127), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAudiophonyFactoryCommonDJamExcludesMixerAndGlobalBrowser() throws {
    try withAudiophonyFactory("Audiophony DJAM") { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 0..<4 {
            for n: UInt8 in [3, 4, 5, 6, 7, 33, 34, 35, 36, 37] {
                for value: UInt8 in [0, 64, 127] { audiophonyFactoryPacket([0xB0 + ch, n, value], input) }
            }
            audiophonyFactoryPacket([0x90 + ch, 28, 127, 28, 0, 78, 127, 78, 0], input)
        }
        for n: UInt8 in [12, 14, 16, 19, 20, 42, 44, 46, 49, 50] {
            for value: UInt8 in [0, 64, 127] { audiophonyFactoryPacket([0xB0, n, value], input) }
        }
        audiophonyFactoryPacket([0x90, 39, 127, 39, 0, 89, 127, 89, 0], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAudiophonyFactoryMasterIsOnlyDocumentedDJamManual() throws {
    for name in audiophonyFactoryNames {
        try withAudiophonyFactory(name) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for n: UInt8 in [12, 42] {
                events.removeAll()
                audiophonyFactoryPacket([0xB0, n, 0], input); #expect(events.isEmpty)
                audiophonyFactoryPacket([0xB0, n, 64], input); audiophonyFactoryPacket([0xB0, n, 127], input)
                #expect(events.count == (name.contains("CTRL MIDI") ? 2 : 0))
                #expect(events.allSatisfy { $0.0 == .init(.master) })
            }
        }
    }
}
