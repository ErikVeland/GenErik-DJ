import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let entryPioneerNames = ["DDJ-SB2", "DDJ-SB", "DDJ-RB", "DDJ-RR", "DDJ-200", "DDJ-WeGO4"]

@MainActor private func withEntryPioneer(_ name: String, body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "entry-pioneer-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func entryPioneerPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerEntryPioneerMatchesModelsAndPreservesMissingHardwareControls() throws {
    for name in entryPioneerNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        let targets = Set(profile.bindings(source: 10).compactMap(\.targetDeck))
        #expect(targets == Set(name == "DDJ-SB2" || name == "DDJ-RR" ? DeckID.allCases : DeckID.primary))
    }
    let small = try #require(ControllerFactoryProfile.matching(["DDJ-200"]))
    #expect(
        !small.bindings(source: 10).contains {
            [.loadA, .loadB, .browse, .loopA, .keylockA, .gainA].contains($0.action)
        })
    let wego = try #require(ControllerFactoryProfile.matching(["DDJ-WeGO4"]))
    #expect(!wego.bindings(source: 10).contains { [.midA, .midB, .gainA, .keylockA].contains($0.action) })
    for name in ["DDJ-SB2 clone", "DDJ-RR clone", "DDJ-WeGO4 clone"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
}

@Test @MainActor func controllerEntryPioneerInitialisesOnlyDocumentedConnectedMessages() {
    for name in entryPioneerNames {
        let suite = "entry-startup-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var packets: [[UInt8]] = []
        let input = ControllerMIDIConnection(
            preferences: preferences,
            factoryPacketSender: { bytes, destination in
                #expect(destination == 20)
                packets.append(bytes)
                return true
            })
        input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
        input.destinations = [
            .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))
        ]
        input.reconcileFactoryProfiles()
        #expect(input.isInputActive(10))
        #expect(packets == (["DDJ-SB", "DDJ-SB2", "DDJ-RR"].contains(name) ? [[0x9B, 9, 127]] : []))
        input.reconcileFactoryProfiles()
        #expect(packets.count <= 1)
    }
}

@Test @MainActor func controllerEntryPioneerRoutesTheDocumentedPadAndDeckLayouts() {
    for name in entryPioneerNames {
        withEntryPioneer(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            let decks = name == "DDJ-SB2" || name == "DDJ-RR" ? DeckID.allCases : DeckID.primary
            for (channel, deck) in zip(UInt8(0)..<4, decks) {
                let wego = name == "DDJ-WeGO4"
                let pad = wego ? channel : 7 + (name == "DDJ-200" ? 2 * channel : channel)
                let number: UInt8 = wego ? 49 : name == "DDJ-SB" || name == "DDJ-SB2" ? 67 : 7
                entryPioneerPacket([0x90 | channel, 11, 127, 0x90 | pad, number, 127], to: input)
                let play: ControllerAction = deck.leftSide ? .playA : .playB
                let cue: ControllerAction =
                    wego ? (deck.leftSide ? .hotcue4A : .hotcue4B) : (deck.leftSide ? .hotcue8A : .hotcue8B)
                #expect(Array(targets.suffix(2)) == [.init(play, deck: deck), .init(cue, deck: deck)])
            }
            #expect(targets.count == 2 * decks.count)
        }
    }
}

@Test @MainActor func controllerEntryPioneerVinylOffTouchOnlyReleasesAnExistingScratch() {
    for name in ["DDJ-SB", "DDJ-SB2"] {
        withEntryPioneer(name) { input in
            var received: [Double] = []
            input.onTargetAction = { target, value in if target.action == .jogTouchA { received.append(value) } }
            entryPioneerPacket([0x90, 54, 127, 53, 127, 0x80, 53, 0, 0x90, 53, 127, 0x80, 53, 0], to: input)
            #expect(received == [1, 0])
        }
    }
}

@Test @MainActor func controllerEntryPioneerWeGO4UsesGlobalMixerPairsAndSeparateLoopLights() throws {
    withEntryPioneer("DDJ-WeGO4") { input in
        var values: [ControllerActionTarget: Double] = [:]
        input.onTargetAction = { target, value in values[target] = value }
        entryPioneerPacket([0xB6, 8, 127, 40, 127, 21, 127, 53, 127, 0x96, 85, 127], to: input)
        input.flushPendingActions()
        #expect(values == [.init(.highB, deck: .b): 1, .init(.levelB, deck: .b): 1, .init(.cueB, deck: .b): 1])
    }
    let profile = try #require(ControllerFactoryProfile.matching(["DDJ-WeGO4"]))
    let outputs = profile.feedback(destination: 20)
    #expect(outputs.contains { $0.action == .loopB && $0.channel == 11 && $0.number == 17 })
    #expect(outputs.contains { $0.action == .cueB && $0.channel == 6 && $0.number == 85 })
    #expect(outputs.contains { $0.action == .hotcue4B && $0.channel == 1 && $0.number == 49 })
}

@Test @MainActor func controllerEntryPioneerSBManualLoopPadsUseTheirOwnMessages() {
    for name in ["DDJ-SB", "DDJ-SB2"] {
        withEntryPioneer(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            entryPioneerPacket([0x98, 32, 127, 33, 127, 34, 127], to: input)
            #expect(targets == [.init(.loopInB, deck: .b), .init(.loopOutB, deck: .b), .init(.reloopB, deck: .b)])
        }
    }
}

@Test func controllerEntryPioneerAcceptsButtonReleaseAliasesAndRejectsInvalidKinds() throws {
    let base: [String: Any] = [
        "action": "jogTouchA", "kind": "note", "channel": 0, "number": 53, "encoding": "absolute", "inverted": false,
        "releaseOnly": true,
    ]
    func data(_ input: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "release fixture", "aliases": ["release fixture"], "inputs": [input], "outputs": [],
                    "startup": [], "shutdown": [], "autoSelect": false, "scope": "Protocol fixture",
                    "source": "manufacturer",
                ]
            ],
        ])
    }
    #expect(try ControllerProfileCatalogue.decode(data(base)).profiles.count == 1)
    for action in ["playA", "hotcue1A"] {
        let button = base.merging(["action": action]) { _, value in value }
        #expect(try ControllerProfileCatalogue.decode(data(button)).profiles.count == 1)
    }
    for mutation in [["action": "levelA"], ["action": "shift"], ["kind": "control"]] {
        let invalid = base.merging(mutation) { _, value in value }
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data(invalid)) }
    }
}
