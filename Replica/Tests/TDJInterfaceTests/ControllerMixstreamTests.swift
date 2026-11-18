import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixstream(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "mixstream-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "MixstreamPro"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func mixstreamPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueMixstreamKeepsOriginalModelBoundariesAndMixedChannelTargets() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["MixstreamPro"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 36 && data.outputs.count == 6)
    #expect(data.startup.isEmpty && data.shutdown.count == 6)
    #expect(data.scope.contains("Computer Mode"))
    #expect(ControllerFactoryProfile.matching(["Mixstream Pro+"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["Mixstream Pro Go"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["MixstreamPro", "Numark Mixstream Pro+"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["MixstreamPro", "Numark Mixstream Pro Go"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["DDJ-FLX4+"], automaticOnly: true) == nil)
    #expect(!data.inputs.contains { $0.action.hotcueSlot != nil })
    withMixstream { input in
        #expect(input.isInputActive(10))
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        mixstreamPacket([0x92, 10, 127, 0x93, 10, 127, 0x9F, 1, 127, 2, 127, 0x90, 13, 127, 0x91, 13, 127], to: input)
        #expect(
            targets == [
                .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.loadA, deck: .a),
                .init(.loadB, deck: .b), .init(.cueA, deck: .a), .init(.cueB, deck: .b),
            ])
    }
}

@Test @MainActor func controllerCatalogueMixstreamRetainsIndependentCounterAndPitchPairs() {
    withMixstream { input in
        var jogs: [(ControllerActionTarget, Double)] = []
        var tempos: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { target, motion in
            if case .relative(let value) = motion { jogs.append((target, value)) }
        }
        input.onTargetAction = { target, value in
            if [.tempoA, .tempoB].contains(target.action) { tempos.append((target, value)) }
        }
        mixstreamPacket(
            [
                0xB2, 77, 100, 0xB3, 77, 50, 0xB2, 77, 101, 0xB3, 77, 49,
                0xB2, 31, 0, 75, 0, 0xB3, 31, 127, 75, 127,
            ], to: input)
        input.flushPendingActions()
        #expect(jogs.first { $0.0.deck == .a }?.0.argument == 180)
        #expect(jogs.first { $0.0.deck == .a }?.1 == 1)
        #expect(jogs.first { $0.0.deck == .b }?.1 == -1)
        #expect(tempos.first { $0.0.deck == .a }?.1 == 1)
        #expect(tempos.first { $0.0.deck == .b }?.1 == 0)
        jogs.removeAll()
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        mixstreamPacket([0xB2, 77, 102], to: input)
        input.flushPendingActions()
        #expect(jogs.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMixstreamShiftGuardsOnlyItsSideAndKeepsMixerInput() {
    withMixstream { input in
        var actions: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in actions.append(target) }
        mixstreamPacket([0x92, 28, 127, 10, 127, 0x9F, 1, 127, 0x93, 10, 127, 0xB0, 4, 127], to: input)
        input.flushPendingActions()
        #expect(actions == [.init(.playB, deck: .b), .init(.highA, deck: .a)])
        actions.removeAll()
        mixstreamPacket([0x82, 10, 0, 28, 0, 0x92, 10, 127], to: input)
        #expect(actions == [.init(.playA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueMixstreamStructuredCounterCannotUsePartialLearning() {
    withMixstream { input in
        input.select(10)
        input.learning = .jogA
        input.learningEncoding = .mixstreamJog
        mixstreamPacket([0xB2, 55, 1], to: input)
        #expect(input.learning == .jogA)
        #expect(input.factoryProfileName(source: 10) != nil)
        #expect(input.status == "Use the factory profile for this encoding.")
    }
}

@Test func controllerCatalogueMixstreamCounterRejectsAnImplicitLowByte() throws {
    let data = try JSONSerialization.data(withJSONObject: [
        "schemaVersion": 1,
        "profiles": [
            [
                "id": "fixture", "aliases": ["fixture"],
                "inputs": [
                    [
                        "action": "jogA", "kind": "control",
                        "channel": 2, "number": 10, "encoding": "mixstreamJog", "inverted": false, "argument": 180,
                    ]
                ],
                "outputs": [], "startup": [], "shutdown": [], "autoSelect": true, "scope": "fixture",
                "source": "fixture",
            ]
        ],
    ])
    #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
}

@Test func controllerCatalogueMixstreamExcludedAliasesHaveBoundedNames() throws {
    for names in [[""], [String(repeating: "x", count: 129)], Array(repeating: "other", count: 25)] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "fixture", "aliases": ["fixture"], "excludedAliases": names,
                    "inputs": [
                        [
                            "action": "playA", "kind": "note", "channel": 0, "number": 0,
                            "encoding": "absolute", "inverted": false,
                        ]
                    ], "outputs": [], "startup": [], "shutdown": [],
                    "autoSelect": true, "scope": "fixture", "source": "fixture",
                ]
            ],
        ])
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
    }
}
