import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withREV7(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "rev7-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "DDJ-REV7",
            identity: .init(id: id, device: UInt32(id), names: ["DDJ-REV7"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching(["DDJ-REV7"]))
    for source: Int32 in [10, 11] {
        input.select(source)
        input.applyFactoryProfile(profile)
    }
    #expect(input.bindingCount == 140)
    try body(input)
}

@MainActor private func rev7Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test func controllerCatalogueREV7KeepsManualMotorAndSiblingBoundaries() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DDJ-REV7"]))
    let definition = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && definition.inputs.count == 70)
    #expect(definition.outputs.isEmpty && definition.startup.isEmpty && definition.shutdown.isEmpty)
    #expect(definition.audioOutput == nil && definition.inputProtocol == nil)
    #expect(
        !definition.inputs.contains {
            $0.action.isJog || [.cueA, .cueB, .cuePreviewA, .cuePreviewB].contains($0.action)
        })
    for name in ["DDJ-REV1", "DDJ-REV5"] { #expect(ControllerFactoryProfile.matching([name]) != profile) }
    #expect(ControllerFactoryProfile.matching(["DDJ-REV7"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueREV7NormalTransportAndBothCueBanksKeepIndependentAddresses() throws {
    try withREV7 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for channel: UInt8 in [0, 1] {
            let deck: DeckID = channel == 0 ? .a : .b
            for (number, action): (UInt8, ControllerAction) in [
                (11, .playA), (88, .syncA), (26, .keylockA), (69, .tempoResetA), (20, .loopA), (18, .loopDownA),
                (19, .loopUpA),
            ] {
                events.removeAll()
                rev7Packet([0x90 + channel, number, 127, number, 127, 0x80 + channel, number, 127], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for (wire, count): (UInt8, UInt8) in [(2 + channel, 4), (7 + 2 * channel, 8)] {
                for slot in 0..<count {
                    for velocity: UInt8 in [1, 127] {
                        for off: UInt8 in [0x80, 0x90] {
                            events.removeAll()
                            rev7Packet(
                                [0x90 + wire, slot, velocity, slot, velocity, off + wire, slot, off == 0x80 ? 127 : 0],
                                input)
                            #expect(
                                events.count == 1 && events.first?.0.action.hotcueSlot == Int(slot)
                                    && events.first?.0.deck == deck)
                        }
                    }
                }
            }
        }
        events.removeAll()
        rev7Packet([0x96, 70, 127, 70, 0, 71, 127, 71, 0], input)
        #expect(events.map(\.0.action) == [.loadA, .loadB])
    }
}

@Test @MainActor func controllerCatalogueREV7ShiftAndModeChangesRetireHeldBendsWithoutCrossSourceRelease() throws {
    try withREV7 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        rev7Packet([0x90, 57, 127, 0x91, 58, 127], input)
        rev7Packet([0x90, 57, 127], input, source: 11)
        rev7Packet([0x90, 27, 127], input)
        #expect(events.map(\.1) == [1, 1])
        rev7Packet([0x90, 57, 0], input, source: 11)
        #expect(events.last?.0.action == .pitchBendDownA && events.last?.1 == 0)
        rev7Packet([0x96, 63, 127], input)
        #expect(events.last?.0.action == .pitchBendUpB && events.last?.1 == 0)
        events.removeAll()
        rev7Packet([0x90, 89, 127, 89, 0, 0x91, 93, 127, 93, 0, 0x97, 0, 127, 0, 0], input)
        #expect(events.isEmpty)
        rev7Packet([0x96, 63, 0, 0x90, 57, 127, 57, 0], input)
        #expect(events.map(\.1) == [1, 0])
        events.removeAll()
        rev7Packet([0x90, 57, 127, 85, 127], input)
        #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueREV7FourteenBitMixerAndPitchKeepPairingAndDirection() throws {
    try withREV7 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        var wires: [(UInt8, UInt8, ControllerAction, DeckID?)] = []
        for channel: UInt8 in [0, 1] {
            let deck: DeckID = channel == 0 ? .a : .b
            for (number, action): (UInt8, ControllerAction) in [
                (4, .gainA), (7, .highA), (11, .midA), (15, .lowA), (19, .levelA), (0, .tempoA),
            ] {
                wires.append((channel, number, action.assigned(to: deck), deck))
            }
            wires.append((6, 23 + channel, ControllerAction.filterKnobA.assigned(to: deck), deck))
        }
        wires += [(6, 31, .crossfader, nil), (6, 8, .master, nil), (6, 13, .monitor, nil), (6, 12, .cueMix, nil)]
        for (wire, number, action, deck) in wires {
            events.removeAll()
            rev7Packet([0xB0 + wire, number + 32, 127], input)
            #expect(events.isEmpty)
            rev7Packet([0xB0 + wire, number, 64], input)
            rev7Packet([0xB0 + wire, number, 127, number + 32, 127], input)
            #expect(events.first?.1 == 8192.0 / 16383 && events.last?.1 == 1)
            #expect(events.allSatisfy { $0.0 == .init(action, deck: deck) })
        }
        events.removeAll()
        rev7Packet([0xB6, 64, 1], input)
        rev7Packet([0xB6, 64, 127], input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
    }
}

@Test @MainActor func controllerCatalogueREV7UnsupportedMotorSilentCueStateLoopAndOtherModesStayInactive() throws {
    try withREV7 { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { events.append(action) } }
        for channel: UInt8 in [0, 1] {
            rev7Packet([0xB0 + channel, 34, 65, 34, 63, 41, 65, 0x90 + channel, 115, 127, 115, 0], input)
            for value: UInt8 in 0...7 { rev7Packet([0x90 + channel, 35, value], input) }
            for page: UInt8 in [16, 32, 48, 64, 80, 96, 112] {
                rev7Packet([0x97 + 2 * channel, page, 127, page, 0], input)
            }
        }
        #expect(events.isEmpty)
        rev7Packet([0x96, 63, 127, 0x90, 11, 127, 11, 0, 0xB0, 5, 64, 37, 0, 0x96, 63, 0], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueREV7ManualBankRulesSurviveReloadAndClearWithTheirBindings() throws {
    let suite = "rev7-reload-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let first = ControllerMIDIConnection(preferences: preferences)
    first.sources = [
        .init(id: 10, reference: 100, name: "DDJ-REV7", identity: .init(id: 10, device: 1, names: ["DDJ-REV7"]))
    ]
    first.select(10)
    first.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DDJ-REV7"])))
    #expect(preferences.data(forKey: "controllers.factory.manualProfiles.v1") != nil)
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = first.sources
    input.select(10)
    var values: [Double] = []
    input.onAction = { action, value in if action == .pitchBendDownA { values.append(value) } }
    rev7Packet([0x90, 57, 127, 27, 127], input)
    #expect(values == [1, 0])
    input.clearBindings()
    let saved = try #require(preferences.data(forKey: "controllers.factory.manualProfiles.v1"))
    #expect(try JSONDecoder().decode([Int32: ControllerFactoryProfile].self, from: saved).isEmpty)
}

@Test @MainActor func controllerCatalogueREV7ModeButtonReleasePreservesANewHeldBend() throws {
    try withREV7 { input in
        var values: [Double] = []
        input.onAction = { action, value in if action == .pitchBendDownA { values.append(value) } }
        rev7Packet([0x90, 27, 127, 57, 127, 0x80, 27, 127], input)
        #expect(values == [1])
        rev7Packet([0x80, 57, 127], input)
        #expect(values == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueREV7RejectsUnknownOversizedAndExcessManualMetadataWithoutInferringRules()
    throws
{
    let suite = "rev7-bounds-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let first = ControllerMIDIConnection(preferences: preferences)
    first.sources = [
        .init(id: 10, reference: 100, name: "DDJ-REV7", identity: .init(id: 10, device: 1, names: ["DDJ-REV7"]))
    ]
    first.select(10)
    let profile = try #require(ControllerFactoryProfile.matching(["DDJ-REV7"]))
    first.applyFactoryProfile(profile)
    var large = try #require(preferences.data(forKey: "controllers.factory.manualProfiles.v1"))
    large.append(contentsOf: [UInt8](repeating: 32, count: 16_385 - large.count))
    let excess = try JSONEncoder().encode(Dictionary(uniqueKeysWithValues: (0..<65).map { (Int32($0), profile) }))
    for data in [large, excess, Data(#"{"10":"Unknown controller profile"}"#.utf8)] {
        preferences.set(data, forKey: "controllers.factory.manualProfiles.v1")
        let input = ControllerMIDIConnection(preferences: preferences)
        input.sources = first.sources
        input.select(10)
        var values: [Double] = []
        input.onAction = { action, value in if action == .pitchBendDownA { values.append(value) } }
        rev7Packet([0x90, 57, 127, 27, 127], input)
        #expect(values == [1])
        rev7Packet([0x80, 57, 127], input)
        #expect(values == [1, 0])
    }
}
