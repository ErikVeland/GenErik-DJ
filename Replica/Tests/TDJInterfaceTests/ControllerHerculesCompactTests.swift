import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withHerculesCompact(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "hercules-compact-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Hercules DJControl Compact"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func compactPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueHerculesCompactKeepsFactoryVolumeAndNoInventedTouchOrRouting() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Hercules DJControl Compact"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 71 && data.outputs.count == 8)
    #expect(data.startup.count == 12 && data.shutdown == data.startup)
    #expect(data.startup.allSatisfy { $0[0] == 0x90 && $0[2] == 0 })
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(!data.inputs.contains { [.gainA, .gainB, .highA, .highB, .jogTouchA, .jogTouchB].contains($0.action) })
    withHerculesCompact { input in
        #expect(input.isInputActive(10))
        var events: [(ControllerAction, Double)] = []
        input.currentTargetValue = { _ in 0.5 }
        input.onTargetAction = { events.append(($0.action, $1)) }
        compactPacket([0xB0, 0x39, 0, 0x3D, 0], to: input)
        #expect(events.isEmpty)
        compactPacket([0xB0, 0x39, 64, 0x3D, 64], to: input)
        #expect(Set(events.map { $0.0 }) == [.levelA, .levelB])
        #expect(events.allSatisfy { abs($0.1 - 64.0 / 127) < 0.000001 })
    }
}

@Test @MainActor func controllerCatalogueHerculesCompactTempoKeepsSourceAccelerationDirectionAndLimits() {
    withHerculesCompact { input in
        var current = 0.6
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? current : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { current = value; values.append(value) }
        }
        compactPacket([0xB0, 0x37, 0], to: input)
        #expect(values.isEmpty && current == 0.6)
        compactPacket([0xB0, 0x37, 1], to: input)
        #expect(abs(current - 0.5995) < 0.000001)
        compactPacket([0xB0, 0x37, 126], to: input)
        #expect(abs(current - 0.6015) < 0.000001)
        compactPacket([0xB0, 0x37, 64], to: input)
        #expect(current == 1)
        compactPacket([0xB0, 0x37, 63], to: input)
        #expect(current == 0)
    }
}

@Test func controllerCatalogueHerculesCompactTempoRejectsOtherWireKindsAndCannotBeLearned() {
    var state = ControllerMIDIValueState()
    var decoder = ControllerMIDIDecoder()
    let packets: [[UInt8]] = [[0x90, 0x37, 1], [0xE0, 1, 0], [0xB0, 0x38, 1]]
    for packet in packets {
        for message in decoder.append(packet) {
            #expect(state.decode(message, encoding: .compactTempo, number: 0x37) == nil)
        }
    }
    #expect(ControllerMIDIEncoding.compactTempo.isRelative)
    #expect(!ControllerMIDIEncoding.compactTempo.supportsLearning)
}

@Test @MainActor func controllerCatalogueHerculesCompactHardwarePagesDoNotTriggerOtherModes() {
    withHerculesCompact { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        compactPacket(
            [
                0x90, 1, 127, 0x80, 5, 127, 0x90, 5, 127, 1, 127, 0x31, 127,
                0x19, 127, 0x1A, 127, 0x1B, 127, 0x1C, 127, 0x4A, 127,
            ], to: input)
        #expect(
            targets == [
                .init(.hotcue1A, deck: .a), .init(.clearHotcue1A, deck: .a), .init(.hotcue1A, deck: .a), .init(.hotcue1B, deck: .b),
                .init(.reloopA, deck: .a), .init(.toggleFixedLoopA, deck: .a, argument: 8),
                .init(.loopDownA, deck: .a), .init(.loopUpA, deck: .a),
                .init(.toggleFixedLoopB, deck: .b, argument: 8),
            ])
        targets.removeAll()
        compactPacket(
            [
                0x90, 9, 127, 0x11, 127, 0x1D, 127, 0x2B, 127, 0x2D, 127, 0x30, 127,
                0x39, 127, 0x41, 127, 0x4D, 127,
            ], to: input)
        #expect(targets.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueHerculesCompactShiftReleaseKeepsCueAndIndependentWheelMotion() {
    withHerculesCompact { input in
        var cues: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { cues.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        compactPacket(
            [
                0x90, 0x22, 127, 0x80, 0x25, 127, 0x90, 0x22, 127, 0x22, 0,
                0xB0, 0x30, 1, 0x31, 127,
            ], to: input)
        #expect(cues == [1, 0, 1, 0])
        #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 256 })
        #expect(jogs.first { $0.0.action == .wheelJogA }?.1 == .relative(1))
        #expect(jogs.first { $0.0.action == .wheelJogB }?.1 == .relative(-1))
    }
}
