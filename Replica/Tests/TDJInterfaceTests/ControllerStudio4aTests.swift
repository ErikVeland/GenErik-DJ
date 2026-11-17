import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withStudio4a(fourDecks: Bool = true, _ body: (ControllerMIDIConnection) throws -> Void) rethrows
{
    let suite = "studio4a-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { fourDecks ? DeckID.allCases : [.a, .b] })
    let name = "Behringer CMD STUDIO 4a"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func studio4aPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueStudio4aKeepsBoundedLifecycleAndSourceLEDValues() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Behringer CMD STUDIO 4a"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 124 && data.outputs.count == 24)
    #expect(data.startup.count == 8 && data.shutdown.count == 32)
    #expect(profile.hasAutomaticSplitOutput)
    let feedback = profile.feedback(destination: 20)
    #expect(feedback.first { $0.action == .playA && $0.targetDeck == .a }?.message(value: 1) == [0x90, 44, 1])
    #expect(feedback.first { $0.action == .cuePreviewB && $0.targetDeck == .d }?.message(value: 0) == [0x93, 75, 0])
}

@Test @MainActor func controllerCatalogueStudio4aKeepsDeckChannelsAndReversedRightManualLoopOrder() {
    withStudio4a { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        studio4aPacket(
            [0x90, 44, 127, 0x91, 76, 127, 56, 127, 55, 127, 0x92, 44, 127, 0x93, 76, 127, 56, 127, 55, 127], to: input)
        #expect(events.map(\.action) == [.playA, .playB, .loopInB, .loopOutB, .playA, .playB, .loopInB, .loopOutB])
        #expect(events.map(\.deck) == [.a, .b, .b, .b, .c, .d, .d, .d])
    }
    withStudio4a(fourDecks: false) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        studio4aPacket([0x92, 44, 127, 0x93, 76, 127, 0x90, 44, 127], to: input)
        #expect(events.map(\.deck) == [.a])
    }
}

@Test @MainActor func controllerCatalogueStudio4aDELGuardsPhysicalSideAcrossBanksAndRetainsCueRelease() {
    withStudio4a { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        studio4aPacket([0x90, 43, 127, 42, 127, 0x92, 34, 127, 44, 127, 0x91, 76, 127, 0x80, 43, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .playB, .cuePreviewA])
        #expect(events.map { $0.1 } == [1, 1, 0])
        studio4aPacket([0x82, 42, 0, 34, 0, 44, 0, 0x92, 34, 127, 44, 127], to: input)
        #expect(events.suffix(2).map { $0.0.action } == [.hotcue1A, .playA])
        #expect(events.suffix(2).allSatisfy { $0.0.deck == .c })
    }
}

@Test @MainActor func controllerCatalogueStudio4aUsesSourceJogMagnitudeAndTouchWithoutTimers() {
    withStudio4a { input in
        var touches: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .jogTouchB { touches.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        studio4aPacket([0x93, 58, 127, 0xB3, 58, 64, 58, 67, 58, 63, 0x83, 58, 127], to: input)
        #expect(touches == [1, 0])
        #expect(jogs.map { $0.1 } == [.relative(2)])
        #expect(jogs.allSatisfy { $0.0.deck == .d && $0.0.argument == 600 })
    }
}

@Test @MainActor func controllerCatalogueStudio4aPitchHasFullResolutionAndPickup() {
    withStudio4a { input in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        studio4aPacket([0xE2, 0, 0], to: input)
        #expect(values.isEmpty)
        studio4aPacket([0xE2, 0, 64, 1, 64], to: input)
        #expect(values.count == 1 && values.last! < 0.5 && values.last! > 0.499)
    }
}
