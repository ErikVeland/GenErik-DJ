import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let mc3000PressValue = 64.0 / 127

@MainActor private func withManualMC3000(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "mc3000-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
    let name = "Denon MC3000"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func mc3000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMC3000StaysManualWithoutPhantomGainOrUnqualifiedLoad() throws {
    #expect(ControllerFactoryProfile.matching(["Denon MC3000"], automaticOnly: true) == nil)
    let profile = try #require(ControllerFactoryProfile.matching(["Denon MC3000"]))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 124 && data.outputs.count == 56)
    #expect(data.startup.isEmpty && data.shutdown.isEmpty && data.bankChanges == nil)
    #expect(!profile.hasAutomaticSplitOutput)
    try withManualMC3000 { input in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        mc3000Packet([0xB0, 88, 127, 0xB2, 89, 127, 90, 127, 91, 127, 92, 127, 0x90, 98, 64, 99, 64], to: input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMC3000UsesACBDChannelsAndFactoryCueVelocity() throws {
    try withManualMC3000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mc3000Packet(
            [0x90, 66, 64, 0x80, 66, 0, 0x91, 66, 64, 66, 0, 0x92, 66, 64, 0x82, 66, 0, 0x93, 66, 64, 66, 0], to: input)
        #expect(events.map { $0.0.deck } == [.a, .a, .c, .c, .b, .b, .d, .d])
        #expect(
            events.map { $0.1 } == [mc3000PressValue, 0, mc3000PressValue, 0, mc3000PressValue, 0, mc3000PressValue, 0])
    }
}

@Test @MainActor func controllerCatalogueMC3000KeepsFactoryMixerAndEightCueAddresses() throws {
    try withManualMC3000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mc3000Packet([0xB0, 1, 127, 0xB1, 7, 127, 0xB2, 12, 127, 0xB3, 17, 127, 0x93, 75, 64], to: input)
        #expect(events.filter { $0.0.action == .gainA || $0.0.action == .gainB }.count == 4)
        #expect(events.contains { $0.0.action == .hotcue8B && $0.0.deck == .d && $0.1 == mc3000PressValue })
        #expect(events.filter { $0.0.action == .gainA || $0.0.action == .gainB }.allSatisfy { $0.1 == 1 })
    }
}

@Test @MainActor func controllerCatalogueMC3000PhysicalShiftReleasesAcrossItsTwoChannels() throws {
    try withManualMC3000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        mc3000Packet([0x90, 66, 64, 96, 64, 0x91, 66, 64, 0x80, 66, 0, 0x81, 66, 0, 96, 0, 0x91, 66, 64], to: input)
        #expect(events.map { $0.0.deck } == [.a, .a, .c])
        #expect(events.map { $0.1 } == [mc3000PressValue, 0, mc3000PressValue])
    }
}

@Test @MainActor func controllerCatalogueMC3000KeepsCompoundLoopOrderAndSourceOutExit() throws {
    try withManualMC3000 { input in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        mc3000Packet([0x92, 55, 64, 57, 64], to: input)
        #expect(actions == [.loopDisableB, .loopInB, .loopOutOrExitB])
    }
}

@Test @MainActor func controllerCatalogueMC3000UsesFactoryTriggerLEDCommandsInsteadOfInputNotes() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Denon MC3000"]))
    let feedback = profile.feedback(destination: 20)
    #expect(feedback.first { $0.action == .cueB && $0.targetDeck == .b }?.message(value: 1) == [0xB2, 80, 81])
    #expect(feedback.first { $0.action == .cueB && $0.targetDeck == .d }?.message(value: 0) == [0xB3, 81, 87])
    #expect(feedback.first { $0.action == .hotcue8A && $0.targetDeck == .c }?.message(value: 1) == [0xB1, 74, 54])
    #expect(feedback.first { $0.action == .cuePreviewA && $0.targetDeck == .a }?.message(value: 0) == [0xB0, 75, 38])
}

@Test @MainActor func controllerCatalogueMC3000PitchIgnoresLegacyMidinoAndKeepsCentrePickup() throws {
    try withManualMC3000 { input in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoB ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoB { values.append(value) } }
        mc3000Packet([0xE2, 0, 0], to: input)
        #expect(values.isEmpty)
        mc3000Packet([0xE2, 0, 64], to: input)
        #expect(values == [0.5])
        mc3000Packet([0xE2, 1, 64], to: input)
        #expect(values.last! < 0.5 && values.last! > 0.499)
    }
}
