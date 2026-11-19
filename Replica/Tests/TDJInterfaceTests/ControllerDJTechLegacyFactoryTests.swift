import Foundation
import TDJCore
import Testing

@testable import TDJInterface

struct DJTechLegacyLayout: Sendable {
    let name: String
    let dragon: Bool
    var cue: UInt8 { dragon ? 22 : 11 }
    var play: UInt8 { dragon ? 23 : 12 }
    var shift: UInt8 { dragon ? 24 : 14 }
    var count: Int { dragon ? 220 : 164 }
    var hotcue: UInt8 { dragon ? 17 : 6 }
}
private let djTechLegacyLayouts = [
    DJTechLegacyLayout(name: "DJ-Tech DRAGON TWO", dragon: true),
    DJTechLegacyLayout(name: "DJ-Tech 4MIX", dragon: false),
]

@MainActor private func withDJTechLegacy(
    _ layout: DJTechLegacyLayout, decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "djtech-legacy-\(UUID().uuidString)"; let prefs = UserDefaults(suiteName: suite)!
    defer { prefs.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: prefs,
        factoryPacketSender: { _, _ in
            Issue.record("Manual DJ-Tech core must not configure hardware."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: layout.name,
            identity: .init(id: id, device: UInt32(id), names: [layout.name]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching([layout.name])); input.select(10);
    input.applyFactoryProfile(p)
    #expect(input.bindingCount == layout.count && input.isInputActive(10) && !input.isInputActive(11))
    try body(input)
}
@MainActor private func djTechLegacyPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: djTechLegacyLayouts) @MainActor func controllerCatalogueDJTechLegacyManualIdentityHasNoSetupOrOutputs(
    layout: DJTechLegacyLayout
) throws {
    let p = try #require(ControllerFactoryProfile.matching([layout.name])); let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == layout.count && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching([layout.name], automaticOnly: true) == nil)
    #expect(p.feedback(destination: 20).isEmpty)
    #expect(ControllerFactoryProfile.matching([layout.dragon ? "4MIX" : "DRAGON TWO"]) != p)
    try withDJTechLegacy(layout) { _ in }
}

@Test(arguments: djTechLegacyLayouts) @MainActor
func controllerCatalogueDJTechLegacyButtonsKeepExplicitChannelsAndCDOptIn(layout: DJTechLegacyLayout) throws {
    for decks in [DeckID.primary, DeckID.allCases] {
        try withDJTechLegacy(layout, decks: decks) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            var buttons: [(ControllerAction, UInt8)] = [
                (.playA, layout.play), (.syncA, layout.dragon ? 16 : 5), (.loopInA, layout.dragon ? 13 : 2),
                (.loopOutA, layout.dragon ? 14 : 3), (.reloopA, layout.dragon ? 15 : 4),
            ]
            if layout.dragon { buttons += [(.loadA, 8), (.cueA, 9)] }
            for (i, deck) in DeckID.allCases.enumerated() {
                let ch = UInt8(i + 1)
                for (action, n) in buttons {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        djTechLegacyPacket(
                            [0x90 + ch, n, 127, n, 127, off + ch, n, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0],
                            input)
                        #expect(
                            events
                                == (decks.contains(deck)
                                    ? Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2) : []))
                    }
                }
            }
        }
    }
}

@Test(arguments: djTechLegacyLayouts) @MainActor
func controllerCatalogueDJTechLegacyCueBendsKeepAllVelocitiesAndOppositeReleases(layout: DJTechLegacyLayout) throws {
    try withDJTechLegacy(layout) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        var buttons: [(ControllerAction, UInt8, UInt8?)] = [(.cuePreviewA, layout.cue, layout.dragon ? nil : 75)]
        if layout.dragon { buttons += [(.pitchBendDownA, 11, 75), (.pitchBendUpA, 12, 76)] }
        for (i, deck) in DeckID.allCases.enumerated() {
            let ch = UInt8(i + 1), other = UInt8((i + 2) % 4 + 1)
            for (action, n, alt) in buttons {
                for release in [n] + (alt.map { [$0] } ?? []) {
                    for velocity: UInt8 in [1, 64, 127] {
                        for off: UInt8 in [0x80, 0x90] {
                            events.removeAll();
                            djTechLegacyPacket(
                                [0x90 + ch, n, velocity, n, 127, off + other, release, off == 0x80 ? 127 : 0], input)
                            #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                            #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                        }
                    }
                }
            }
        }
    }
}

@Test(arguments: djTechLegacyLayouts) @MainActor func controllerCatalogueDJTechLegacyShiftAliasesRetainOnePhysicalSide(
    layout: DJTechLegacyLayout
) throws {
    try withDJTechLegacy(layout) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        djTechLegacyPacket([0x91, layout.cue, 127, layout.shift, 127], input); events.removeAll()
        if !layout.dragon {
            djTechLegacyPacket([0x91, 75, 127, 75, 0], input)
        } else {
            djTechLegacyPacket([0x93, layout.cue, 0], input)
        }
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
        events.removeAll();
        djTechLegacyPacket(
            [0x91, layout.play, 127, layout.play, 0, layout.hotcue + 64, 127, layout.hotcue + 64, 0], input)
        #expect(events.isEmpty)
        djTechLegacyPacket([0x83, layout.shift, 127, 0x91, layout.play, 127, layout.play, 0], input)
        #expect(events.map(\.0) == [.init(.playA, deck: .a)])
    }
}

@Test(arguments: djTechLegacyLayouts) @MainActor
func controllerCatalogueDJTechLegacyFourHotCuesKeepNegativeClearAliases(layout: DJTechLegacyLayout) throws {
    try withDJTechLegacy(layout) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (i, deck) in DeckID.allCases.enumerated() {
            let ch = UInt8(i + 1), other = UInt8((i + 2) % 4 + 1)
            for (offset, action) in [ControllerAction.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A].enumerated() {
                let n = layout.hotcue + UInt8(offset)
                events.removeAll(); djTechLegacyPacket([0x90 + ch, n + 64, 127, n + 64, 0], input);
                #expect(events.isEmpty)
                djTechLegacyPacket(
                    [0x90 + ch, n, 127, n, 127, 0x80 + other, n + 64, 127, 0x90 + ch, n, 127, n, 0], input)
                #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
            }
        }
    }
}

@Test(arguments: djTechLegacyLayouts) @MainActor func controllerCatalogueDJTechLegacyMixerKeepsQualifiedPickupOnly(
    layout: DJTechLegacyLayout
) throws {
    try withDJTechLegacy(layout) { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (i, deck) in DeckID.allCases.enumerated() {
            for (action, n): (ControllerAction, UInt8) in [
                (.gainA, 8), (.highA, 25), (.midA, 26), (.lowA, 27), (.filterKnobA, 28), (.levelA, 9),
            ] {
                events.removeAll(); let ch = UInt8(i + 1)
                djTechLegacyPacket([0xB0 + ch, n, 0], input); #expect(events.isEmpty)
                djTechLegacyPacket([0xB0 + ch, n, 64], input); djTechLegacyPacket([0xB0 + ch, n, 127], input)
                #expect(events.count == (layout.dragon ? 2 : 0))
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                if layout.dragon { #expect(events.map(\.1) == [64.0 / 127, 1]) }
            }
        }
    }
}

@Test(arguments: djTechLegacyLayouts) @MainActor
func controllerCatalogueDJTechLegacyUnqualifiedWiresSourcesAndGroupsStayInactive(layout: DJTechLegacyLayout) throws {
    try withDJTechLegacy(layout) { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        let p = try #require(ControllerFactoryProfile.matching([layout.name])); let bindings = p.bindings(source: 10)
        for ch: UInt8 in 0..<16 {
            let notes = bindings.filter { $0.kind == .note && $0.channel == ch }.map(\.number)
            let controls = bindings.filter { $0.kind == .control && $0.channel == ch }.map(\.number)
            for n: UInt8 in 0..<128 where !notes.contains(n) { djTechLegacyPacket([0x90 + ch, n, 127, n, 0], input) }
            for n: UInt8 in 0..<128 where !controls.contains(n) {
                djTechLegacyPacket([0xB0 + ch, n, 0, n, 64, n, 127], input)
            }
            djTechLegacyPacket([0xE0 + ch, 0, 64], input)
        }
        for source: Int32 in [11, 999] {
            djTechLegacyPacket([0x91, layout.play, 127, 0xB1, 8, 64], input, source: source)
        }
        input.receive(.init(kind: .note, group: 1, channel: 1, number: layout.play, value: 127), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}

@Test(arguments: djTechLegacyLayouts) @MainActor func controllerCatalogueDJTechLegacyManualReapplyRetiresOwnedCue(
    layout: DJTechLegacyLayout
) throws {
    try withDJTechLegacy(layout) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        djTechLegacyPacket([0x91, layout.cue, 127], input); events.removeAll()
        let p = try #require(ControllerFactoryProfile.matching([layout.name])); input.select(10);
        input.applyFactoryProfile(p)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
        events.removeAll(); djTechLegacyPacket([0x91, layout.cue, 127, layout.cue, 0], input)
        #expect(events.map(\.1) == [1, 0])
    }
}
