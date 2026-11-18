import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let padAccessoryNames = ["DDJ-XP2", "DDJ-XP1", "DDJ-SP1"]

@MainActor private func withPadAccessory(
    _ name: String, decks: [DeckID] = DeckID.allCases, body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "pad-accessory-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func padAccessoryPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCataloguePadAccessoriesRetainTheirRolesAndDoNotAllocatePlayerDecks() throws {
    for name in padAccessoryNames {
        let profile = try #require(ControllerFactoryProfile.matching(["Pioneer DJ " + name], automaticOnly: true))
        #expect(profile.definition?.role == "accessory")
        #expect(
            !profile.bindings(source: 10).contains {
                [.playA, .playB, .tempoA, .tempoB, .levelA, .levelB].contains($0.action)
            })
        withPadAccessory(name) { input in
            #expect(input.isInputActive(10))
            #expect(input.playerDeck(source: 10) == nil)
        }
    }
}

@Test @MainActor func controllerCataloguePadAccessoriesKeepDifferentPhysicalPadLayoutsAndDeckChannels() {
    for name in padAccessoryNames {
        withPadAccessory(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            let numbers: [UInt8] = name == "DDJ-XP2" ? [12, 13, 14, 15, 8, 9, 10, 11] : Array(0...7)
            for (index, deck) in DeckID.allCases.enumerated() {
                let channel = name == "DDJ-SP1" ? index + 7 : index * 2 + 7
                padAccessoryPacket([0x90 | UInt8(channel), numbers[0], 127, numbers[7], 127], to: input)
                #expect(
                    targets.suffix(2) == [
                        .init(index == 0 || index == 2 ? .hotcue1A : .hotcue1B, deck: deck),
                        .init(index == 0 || index == 2 ? .hotcue8A : .hotcue8B, deck: deck),
                    ])
            }
            #expect(targets.count == 8)
        }
    }
}

@Test @MainActor func controllerCataloguePadAccessoriesBlockOtherModesShiftDeleteAndExtraCueSlots() {
    for name in padAccessoryNames {
        withPadAccessory(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            let shiftedChannel: UInt8 = name == "DDJ-SP1" ? 7 : 8
            let shiftedNumber: UInt8 = name == "DDJ-SP1" ? 8 : name == "DDJ-XP2" ? 12 : 0
            padAccessoryPacket(
                [0x97, 16, 127, 28, 127, 32, 127, 48, 127, 0x90 | shiftedChannel, shiftedNumber, 127], to: input)
            #expect(targets.isEmpty)
        }
    }
}

@Test @MainActor func controllerCataloguePadAccessoriesKeepTheirOwnLoopControls() {
    withPadAccessory("DDJ-XP2") { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        padAccessoryPacket([0x90, 20, 127, 16, 127, 17, 127], to: input)
        #expect(
            targets == [.init(.loopA, deck: .a, argument: 4), .init(.loopDownA, deck: .a), .init(.loopUpA, deck: .a)])
    }
    withPadAccessory("DDJ-XP1") { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        padAccessoryPacket([0x91, 16, 127, 17, 127, 20, 127], to: input)
        #expect(
            targets == [.init(.loopInB, deck: .b), .init(.loopOutB, deck: .b), .init(.loopB, deck: .b, argument: 4)])
    }
    withPadAccessory("DDJ-SP1") { input in
        var values: [(ControllerAction, Double)] = []
        input.onAction = { action, value in values.append((action, value)) }
        padAccessoryPacket([0xB0, 23, 127, 0x90, 85, 127], to: input)
        #expect(values.map(\.0) == [.loopSizeA, .loopA])
        #expect(values.first?.1 == 0.5 - 1.0 / 126)
    }
}

@Test @MainActor func controllerCataloguePadAccessoriesFlushBrowseBeforeLoadAndRespectTwoDeckCapacity() {
    for name in padAccessoryNames {
        withPadAccessory(name, decks: DeckID.primary) { input in
            var values: [(ControllerAction, Double)] = []
            input.onAction = { action, value in values.append((action, value)) }
            padAccessoryPacket([0xB6, 64, 3, 0x96, 72, 127, 73, 127, 70, 127], to: input)
            #expect(values.map(\.0) == [.browse, .loadA])
            #expect(values.first?.1 == 0.5 + 3.0 / 126)
        }
    }
}

@Test @MainActor func controllerCataloguePadAccessoriesSendOnlyPublishedConnectMessages() throws {
    for name in padAccessoryNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.definition?.startup == (name == "DDJ-SP1" ? [[0x9B, 9, 127]] : []))
        #expect(profile.definition?.shutdown.isEmpty == true)
    }
}

@Test @MainActor func controllerCataloguePadAccessoriesKeepDimNoteOffFeedbackAndLeavePadLightsOpen() throws {
    for name in padAccessoryNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        let feedback = profile.feedback(destination: 20)
        #expect(!feedback.contains { $0.action.rawValue.hasPrefix("hotcue") })
        let sync = try #require(feedback.first { $0.target == .init(.syncA, deck: .a) })
        #expect(sync.message(value: 1) == [0x90, 88, 127])
        #expect(sync.message(value: 0) == [name == "DDJ-SP1" ? 0x90 : 0x80, 88, 0])
    }
}

@Test func controllerCatalogueAccessoryRoleDoesNotAllowPlayerOnlyAnyChannelBindings() throws {
    for anyChannel in [false, true] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "accessory fixture", "aliases": ["accessory fixture"], "role": "accessory",
                    "inputs": [
                        [
                            "action": "hotcue1A", "kind": "note", "channel": 7, "number": 0,
                            "encoding": "absolute", "inverted": false, "anyChannel": anyChannel,
                        ]
                    ],
                    "outputs": [], "startup": [], "shutdown": [], "autoSelect": true, "scope": "fixture",
                    "source": "fixture",
                ]
            ],
        ])
        if anyChannel {
            #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
        } else {
            #expect(try ControllerProfileCatalogue.decode(data).profiles.count == 1)
        }
    }
}
