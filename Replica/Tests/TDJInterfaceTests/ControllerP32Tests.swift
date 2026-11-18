import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withP32(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "p32-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Hercules P32 DJ"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func p32Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueP32KeepsFactoryAudioAndBoundedOwnedFeedback() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["P32DJ"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 105 && data.outputs.count == 58)
    #expect(data.startup == [[0xB0, 127, 127]] && data.shutdown.count == 58)
    #expect(data.shutdown.allSatisfy { $0[2] == 0 })
    #expect(profile.hasAutomaticSplitOutput)
    let feedback = profile.feedback(destination: 20)
    #expect(feedback.first { $0.action == .hotcue1A }?.message(value: 1) == [0x91, 96, 125])
    #expect(feedback.first { $0.action == .pitchBendDownB }?.message(value: 0) == [0x92, 68, 127])
    #expect(!data.outputs.contains { $0.number == 1 })
}

@Test @MainActor func controllerCatalogueP32TempoKeepsExactSourceDirectionStepsAndQueuedAccumulation() {
    withP32 { input in
        var current = 0.5
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? current : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { current = value; values.append(value) }
        }
        p32Packet([0xB1, 5, 0], to: input)
        #expect(values.isEmpty)
        p32Packet([0xB1, 5, 1, 5, 63, 5, 127], to: input)
        #expect(values.count == 1 && abs(current - 0.495) < 0.0000001)
        p32Packet([0xB1, 5, 64], to: input)
        #expect(abs(current - 0.5) < 0.0000001)
        current = 0.999
        p32Packet([0xB1, 5, 127], to: input)
        #expect(current == 1)
        current = 0.001
        p32Packet([0xB1, 5, 1], to: input)
        #expect(current == 0)
    }
}

@Test @MainActor func controllerCatalogueP32CueBlendKeepsSourceFivePercentNormalisedSteps() {
    withP32 { input in
        var current = 0.5
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .cueMix ? current : nil }
        input.onTargetAction = { target, value in if target.action == .cueMix { current = value; values.append(value) }
        }
        p32Packet([0xB3, 2, 1, 2, 63, 2, 127], to: input)
        #expect(values.count == 1 && abs(current - 0.55) < 0.0000001)
        p32Packet([0xB3, 2, 0], to: input)
        #expect(values.count == 1)
    }
}

@Test @MainActor func controllerCatalogueP32ShiftReleasesRearmTopEightCuesWithoutExposingOtherSlots() {
    withP32 { input in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        p32Packet([0x91, 96, 127, 95, 127, 84, 127, 7, 127, 0x94, 96, 127, 96, 0, 0x91, 7, 0, 96, 127], to: input)
        #expect(actions == [.hotcue1A, .hotcue8A, .hotcue1A])
    }
}

@Test @MainActor func controllerCatalogueP32KeepsHeldCueAndBendAcrossShiftAndOmitsSoftwareDeckToggle() {
    withP32 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        p32Packet([0x91, 9, 127, 68, 127, 7, 127, 0x90, 3, 127, 0x94, 9, 0, 68, 0, 0x91, 7, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .pitchBendDownA, .cuePreviewA, .pitchBendDownA])
        #expect(events.map { $0.1 } == [1, 1, 0, 0])
        #expect(events.allSatisfy { $0.0.deck == .a })
    }
}

@Test @MainActor func controllerCatalogueP32DirectionStepsSurviveCopiedProfileAndEndpointReplacement() throws {
    try withP32 { input in
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["P32DJ"])))
        let name = "Hercules P32 DJ"
        input.sources = [.init(id: 11, reference: 101, name: name, identity: .init(id: 11, device: 1, names: [name]))]
        input.destinations = [
            .init(id: 21, reference: 201, name: name, identity: .init(id: 21, device: 1, names: [name]))
        ]
        input.reconcileFactoryProfiles()
        #expect(input.isInputActive(11))
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        var values: [Double] = []
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        p32Packet([0xB1, 5, 1], to: input, source: 11)
        #expect(values == [0.495])
    }
}

@Test @MainActor func controllerCatalogueP32MixerUsesWorkingEQAddressesWithoutDryWetAsGain() {
    withP32 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        p32Packet([0xB1, 2, 127, 3, 127, 4, 127, 9, 127], to: input)
        #expect(Set(events.map { $0.0.action }) == [.lowA, .midA, .highA])
        #expect(events.allSatisfy { $0.1 == 1 })
    }
}

@Test func controllerCatalogueDirectionStepMetadataOnlyAcceptsBoundedReviewedEncoders() throws {
    func valid(step: Double, kind: String = "control", encoding: String = "twosComplement", action: String = "tempoA")
        throws -> Bool
    {
        let data = Data(
            """
            {"id":"step-test","aliases":["step-test"],"inputs":[
              {"action":"\(action)","kind":"\(kind)","channel":0,"number":5,"encoding":"\(encoding)","inverted":false,"directionStep":\(step)}
            ],"outputs":[],"startup":[],"shutdown":[],"autoSelect":false,"scope":"test","source":"test"}
            """.utf8)
        return try JSONDecoder().decode(ControllerProfileData.self, from: data).isValid
    }
    #expect(try valid(step: 0.005))
    #expect(try valid(step: 0.05, action: "cueMix"))
    #expect(try !valid(step: 0))
    #expect(try !valid(step: -0.005))
    #expect(try !valid(step: 0.2))
    #expect(try !valid(step: 0.005, kind: "note"))
    #expect(try !valid(step: 0.005, encoding: "absolute"))
    #expect(try !valid(step: 0.005, action: "gainA"))
}
