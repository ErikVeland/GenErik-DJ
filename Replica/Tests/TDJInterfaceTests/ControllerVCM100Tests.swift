import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withVCM100(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "vcm100-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "Vestax PC-CONTROLLER",
            identity: .init(id: id, device: UInt32(id), names: ["Vestax PC-CONTROLLER"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching(["VCM-100"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    #expect(input.bindingCount == 144)
    try body(input)
}

@MainActor private func vcm100Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueVCM100BothChannelsContainBothProgramDecks() throws {
    try withVCM100 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if !target.action.isJog { events.append((target, value)) }
        }
        for channel: UInt8 in [0, 1] {
            for (side, deck) in DeckID.primary.enumerated() {
                let side = UInt8(side)
                for (number, action): (UInt8, ControllerAction) in [
                    (50 + 4 * side, .playA), (53 + 4 * side, .cueSetA), (72 + side, .cueA), (70 + side, .syncA),
                    (66 + side, .loopA), (96 + side, .loadA),
                ] {
                    events.removeAll()
                    vcm100Packet([0x90 + channel, number, 127, number, 127, number, 0], input)
                    #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
                }
                for number: UInt8 in [52 + 4 * side, 78 + 2 * side, 79 + 2 * side] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll()
                        vcm100Packet(
                            [0x90 + channel, number, 127, number, 127, off + channel, number, off == 0x80 ? 127 : 0],
                            input)
                        #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueVCM100ChannelAndSourceHoldsRemainIndependentUntilStop() throws {
    try withVCM100 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if !target.action.isJog { events.append((target, value)) }
        }
        vcm100Packet([0x90, 52, 127, 0x81, 52, 127], input)
        #expect(events.map(\.1) == [1])
        vcm100Packet([0x91, 52, 127], input)
        vcm100Packet([0x90, 52, 127], input, source: 11)
        vcm100Packet([0x80, 52, 127, 0x81, 52, 127], input)
        #expect(events.map(\.1) == [1])
        vcm100Packet([0x80, 52, 127], input, source: 11)
        #expect(events.map(\.1) == [1, 0])
        vcm100Packet([0x91, 56, 127, 81, 127], input)
        input.stop()
        #expect(events.suffix(2).allSatisfy { $0.0.deck == .b && $0.1 == 0 })
    }
}

@Test @MainActor func controllerCatalogueVCM100RotaryLevelsAndSoundControlsUseTheirOwnNumbers() throws {
    try withVCM100 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in events.append((target, value)) }
        for channel: UInt8 in [0, 1] {
            for (side, deck) in DeckID.primary.enumerated() {
                let side = UInt8(side)
                for (number, action): (UInt8, ControllerAction) in [
                    (12 + side, .levelA), (14 + side, .tempoA), (20 + 4 * side, .highA), (21 + 4 * side, .midA),
                    (23 + 4 * side, .lowA), (28 + side, .gainA),
                ] {
                    events.removeAll()
                    vcm100Packet([0xB0 + channel, number, 64], input)
                    vcm100Packet([0xB0 + channel, number, 127], input)
                    #expect(
                        events.count == 2 && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    #expect(events.last?.1 == (action == .tempoA ? 0 : 1))
                }
            }
            for (number, action): (UInt8, ControllerAction) in [
                (7, .master), (8, .crossfader), (88, .monitor), (89, .cueMix),
            ] {
                events.removeAll()
                vcm100Packet([0xB0 + channel, number, 64], input)
                vcm100Packet([0xB0 + channel, number, 127], input)
                #expect(events.map(\.0.action) == [action, action] && events.last?.1 == 1)
            }
            events.removeAll()
            vcm100Packet([0x90 + channel, 92, 127, 92, 0, 93, 127, 93, 0], input)
            #expect(events.map(\.0.action) == [.browsePrevious, .browseNext])
        }
    }
}

@Test @MainActor func controllerCatalogueVCM100GenericIdentityCentreNotesAndUnqualifiedFunctionsStayInactive() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["VCM-100"]))
    let definition = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && definition.inputs.count == 72)
    #expect(
        definition.outputs.isEmpty && definition.startup.isEmpty && definition.shutdown.isEmpty
            && definition.audioOutput == nil)
    for name in ["Vestax PC-CONTROLLER", "Vestax PC CONTROLLER", "Vestax VCM-600", "VCM100 clone"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    try withVCM100 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        for channel: UInt8 in [0, 1] {
            for number: UInt8 in [12, 13, 14, 15, 17, 18, 19, 21, 22, 23, 24, 25, 26, 51, 55, 74, 75, 76, 77, 94] {
                vcm100Packet([0x90 + channel, number, 127, number, 0], input)
            }
            vcm100Packet([0xB0 + channel, 30, 127, 31, 127], input)
        }
        vcm100Packet([0x92, 50, 127, 50, 0, 54, 127, 54, 0, 0xB2, 12, 127, 13, 127], input)
        #expect(actions.isEmpty)
    }
}

@Test func controllerCatalogueVCM100HoldIdentitiesAreBoundedAndOnlyApplyToMomentaryActions() throws {
    for (action, identity, valid) in [
        ("cuePreviewA", 0, true), ("pitchBendUpA", 127, true),
        ("cuePreviewA", 128, false), ("playA", 0, false), ("shift", 0, false),
    ] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "fixture", "aliases": ["fixture"], "autoSelect": false,
                    "scope": "fixture", "source": "fixture", "outputs": [], "startup": [], "shutdown": [],
                    "inputs": [
                        [
                            "action": action, "kind": "note", "channel": 0, "number": 52,
                            "encoding": "absolute", "inverted": false, "holdInput": identity,
                        ]
                    ],
                ]
            ],
        ])
        if valid {
            _ = try ControllerProfileCatalogue.decode(data)
        } else {
            #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
        }
    }
}
