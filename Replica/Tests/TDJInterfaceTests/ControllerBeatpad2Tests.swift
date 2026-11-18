import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withBeatpad2(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "beatpad2-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Beatpad 2"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func beatpad2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueBeatpad2KeepsOriginalSeparateAndOwnsOnlyReviewedFeedback() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Beatpad 2"], automaticOnly: true))
    #expect(profile.rawValue == "Reloop Beatpad 2")
    #expect(!BeatpadIdentity.matches("Beatpad 2"))
    #expect(profile != ControllerFactoryProfile.matching(["Beatpad"], automaticOnly: true))
    #expect(ControllerFactoryProfile.matching(["Beatpad 2", "Beatpad"], automaticOnly: true) == nil)
    #expect(profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.startup.isEmpty)
    #expect(data.shutdown.count <= 64)
    #expect(data.inputs.filter { $0.action.isJog }.allSatisfy { $0.argument == nil && $0.encoding == .binaryOffset })
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .hotcue8B })
    #expect(cue.message(value: 1) == [0x93, 7, 11])
    #expect(cue.message(value: 0) == [0x93, 7, 0])
}

@Test @MainActor func controllerCatalogueBeatpad2ColdLoadTransportAndHeldCueUseOwnChannels() {
    withBeatpad2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        beatpad2Packet(
            [0x90, 98, 127, 96, 127, 93, 127, 94, 127, 0x91, 98, 127, 94, 127, 0x80, 94, 127, 0x91, 94, 0], to: input)
        #expect(
            events.map { $0.0.action } == [
                .loadA, .playA, .syncA, .cuePreviewA, .loadB, .cuePreviewB, .cuePreviewA, .cuePreviewB,
            ])
        #expect(events.compactMap { $0.0.deck } == [.a, .a, .a, .a, .b, .b, .a, .b])
        #expect(events.suffix(2).map(\.1) == [0, 0])
    }
}

@Test @MainActor func controllerCatalogueBeatpad2ShiftClearsContactAndBlocksFaderStartPlayCollision() {
    withBeatpad2 { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { target, value in
            if !target.action.isJog { events.append((target.action, value)) }
        }
        beatpad2Packet([0x90, 94, 127, 99, 127, 28, 127, 96, 127, 115, 127], to: input)
        #expect(events.prefix(2).map(\.0) == [.cuePreviewA, .jogTouchA])
        #expect(Set(events.suffix(2).map(\.0)) == Set([.cuePreviewA, .jogTouchA]))
        #expect(events.suffix(2).allSatisfy { $0.1 == 0 })
        beatpad2Packet([0x90, 28, 0, 96, 127, 94, 127], to: input)
        #expect(events.suffix(2).map(\.0) == [.playA, .cuePreviewA])
        beatpad2Packet([0x80, 28, 127], to: input)
        #expect(events.last?.0 == .cuePreviewA && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueBeatpad2JogsAndBrowseUseTheirOwnCentre64DefinitionsAndPitchKeepsCentre() {
    withBeatpad2 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var events: [(ControllerAction, Double)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { events.append(($0.action, $1)) }
        beatpad2Packet([0xB0, 99, 65, 0xB1, 99, 63], to: input)
        #expect(jogs.contains { $0.0 == .init(.jogA, deck: .a) && $0.1 == .relative(1) })
        #expect(jogs.contains { $0.0 == .init(.jogB, deck: .b) && $0.1 == .relative(-1) })
        beatpad2Packet([0xB4, 66, 65], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        beatpad2Packet([0xB4, 66, 63], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        beatpad2Packet([0xE0, 0, 64], to: input)
        #expect(events.last?.0 == .tempoA && events.last?.1 == 0.5)
        beatpad2Packet([0xE0, 1, 64], to: input)
        #expect(events.last?.0 == .tempoA && (events.last?.1 ?? 0) > 0.5)
    }
}

@Test @MainActor func controllerCatalogueBeatpad2EightCueNotesKeepVelocityAftertouchAndOtherModesInactive() {
    withBeatpad2 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 2...3 {
            for number: UInt8 in 0...7 { beatpad2Packet([0x90 + channel, number, 80, number, 0], to: input) }
        }
        #expect(events.compactMap { $0.action.hotcueSlot } == Array(0..<8) + Array(0..<8))
        events.removeAll()
        beatpad2Packet(
            [0x92, 16, 127, 24, 127, 32, 127, 40, 127, 48, 127, 56, 127, 64, 127, 0xB2, 0, 127, 0xA2, 0, 127], to: input
        )
        #expect(events.isEmpty)
        beatpad2Packet([0x92, 0, 127, 64, 127, 64, 0, 0, 127], to: input)
        #expect(events.map(\.action) == [.hotcue1A, .hotcue1A])
    }
}

@Test @MainActor func controllerCatalogueBeatpad2EQMessagesFollowPhysicalFunctionAndShiftRearmsPickup() {
    withBeatpad2 { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { target, value in
            if !target.action.isJog { events.append((target.action, value)) }
        }
        input.currentTargetValue = { $0.action == .midA ? 0.5 : nil }
        beatpad2Packet([0xB0, 75, 64, 76, 64, 77, 64, 78, 64, 73, 64, 79, 80], to: input)
        #expect(Set(events.map(\.0)) == Set([.gainA, .highA, .midA, .lowA, .filterKnobA, .levelA]))
        events.removeAll()
        beatpad2Packet([0x90, 28, 127, 0xB0, 77, 127, 13, 127, 0x90, 28, 0, 0xB0, 77, 127], to: input)
        #expect(events.isEmpty)
        beatpad2Packet([0xB0, 77, 64], to: input)
        #expect(events.last?.0 == .midA && events.last?.1 == 0.5)
    }
}
