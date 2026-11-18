import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func attachScratch(
    _ input: ControllerMIDIConnection, source: Int32 = 10, name: String = "Numark Scratch"
) {
    input.sources = [
        .init(
            id: source, reference: UInt32(source + 90), name: name,
            identity: .init(id: source, device: 1, names: [name]))
    ]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
}

@MainActor private func scratchPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@MainActor private func withScratch(_ body: (ControllerMIDIConnection, UserDefaults) throws -> Void) rethrows {
    let suite = "scratch-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    attachScratch(input)
    try body(input, preferences)
}

@Test @MainActor func controllerCatalogueScratchKeepsMixerAddressesAndSharedPadModes() throws {
    try withScratch { input, _ in
        #expect(input.isInputActive(10))
        let profile = try #require(ControllerFactoryProfile.matching(["Numark Scratch"], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == 45 && data.outputs.isEmpty && data.role == "accessory")
        #expect(data.inputModes?.count == 2 && data.bankChanges?.count == 2)
        #expect(data.startup == [[0x9F, 50, 1], [0xF0, 0, 32, 127, 0, 0xF7]])
        #expect(data.shutdown == [[0xF0, 0, 32, 127, 4, 0xF7]])
        #expect(!data.inputs.contains { [.master, .monitor].contains($0.action) })
        #expect(ControllerFactoryProfile.matching(["Numark Scratch MK2"]) == nil)
    }
}

@Test @MainActor func controllerCatalogueScratchEncoderPulsesDoNotRequireReleaseEdges() {
    withScratch { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        scratchPacket([0x94, 53, 127, 53, 127, 53, 127, 52, 1, 52, 1, 0x84, 53, 127], to: input)
        #expect(targets.map(\.action) == [.loopUpA, .loopUpA, .loopUpA, .loopDownA, .loopDownA])
        targets.removeAll()
        scratchPacket([0x9F, 50, 127, 0x94, 53, 1, 53, 1, 52, 1, 63, 127], to: input)
        #expect(targets == [.init(.browseNext), .init(.browseNext), .init(.browsePrevious), .init(.loadA, deck: .a)])
        targets.removeAll()
        scratchPacket([0x8F, 50, 127, 0x94, 53, 1, 0x95, 63, 127], to: input)
        #expect(targets == [.init(.loopUpA, deck: .a), .init(.loopB, deck: .b)])
    }
}

@Test @MainActor func controllerCatalogueScratchModesAndShiftedReleaseProtectCuePads() {
    withScratch { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        scratchPacket([0x94, 7, 127, 20, 127, 20, 0, 11, 127, 20, 127, 20, 0], to: input)
        #expect(targets.isEmpty)
        scratchPacket(
            [0x94, 0, 127, 20, 127, 0x9F, 50, 127, 0x94, 28, 127, 0x84, 28, 99, 0x8F, 50, 0, 0x94, 20, 127], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a), .init(.hotcue1A, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueScratchHeadphoneReportsApplyLatchedOnAndOffStates() {
    withScratch { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { _ in 0.5 }
        input.onTargetAction = { events.append(($0, $1)) }
        scratchPacket([0x90, 27, 127, 27, 127, 0x91, 27, 127, 0x80, 27, 99], to: input)
        #expect(
            events.map(\.0) == [
                .init(.cueStateA, deck: .a), .init(.cueStateA, deck: .a), .init(.cueStateB, deck: .b),
                .init(.cueStateA, deck: .a),
            ])
        #expect(events.map(\.1) == [1, 1, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueScratchInputSelectorsRearmOnlyTheirSidesMixerPickup() {
    for value in [UInt8(0), 2] {
        withScratch { input, _ in
            var targets: [ControllerActionTarget] = []
            input.currentTargetValue = { [.levelA, .levelB].contains($0.action) ? 0.5 : nil }
            input.onTargetAction = { target, _ in targets.append(target) }
            scratchPacket([0xB0, 28, 64, 0xB1, 28, 64], to: input)
            targets.removeAll()
            scratchPacket([0x9F, 87, value, 0xB0, 28, 127, 0xB1, 28, 127], to: input)
            #expect(targets == [.init(.levelB, deck: .b)])
        }
    }
}

@Test @MainActor func controllerFactoryStartupConnectsReadyInputsBeforeRequestingControllerState() {
    let suite = "startup-order-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var events: [String] = []
    var input: ControllerMIDIConnection!
    input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            #expect(input.isInputActive(10))
            events.append("packet")
            return true
        },
        factoryInputConnector: { source in
            #expect(source == 10 && input.isInputActive(source))
            events.append("input")
            return true
        })
    attachScratch(input)
    #expect(events == ["input", "packet", "packet"])
    var targets: [ControllerActionTarget] = []
    input.onTargetAction = { target, _ in targets.append(target) }
    scratchPacket([0x94, 7, 127, 20, 127], to: input)
    #expect(targets.isEmpty)
    let count = events.count
    input.reconcileFactoryProfiles()
    #expect(events.count == count)
}

@Test @MainActor func controllerFactoryFailedInputConnectionSendsNoSetupAndCanRetry() {
    let suite = "startup-failure-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    var allow = false
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        },
        factoryInputConnector: { _ in allow })
    attachScratch(input)
    #expect(!input.isInputActive(10) && packets.isEmpty)
    allow = true
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && packets.count == 2)
}

@Test @MainActor func controllerFactoryScratchCustomReconnectRetainsModesPulseAndReleaseMetadata() throws {
    try withScratch { input, preferences in
        input.select(10)
        input.learning = .cueA
        scratchPacket([0x90, 100, 127], to: input)
        let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
        attachScratch(restored, source: 11)
        var targets: [ControllerActionTarget] = []
        restored.onTargetAction = { target, _ in targets.append(target) }
        scratchPacket([0x94, 7, 127, 20, 127], to: restored, source: 11)
        #expect(targets.isEmpty)
        scratchPacket([0x94, 53, 1, 53, 1], to: restored, source: 11)
        #expect(targets.map(\.action) == [.loopUpA, .loopUpA])
        targets.removeAll()
        scratchPacket([0x94, 0, 127, 0x9F, 50, 127, 0x94, 28, 127], to: restored, source: 11)
        #expect(targets.isEmpty)
    }
}

@Test @MainActor func controllerFactoryCustomReconnectRetainsExplicitLowBytesAndPhysicalShiftScopes() throws {
    for name in ["Mixtrack Platinum", "MC7000"] {
        let suite = "metadata-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let input = ControllerMIDIConnection(
            preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
        attachScratch(input, name: name)
        input.select(10)
        input.learning = .cueA
        scratchPacket([0x90, 100, 127], to: input)
        let restored = ControllerMIDIConnection(
            preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
        attachScratch(restored, source: 11, name: name)
        var events: [(ControllerActionTarget, Double)] = []
        restored.onTargetAction = { events.append(($0, $1)) }
        if name == "Mixtrack Platinum" {
            scratchPacket([0xB0, 9, 64, 119, 127], to: restored, source: 11)
            #expect(events.count == 1)
            #expect(abs((events.first?.1 ?? 0) - Double(64 * 128 + 127) / 16383) < 0.000001)
        } else {
            scratchPacket([0x90, 50, 127, 0x91, 0, 127], to: restored, source: 11)
            #expect(events.map(\.0) == [.init(.playB, deck: .b)])
            scratchPacket([0x82, 50, 0, 0x90, 0, 127], to: restored, source: 11)
            #expect(events.map(\.0) == [.init(.playB, deck: .b), .init(.playA, deck: .a)])
        }
    }
}

@Test func controllerCataloguePulseSchemaRejectsMomentaryShiftRelativeAndReleaseOnlyInputs() throws {
    let valid: [String: Any] = [
        "action": "loopUpA", "kind": "note", "channel": 4, "number": 53, "encoding": "absolute", "inverted": false,
        "pulse": true,
    ]
    func decode(_ binding: [String: Any]) throws -> ControllerProfileCatalogue {
        let profile: [String: Any] = [
            "id": "pulse fixture", "aliases": ["pulse fixture"], "inputs": [binding], "outputs": [], "startup": [],
            "shutdown": [], "autoSelect": false, "scope": "fixture", "source": "fixture",
        ]
        return try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [profile]]))
    }
    #expect(try decode(valid).profiles.count == 1)
    for (key, value) in [
        ("action", "cuePreviewA" as Any), ("action", "shift" as Any), ("kind", "control" as Any),
        ("encoding", "twosComplement" as Any), ("releaseOnly", true as Any),
    ] {
        var invalid = valid
        invalid[key] = value
        #expect(throws: (any Error).self) { try decode(invalid) }
    }
}
