import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func attachReady(_ input: ControllerMIDIConnection, source: Int32 = 10) {
    let name = "Reloop Ready"
    input.sources = [
        .init(id: source, reference: 100, name: name, identity: .init(id: source, device: 1, names: [name]))
    ]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
}

@MainActor private func withReady(_ body: (ControllerMIDIConnection, UserDefaults) throws -> Void) rethrows {
    let suite = "ready-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    attachReady(input)
    try body(input, preferences)
}

@MainActor private func readyPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueReadyKeepsMeasuredRecipeAndSeparateBuddyIdentity() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Reloop Ready"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 138 && data.outputs.count == 8)
    #expect(data.startup.count == 18 && data.shutdown.count == 10)
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["Reloop Buddy"], automaticOnly: true) != profile)
    #expect(data.outputs.allSatisfy { !($0.number == 32 && $0.channel < 2) })
    #expect(data.startup.filter { $0[1] == 15 } == [[0x90, 15, 127], [0x91, 15, 127]])
    withReady { input, _ in
        #expect(input.isInputActive(10))
        var actions: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in actions.append(target) }
        readyPacket([0x90, 0, 127, 0x91, 0, 127, 0x9E, 2, 127, 3, 127], to: input)
        #expect(
            actions == [
                .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.loadA, deck: .a), .init(.loadB, deck: .b),
            ])
    }
}

@Test @MainActor func controllerCatalogueReadyTempoUsesFullTravelPickupAndFreshPairs() {
    withReady { input, _ in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        readyPacket([0xB0, 9, 0, 63, 0], to: input)
        #expect(values.isEmpty)
        readyPacket([0xB0, 9, 4, 63, 0], to: input)
        #expect(values == [1 - 512.0 / 1023])
        readyPacket([0xB0, 9, 7, 63, 127], to: input)
        #expect(values.last == 0)
        let count = values.count
        readyPacket([0xB0, 63, 0, 9, 8, 63, 0], to: input)
        #expect(values.count == count)
        readyPacket([0xB0, 9, 0, 63, 0], to: input)
        #expect(values.last == 1)
    }
}

@Test @MainActor func controllerCatalogueReadyHardwareModifierReleasesCannotLatchCueOrRetriggerShiftActions() {
    withReady { input, _ in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { target, value in events.append((target.action, value)) }
        readyPacket([0x90, 1, 127, 0x9E, 0, 127, 0x80, 5, 127], to: input)
        #expect(events.map { $0.0 } == [.cuePreviewA, .cuePreviewA] && events.map { $0.1 } == [1, 0])
        events.removeAll()
        readyPacket([0x90, 0, 127, 0x80, 16, 127, 0x90, 16, 127, 0x8E, 0, 127, 0x90, 0, 127], to: input)
        #expect(events.map { $0.0 } == [.playA, .playA])
    }
}

@Test @MainActor func controllerCatalogueReadyPadModesStayIndependentAndBlockUnimplementedPages() {
    withReady { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        readyPacket([0x94, 20, 127, 0x84, 20, 127, 0x94, 5, 127, 20, 127, 0x84, 20, 127, 0x94, 23, 127], to: input)
        #expect(
            targets == [
                .init(.hotcue1A, deck: .a), .init(.toggleFixedLoopA, deck: .a, argument: 1),
                .init(.toggleFixedLoopA, deck: .a, argument: 8),
            ])
        targets.removeAll()
        readyPacket([0x95, 20, 127, 0x85, 20, 127, 0x94, 14, 127, 20, 127, 21, 127, 22, 127], to: input)
        #expect(
            targets == [
                .init(.hotcue1B, deck: .b), .init(.loopInA, deck: .a), .init(.loopOutA, deck: .a),
                .init(.reloopA, deck: .a),
            ])
        for mode: UInt8 in [11, 15, 9, 8, 18] {
            targets.removeAll()
            readyPacket([0x94, mode, 127, 20, 127, 0x84, 20, 127], to: input)
            #expect(targets.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueReadyShiftSearchCannotAcquireANewContactButRetainsRelease() {
    withReady { input, _ in
        var touches: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .jogTouchA { touches.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        readyPacket([0x9E, 0, 127, 0x90, 6, 127, 0xB0, 43, 1, 0x80, 6, 127, 0x8E, 0, 127], to: input)
        #expect(touches.isEmpty && jogs.isEmpty)
        readyPacket([0x90, 6, 127, 0xB0, 6, 3, 0x9E, 0, 127, 0x80, 6, 127], to: input)
        #expect(touches == [1, 0])
        #expect(jogs.count == 1 && jogs[0].0.argument == 1024 && jogs[0].1 == .relative(3))
    }
}

@Test @MainActor func controllerCatalogueReadyCustomReconnectRetainsTenBitCodecLowByteAndModes() {
    withReady { input, preferences in
        input.select(10)
        input.learning = .cueA
        readyPacket([0x9F, 100, 127], to: input)
        let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
        attachReady(restored, source: 11)
        var events: [(ControllerActionTarget, Double)] = []
        restored.onTargetAction = { events.append(($0, $1)) }
        readyPacket([0xB0, 9, 7, 63, 127], to: restored, source: 11)
        #expect(events.count == 1 && events[0].0.action == .tempoA && events[0].1 == 0)
        events.removeAll()
        readyPacket([0x94, 11, 127, 20, 127, 0x84, 20, 127, 0x94, 5, 127, 20, 127], to: restored, source: 11)
        #expect(events.count == 1 && events[0].0 == .init(.toggleFixedLoopA, deck: .a, argument: 1))
    }
}
