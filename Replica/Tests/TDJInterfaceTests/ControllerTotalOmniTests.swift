import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let totalOmniNames = ["Numark Total Control", "Numark Omni Control"]

@MainActor private func withTotalOmni(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "total-omni-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func totalOmniPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test(arguments: totalOmniNames) @MainActor
func controllerCatalogueTotalOmniKeepSourceLEDAddressesAndPFLPolarity(_ name: String) throws {
    let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 46 && data.outputs.count == 8)
    #expect(data.startup.count == 39 && data.shutdown.count == 8)
    #expect(data.startup.first == [0x90, 48, 0] && data.startup.last == [0x90, 86, 0])
    #expect(!profile.hasAutomaticSplitOutput)
    let feedback = profile.feedback(destination: 20)
    let pfl = try #require(feedback.first { $0.action == .cueA })
    #expect(pfl.message(value: 1) == [0x90, 53, 100] && pfl.message(value: 0) == [0x90, 53, 0])
    #expect(feedback.first { $0.action == .playB }?.message(value: 1) == [0x90, 78, 100])
    withTotalOmni(name) { input in #expect(input.isInputActive(10)) }
}

@Test(arguments: totalOmniNames) @MainActor
func controllerCatalogueTotalOmniKeepDistinctCueAndCompoundLoopInputOrder(_ name: String) {
    withTotalOmni(name) { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        totalOmniPacket(
            [
                0x90, 59, 127, 51, 127, 0x80, 51, 127, 0x90, 65, 127, 0x80, 65, 127,
                0x90, 73, 127, 74, 127,
            ], to: input)
        #expect(
            events.map { $0.0.action } == [
                .cueSetA, .cuePreviewA, .cuePreviewA, .pitchBendDownA,
                .pitchBendDownA, .loopDisableA, .loopInA, .loopOutOrExitA,
            ])
        #expect(events.map { $0.1 } == [1, 1, 0, 1, 0, 1, 1, 1])
    }
}

@Test(arguments: totalOmniNames) @MainActor
func controllerCatalogueTotalOmniJogOrderStaysModelSpecific(_ name: String) {
    withTotalOmni(name) { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        let left: UInt8 = name == "Numark Total Control" ? 25 : 24
        let right: UInt8 = name == "Numark Total Control" ? 24 : 25
        totalOmniPacket([0xB0, left, 0, right, 0], to: input)
        #expect(jogs.isEmpty)
        totalOmniPacket([0xB0, left, 3, right, 127], to: input)
        #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 128 })
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(3))
        #expect(jogs.first { $0.0.deck == .b }?.1 == .relative(-1))
    }
}

@Test(arguments: totalOmniNames) @MainActor
func controllerCatalogueTotalOmniFinePitchKeepsSourceStepScaleAndInversion(_ name: String) {
    withTotalOmni(name) { input in
        var current = 0.5
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? current : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { current = value; values.append(value) }
        }
        totalOmniPacket([0xB0, 3, 0], to: input)
        #expect(values.isEmpty)
        totalOmniPacket([0xB0, 3, 1], to: input)
        #expect(current == 0.5 - 1.0 / 1024)
        totalOmniPacket([0xB0, 3, 127], to: input)
        #expect(current == 0.5)
        totalOmniPacket([0xB0, 3, 64], to: input)
        #expect(current == 0.5625)
    }
}

@Test func controllerCatalogueTotalOmniFineTempoRequiresReviewedSevenBitCC() {
    var state = ControllerMIDIValueState()
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append([0x90, 3, 127, 0xE0, 3, 0, 0xB0, 7, 1]) {
        #expect(state.decode(message, encoding: .fineTempo512, number: 3) == nil)
    }
    #expect(ControllerMIDIEncoding.fineTempo512.isRelative && !ControllerMIDIEncoding.fineTempo512.supportsLearning)
}
