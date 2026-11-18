import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSC2000(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "sc2000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { DeckID.allCases })
    let name = "DN-SC2000"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func scPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSC2000UsesFactoryTriggerLEDsAndNoGenericDeviceAlias() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DN-SC2000"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 120 && data.outputs.count == 52)
    #expect(data.startup.isEmpty && data.shutdown.count == 52)
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["USB Audio Device"], automaticOnly: true) == nil)
    let feedback = profile.feedback(destination: 20)
    let cue8D = try #require(feedback.first { $0.action == .hotcue8B && $0.targetDeck == .d })
    #expect(cue8D.message(value: 1) == [0xB3, 74, 32])
    #expect(cue8D.message(value: 0) == [0xB3, 75, 32])
    #expect(feedback.first { $0.action == .playA && $0.targetDeck == .a }?.message(value: 1) == [0xB0, 74, 39])
}

@Test @MainActor func controllerCatalogueSC2000BankChangeReleasesContactsAndRetainsPhysicalShift() {
    withSC2000 { input in
        #expect(input.isInputActive(10))
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        scPacket([0x90, 81, 64, 12, 64, 0x91, 66, 64, 0x90, 96, 64, 0x91, 3, 64, 67, 64], to: input)
        #expect(Set(events.filter { $0.1 == 0 }.map { $0.0.action }) == [.jogTouchA, .pitchBendUpA, .cuePreviewB])
        #expect(!events.contains { $0.0.action == .playB })
        events.removeAll()
        scPacket([0x81, 96, 0], to: input)
        #expect(events.isEmpty)
        scPacket([0x81, 67, 0, 0x91, 67, 64], to: input)
        #expect(events.count == 1 && events[0].0 == .init(.playB, deck: .b))
        events.removeAll()
        scPacket([0x90, 96, 64, 0x87, 96, 0, 0x90, 67, 64], to: input)
        #expect(events.count == 1 && events[0].0 == .init(.playA, deck: .a))
    }
}

@Test @MainActor func controllerCatalogueSC2000UsesFactoryJogScaleAndAllEightCueAddresses() {
    withSC2000 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var targets: [ControllerActionTarget] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, _ in targets.append(target) }
        scPacket([0xB0, 81, 0, 81, 64], to: input)
        #expect(jogs.isEmpty)
        scPacket(
            [
                0x90, 81, 64, 0xB0, 81, 65, 0xB2, 81, 63, 0x90, 23, 64, 32, 64, 33, 64,
                36, 64, 0x93, 36, 64, 40, 64,
            ], to: input)
        #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 2048 })
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(1))
        #expect(jogs.first { $0.0.deck == .c }?.1 == .relative(-1))
        #expect(
            targets == [
                .init(.jogTouchA, deck: .a), .init(.hotcue1A, deck: .a), .init(.hotcue4A, deck: .a),
                .init(.hotcue5A, deck: .a), .init(.hotcue8A, deck: .a), .init(.hotcue8B, deck: .d),
                .init(.loadB, deck: .d),
            ])
    }
}

@Test @MainActor func controllerCatalogueSC2000PitchUsesFullMessageAndRearmsPickupOnBankChange() {
    withSC2000 { input in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        scPacket([0xE0, 127, 127], to: input)
        #expect(values.isEmpty)
        scPacket([0xE0, 0, 64], to: input)
        #expect(values == [0.5])
        scPacket([0xE0, 127, 127], to: input)
        #expect(values.last == 0)
        let count = values.count
        scPacket([0x90, 3, 64, 0xE0, 127, 127], to: input)
        #expect(values.count == count)
        scPacket([0xE0, 0, 64], to: input)
        #expect(values.last == 0.5)
    }
}

@Test @MainActor func controllerCatalogueSC2000UnsupportedChannelsHaveNoInferredDeckTargets() {
    withSC2000 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        scPacket([0x94, 67, 64, 40, 64, 0x97, 67, 64, 36, 64, 0xE7, 0, 64], to: input)
        #expect(events.isEmpty)
    }
}
