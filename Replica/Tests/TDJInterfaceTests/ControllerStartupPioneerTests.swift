import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let startupPioneerNames = ["DDJ-SX", "DDJ-SX2", "DDJ-RX", "DDJ-RZ", "DDJ-RZX", "DDJ-SZ", "DDJ-SZ2"]

@MainActor private func withStartupPioneer(
    _ name: String, sender: @escaping ([UInt8], Int32) -> Bool, body: (ControllerMIDIConnection) -> Void
) {
    let suite = "startup-pioneer-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: sender)
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [
        .init(id: 30, reference: 300, name: name, identity: .init(id: 30, device: 2, names: [name])),
        .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name])),
    ]
    input.reconcileFactoryProfiles()
    body(input)
}

@Test @MainActor func controllerStartupPioneerConnectsOnlyThePairedDeviceOnceAndRepeatsAfterReconnect() {
    for name in startupPioneerNames {
        var packets: [[UInt8]] = []
        withStartupPioneer(
            name,
            sender: { bytes, destination in
                #expect(destination == 20)
                packets.append(bytes)
                return true
            }
        ) { input in
            #expect(input.isInputActive(10))
            #expect(packets == [[0x9B, 9, 127]])
            input.reconcileFactoryProfiles()
            #expect(packets.count == 1)
            let sources = input.sources
            input.sources = []
            input.reconcileFactoryProfiles()
            #expect(packets.count == 1)
            input.sources = sources
            input.reconcileFactoryProfiles()
            #expect(input.isInputActive(10))
            #expect(packets == [[0x9B, 9, 127], [0x9B, 9, 127]])
        }
    }
}

@Test @MainActor func controllerStartupPioneerFailedPacketCannotEnableTheFactoryControls() {
    for name in startupPioneerNames {
        withStartupPioneer(name, sender: { _, _ in false }) { input in
            #expect(!input.isInputActive(10))
            #expect(input.status.contains("could not start"))
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in actions.append(action) }
            var decoder = ControllerMIDIDecoder()
            for message in decoder.append([0x90, 11, 127]) { input.receive(message, source: 10) }
            #expect(actions.isEmpty)
        }
    }
}

@Test func controllerStartupPioneerDoesNotGuessPacketsForOtherModelsOrReverseModeReports() throws {
    for name in [
        "DDJ-SR", "DDJ-SX3", "DDJ-1000SRT", "DDJ-FLX6", "DDJ-200", "DDJ-WeGO4", "XDJ-AZ", "XDJ-RX3", "XDJ-XZ",
        "XDJ-RX2",
    ] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.definition?.startup.isEmpty == true)
    }
}
