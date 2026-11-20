import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let radiusVersions = [
    "American Audio RADIUS 1000 (2009 factory mapping)", "American Audio RADIUS 1000", "American Audio RADIUS 3000",
]

@MainActor private func withRadiusVersion(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "radius-version-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Radius input must not configure hardware."); return false
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    let automatic = name == radiusVersions[2]; let sourceName = automatic ? "RADIUS3000" : "RADIUS1000"
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: sourceName,
            identity: .init(id: id, device: UInt32(id), names: [sourceName]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) == automatic && input.isInputActive(11) == automatic)
    if !automatic {
        let p = try #require(ControllerFactoryProfile.matching([name]))
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    }
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func radiusVersionPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRadiusVersionsKeepSeparateIdentityAndNoHardwareWrites() throws {
    for (index, name) in radiusVersions.enumerated() {
        let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
        #expect(
            p.rawValue == name && d.isValid && d.inputs.count == [39, 38, 40][index]
                && p.selectsAutomatically == (index == 2))
        #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == (index == 2 ? p : nil))
        try withRadiusVersion(name) { _ in }
    }
    #expect(ControllerFactoryProfile.matching(["Radius 1000"])?.rawValue == radiusVersions[1])
    #expect(ControllerFactoryProfile.matching(["Radius 2000"])?.rawValue != radiusVersions[2])
}

@Test @MainActor func controllerCatalogueRadiusVersionsUseOwnTransportReleaseOffsetAcrossQualifiedChannels() throws {
    for (index, name) in radiusVersions.enumerated() {
        try withRadiusVersion(name) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            let offset: UInt8 = index == 1 ? 61 : 63
            for ch: UInt8 in 0..<(index == 0 ? 1 : 16) {
                for (action, n): (ControllerAction, UInt8) in [
                    (.playA, 42), (.keylockA, 6), (.loopInA, 11), (.loopOutOrExitA, 5), (.reloopA, 23),
                    (.loopDownA, 14), (.loopUpA, 8), (.loadA, 31),
                ] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll(); radiusVersionPacket([0x90 + ch, n + offset, 127, n + offset, 0], input);
                        #expect(events.isEmpty)
                        radiusVersionPacket(
                            [
                                0x90 + ch, n, 127, n, 127, off + ch, n + offset, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1,
                                n, 0,
                            ], input)
                        #expect(events == Array(repeating: .init(action, deck: .a), count: 2))
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueRadiusVersionsHoldCueBendsAndLegacyContactThroughBothReleaseForms() throws {
    for (index, name) in radiusVersions.enumerated() {
        try withRadiusVersion(name) { input in
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            let offset: UInt8 = index == 1 ? 61 : 63
            let controls: [(ControllerAction, UInt8)] =
                [(.cuePreviewA, 48), (.pitchBendDownA, 7), (.pitchBendUpA, 13)] + (index == 0 ? [(.jogTouchA, 38)] : [])
            for ch: UInt8 in 0..<(index == 0 ? 1 : 16) {
                for (action, n) in controls {
                    for velocity: UInt8 in [1, 64, 127] {
                        for off: UInt8 in [0x80, 0x90] {
                            events.removeAll();
                            radiusVersionPacket(
                                [0x90 + ch, n, velocity, n, 127, off + ch, n + offset, off == 0x80 ? 127 : 0], input)
                            #expect(
                                events.map(\.1) == [Double(velocity) / 127, 0]
                                    && events.allSatisfy { $0.0 == .init(action, deck: .a) })
                        }
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueRadiusVersionsKeepThreeOrFourCuesAndExplicitShiftedClears() throws {
    for (index, name) in radiusVersions.enumerated() {
        try withRadiusVersion(name) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            let offset: UInt8 = index == 1 ? 61 : 63
            let cues: [UInt8] = [22, 16, 10] + (index == 2 ? [34] : [])
            for (slot, n) in cues.enumerated() {
                events.removeAll();
                radiusVersionPacket(
                    [0x90, n + offset, 127, n + offset, 0, n, 127, n, 127, 0x80, n + offset, 127, 0x90, n, 1, n, 0],
                    input)
                #expect(events.count == 2 && events.allSatisfy { $0.deck == .a && $0.action.hotcueSlot == slot })
            }
            events.removeAll(); radiusVersionPacket([0x90, 25, 127, 25, 127, 25 + offset, 0, 25, 1, 25, 0], input)
            #expect(events == [.init(.openGroup), .init(.openGroup)])
        }
    }
}

@Test @MainActor func controllerCatalogueRadiusManualTablesKeepDirectionalNoteFormatSeparateFromRelativeCC() throws {
    for (index, name) in radiusVersions.enumerated() where index > 0 {
        try withRadiusVersion(name) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            let offset: UInt8 = index == 1 ? 61 : 63
            for (action, n): (ControllerAction, UInt8) in [
                (.browseNextGroup, 54), (.browsePreviousGroup, 55), (.browseNext, 56), (.browsePrevious, 57),
            ] {
                for number in [n, n + offset] {
                    events.removeAll(); radiusVersionPacket([0x9F, number, 127, number, 127, 0x8F, number, 127], input)
                    #expect(events == [.init(action), .init(action)])
                }
            }
            events.removeAll()
            for ch: UInt8 in 0..<16 {
                radiusVersionPacket(
                    [
                        0xB0 + ch, 53, 65, 54, 65, 56, 65, 114, 65, 116, 65, 117, 65, 119, 65, 0xE0 + ch, 0, 64,
                        0x90 + ch, 38, 127,
                    ], input)
            }
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueRadius2009KeepsOwnJogPitchAndRelativeBrowserFacts() throws {
    try withRadiusVersion(radiusVersions[0]) { input in
        input.currentTargetValue = { _ in 0.5 }
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []; input.onJogAction = { jogs.append(($0, $1)) }
        var events: [(ControllerActionTarget, Double)] = [];
        input.onTargetAction = { if !$0.action.isJog { events.append(($0, $1)) } }
        radiusVersionPacket([0xB0, 53, 64], input); #expect(jogs.isEmpty)
        radiusVersionPacket([0xB0, 53, 65], input); radiusVersionPacket([0xB0, 53, 63], input)
        #expect(
            jogs.map(\.1) == [.relative(1), .relative(-1)]
                && jogs.allSatisfy { $0.0 == .init(.jogA, deck: .a, argument: 1024) })
        radiusVersionPacket([0xE0, 0, 0], input); #expect(events.isEmpty)
        radiusVersionPacket([0xE0, 0, 64], input); radiusVersionPacket([0xE0, 127, 127], input)
        #expect(events.count == 2 && events.allSatisfy { $0.0 == .init(.tempoA, deck: .a) } && events.last?.1 == 0)
        radiusVersionPacket([0x90, 32, 127], input); events.removeAll(); jogs.removeAll()
        radiusVersionPacket([0xB0, 53, 65, 116, 65, 0xE0, 0, 64], input); #expect(events.isEmpty && jogs.isEmpty)
        for (action, n): (ControllerAction, UInt8) in [(.browseGroups, 54), (.browse, 56)] {
            for number in [n, n + 63] {
                events.removeAll(); radiusVersionPacket([0xB0, number, 64], input); #expect(events.isEmpty)
                radiusVersionPacket([0xB0, number, 65], input); radiusVersionPacket([0xB0, number, 63], input)
                #expect(events.map(\.0) == [.init(action), .init(action)] && events[0].1 > 0.5 && events[1].1 < 0.5)
            }
        }
        radiusVersionPacket([0x90, 32, 0], input); events.removeAll()
        radiusVersionPacket([0xE0, 127, 127], input); #expect(events.isEmpty)
        radiusVersionPacket([0xE0, 0, 64], input); #expect(events.count == 1)
    }
}

@Test @MainActor func controllerCatalogueRadiusTAPAndPagingCleanupPreserveOtherSourceOwnership() throws {
    for (index, name) in radiusVersions.enumerated() {
        try withRadiusVersion(name) { input in
            var events: [(ControllerActionTarget, Double)] = [];
            input.onTargetAction = { if !$0.action.isJog { events.append(($0, $1)) } }
            let buttons: [UInt8] = index == 0 ? [32] : index == 1 ? [46, 34] : [32, 46]
            let offset: UInt8 = index == 1 ? 61 : 63
            for n in buttons {
                radiusVersionPacket([0x90, 48, 127], input); radiusVersionPacket([0x90, 48, 127], input, source: 11);
                events.removeAll()
                radiusVersionPacket([0x90, n, 127, n, 0], input)
                if index == 2 {
                    #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
                } else {
                    #expect(events.isEmpty)
                }
                events.removeAll(); radiusVersionPacket([0x80, 48 + offset, 127], input, source: 11)
                #expect(
                    events.map(\.0) == [.init(index == 2 ? .cuePreviewB : .cuePreviewA, deck: index == 2 ? .b : .a)]
                        && events.map(\.1) == [0])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueRadius3000SourceAssignmentsSurviveMIDIChannelChangesAndReassignment() throws {
    try withRadiusVersion(radiusVersions[2]) { input in
        #expect(input.playerDeck(source: 10) == .a && input.playerDeck(source: 11) == .b)
        var events: [ControllerActionTarget] = [];
        input.onTargetAction = { target, _ in
            if target.action == .playA || target.action == .playB { events.append(target) }
        }
        for ch: UInt8 in 0..<16 {
            radiusVersionPacket([0x90 + ch, 42, 127, 42, 0], input);
            radiusVersionPacket([0x90 + ch, 42, 127, 42, 0], input, source: 11)
        }
        #expect(
            events.count == 32 && events.enumerated().allSatisfy { $0.element.deck == ($0.offset % 2 == 0 ? .a : .b) })
        input.setPlayerDeck(.c, source: 10); events.removeAll()
        radiusVersionPacket([0x9F, 42, 127, 42, 0], input);
        radiusVersionPacket([0x95, 42, 127, 42, 0], input, source: 11)
        #expect(events.map(\.deck) == [.c, .b])
    }
}

@Test @MainActor func controllerCatalogueRadiusVersionsRejectUnqualifiedFunctionsGroupsAndSources() throws {
    for (index, name) in radiusVersions.enumerated() {
        try withRadiusVersion(name) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            radiusVersionPacket(
                [
                    0x90, 1, 127, 2, 127, 3, 127, 4, 127, 9, 127, 12, 127, 15, 127, 18, 127, 20, 127, 21, 127, 24, 127,
                    27, 127, 28, 127, 33, 127, 36, 127, 37, 127, 39, 127, 40, 127, 47, 127, 0xB0, 1, 127, 2, 127, 3,
                    127, 4, 127,
                ], input)
            if index == 0 { radiusVersionPacket([0x91, 42, 127, 48, 127, 38, 127, 0xB1, 53, 65, 0xE1, 0, 64], input) }
            radiusVersionPacket([0x90, 42, 127], input, source: 999)
            input.receive(.init(kind: .note, group: 1, channel: 0, number: 42, value: 127), source: 10);
            input.flushPendingActions()
            #expect(events.isEmpty)
        }
    }
}
