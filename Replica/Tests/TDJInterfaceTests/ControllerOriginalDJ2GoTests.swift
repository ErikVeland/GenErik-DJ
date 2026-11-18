import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalDJ2Go(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original-dj2go-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Numark DJ2GO"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func originalDJ2GoPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalDJ2GoKeepsFactoryIdentityAndEightLEDs() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Numark DJ2GO"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 26 && data.outputs.count == 8)
    #expect(data.startup.count == 8 && data.startup == data.shutdown)
    #expect(Set(data.outputs.map(\.number)) == [0x33, 0x3B, 0x40, 0x65, 0x3C, 0x42, 0x47, 0x66])
    #expect(!profile.hasAutomaticSplitOutput)
    for name in ["DJ2GO2", "Numark DJ2GO2", "DJ2GO2 Touch"] {
        #expect(ControllerFactoryProfile.matching(["Numark DJ2GO", name], automaticOnly: true) != profile)
    }
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewA })
    #expect(cue.message(value: 1) == [0x90, 0x33, 127])
    #expect(cue.message(value: 0) == [0x90, 0x33, 0])
}

@Test @MainActor func controllerCatalogueOriginalDJ2GoLoadsOnPressAndKeepsPitchButtonsOutOfLoopLayer() {
    withOriginalDJ2Go { input in
        #expect(input.isInputActive(10))
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        originalDJ2GoPacket(
            [
                0x90, 0x4B, 127, 0x34, 127, 0x80, 0x4B, 127, 0x34, 127,
                0x90, 0x43, 127, 0x44, 127, 0x80, 0x43, 127, 0x44, 127,
            ], to: input)
        #expect(
            events.map { $0.0.action } == [
                .loadA, .loadB, .pitchBendUpA, .pitchBendDownA,
                .pitchBendUpA, .pitchBendDownA,
            ])
        #expect(events.map { $0.1 } == [1, 1, 1, 1, 0, 0])
    }
}

@Test @MainActor func controllerCatalogueOriginalDJ2GoUsesFactorySignedMagnitudeAndStationaryZero() {
    withOriginalDJ2Go { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var browser: [Double] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, value in if target.action == .browse { browser.append(value) } }
        originalDJ2GoPacket([0xB0, 0x19, 0, 0x18, 0, 0x1A, 0], to: input)
        #expect(jogs.isEmpty && browser.isEmpty)
        originalDJ2GoPacket([0xB0, 0x19, 3, 0x18, 64, 0x1A, 3], to: input)
        #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 60 })
        #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(3))
        #expect(jogs.first { $0.0.deck == .b }?.1 == .relative(-64))
        #expect(browser.count == 1 && abs(browser[0] - (0.5 + 3.0 / 126)) < 0.000001)
    }
}

@Test @MainActor func controllerCatalogueOriginalDJ2GoPhysicalPitchDetentKeepsNativeCentreAndPickup() {
    withOriginalDJ2Go { input in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        originalDJ2GoPacket([0xB0, 13, 127], to: input)
        #expect(values.isEmpty)
        originalDJ2GoPacket([0xB0, 13, 64], to: input)
        originalDJ2GoPacket([0xB0, 13, 0], to: input)
        #expect(values == [0.5, 1])
    }
}
