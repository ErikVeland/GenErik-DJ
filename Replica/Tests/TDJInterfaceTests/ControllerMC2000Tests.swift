import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMC2000(_ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void) rethrows {
    let suite = "mc2000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        },
        deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(id: 10, reference: 100, name: "MC2000", identity: .init(id: 10, device: 1, names: ["MC2000"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "MC2000", identity: .init(id: 20, device: 1, names: ["MC2000"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func mc2000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMC2000KeepsFactorySetupAndSeparateLEDTriggers() throws {
    try withMC2000 { input, packets in
        #expect(input.isInputActive(10))
        #expect(packets == [[0xB0, 74, 6], [0xB0, 74, 57], [0xB1, 74, 6], [0xB1, 74, 57]])
        let profile = try #require(ControllerFactoryProfile.matching(["Denon DJ MC2000"], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == 55 && data.outputs.count == 18)
        #expect(ControllerFactoryProfile.matching(["MC2000 MK2"]) == nil)
        let outputs = profile.feedback(destination: 20)
        let play = try #require(outputs.first { $0.action == .playA })
        #expect(play.number == 74 && play.offNumber == 75 && play.onValue == 39 && play.offValue == 39)
        let cue = try #require(outputs.first { $0.action == .cueB })
        #expect(cue.channel == 1 && cue.number == 80 && cue.offNumber == 81 && cue.onValue == 81 && cue.offValue == 81)
    }
}

@Test @MainActor func controllerCatalogueMC2000UsesFactoryRightMixerAndGlobalLoadAddresses() {
    withMC2000 { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in events.append((target, value)) }
        mc2000Packet([0x90, 67, 64, 98, 64, 99, 64, 0x91, 5, 64], to: input)
        #expect(
            events.map(\.0) == [
                .init(.playA, deck: .a), .init(.loadA, deck: .a), .init(.loadB, deck: .b), .init(.cueB, deck: .b),
            ])
        events.removeAll()
        mc2000Packet([0xB1, 12, 127, 13, 127, 14, 127, 15, 127, 16, 127, 0xB0, 25, 127], to: input)
        #expect(Set(events.map(\.0.action)) == [.gainB, .highB, .midB, .lowB, .levelB, .master])
        events.removeAll()
        mc2000Packet([0xB1, 1, 0, 0x91, 99, 64, 0xB0, 41, 0], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMC2000GuardsShiftAndFinishesFactoryCueAndTouchReleases() {
    withMC2000 { input, _ in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { target, value in events.append((target.action, value)) }
        mc2000Packet([0x90, 66, 64, 81, 64, 96, 64, 67, 64, 23, 64, 0x80, 66, 0, 86, 0], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .jogTouchA, .cuePreviewA, .jogTouchA])
        #expect(events.map(\.1).map { $0 > 0 } == [true, true, false, false])
        events.removeAll()
        mc2000Packet([0x80, 23, 0, 96, 0, 0x90, 23, 64, 24, 64, 25, 64, 32, 64], to: input)
        #expect(events.map(\.0) == [.hotcue1A, .hotcue2A, .hotcue3A, .hotcue4A])
        events.removeAll()
        mc2000Packet([0x90, 33, 64, 34, 64, 35, 64, 36, 64, 0x91, 49, 64, 50, 64, 51, 64, 52, 64], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMC2000UsesDistinctVinylAndBendReportsWithZeroNeutral() {
    withMC2000 { input, _ in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { target, value in jogs.append((target, value)) }
        mc2000Packet([0xB0, 81, 65], to: input)
        mc2000Packet([0xB1, 82, 63], to: input)
        mc2000Packet([0xB0, 81, 0, 81, 64, 83, 65], to: input)
        #expect(jogs.map(\.0) == [.init(.jogA, deck: .a), .init(.wheelJogB, deck: .b)])
        #expect(jogs.map(\.1) == [.relative(1), .relative(-1)])
    }
}

@Test @MainActor func controllerCatalogueMC2000PitchRetainsFourteenBitsAndCentrePickup() {
    withMC2000 { input, _ in
        var tempos: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { tempos.append(value) } }
        mc2000Packet([0xE0, 127, 127], to: input)
        #expect(tempos.isEmpty)
        mc2000Packet([0xE0, 0, 64], to: input)
        mc2000Packet([0xE0, 1, 64], to: input)
        #expect(tempos.count == 2 && tempos[0] == 0.5 && tempos[1] < 0.5)
        #expect(abs(tempos[1] - (0.5 - 1.0 / 16382)) < 0.0000001)
    }
}
