import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withLegacyPioneerTransport(
    _ name: String, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "legacy-pioneer-transport-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("These input sessions must not send hardware writes.")
            return false
        })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    if name == "DJM-T1" {
        #expect(!input.isInputActive(10))
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
        #expect(input.bindingCount == 120)
    } else {
        #expect(input.isInputActive(10) && input.isInputActive(11))
        #expect(profile.bindings(source: 10).count == 26)
    }
    try body(input)
}

@MainActor private func legacyPioneerPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueLegacyPioneerT1ReleasesHeldCueAcrossAllThreeWireLayers() throws {
    try withLegacyPioneerTransport("DJM-T1") { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if target.action.isMomentary { events.append((target, value)) } }
        for (index, deck) in DeckID.primary.enumerated() {
            for release: UInt8 in [UInt8(11 + index), UInt8(75 + index), UInt8(125 + index)] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    legacyPioneerPacket([0x90, UInt8(11 + index), 127, UInt8(11 + index), 127], input)
                    legacyPioneerPacket([off, release, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
                    events.removeAll()
                    legacyPioneerPacket(
                        [
                            0x90, UInt8(75 + index), 127, UInt8(75 + index), 0, UInt8(125 + index), 127,
                            UInt8(125 + index), 0,
                        ], input)
                    #expect(events.isEmpty)
                }
            }
        }
        events.removeAll()
        legacyPioneerPacket([0x90, 11, 127], input)
        legacyPioneerPacket([0x90, 11, 127], input, source: 11)
        legacyPioneerPacket([0x80, 75, 127], input)
        #expect(events.map(\.1) == [1])
        legacyPioneerPacket([0x80, 125, 127], input, source: 11)
        #expect(events.map(\.1) == [1, 0])
        legacyPioneerPacket([0x90, 12, 127], input)
        input.stop()
        #expect(events.suffix(2).map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueLegacyPioneerT1AllMixerLayersKeepPickupAndNativeOwnership() throws {
    try withLegacyPioneerTransport("DJM-T1") { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (index, deck) in DeckID.primary.enumerated() {
            for layer in [0, 64, 76] {
                for (base, action): (Int, ControllerAction) in [
                    (13, .gainA), (15, .highA), (17, .midA), (19, .lowA), (21, .levelA),
                ] {
                    events.removeAll()
                    let number = UInt8(base + index + layer)
                    legacyPioneerPacket([0xB0, number, 0], input)
                    #expect(events.isEmpty)
                    legacyPioneerPacket([0xB0, number, 64], input)
                    legacyPioneerPacket([0xB0, number, 127], input)
                    #expect(events.map(\.1) == [64.0 / 127, 1])
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueLegacyPioneerT1PadsLoopsLibraryAndInactiveFunctionsStayDistinct() throws {
    try withLegacyPioneerTransport("DJM-T1") { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (index, deck) in DeckID.primary.enumerated() {
            for slot in 0..<4 {
                let note = UInt8(27 + 2 * index + 4 * slot)
                legacyPioneerPacket([0x90, note, 127, note, 127, note, 0], input)
                #expect(events.last?.0.action.hotcueSlot == slot && events.last?.0.deck == deck)
            }
            events.removeAll()
            for n in [1 + index, 3 + index, 5 + index, 47 + index, 21 + 2 * index] {
                legacyPioneerPacket([0x90, UInt8(n), 127, UInt8(n), 127, UInt8(n), 0], input)
            }
            #expect(
                events.map(\.0.action)
                    == [ControllerAction.loadA, .playA, .syncA, .cueA, .loopA].map { $0.assigned(to: deck) })
            events.removeAll()
            for value: UInt8 in [0, 1, 30, 127, 98] { legacyPioneerPacket([0xB0, UInt8(9 + 2 * index), value], input) }
            #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 + 30.0 / 126, 0.5 - 1.0 / 126, 0.5 - 30.0 / 126])
            #expect(events.allSatisfy { $0.0.deck == deck })
        }
        events.removeAll()
        for number: UInt8 in [0, 64] {
            for value: UInt8 in [0, 1, 127] { legacyPioneerPacket([0xB0, number, value], input) }
            legacyPioneerPacket([0x90, number, 127, number, 0], input)
        }
        #expect(events.map(\.0.action) == [.browse, .browse, .openGroup, .browseGroups, .browseGroups, .openGroup])
        events.removeAll()
        for number: UInt8 in [1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 23, 24, 27, 28, 29, 87, 88, 99, 100] {
            legacyPioneerPacket([0xB0, number, 64, number, 127], input)
        }
        for number: UInt8 in [22, 24, 25, 26, 65, 66, 67, 68, 69, 70, 89, 90, 91, 93, 95, 97, 99, 101, 103, 105] {
            legacyPioneerPacket([0x90, number, 127, number, 0], input)
        }
        legacyPioneerPacket([0x91, 3, 127, 3, 0], input)
        legacyPioneerPacket([0x90, 3, 127, 3, 0], input, source: 99)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueLegacyPioneerT1BaseLampsStayBoundedAndManual() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJM-T1"]))
    #expect(!profile.selectsAutomatically && profile.definition?.audioOutput == nil)
    let lamps = profile.feedback(destination: 20)
    #expect(lamps.count == 14)
    #expect(Set(lamps.map(\.number)) == [3, 4, 5, 6, 11, 12, 27, 29, 31, 33, 35, 37, 39, 41])
    for lamp in lamps {
        #expect(lamp.message(value: 1) == [0x90, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90, lamp.number, 0])
    }
    #expect(profile.definition?.startup.isEmpty == true && profile.definition?.shutdown.isEmpty == true)
    #expect(ControllerFactoryProfile.matching(["DDJ-T1"]) != profile)
}

@Test @MainActor func controllerCatalogueLegacyPioneerMEPSpeedPitchAndLibraryUseTheirOwnPublishedScale() throws {
    try withLegacyPioneerTransport("MEP-7000") { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in events.append((target, value)) }
        for (channel, deck) in [(UInt8(0), DeckID.a), (1, .b)] {
            events.removeAll()
            for value: UInt8 in [64, 65, 63, 127, 0] { legacyPioneerPacket([0xB0 + channel, 16, value], input) }
            #expect(events.map(\.1) == [0.5, 0.5 + 0.5 / 63, 0.5 - 0.5 / 64, 1, 0])
            #expect(events.allSatisfy { $0.0 == .init(ControllerAction.jogA.assigned(to: deck), deck: deck) })
            events.removeAll()
            legacyPioneerPacket([0xB0 + channel, 29, 0], input)
            #expect(events.isEmpty)
            for value: UInt8 in [64, 127, 0] { legacyPioneerPacket([0xB0 + channel, 29, value], input) }
            #expect(events.map(\.1) == [0.5, 1, 0])
            #expect(events.allSatisfy { $0.0.action == ControllerAction.tempoA.assigned(to: deck) })
        }
        events.removeAll()
        legacyPioneerPacket([0x90, 52, 127, 52, 127, 52, 0, 53, 127, 53, 0, 51, 127, 51, 0], input)
        #expect(events.map(\.0.action) == [.loadA, .loadB, .openGroup])
        events.removeAll()
        for value: UInt8 in [0, 1, 30, 127, 98] { legacyPioneerPacket([0xB0, 79, value], input) }
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 + 30.0 / 126, 0.5 - 1.0 / 126, 0.5 - 30.0 / 126])
        #expect(events.allSatisfy { $0.0.action == .browse })
    }
}

@Test @MainActor func controllerCatalogueLegacyPioneerMEPTransportAndMomentaryContactsCleanUpPerSource() throws {
    try withLegacyPioneerTransport("MEP-7000") { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (channel, deck) in [(UInt8(0), DeckID.a), (1, .b)] {
            for (number, action): (UInt8, ControllerAction) in [
                (0, .playA), (6, .loopInA), (7, .loopOutA), (8, .reloopA), (17, .keylockA),
            ] {
                events.removeAll()
                legacyPioneerPacket([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events.map(\.0.action) == [action.assigned(to: deck)])
            }
            for (number, action): (UInt8, ControllerAction) in [
                (1, .cuePreviewA), (20, .pitchBendUpA), (21, .pitchBendDownA), (32, .jogTouchA),
            ] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    legacyPioneerPacket(
                        [0x90 + channel, number, 127, number, 127, off + channel, number, off == 0x80 ? 127 : 0], input)
                    #expect(
                        events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.action == action.assigned(to: deck) })
                }
            }
        }
        events.removeAll()
        legacyPioneerPacket([0x90, 1, 127, 20, 127], input)
        legacyPioneerPacket([0x90, 1, 127], input, source: 11)
        input.sources.removeAll { $0.id == 10 }
        input.reconcileFactoryProfiles()
        #expect(events.filter { $0.0.action == .cuePreviewA }.map(\.1) == [1])
        #expect(events.filter { $0.0.action == .pitchBendUpA }.map(\.1) == [1, 0])
        input.stop()
        #expect(events.filter { $0.0.action == .cuePreviewA }.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueLegacyPioneerMEPUnmappedModesAndSiblingModelsStayInactive() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["MEP-7000"], automaticOnly: true))
    #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.audioOutput == nil)
    #expect(profile.definition?.startup.isEmpty == true && profile.definition?.shutdown.isEmpty == true)
    for name in ["SEP-C1", "CDJ-700", "CDJ-2000", "MEP-7000 clone"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
    try withLegacyPioneerTransport("MEP-7000") { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, value in if !(action.isJog && value == 0.5) { actions.append(action) } }
        for channel: UInt8 in [0, 1] {
            for number: UInt8 in [2, 3, 4, 5, 10, 11, 14, 16, 18, 19, 49, 50, 54, 55, 56, 57, 58, 59, 60, 61, 62] {
                legacyPioneerPacket([0x90 + channel, number, 127, number, 0], input)
            }
        }
        legacyPioneerPacket([0x92, 0, 127, 0, 0, 0xB2, 16, 127, 29, 64, 0xF8, 0xFA, 0xFC], input)
        legacyPioneerPacket([0x90, 0, 127, 0, 0], input, source: 99)
        #expect(actions.isEmpty)
    }
}
