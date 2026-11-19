import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let terminalMixNames = ["Terminal Mix 4", "Terminal Mix 2"]

@MainActor private func withTerminalMix(_ name: String, body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "terminal-mix-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func terminalMixPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueTerminalMixPreservesTheSharedRecipeIdentityAndExactModelAliases() throws {
    for name in terminalMixNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.rawValue == "Reloop Terminal Mix 2/4")
        #expect(profile.definition?.startup.isEmpty == true)
        #expect(profile.feedback(destination: 20).count == 48)
        #expect(profile.definition?.shutdown.count == 16)
    }
    #expect(ControllerFactoryProfile(rawValue: "Reloop Terminal Mix 2/4") != nil)
    #expect(ControllerFactoryProfile.matching(["TerminalMix"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueTerminalMixPreservesFourDeckTargetsWithoutEnablingTheTrial() {
    for name in terminalMixNames {
        withTerminalMix(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            terminalMixPacket([0x90, 37, 127, 0x93, 37, 127, 50, 127, 0x92, 48, 127], to: input)
            #expect(
                targets == [
                    .init(.playA, deck: .a), .init(.playB, deck: .d), .init(.loadB, deck: .d), .init(.cueA, deck: .c),
                ])
        }
    }
}

@Test @MainActor func controllerCatalogueTerminalMixRetainsTheExactPitchCentreAndCrossfaderDetent() {
    for name in terminalMixNames {
        withTerminalMix(name) { input in
            var values: [(ControllerAction, Double)] = []
            input.onAction = { action, value in values.append((action, value)) }
            for bytes: [UInt8] in [[0xE0, 0, 0], [0xE0, 0, 64], [0xE0, 127, 127]] {
                terminalMixPacket(bytes, to: input)
                input.flushPendingActions()
            }
            #expect(values.filter { $0.0 == .tempoA }.map(\.1) == [0, 0.5, 1])
            for raw: UInt8 in [0, 63, 64, 127] {
                terminalMixPacket([0xB0, 58, raw], to: input)
                input.flushPendingActions()
            }
            #expect(values.filter { $0.0 == .crossfader }.map(\.1) == [0, 63.0 / 127, 0.5, 1])
        }
    }
}

@Test @MainActor func controllerCatalogueTerminalMixUsesStrictLoopStepsAndFullBrowserCounts() {
    for name in terminalMixNames {
        withTerminalMix(name) { input in
            var values: [(ControllerAction, Double)] = []
            input.onAction = { action, value in values.append((action, value)) }
            terminalMixPacket([0xB0, 11, 0, 11, 64, 11, 127, 11, 66], to: input)
            #expect(values.isEmpty)
            terminalMixPacket([0xB0, 11, 65, 11, 63, 57, 66, 0x90, 50, 127], to: input)
            #expect(values.map(\.0) == [.loopSizeA, .loopSizeA, .browse, .loadA])
            #expect(values[0].1 == 0.5 + 1.0 / 126)
            #expect(values[1].1 == 0.5 - 1.0 / 126)
            #expect(values[2].1 == 0.5 + 2.0 / 126)
        }
    }
}

@Test @MainActor func controllerCatalogueTerminalMixRetainsTouchAndBothJogMessagesAndEightCueAddresses() {
    for name in terminalMixNames {
        withTerminalMix(name) { input in
            var values: [(ControllerAction, Double)] = []
            input.onAction = { action, value in values.append((action, value)) }
            terminalMixPacket([0x90, 40, 127, 16, 127, 27, 127, 86, 127, 0xB0, 39, 65], to: input)
            input.flushPendingActions()
            #expect(values.map(\.0) == [.jogTouchA, .hotcue1A, .hotcue8A, .clearHotcue1A, .jogA])
            #expect(values.last?.1 == 0.625)
            terminalMixPacket([0xB0, 40, 63], to: input)
            input.flushPendingActions()
            #expect(values.last?.1 == 0.375)
            terminalMixPacket([0x80, 40, 0], to: input)
            #expect(values.last?.0 == .jogTouchA)
            #expect(values.last?.1 == 0)
        }
    }
}

@Test func controllerCatalogueTerminalMixRejectsWrongEncodingKindsAndRetainsRelativeMetadata() throws {
    #expect(ControllerMIDIEncoding.binaryStep.isRelative)
    #expect(!ControllerMIDIEncoding.centreDetent.isRelative)
    #expect(!ControllerMIDIEncoding.centredPitch.isRelative)
    for (encoding, kind, number) in [
        ("centredPitch", "control", 0), ("centredPitch", "pitch", 7), ("centreDetent", "pitch", 0),
        ("binaryStep", "note", 11),
    ] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "invalid", "aliases": ["invalid"],
                    "inputs": [
                        [
                            "action": "tempoA", "kind": kind, "channel": 0, "number": number,
                            "encoding": encoding, "inverted": false,
                        ]
                    ],
                    "outputs": [], "startup": [], "shutdown": [], "autoSelect": true, "scope": "fixture",
                    "source": "fixture",
                ]
            ],
        ])
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
    }
}

@Test @MainActor func controllerCatalogueTerminalMixPreservesSavedFamilyDisableAndCustomMappingPreferences() throws {
    let suite = "terminal-mix-preferences-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let legacy = "Reloop Terminal Mix 2/4"
    let profile = try #require(ControllerFactoryProfile(rawValue: legacy))
    preferences.set([legacy], forKey: "controllers.factory.disabled")
    let disabled = ControllerMIDIConnection(preferences: preferences)
    disabled.sources = [
        .init(
            id: 10, reference: 100, name: "Terminal Mix 4",
            identity: .init(id: 10, device: 1, names: ["Terminal Mix 4"]))
    ]
    disabled.reconcileFactoryProfiles()
    #expect(!disabled.isInputActive(10))
    preferences.removeObject(forKey: "controllers.factory.disabled")
    var custom = try #require(profile.bindings(source: 10).first { $0.action == .playA && $0.targetDeck == .a })
    custom.action = .syncA
    preferences.set(try JSONEncoder().encode([legacy: [custom]]), forKey: "controllers.factory.customInputs")
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = disabled.sources
    input.reconcileFactoryProfiles()
    var actions: [ControllerAction] = []
    input.onAction = { action, _ in actions.append(action) }
    terminalMixPacket([0x90, 37, 127], to: input)
    #expect(actions == [.syncA])
}
