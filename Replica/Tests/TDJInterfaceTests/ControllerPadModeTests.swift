import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func controllerCataloguePadModesAllowUnknownStartupAndCrossChannelInvalidation() throws {
    let data = Data(#"{"channel":7,"numbers":[56,57,58,59],"invalidatingSelectors":[{"channel":9,"number":56}]}"#.utf8)
    let mode = try JSONDecoder().decode(ControllerProfileData.InputMode.self, from: data)
    #expect(mode.isValid)
    var state = ControllerPadModeState(modes: [mode])
    let binding = ControllerBinding(
        source: 10, group: nil, channel: 7, kind: .note, number: 60,
        parameter: nil, noteNumber: nil, action: .hotcue1A, encoding: .absolute, inverted: false,
        shifted: nil, requiredMode: 56)
    #expect(!state.allows(binding))
    _ = state.receive(.init(kind: .note, channel: 7, number: 56, value: 1))
    #expect(state.allows(binding))
    _ = state.receive(.init(kind: .note, channel: 9, number: 56, value: 0))
    #expect(state.allows(binding))
    _ = state.receive(.init(kind: .note, group: 1, channel: 9, number: 56, value: 127))
    #expect(state.allows(binding))
    _ = state.receive(.init(kind: .note, channel: 9, number: 56, value: 64))
    #expect(!state.allows(binding))
    #expect(!state.isSelected(56, channel: 7))
    _ = state.receive(.init(kind: .note, channel: 7, number: 56, value: 127))
    #expect(state.allows(binding))
}

@MainActor private func withProFXPads(
    sender: @escaping ([UInt8], Int32) -> Bool = { _, _ in true },
    body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "pro-fx-pads-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: sender)
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Mixtrack Pro FX",
            identity: .init(id: 10, device: 1, names: ["Mixtrack Pro FX"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "Mixtrack Pro FX",
            identity: .init(id: 20, device: 1, names: ["Mixtrack Pro FX"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func proFXPadPacket(_ bytes: [UInt8], source: Int32 = 10, to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
}

@Test @MainActor func controllerCataloguePadModesKeepDecksSeparateAndBlockUnsupportedProFXModes() {
    withProFXPads { input in
        var received: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in received.append(target) }
        for mode: UInt8 in [7, 11, 2, 15] {
            proFXPadPacket([0x94, mode, 127, 20, 127, 0x84, 20, 0, mode, 0], to: input)
            #expect(received.isEmpty)
        }
        proFXPadPacket([0x95, 27, 127], to: input)
        #expect(received == [.init(.hotcue8B, deck: .b)])
        proFXPadPacket([0x94, 0, 127, 20, 127], to: input)
        #expect(received.last == .init(.hotcue1A, deck: .a))
        proFXPadPacket([0x94, 28, 127, 35, 127], to: input)
        #expect(received.count == 2)
    }
}

@Test @MainActor func controllerCataloguePadModesRetainReleasesAcrossModeChangesAndRepeatedDiscovery() {
    withProFXPads { input in
        var received: [ControllerAction] = []
        input.onAction = { action, _ in received.append(action) }
        proFXPadPacket([0x94, 20, 127, 13, 127], to: input)
        input.reconcileFactoryProfiles()
        proFXPadPacket([0x84, 20, 0, 0x94, 21, 127], to: input)
        #expect(received == [.hotcue1A, .toggleFixedLoopA])
        proFXPadPacket([0x94, 0, 127, 20, 127], to: input)
        #expect(received == [.hotcue1A, .toggleFixedLoopA, .hotcue1A])
    }
}

@Test @MainActor func controllerCataloguePadModesResetOnReconnectAndSendOnlyPairedModeLights() {
    var packets: [[UInt8]] = []
    withProFXPads(sender: { bytes, destination in
        #expect(destination == 20)
        packets.append(bytes)
        return true
    }) { input in
        var received: [ControllerAction] = []
        input.onAction = { action, _ in received.append(action) }
        proFXPadPacket([0x94, 13, 127], to: input)
        #expect(Array(packets.suffix(6)) == [0, 13, 7, 11, 2, 15].map { [0x94, UInt8($0), $0 == 13 ? 127 : 1] })
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        proFXPadPacket([0x94, 20, 127], to: input)
        #expect(received == [.hotcue1A])
    }
}

@Test @MainActor func controllerCataloguePadModesIgnoreForeignSourcesGroupsAndModeReleases() {
    withProFXPads { input in
        var received: [ControllerAction] = []
        input.onAction = { action, _ in received.append(action) }
        proFXPadPacket([0x94, 13, 127], source: 99, to: input)
        input.receive(.init(kind: .note, group: 1, channel: 4, number: 13, value: 127), source: 10)
        proFXPadPacket([0x84, 13, 0, 0x94, 20, 127], to: input)
        #expect(received == [.hotcue1A])
    }
}

@Test func controllerCataloguePadModesRejectInvalidConfigurationAndUnboundModeRequirements() throws {
    let input: [String: Any] = [
        "action": "hotcue1A", "kind": "note", "channel": 4, "number": 20,
        "encoding": "absolute", "inverted": false, "requiredMode": 0,
    ]
    let valid: [String: Any] = ["channel": 4, "initial": 0, "numbers": [0, 13], "onValue": 127, "offValue": 1]
    func data(_ modes: [[String: Any]], binding: [String: Any] = input) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "mode fixture", "aliases": ["mode fixture"], "inputs": [binding], "outputs": [],
                    "startup": [], "shutdown": [], "autoSelect": true, "scope": "fixture", "source": "fixture",
                    "inputModes": modes,
                ]
            ],
        ])
    }
    #expect(try ControllerProfileCatalogue.decode(data([valid])).profiles.count == 1)
    let inputOnly: [String: Any] = ["channel": 4, "initial": 0, "numbers": [0, 13]]
    #expect(try ControllerProfileCatalogue.decode(data([inputOnly])).profiles.count == 1)
    for key in ["onValue", "offValue"] {
        var incomplete = valid
        incomplete[key] = nil
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data([incomplete])) }
    }
    for (key, value): (String, Any) in [
        ("channel", 16), ("initial", 1), ("numbers", [0, 0]), ("onValue", 128), ("offValue", 128),
    ] {
        var invalid = valid
        invalid[key] = value
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data([invalid])) }
    }
    #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data([valid, valid])) }
    var invalidInput = input
    invalidInput["requiredMode"] = 99
    #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data([valid], binding: invalidInput)) }
    var unknown = inputOnly
    unknown["initial"] = nil
    unknown["invalidatingSelectors"] = [["channel": 6, "number": 0]]
    #expect(try ControllerProfileCatalogue.decode(data([unknown])).profiles.count == 1)
    for selectors: [[String: Int]] in [
        [["channel": 16, "number": 0]], [["channel": 6, "number": 128]],
        [["channel": 6, "number": 0], ["channel": 6, "number": 0]],
        [["channel": 4, "number": 13]], Array(repeating: ["channel": 6, "number": 0], count: 17),
    ] {
        var invalid = unknown; invalid["invalidatingSelectors"] = selectors
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data([invalid])) }
    }
    var other = unknown; other["channel"] = 5
    #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data([unknown, other])) }
    other["invalidatingSelectors"] = [["channel": 4, "number": 0]]
    #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data([unknown, other])) }
}

@Test @MainActor func controllerCatalogueManualPadModesInitialiseRestoreAndSurviveOtherDiscovery() throws {
    let suite = "manual-pad-modes-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let p = try #require(ControllerFactoryProfile.matching(["Vestax VCI-380"]))
    func connection() -> ControllerMIDIConnection {
        let input = ControllerMIDIConnection(preferences: preferences, factoryInputConnector: { _ in true })
        input.sources = [
            .init(
                id: 10, reference: 10, name: "Manual bridge",
                identity: .init(id: 10, device: 10, names: ["Manual bridge"]))
        ]
        input.reconcileFactoryProfiles()
        return input
    }
    let input = connection(); input.select(10); input.applyFactoryProfile(p)
    var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
    func packet(_ bytes: [UInt8], to target: ControllerMIDIConnection) {
        target.receiveBytes(bytes, source: 10); target.flushPendingActions()
    }
    packet([0x97, 60, 127, 60, 0], to: input); #expect(events.isEmpty)
    packet([0x97, 56, 127, 56, 0, 60, 127, 60, 0], to: input)
    #expect(events == [.init(.hotcue1A, deck: .a)])
    input.sources.append(
        .init(
            id: 11, reference: 11, name: "Mixtrack Pro FX",
            identity: .init(id: 11, device: 11, names: ["Mixtrack Pro FX"])))
    input.reconcileFactoryProfiles(); events.removeAll()
    packet([0x97, 60, 127, 60, 0], to: input); #expect(events == [.init(.hotcue1A, deck: .a)])
    let restored = connection(); var restoredEvents: [ControllerActionTarget] = []
    restored.onTargetAction = { target, _ in restoredEvents.append(target) }
    packet([0x97, 60, 127, 60, 0], to: restored); #expect(restoredEvents.isEmpty)
    packet([0x97, 56, 127, 56, 0, 60, 127, 60, 0], to: restored)
    #expect(restoredEvents == [.init(.hotcue1A, deck: .a)])
    restoredEvents.removeAll(); packet([0x99, 56, 127, 56, 0, 0x97, 60, 127, 60, 0], to: restored);
    #expect(restoredEvents.isEmpty)
}

@Test @MainActor func controllerCatalogueManualPadModesResetOnMissingSourceAndUseDocumentedInitialMode() throws {
    let suite = "manual-pad-reset-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryInputConnector: { _ in true })
    let source = ControllerMIDIConnection.Source(
        id: 10, reference: 10, name: "Manual bridge", identity: .init(id: 10, device: 10, names: ["Manual bridge"]))
    input.sources = [source]; input.select(10)
    let p = try #require(ControllerFactoryProfile.matching(["Vestax VCI-380"]))
    input.applyFactoryProfile(p)
    var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
    input.receiveBytes([0x97, 56, 127, 56, 0, 60, 127, 60, 0], source: 10); input.flushPendingActions()
    #expect(events == [.init(.hotcue1A, deck: .a)])
    input.sources = []; input.reconcileFactoryProfiles()
    input.sources = [source]; input.reconcileFactoryProfiles(); events.removeAll()
    input.receiveBytes([0x97, 60, 127, 60, 0], source: 10); input.flushPendingActions(); #expect(events.isEmpty)
    input.receiveBytes([0x97, 56, 127, 56, 0, 60, 127, 60, 0], source: 10); input.flushPendingActions()
    #expect(events == [.init(.hotcue1A, deck: .a)])
    let proFX = try #require(ControllerFactoryProfile.matching(["Mixtrack Pro FX"]))
    input.select(10); input.applyFactoryProfile(proFX); events.removeAll()
    input.receiveBytes([0x94, 20, 127, 20, 0], source: 10); input.flushPendingActions()
    #expect(events == [.init(.hotcue1A, deck: .a)])
}
