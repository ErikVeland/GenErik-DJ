import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRX221(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "rx221-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
    let name = "PIONEER XDJ-RX"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func rx221Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerRX221KeepsLegacyPitchAndLaterGenerationsSeparate() throws {
    let current = try #require(ControllerFactoryProfile.matching(["PIONEER XDJ-RX"], automaticOnly: true))
    let data = try #require(current.definition)
    #expect(data.inputs.count == 159 && data.outputs.count == 24)
    #expect(data.startup.count + data.shutdown.count == 56)
    #expect(!current.hasAutomaticSplitOutput)
    let legacy = try #require(ControllerFactoryProfile.matching(["XDJ-RX legacy 7-bit"]))
    #expect(!legacy.selectsAutomatically && legacy.feedback(destination: 20).isEmpty)
    #expect(legacy.bindings(source: 10).first { $0.action == .tempoA }?.mode == .cdjTempo)
    #expect(current.bindings(source: 10).first { $0.action == .tempoA }?.mode == .paired14Bit)
    for name in ["XDJ-RX2", "XDJ-RX3"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != current)
    }
}

@Test @MainActor func controllerRX221UsesDocumentedLoadInsteadOfPCStatusOrLoadIllumination() {
    withRX221 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if [.loadA, .loadB].contains(target.action) { events.append(target) } }
        rx221Packet([0x90, 81, 127, 0x91, 81, 127, 0x92, 81, 127, 0x93, 81, 127], to: input)
        #expect(events.map(\.deck) == [.a, .b, .c, .d])
        events.removeAll()
        rx221Packet([0xB0, 100, 127, 0x90, 75, 127, 0x9B, 0, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerRX221PitchKeepsLowBytePrecisionNormalShiftAndPickup() {
    withRX221 { input in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        rx221Packet([0xB0, 29, 0, 61, 0], to: input)
        #expect(values.isEmpty)
        rx221Packet([0xB0, 29, 64, 61, 1], to: input)
        #expect(values.last == 8193.0 / 16383)
        rx221Packet([0xB0, 61, 2], to: input)
        #expect(values.last == 8194.0 / 16383)
        rx221Packet([0xB0, 52, 64, 84, 3], to: input)
        #expect(values.last == 8195.0 / 16383)
        rx221Packet([0xB0, 29, 127, 61, 127], to: input)
        #expect(values.last == 1)
    }
}

@Test @MainActor func controllerRX221AlternateReleasesRearmCueTransportAndCuePads() {
    withRX221 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rx221Packet([0x90, 1, 127, 0, 127, 24, 127, 53, 127, 52, 127, 99, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .playA, .hotcue1A])
        rx221Packet([0x90, 53, 0, 52, 0, 99, 0, 1, 127, 0, 127, 24, 127], to: input)
        #expect(
            events.map { $0.0.action } == [
                .cuePreviewA, .playA, .hotcue1A, .cuePreviewA, .cuePreviewA, .playA, .hotcue1A,
            ])
        #expect(events.dropFirst(3).first?.1 == 0)
    }
}

@Test @MainActor func controllerRX221BankReportsAndPCExitReleaseOwnedContacts() {
    withRX221 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if target.action.isMomentary { events.append((target, value)) } }
        rx221Packet([0x90, 1, 127, 32, 127, 0x91, 1, 127, 0xB2, 102, 127], to: input)
        #expect(Set(events.filter { $0.1 == 0 }.map { $0.0.action }) == [.cuePreviewA, .jogTouchA, .cuePreviewB])
        events.removeAll()
        rx221Packet([0x90, 1, 127, 0x91, 1, 127, 0xB0, 100, 127], to: input)
        #expect(events.filter { $0.1 == 0 }.isEmpty)
        rx221Packet([0xB0, 100, 0], to: input)
        #expect(events.filter { $0.1 == 0 }.map { $0.0.action } == [.cuePreviewA])
        rx221Packet([0x81, 1, 0], to: input)
        #expect(events.last?.0.action == .cuePreviewB && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerRX221UsesFactoryTransportAndPFLFeedback() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["XDJ-RX"]))
    for (action, channel, number, status) in [
        (ControllerAction.playA, 0, 0, 0x90), (.cuePreviewB, 1, 1, 0x91), (.syncA, 2, 31, 0x92), (.cueB, 4, 73, 0xB4),
    ] {
        let row = try #require(
            profile.feedback(destination: 20).first {
                $0.action == action && $0.channel == channel && $0.number == number
            })
        #expect(row.message(value: 1) == [UInt8(status), UInt8(number), 127])
        #expect(row.message(value: 0) == [UInt8(status), UInt8(number), 0])
    }
}
