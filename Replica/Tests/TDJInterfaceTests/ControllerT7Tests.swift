import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withT7(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "t7-manual-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Hercules DJControl Inpulse T7"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func t7Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueT7StaysManualAndNeverEmitsMotorOrSpeedCommands() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJControl Inpulse T7"]))
    #expect(ControllerFactoryProfile.matching(["DJControl Inpulse T7"], automaticOnly: true) == nil)
    #expect(profile != ControllerFactoryProfile.matching(["DJControl Inpulse 500"], automaticOnly: true))
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.startup.isEmpty)
    #expect(!data.inputs.contains { $0.kind == .pitch || $0.action.isJog || $0.action == .crossfader })
    for bytes in data.startup + data.shutdown {
        #expect(!([0x91, 0x92].contains(bytes[0]) && bytes[1] == 127))
        #expect(!([0xB1, 0xB2].contains(bytes[0]) && [8, 40].contains(bytes[1])))
    }
    #expect(data.outputs.allSatisfy { $0.kind == .note && $0.number != 127 })
}

@Test @MainActor func controllerCatalogueT7NormalTransportAndShiftedLoadKeepTheirOwnDecks() throws {
    try withT7 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        t7Packet([0x91, 7, 127, 5, 127, 13, 127, 0x92, 7, 127, 5, 127, 13, 127], to: input)
        #expect(events.map(\.action) == [.playA, .syncA, .loadA, .playB, .syncB, .loadB])
        events.removeAll()
        t7Packet([0x94, 13, 0, 13, 127, 0x95, 13, 0, 13, 127], to: input)
        #expect(events.map(\.action) == [.loadA, .loadB])
    }
}

@Test @MainActor func controllerCatalogueT7CueAndBendReleasesCrossShiftWithoutRetrigger() throws {
    try withT7 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        t7Packet([0x91, 6, 127, 83, 127, 0x94, 6, 127, 0x84, 6, 127, 83, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .pitchBendUpA, .cuePreviewA, .pitchBendUpA])
        #expect(events.map(\.1) == [1, 1, 0, 0])
        t7Packet([0x92, 6, 127, 84, 127, 0x95, 6, 0, 84, 0], to: input)
        #expect(events.suffix(2).map { $0.0.action } == [.cuePreviewB, .pitchBendDownB])
        #expect(events.suffix(2).map(\.1) == [0, 0])
    }
}

@Test @MainActor func controllerCatalogueT7PlatterClocksCannotBecomeTempoOrJogAndCCPairsStayOnTheirDeck() throws {
    try withT7 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        t7Packet([0xB1, 9, 127, 0xE1, 0, 64, 0xB4, 9, 0, 0xE4, 127, 127, 0x91, 127, 127], to: input)
        #expect(events.isEmpty)
        t7Packet([0xB1, 8, 64, 0xB2, 40, 0], to: input)
        #expect(events.count == 1 && events[0].0 == .init(.tempoA, deck: .a))
        #expect(abs(events[0].1 - 0.5) < 0.0001)
        t7Packet([0xB1, 40, 127], to: input)
        #expect(events.count == 2 && events[1].0 == .init(.tempoA, deck: .a))
        #expect(events[1].1 > events[0].1)
        t7Packet([0xB2, 8, 32], to: input)
        #expect(events.count == 3 && events[2].0 == .init(.tempoB, deck: .b))
        #expect(abs(events[2].1 - 0.25) < 0.0001)
    }
}

@Test @MainActor func controllerCatalogueT7CueAndLoopPagesDoNotAliasShiftClearRollsOrOtherModes() throws {
    try withT7 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for number: UInt8 in 0...7 { t7Packet([0x96, number, 127, number, 0], to: input) }
        #expect(events.compactMap { $0.action.hotcueSlot } == Array(0..<8))
        events.removeAll()
        for number: UInt8 in 16...23 { t7Packet([0x97, number, 127, number, 0], to: input) }
        #expect(events.compactMap(\.argument) == [0.25, 0.5, 1, 2, 4, 8, 16, 32])
        #expect(events.allSatisfy { $0.deck == .b && $0.action == .toggleFixedLoopB })
        events.removeAll()
        t7Packet([0x96, 8, 127, 24, 127, 32, 127, 48, 127, 64, 127, 80, 127, 96, 127, 112, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueT7LoopEncoderAndBrowserRetainMeasuredDirections() throws {
    try withT7 { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        t7Packet([0xB1, 14, 1], to: input)
        #expect(events.last?.0 == .loopSizeA && events.last?.1 == 0.5 + 1.0 / 126)
        t7Packet([0xB1, 14, 127], to: input)
        #expect(events.last?.0 == .loopSizeA && events.last?.1 == 0.5 - 1.0 / 126)
        t7Packet([0xB2, 15, 1], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        t7Packet([0xB2, 15, 127], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        let count = events.count
        t7Packet([0xB1, 14, 64, 0xB2, 15, 0], to: input)
        #expect(events.count == count)
    }
}
