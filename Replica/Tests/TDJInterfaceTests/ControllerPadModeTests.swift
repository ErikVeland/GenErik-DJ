import Foundation
import TDJCore
import Testing

@testable import TDJInterface

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

@Test @MainActor func controllerCataloguePadModesKeepDecksSeparateAndBlockEveryOtherProFXMode() {
    withProFXPads { input in
        var received: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in received.append(target) }
        for mode: UInt8 in [13, 7, 11, 2, 15] {
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
        #expect(received == [.hotcue1A])
        proFXPadPacket([0x94, 0, 127, 20, 127], to: input)
        #expect(received == [.hotcue1A, .hotcue1A])
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
}
