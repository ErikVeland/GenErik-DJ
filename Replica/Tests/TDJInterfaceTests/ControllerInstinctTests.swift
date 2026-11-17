import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withInstinct(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original-instinct-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Hercules DJControl Instinct"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func instinctPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueInstinctUsesFactoryActiveLowLEDsAndKeepsP8Separate() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Hercules DJControl Instinct"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 51 && data.outputs.count == 6)
    #expect(profile.hasAutomaticSplitOutput)
    for name in ["DJControl Instinct P8", "DJControl Instinct iPad Edition"] {
        #expect(ControllerFactoryProfile.matching(["Hercules DJControl Instinct", name], automaticOnly: true) == nil)
    }
    let play = try #require(profile.feedback(destination: 20).first { $0.action == .playA })
    #expect(play.number == 22)
    #expect(play.message(value: 1) == [0x90, 22, 0] && play.message(value: 0) == [0x90, 22, 127])
    #expect(data.startup.count == 44 && data.shutdown.count == 7)
    #expect(data.startup.last == [0x90, 53, 0] && data.shutdown.last == [0x90, 53, 127])
    #expect(data.startup.dropLast().count == 43 && data.startup.dropLast().allSatisfy { $0[2] == 127 })
}

@Test @MainActor func controllerCatalogueInstinctFourCuePageAndManualLoopsUsePublishedPressAddresses() {
    withInstinct { input in
        #expect(input.isInputActive(10))
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        instinctPacket(
            [
                0x90, 13, 127, 15, 127, 16, 127, 39, 127, 41, 127, 42, 127,
                9, 127, 10, 127, 11, 127, 12, 127, 0x80, 10, 127, 0x90, 25, 127, 51, 127,
            ], to: input)
        #expect(
            targets == [
                .init(.hotcue1A, deck: .a), .init(.hotcue3A, deck: .a), .init(.hotcue4A, deck: .a),
                .init(.hotcue1B, deck: .b), .init(.hotcue3B, deck: .b), .init(.hotcue4B, deck: .b),
                .init(.loopInA, deck: .a), .init(.loopOutA, deck: .a), .init(.reloopA, deck: .a),
                .init(.loopDownA, deck: .a),
                .init(.loadA, deck: .a), .init(.loadB, deck: .b),
            ])
    }
}

@Test @MainActor func controllerCatalogueInstinctPitchStepsIgnoreZeroAndKeepNativeDirection() {
    withInstinct { input in
        var current = 0.5
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? current : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { current = value; values.append(value) }
        }
        instinctPacket([0xB0, 52, 0], to: input)
        #expect(values.isEmpty)
        instinctPacket([0xB0, 52, 1], to: input)
        #expect(abs(current - (0.5 + 1.0 / 127)) < 0.000001)
        instinctPacket([0xB0, 52, 127], to: input)
        #expect(abs(current - 0.5) < 0.000001)
    }
}

@Test @MainActor func controllerCatalogueInstinctSeparatesFactoryNormalWheelFromPressureStream() {
    withInstinct { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var contacts: [Double] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, value in if target.action == .jogTouchA { contacts.append(value) } }
        instinctPacket([0xB0, 50, 1, 48, 1], to: input)
        #expect(jogs.count == 1 && jogs[0].0.action == .wheelJogA)
        instinctPacket([0x90, 26, 127, 0xB0, 50, 64, 0x80, 26, 127, 0xB0, 50, 1], to: input)
        #expect(contacts == [1, 0])
        #expect(jogs.count == 2 && jogs[1].0.action == .jogA && jogs[1].1 == .relative(-64))
        #expect(jogs.allSatisfy { $0.0.argument == 128 })
    }
}

@Test @MainActor func controllerCatalogueInstinctDisconnectReleasesBothPitchAndPressure() {
    withInstinct { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { target, value in if target.action.isMomentary { events.append((target.action, value)) }
        }
        instinctPacket([0x90, 17, 127, 26, 127], to: input)
        input.sources = []
        input.reconcileFactoryProfiles()
        #expect(Set(events.filter { $0.1 == 0 }.map { $0.0 }) == [.pitchBendDownA, .jogTouchA])
    }
}
