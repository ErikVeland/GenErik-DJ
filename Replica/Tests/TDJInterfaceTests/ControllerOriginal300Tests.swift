import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginal300(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original300-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Hercules DJControl Inpulse 300"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func original300Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginal300KeepsSeparateIdentityAndReviewedStartup() throws {
    let profile = try #require(
        ControllerFactoryProfile.matching(["Hercules DJControl Inpulse 300"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 134 && data.outputs.count == 8)
    #expect(data.startup == [[0x91, 3, 127], [0x92, 3, 127], [0x90, 4, 5], [0xB0, 127, 127]])
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["Hercules DJControl Inpulse 300 MK2"], automaticOnly: true) != profile)
    withOriginal300 { input in #expect(input.isInputActive(10)) }
}

@Test @MainActor func controllerCatalogueOriginal300PairsMixerControlsAndRearmsShiftPitchPickup() {
    withOriginal300 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { _ in 0.5 }
        input.onTargetAction = { events.append(($0, $1)) }
        original300Packet([0xB1, 8, 127, 40, 127], to: input)
        #expect(events.isEmpty)
        original300Packet([0xB1, 8, 64, 40, 1, 0, 64, 32, 1], to: input)
        #expect(Set(events.map { $0.0.action }) == [.tempoA, .levelA])
        events.removeAll()
        original300Packet([0x91, 4, 127, 0xB4, 8, 127, 40, 127], to: input)
        #expect(events.isEmpty)
        original300Packet([0xB4, 8, 64, 40, 1], to: input)
        #expect(events.count == 1 && events[0].0 == .init(.tempoA, deck: .a))
        #expect(abs(events[0].1 - (1 - 8193.0 / 16383)) < 0.000001)
    }
}

@Test @MainActor func controllerCatalogueOriginal300CueReleaseAnd248To62CountShiftMotionKeepOwnership() {
    withOriginal300 { input in
        var events: [(ControllerActionTarget, Double)] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.onJogAction = { jogs.append(($0, $1)) }
        original300Packet([0x91, 6, 127, 4, 127, 0x84, 6, 127, 0x94, 6, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewA] && events.map { $0.1 } == [1, 0])
        events.removeAll()
        original300Packet(
            [
                0x81, 4, 127, 0x91, 8, 127, 0xB1, 10, 3, 0x91, 4, 127, 0xB4, 10, 127,
                0x84, 8, 127,
            ], to: input)
        #expect(jogs.count == 2 && jogs.map { $0.0.argument } == [248, 62])
        #expect(jogs.map { $0.1 } == [.relative(3), .relative(-1)])
        #expect(events.map { $0.0.action } == [.jogTouchA, .jogTouchA] && events.map { $0.1 } == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueOriginal300CuesAndCustomLoopLayoutDoNotInvokeOtherPadPages() {
    withOriginal300 { input in
        var actions: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in actions.append(target) }
        original300Packet(
            [
                0x96, 0, 127, 0x86, 8, 127, 0x96, 8, 127, 0, 127, 7, 127, 0x97, 7, 127,
                0x91, 9, 127, 10, 127, 4, 127, 0x94, 9, 127, 10, 127,
            ], to: input)
        #expect(
            actions == [
                .init(.hotcue1A, deck: .a), .init(.clearHotcue1A, deck: .a), .init(.hotcue1A, deck: .a), .init(.hotcue8A, deck: .a),
                .init(.hotcue8B, deck: .b), .init(.fixedLoopA, deck: .a, argument: 4),
                .init(.loopDisableA, deck: .a), .init(.loopDownA, deck: .a), .init(.loopUpA, deck: .a),
            ])
        actions.removeAll()
        original300Packet([0x96, 16, 127, 32, 127, 48, 127, 64, 127, 80, 127, 96, 127, 112, 127], to: input)
        #expect(actions.isEmpty)
    }
}
