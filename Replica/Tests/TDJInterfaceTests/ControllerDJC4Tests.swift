import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJC4(fourDecks: Bool = true, _ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "djc4-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { fourDecks ? DeckID.allCases : [.a, .b] })
    let name = "DJC-4"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func djc4Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJC4KeepsNativeLEDsAndBoundedFixedScratchLifecycle() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJC-4"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 234 && data.outputs.count == 40)
    #expect(data.startup.count == 4 && data.shutdown.count == 44)
    #expect(data.bankChanges?.count == 8 && profile.hasAutomaticSplitOutput)
    let feedback = profile.feedback(destination: 20)
    #expect(feedback.first { $0.action == .playB && $0.targetDeck == .d }?.message(value: 1) == [0x93, 24, 127])
    #expect(feedback.first { $0.action == .hotcue4A && $0.targetDeck == .c }?.message(value: 0) == [0x92, 11, 0])
}

@Test @MainActor func controllerCatalogueDJC4UsesOnlyDefaultDeckChannelsAndExistingFourDeckOptIn() {
    withDJC4 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        djc4Packet([0x90, 24, 127, 0x91, 24, 127, 0x92, 24, 127, 0x93, 24, 127, 0x94, 24, 127], to: input)
        #expect(targets.map(\.deck) == [.a, .b, .c, .d])
    }
    withDJC4(fourDecks: false) { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        djc4Packet([0x92, 24, 127, 0x93, 24, 127, 0x90, 24, 127], to: input)
        #expect(targets.map(\.deck) == [.a])
    }
}

@Test @MainActor func controllerCatalogueDJC4KeepsShiftedCueAndBendReleasesWithoutAlternatePresses() {
    withDJC4 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        djc4Packet([0x90, 23, 127, 19, 127, 45, 127, 73, 127, 69, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .pitchBendDownA])
        djc4Packet([0x90, 73, 0, 69, 0], to: input)
        #expect(events.map { $0.1 } == [1, 1, 0, 0])
        #expect(events.suffix(2).map { $0.0.action } == [.cuePreviewA, .pitchBendDownA])
        djc4Packet([0x90, 45, 0, 23, 127], to: input)
        #expect(events.last?.0.action == .cuePreviewA && events.last?.1 == 1)
    }
}

@Test @MainActor func controllerCatalogueDJC4DeckChangeReleasesOwnedContactsAndKeepsHeldShift() {
    withDJC4 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        djc4Packet([0x90, 23, 127, 19, 127, 38, 127, 45, 127, 17, 127], to: input)
        let released = Set(events.filter { $0.1 == 0 }.map { $0.0.action })
        #expect(released == [.cuePreviewA, .pitchBendDownA, .jogTouchA])
        events.removeAll()
        djc4Packet([0x92, 24, 127, 0x82, 24, 0, 0x90, 45, 0, 0x92, 24, 127], to: input)
        #expect(events.count == 1 && events.first?.0.action == .playA && events.first?.0.deck == .c)
    }
}

@Test @MainActor func controllerCatalogueDJC4KeepsFullTouchGateJogScaleAndStrictBrowserSteps() {
    withDJC4 { input in
        var touches: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var browsing: [Double] = []
        input.onTargetAction = { target, value in
            if target.action == .jogTouchB { touches.append(value) }
            if target.action == .browse { browsing.append(value) }
        }
        input.onJogAction = { jogs.append(($0, $1)) }
        djc4Packet([0x91, 38, 126], to: input)
        #expect(touches.isEmpty)
        djc4Packet([0x91, 38, 127, 0xB1, 2, 64, 2, 67, 0x90, 45, 127, 0x91, 88, 0], to: input)
        #expect(touches == [1, 0])
        #expect(jogs.count == 1 && jogs.first?.1 == .relative(3) && jogs.first?.0.argument == 128)
        djc4Packet([0x90, 45, 0, 0xB0, 14, 0, 14, 64, 14, 66], to: input)
        #expect(browsing.isEmpty)
        djc4Packet([0xB0, 14, 65], to: input)
        #expect(browsing.count == 1 && browsing.first! > 0.5)
    }
}

@Test @MainActor func controllerCatalogueDJC4ShiftedPlaySetsCueAndClearPressRetainsNativePadRearm() {
    withDJC4 { input in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        djc4Packet([0x90, 8, 127, 45, 127, 58, 127, 58, 0, 74, 127, 74, 0, 45, 0, 8, 127], to: input)
        #expect(actions == [.hotcue1A, .clearHotcue1A, .cueSetA, .hotcue1A])
    }
}

@Test @MainActor func controllerCatalogueDJC4DeckChangeRearmsPitchPickupWithoutLosingFullResolution() {
    withDJC4 { input in
        var current = 0.5
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? current : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        djc4Packet([0xE0, 0, 0], to: input)
        #expect(values.isEmpty)
        djc4Packet([0xE0, 0, 64], to: input)
        #expect(values == [0.5])
        djc4Packet([0xE0, 1, 64], to: input)
        #expect(values.last! < 0.5 && values.last! > 0.499)
        current = 0.8
        djc4Packet([0x90, 17, 127, 0xE0, 0, 64], to: input)
        #expect(values.count == 2)
    }
}
