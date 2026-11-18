import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRP8000(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "rp8000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "RP-8000", identity: .init(id: 10, device: 1, names: ["RP-8000"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "RP-8000", identity: .init(id: 20, device: 1, names: ["RP-8000"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func rp8000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRP8000MatchesOnlyTheReviewedOriginalAccessory() throws {
    try withRP8000 { input in
        #expect(input.isInputActive(10))
        let profile = try #require(ControllerFactoryProfile.matching(["Reloop RP8000"], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.role == "accessory" && data.inputs.count == 136 && data.outputs.count == 40)
        #expect(data.startup.isEmpty && data.shutdown.isEmpty)
        #expect(ControllerFactoryProfile.matching(["RP-8000 MK2"], automaticOnly: true) == nil)
        #expect(ControllerFactoryProfile.matching(["RP-8000 Straight"], automaticOnly: true) == nil)
        #expect(!data.inputs.contains { $0.action.isJog || [.playA, .playB, .tempoA, .tempoB].contains($0.action) })
    }
}

@Test @MainActor func controllerCatalogueRP8000HardwareChannelsRetainFourDistinctTargets() {
    withRP8000 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        for channel in UInt8(0)...3 { rp8000Packet([0x90 + channel, 7, 127, 64, 127], to: input) }
        #expect(
            targets == [
                .init(.hotcue8A, deck: .a), .init(.loadA, deck: .a), .init(.hotcue8B, deck: .b),
                .init(.loadB, deck: .b), .init(.hotcue8A, deck: .c), .init(.loadA, deck: .c),
                .init(.hotcue8B, deck: .d), .init(.loadB, deck: .d),
            ])
    }
}

@Test @MainActor func controllerCatalogueRP8000KeepsSampleUserAndOptionalMotorInputsUnmapped() {
    withRP8000 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        rp8000Packet(
            [0x90, 16, 127, 24, 127, 69, 127, 70, 127, 74, 127, 0xE0, 0, 127, 0xB0, 78, 127, 79, 127, 80, 65], to: input
        )
        #expect(targets.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueRP8000RetainsFixedLoopLengthsAndHeldReleaseAliases() {
    for release in [UInt8(0x90), 0x80] {
        withRP8000 { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            rp8000Packet([0x90, 8, 127, 40, 127, 15, 127], to: input)
            #expect(
                targets == [
                    .init(.toggleFixedLoopA, deck: .a, argument: 0.25),
                    .init(.toggleFixedLoopA, deck: .a, argument: 32),
                ])
            rp8000Packet([release, 40, release == 0x80 ? 99 : 0, 0x90, 8, 127], to: input)
            #expect(targets.last == .init(.toggleFixedLoopA, deck: .a, argument: 0.25))
            #expect(targets.count == 3)
        }
    }
}

@Test @MainActor func controllerCatalogueRP8000DeleteReleaseRearmsAnExistingCuePress() {
    withRP8000 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        rp8000Packet([0x91, 0, 127, 32, 127, 0x81, 32, 77, 0x91, 0, 127], to: input)
        #expect(targets == [.init(.hotcue1B, deck: .b), .init(.hotcue1B, deck: .b)])
    }
}

@Test @MainActor func controllerCatalogueRP8000BrowserKeepsCentre64DirectionAndFlushesBeforeLoad() {
    withRP8000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rp8000Packet([0xB0, 64, 65, 0x90, 64, 127], to: input)
        #expect(events.map(\.0) == [.init(.browse), .init(.loadA, deck: .a)])
        #expect(abs(events[0].1 - (0.5 + 1.0 / 126)) < 0.000001)
        events.removeAll()
        rp8000Packet([0xB1, 64, 63], to: input)
        #expect(events.count == 1 && abs(events[0].1 - (0.5 - 1.0 / 126)) < 0.000001)
        events.removeAll()
        rp8000Packet([0xB1, 64, 64], to: input)
        #expect(events.isEmpty)
    }
}

@Test func controllerCatalogueRP8000CueLightsKeepTheReviewedOutputAddressesOnly() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["RP-8000"], automaticOnly: true))
    let data = try #require(profile.definition)
    let output = try #require(data.outputs.first { $0.action == .hotcue1A && $0.targetDeck == .c && $0.number == 32 })
    #expect(output.binding(destination: 20).message(value: 1) == [0x92, 32, 127])
    #expect(output.binding(destination: 20).message(value: 0) == [0x92, 32, 0])
    #expect(
        !data.outputs.contains {
            [.hotcue6A, .hotcue7A, .hotcue8A, .hotcue6B, .hotcue7B, .hotcue8B].contains($0.action)
        })
}

@Test @MainActor func controllerCatalogueRP8000AppDeckAvailabilityGuardsTheLinkedExtraChannels() {
    withRP8000(decks: [.a, .b]) { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        rp8000Packet([0x92, 0, 127, 64, 127, 0x93, 0, 127, 64, 127, 0x90, 0, 127], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a)])
    }
}
