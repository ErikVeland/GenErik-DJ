import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixage(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "mixage-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Reloop Mixage"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func mixagePacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMixageSharesQualifiedModelsWithoutAnInferredFamilyAudioRoute() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Reloop Mixage"], automaticOnly: true))
    for name in [
        "Reloop Mixage Interface Edition", "Reloop Mixage Interface Edition MK2", "Reloop Mixage Controller Edition",
    ] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == profile)
    }
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 108 && data.outputs.count == 12)
    #expect(data.startup.count == 28 && data.shutdown.count == 26)
    #expect(data.startup.suffix(2) == [[0x90, 4, 127], [0x90, 18, 127]])
    #expect(data.shutdown.allSatisfy { $0[1] < 128 && $0[2] == 0 })
    #expect(!profile.hasAutomaticSplitOutput)
    withMixage { input in #expect(input.isInputActive(10)) }
}

@Test @MainActor func controllerCatalogueMixageSideShiftReleasesCueAndRetainsIndependentOtherDeck() {
    withMixage { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mixagePacket([0x90, 11, 127, 42, 127, 0x80, 74, 127, 0x90, 23, 127, 74, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewA, .syncB, .hotcue3A])
        #expect(events[0].1 == 1 && events[1].1 == 0)
        events.removeAll()
        mixagePacket([0x80, 74, 127, 42, 127, 0x90, 11, 127, 0x80, 11, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewA])
        #expect(events.map { $0.1 } == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueMixageShiftedTransportPadsKeepBaseButtonsRearmed() {
    withMixage { input in
        var actions: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in actions.append(target) }
        mixagePacket(
            [
                0x90, 12, 127, 42, 127, 0x80, 75, 127, 0x90, 75, 127, 0x80, 75, 127, 42, 127,
                0x90, 12, 127,
            ], to: input)
        #expect(actions == [.init(.playA, deck: .a), .init(.hotcue4A, deck: .a), .init(.playA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueMixageKeeps620CountMotionAndShiftedPitchMessages() {
    withMixage { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        mixagePacket(
            [
                0x90, 36, 127, 0xB0, 36, 65, 0x90, 42, 127, 0xB0, 99, 63, 0xE2, 0, 64,
                0x80, 99, 127,
            ], to: input)
        #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 620 && $0.0.deck == .a })
        #expect(jogs.map { $0.1 } == [.relative(1), .relative(-1)])
        #expect(values == [0.5])
    }
}

@Test @MainActor func controllerCatalogueMixageLoopEncoderUsesDirectionAndNativeLoopPagesStaySeparate() {
    withMixage { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mixagePacket([0xB0, 32, 69], to: input)
        #expect(events.count == 1 && events[0].0 == .init(.loopSizeA, deck: .a))
        #expect(abs(events[0].1 - (0.5 + 1.0 / 126)) < 0.000001)
        events.removeAll()
        mixagePacket([0x90, 5, 127, 6, 127, 42, 127, 68, 127, 69, 127], to: input)
        #expect(events.map { $0.0.action } == [.loopEnableA, .reloopA, .loopInA, .loopOutA])
        events.removeAll()
        mixagePacket([0x90, 3, 127, 4, 127, 32, 127, 8, 127], to: input)
        #expect(events.isEmpty)
    }
}
