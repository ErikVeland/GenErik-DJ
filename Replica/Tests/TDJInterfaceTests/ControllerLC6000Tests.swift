import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private func lcEndpoint(_ id: Int32, device: UInt32 = 1, port: String = "LC6000 PR") -> ControllerFactoryEndpoint {
    .init(id: id, device: device, names: ["Denon DJ LC6000 PRIME", port], portNames: [port])
}

@MainActor private func attachLC6000(_ input: ControllerMIDIConnection, first: Int32 = 10) {
    input.sources = [
        .init(id: first, reference: 100, name: "LC6000 PR", identity: lcEndpoint(first)),
        .init(id: first + 1, reference: 101, name: "LC6000 WD", identity: lcEndpoint(first + 1, port: "LC6000 WD")),
        .init(id: first + 2, reference: 102, name: "LC6000 PR", identity: lcEndpoint(first + 2, device: 2)),
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "LC6000 PR", identity: lcEndpoint(20)),
        .init(id: 21, reference: 201, name: "LC6000 WD", identity: lcEndpoint(21, port: "LC6000 WD")),
        .init(id: 22, reference: 202, name: "LC6000 PR", identity: lcEndpoint(22, device: 2)),
    ]
    input.reconcileFactoryProfiles()
}

@MainActor private func lcPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@MainActor private func withLC6000(_ body: (ControllerMIDIConnection, UserDefaults) throws -> Void) rethrows {
    let suite = "lc6000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    attachLC6000(input)
    try body(input, preferences)
}

@Test func controllerFactoryLC6000PairsOnlyExactPRPortsOnTheirOwnDevice() throws {
    let sessions = ControllerFactorySession.discover(
        sources: [lcEndpoint(10), lcEndpoint(11, port: "LC6000 WD"), lcEndpoint(12, device: 2)],
        destinations: [lcEndpoint(20), lcEndpoint(21, port: "LC6000 WD"), lcEndpoint(22, device: 2)], disabled: [])
    #expect(sessions.map(\.source) == [10, 12] && sessions.map(\.destination) == [20, 22])
    for sources in [
        [lcEndpoint(11, port: "LC6000 WD")], [lcEndpoint(10), lcEndpoint(11)],
        [lcEndpoint(10, port: "MIDI 1")],
    ] {
        #expect(
            ControllerFactorySession.discover(sources: sources, destinations: [lcEndpoint(20)], disabled: []).isEmpty)
    }
    #expect(
        ControllerFactorySession.discover(
            sources: [lcEndpoint(10)], destinations: [lcEndpoint(20), lcEndpoint(21)], disabled: []
        ).isEmpty)
    let profile = try #require(sessions.first?.profile)
    #expect(profile.isPlayer && !profile.hasAutomaticSplitOutput)
    #expect(
        ControllerFactorySession.discover(
            sources: [lcEndpoint(10)], destinations: [lcEndpoint(20)], disabled: [profile]
        ).isEmpty)
}

@Test @MainActor func controllerCatalogueLC6000AllocatesIndependentPlayersAndKeepsDirectionStateSeparate() {
    withLC6000 { input, _ in
        #expect(input.playerDeck(source: 10) == .a && input.playerDeck(source: 12) == .b)
        #expect(!input.isInputActive(11))
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var targets: [ControllerActionTarget] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, _ in targets.append(target) }
        lcPacket([0xB0, 54, 1, 55, 0, 54, 3], to: input)
        lcPacket([0xB0, 55, 127, 54, 125], to: input, source: 12)
        lcPacket([0xB0, 54, 1], to: input)
        lcPacket([0xB0, 54, 1], to: input, source: 11)
        #expect(jogs.map { $0.0.deck } == [.a, .b, .a])
        #expect(jogs.map { $0.1 } == [.relative(3), .relative(-2), .relative(1)])
        #expect(jogs.allSatisfy { $0.0.argument == 1024 })
        lcPacket([0x90, 1, 127, 18, 127, 2, 127, 0x80, 2, 127], to: input, source: 12)
        #expect(targets.map(\.action) == [.playB, .loadB, .cuePreviewB, .cuePreviewB])
        #expect(targets.allSatisfy { $0.deck == .b })
    }
}

@Test @MainActor func controllerCatalogueLC6000PadModesAndShiftCannotTriggerAnotherPage() {
    withLC6000 { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if target.action != .shift { targets.append(target) } }
        lcPacket([0x90, 32, 127, 32, 0, 26, 127, 32, 127, 32, 0, 26, 0, 32, 127, 32, 0], to: input)
        #expect(targets.map(\.action) == [.hotcue1A, .hotcue1A])
        targets.removeAll()
        lcPacket([0x90, 28, 127, 32, 127, 32, 0, 29, 127, 32, 127, 32, 0], to: input)
        #expect(targets.isEmpty)
        lcPacket([0x90, 30, 127, 32, 127, 32, 0, 39, 127], to: input)
        #expect(
            targets == [
                .init(.toggleFixedLoopA, deck: .a, argument: 0.125), .init(.toggleFixedLoopA, deck: .a, argument: 16),
            ])
        lcPacket([0x90, 32, 127], to: input, source: 12)
        #expect(targets.last == .init(.hotcue1B, deck: .b))
    }
}

@Test @MainActor func controllerCatalogueLC6000ReassignmentAndDisconnectReleaseOwnedContacts() {
    withLC6000 { input, _ in
        var contacts: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if target.action.isMomentary { contacts.append((target, value)) } }
        lcPacket([0x90, 40, 127, 24, 127], to: input)
        input.setPlayerDeck(.b, source: 10)
        #expect(contacts.filter { $0.1 == 0 }.map { $0.0.action }.contains(.jogTouchA))
        #expect(contacts.filter { $0.1 == 0 }.map { $0.0.action }.contains(.pitchBendDownA))
        contacts.removeAll()
        lcPacket([0x90, 40, 127], to: input)
        #expect(contacts.first?.0 == .init(.jogTouchB, deck: .b))
        input.sources = []
        input.reconcileFactoryProfiles()
        #expect(contacts.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueLC6000CustomReconnectRetainsDirectionAndPadMetadata() {
    withLC6000 { input, preferences in
        input.select(10)
        input.learning = .cueA
        lcPacket([0x90, 100, 127], to: input)
        let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
        attachLC6000(restored, first: 30)
        var jogs: [ControllerMIDIValue] = []
        var actions: [ControllerAction] = []
        restored.onJogAction = { _, value in jogs.append(value) }
        restored.onTargetAction = { target, _ in actions.append(target.action) }
        lcPacket([0xB0, 55, 127, 54, 126], to: restored, source: 30)
        #expect(jogs == [.relative(-1)])
        lcPacket([0x90, 28, 127, 32, 127], to: restored, source: 30)
        #expect(actions.isEmpty)
    }
}

@Test func controllerFactoryLC6000RejectsEmptyOrExcessivePortAliases() throws {
    for aliases in [[], [""], Array(repeating: "PR", count: 17)] as [[String]] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "fixture", "aliases": ["fixture"], "portAliases": aliases,
                    "inputs": [
                        [
                            "action": "playA", "kind": "note", "channel": 0, "number": 1,
                            "encoding": "absolute", "inverted": false,
                        ]
                    ],
                    "outputs": [], "startup": [], "shutdown": [], "autoSelect": true,
                    "scope": "fixture", "source": "fixture",
                ]
            ],
        ])
        #expect(throws: Error.self) { try ControllerProfileCatalogue.decode(data) }
    }
}
