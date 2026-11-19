import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withBuddy(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "buddy-manual-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Reloop Buddy"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func buddyPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueBuddyRemainsSeparateManualAndSendsNoUnqualifiedPackets() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Reloop Buddy"]))
    #expect(ControllerFactoryProfile.matching(["Reloop Buddy"], automaticOnly: true) == nil)
    #expect(profile != ControllerFactoryProfile.matching(["Reloop Ready"], automaticOnly: true))
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 21)
    #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
}

@Test @MainActor func controllerCatalogueBuddyNormalTransportAndLoadKeepTheirWireTargets() throws {
    try withBuddy { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        buddyPacket([0x90, 0, 127, 2, 127, 27, 127, 0x91, 0, 127, 2, 127, 27, 127, 0x9E, 2, 127, 3, 127], to: input)
        #expect(events.map(\.action) == [.playA, .syncA, .cueA, .playB, .syncB, .cueB, .loadA, .loadB])
        #expect(events.compactMap(\.deck) == [.a, .a, .a, .b, .b, .b, .a, .b])
    }
}

@Test @MainActor func controllerCatalogueBuddyCueReleasesCrossTheAlternateAddressWithoutRetrigger() throws {
    try withBuddy { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        buddyPacket([0x90, 1, 127, 1, 127, 5, 127, 0x80, 5, 127, 0x91, 1, 127, 5, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewA, .cuePreviewB, .cuePreviewB])
        #expect(events.map(\.1) == [1, 0, 1, 0])
        buddyPacket([0x90, 1, 127, 1, 0], to: input)
        #expect(events.suffix(2).map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueBuddyMixerPickupAndBrowseRetainTheAuthorAddresses() throws {
    try withBuddy { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.currentTargetValue = { $0 == .init(.levelA, deck: .a) ? 0.5 : nil }
        buddyPacket([0xB0, 28, 127], to: input)
        #expect(events.isEmpty)
        buddyPacket([0xB0, 28, 64, 0xBE, 0, 65, 8, 127, 13, 0], to: input)
        #expect(events.contains { $0.0 == .init(.levelA, deck: .a) && abs($0.1 - 0.5) < 0.005 })
        #expect(events.contains { $0.0.action == .browse && $0.1 == 0.5 - 1.0 / 126 })
        #expect(events.contains { $0.0.action == .crossfader && $0.1 == 1 })
        #expect(events.contains { $0.0.action == .cueMix && $0.1 == 0 })
        let count = events.count
        buddyPacket(
            [
                0xB0, 9, 127, 63, 127, 6, 65, 23, 127, 25, 127, 26, 127, 33, 65, 0x90, 12, 127, 13, 127, 0x94, 20, 127,
                0xBE, 10, 127, 12, 127,
            ], to: input)
        #expect(events.count == count)
    }
}
