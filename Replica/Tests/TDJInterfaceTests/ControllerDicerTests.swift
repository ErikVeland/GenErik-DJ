import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDicer(_ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void) rethrows {
    let suite = "dicer-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        },
        deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Dicer Novation Dicer",
            identity: .init(id: 10, device: 1, names: ["Dicer Novation Dicer"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "Dicer Novation Dicer",
            identity: .init(id: 20, device: 1, names: ["Dicer Novation Dicer"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func dicerPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDicerRetainsStoredAccessoryIdentityAndResetCommand() throws {
    try withDicer { input, packets in
        #expect(input.isInputActive(10))
        #expect(packets == [[0xBA, 0, 0]])
        let profile = try #require(ControllerFactoryProfile.matching(["Novation Dicers"], automaticOnly: true))
        #expect(profile.rawValue == "Novation Dicer")
        let data = try #require(profile.definition)
        #expect(data.role == "accessory" && data.inputs.count == 42 && data.outputs.count == 20)
        #expect(data.shutdown == [[0xBA, 0, 0]])
        #expect(ControllerFactoryProfile.matching(["Dicer 2"]) == nil)
        #expect(data.outputs.allSatisfy { $0.onValue == 14 && $0.offValue == 0 })
    }
}

@Test @MainActor func controllerCatalogueDicerMapsFiveCuesAndShiftedFixedLoopsPerDeck() {
    withDicer { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        dicerPacket([0x9A, 60, 127, 64, 127, 0x9D, 60, 127, 64, 127, 0x9B, 65, 127, 0x9E, 69, 127], to: input)
        #expect(
            targets == [
                .init(.hotcue1A, deck: .a), .init(.hotcue5A, deck: .a), .init(.hotcue1B, deck: .b),
                .init(.hotcue5B, deck: .b),
                .init(.toggleFixedLoopA, deck: .a, argument: 1), .init(.toggleFixedLoopB, deck: .b, argument: 16),
            ])
        targets.removeAll()
        dicerPacket([0x9C, 67, 127, 0x9F, 67, 127], to: input)
        #expect(targets == [.init(.loadA, deck: .a), .init(.loadB, deck: .b)])
    }
}

@Test @MainActor func controllerCatalogueDicerAlternateDeleteReleaseRearmsCueWithoutDeletingIt() {
    for release in [UInt8(0x9A), UInt8(0x8A)] {
        withDicer { input, _ in
            var cues = 0
            input.onTargetAction = { target, _ in if target.action == .hotcue1A { cues += 1 } }
            dicerPacket([0x9A, 60, 127, 60, 127, 65, 127], to: input)
            #expect(cues == 1)
            dicerPacket([release, 65, 0, 0x9A, 60, 127, 60, 0], to: input)
            #expect(cues == 2)
        }
    }
}

@Test @MainActor func controllerCatalogueDicerUsesHeldNativeCueAndOmitsUnsafeScriptEffects() {
    withDicer { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in events.append((target, value)) }
        dicerPacket([0x9B, 60, 127, 64, 127, 0x9C, 60, 127, 63, 127, 64, 127, 0x9F, 63, 127], to: input)
        #expect(events.isEmpty)
        dicerPacket([0x9C, 61, 127, 61, 0, 0x9F, 61, 127, 0x8F, 61, 0], to: input)
        #expect(
            events.map(\.0) == [
                .init(.cuePreviewA, deck: .a), .init(.cuePreviewA, deck: .a), .init(.cuePreviewB, deck: .b),
                .init(.cuePreviewB, deck: .b),
            ])
        #expect(events.map(\.1) == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueDicerOrangeBrowserButtonsRetainSingleStepsAndOrdering() {
    withDicer { input, _ in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        dicerPacket([0x9C, 65, 127, 66, 127, 66, 127, 68, 127, 69, 127, 67, 127], to: input)
        #expect(actions == [.browsePreviousGroup, .browsePrevious, .browseNext, .browseNextGroup, .loadA])
        dicerPacket([0x8C, 66, 127, 0x9C, 66, 127], to: input)
        #expect(actions.last == .browsePrevious)
    }
}
