import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withTM8(_ allDecks: Bool = true, _ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "tm8-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { allDecks ? DeckID.allCases : DeckID.primary })
    let name = "Terminal Mix 8"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func tm8Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueTM8KeepsFactoryPickupRGBAndSeparateModel() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Terminal Mix 8"], automaticOnly: true))
    #expect(profile.rawValue == "Reloop Terminal Mix 8")
    #expect(profile != ControllerFactoryProfile.matching(["Terminal Mix 4"], automaticOnly: true))
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 208 && data.outputs.count == 52)
    #expect(data.startup == [[0xF0, 0x7E, 0x7F, 0x56, 0x44, 0x4A, 0x20, 0x69, 0x6E, 0x69, 0x74, 0xF7]])
    #expect(data.shutdown.count == 60)
    let colour = try #require(profile.feedback(destination: 20).first { $0.action == .hotcue8B && $0.targetDeck == .d })
    #expect(colour.message(value: 1) == [0x97, 7, 19])
    #expect(colour.message(value: 0) == [0x97, 7, 0])
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewA && $0.targetDeck == .a })
    #expect(cue.message(value: 1) == [0x90, 4, 127])
}

@Test @MainActor func controllerCatalogueTM8ColdLoadAndMixerUseExplicitFourDeckWireChannels() {
    withTM8 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 0..<4 { tm8Packet([0x90 + channel, 16, 127], to: input) }
        #expect(events.compactMap(\.deck) == DeckID.allCases)
        #expect(events.map(\.action) == [.loadA, .loadB, .loadA, .loadB])
        events.removeAll()
        for channel: UInt8 in 0..<4 { tm8Packet([0xB0 + channel, 9, 1, 10, 2, 11, 3, 12, 4, 13, 5, 15, 6], to: input) }
        #expect(events.count == 24)
        #expect(Set(events.compactMap(\.deck)) == Set(DeckID.allCases))
        #expect(!events.contains { $0.action == .master || $0.action == .monitor })
    }
    withTM8(false) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        tm8Packet([0x92, 16, 127, 5, 127, 0x93, 16, 127, 5, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueTM8ShiftAndBankKeepPhysicalSideAndDoNotRetriggerNewCueOnBankRelease() {
    withTM8 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        tm8Packet([0x90, 4, 127, 31, 127, 0x91, 4, 127, 0x90, 68, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewB, .cuePreviewA])
        tm8Packet([0x92, 32, 127, 31, 0, 4, 127], to: input)
        #expect(events.last?.0 == .init(.cuePreviewA, deck: .c) && events.last?.1 == 1)
        let count = events.count
        tm8Packet([0x82, 32, 0], to: input)
        #expect(events.count == count)
        tm8Packet([0x91, 4, 0, 0x92, 4, 0], to: input)
        #expect(events.suffix(2).map { $0.0.deck } == [.b, .c])
    }
}

@Test @MainActor func controllerCatalogueTM8SideShiftGuardsPadsAndResetsMixerPickupAcrossBanks() {
    withTM8 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { $0.action == .highA ? 0.5 : nil }
        input.onTargetAction = { events.append(($0, $1)) }
        tm8Packet([0xB0, 10, 64], to: input)
        #expect(events.count == 1)
        events.removeAll()
        tm8Packet([0x90, 31, 127, 0xB0, 10, 127, 74, 127, 0x94, 0, 127, 64, 127, 0x95, 0, 127], to: input)
        #expect(events.map { $0.0.action } == [.hotcue1B])
        tm8Packet([0x92, 32, 127, 31, 0, 0xB0, 10, 127], to: input)
        #expect(!events.contains { $0.0.action == .highA })
        tm8Packet([0xB0, 10, 64], to: input)
        #expect(events.last?.0.action == .highA)
        tm8Packet([0x94, 0, 0, 64, 0, 0, 127], to: input)
        #expect(events.last?.0.action == .hotcue1A)
    }
}

@Test @MainActor func controllerCatalogueTM8KeepsTouchRimAndFullPitchWithoutSiblingCalibration() {
    withTM8 { input in
        var events: [(ControllerActionTarget, Double)] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.onJogAction = { jogs.append(($0, $1)) }
        tm8Packet([0xB0, 7, 64, 8, 65, 70, 65, 71, 65, 0x90, 8, 127], to: input)
        #expect(jogs.isEmpty && events.isEmpty)
        tm8Packet([0x90, 7, 127, 0xB0, 7, 66, 6, 63], to: input)
        #expect(events.first?.0.action == .jogTouchA && events.first?.1 == 1)
        #expect(jogs.first { $0.0.action == .jogA }?.1 == .relative(2))
        #expect(jogs.first { $0.0.action == .wheelJogA }?.1 == .relative(-1))
        #expect(jogs.allSatisfy { $0.0.argument == nil })
        tm8Packet([0x90, 31, 127, 71, 0], to: input)
        #expect(events.last?.0.action == .jogTouchA && events.last?.1 == 0)
        tm8Packet([0xE0, 0, 64], to: input)
        let centre = events.last?.1 ?? -1
        #expect(events.last?.0.action == .tempoA && abs(centre - 0.5) < 0.0001)
        tm8Packet([0xE0, 1, 64], to: input)
        #expect((events.last?.1 ?? 0) > centre)
    }
}

@Test @MainActor func controllerCatalogueTM8EightCuesAndFourManualLoopPadsKeepOtherModesInactive() {
    withTM8 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for pad: UInt8 in 0..<8 { tm8Packet([0x94, pad, 64, pad, 0], to: input) }
        #expect(events.compactMap { $0.action.hotcueSlot } == Array(0..<8))
        events.removeAll()
        tm8Packet([0x94, 12, 127, 13, 127, 14, 127, 15, 127, 16, 127, 24, 127, 32, 127, 56, 127], to: input)
        #expect(events.map(\.action) == [.loopInA, .loopOutA, .loopDownA, .loopUpA])
        events.removeAll()
        tm8Packet([0x90, 89, 127, 31, 127, 89, 0, 89, 127], to: input)
        #expect(events.map(\.action) == [.keylockA])
    }
}
