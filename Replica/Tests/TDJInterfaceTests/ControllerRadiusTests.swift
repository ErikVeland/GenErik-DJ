import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRadius(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "radius-player-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Radius 2000 MIDI 1"
    input.sources = [
        .init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name])),
        .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 2, names: [name])),
    ]
    input.destinations = [
        .init(id: 30, reference: 300, name: name, identity: .init(id: 30, device: 1, names: [name])),
        .init(id: 40, reference: 400, name: name, identity: .init(id: 40, device: 2, names: [name])),
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(20))
    try body(input)
}

@MainActor private func radiusPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRadiusKeepsPhysicalModelAndFactoryDefaultChannel() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Radius 2000 MIDI 1"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(profile.isPlayer && !profile.hasAutomaticSplitOutput)
    #expect(data.inputs.count == 41 && data.outputs.count == 7)
    #expect(data.startup.count == 31 && data.shutdown.count == 31)
    #expect(data.inputs.allSatisfy { $0.channel == 0 })
    #expect(ControllerFactoryProfile.matching(["Radius 1000"], automaticOnly: true) != profile)
    #expect(ControllerFactoryProfile.matching(["Radius 3000"], automaticOnly: true) != profile)
    withRadius { input in
        #expect(input.playerDeck(source: 10) == .a && input.playerDeck(source: 20) == .b)
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        radiusPacket([0x90, 42, 127, 31, 127], to: input, source: 20)
        #expect(events.map(\.action) == [.playB, .loadB])
        radiusPacket([0x91, 42, 127, 0x90, 19, 127], to: input)
        #expect(events.count == 2)
    }
}

@Test @MainActor func controllerCatalogueRadiusTapReleasesOnlyOwnedCueBendTouchAndCues() {
    withRadius { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        radiusPacket([0x90, 48, 127, 7, 127, 38, 127, 22, 127, 111, 127, 70, 127, 101, 127, 85, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .pitchBendDownA, .jogTouchA, .hotcue1A])
        radiusPacket([0x90, 111, 0, 70, 0, 101, 0, 85, 0], to: input)
        #expect(events.suffix(3).map { $0.0.action } == [.cuePreviewA, .pitchBendDownA, .jogTouchA])
        #expect(events.suffix(3).allSatisfy { $0.1 == 0 })
        radiusPacket([0x90, 22, 127], to: input)
        #expect(events.last?.0.action == .hotcue1A)
    }
}

@Test @MainActor func controllerCatalogueRadiusWheelsPitchAndLoopControlsUseFactoryAddresses() {
    withRadius { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var events: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { events.append(($0, $1)) }
        radiusPacket([0xB0, 53, 64, 116, 65], to: input)
        #expect(jogs.isEmpty)
        radiusPacket([0xB0, 53, 66], to: input)
        #expect(jogs.last?.0.argument == 990 && jogs.last?.1 == .relative(2))
        radiusPacket([0xE0, 0, 0], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 1)
        radiusPacket([0xE0, 127, 127], to: input)
        #expect(events.last?.1 == 0)
        events.removeAll()
        radiusPacket([0x90, 11, 127, 5, 127, 23, 127, 14, 127, 8, 127, 2, 127, 25, 127], to: input)
        #expect(
            events.map { $0.0.action } == [
                .loopInA, .loopOutA, .reloopA, .loopDownA, .loopUpA, .fixedLoopA, .openGroup,
            ])
        #expect(events.first { $0.0.action == .fixedLoopA }?.0.argument == 4)
        events.removeAll()
        radiusPacket([0xB0, 56, 64, 54, 0], to: input)
        #expect(events.isEmpty)
        radiusPacket([0xB0, 56, 65, 54, 63], to: input)
        #expect(Set(events.map { $0.0.action }) == [.browse, .browseGroups])
    }
}

@Test @MainActor func controllerCatalogueRadiusLightsFollowAssignedPlayerAndReconnect() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Radius 2000 MIDI 1"]))
    let light = try #require(profile.feedback(destination: 40, playerDeck: .b).first { $0.action == .cuePreviewB })
    #expect(light.targetDeck == .b && light.message(value: 1) == [0x90, 48, 127])
    withRadius { input in
        input.setFeedbackDestination(40)
        #expect(input.selectedFeedbackBindings.count == 7)
        #expect(input.selectedFeedbackBindings.allSatisfy { $0.targetDeck == .b })
        input.setPlayerDeck(.a, source: 20)
        #expect(input.playerDeck(source: 20) == .a && input.playerDeck(source: 10) == .b)
        #expect(input.selectedFeedbackBindings.allSatisfy { $0.targetDeck == .a })
        input.setMIDIFeedbackEnabled(false)
        input.setMIDIFeedbackEnabled(true)
        #expect(input.selectedFeedbackBindings.allSatisfy { $0.targetDeck == .a })
        input.selected = 10
        input.applyFactoryFeedbackProfile(profile)
        #expect(input.selectedFeedbackBindings.allSatisfy { $0.targetDeck == .a })
        input.setPlayerDeck(.b, source: 20)
        #expect(input.selectedFeedbackBindings.count == 7)
        #expect(input.selectedFeedbackBindings.allSatisfy { $0.targetDeck == .b })
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        #expect(input.playerDeck(source: 20) == .b)
        #expect(input.selectedFeedbackBindings.allSatisfy { $0.targetDeck == .b })
    }
}

@Test func controllerCatalogueRadiusPlayerLightAssignmentKeepsGlobalAndWireMetadata() {
    let source = ControllerFeedbackBinding(
        destination: 40, action: .cuePreviewA, kind: .note, channel: 0,
        number: 48, offValue: 0, onValue: 127, offUsesNoteOn: true, targetDeck: .a, offNumber: 49)
    let assigned = source.assigned(to: .d)
    #expect(assigned.action == .cuePreviewB && assigned.targetDeck == .d)
    #expect(assigned.destination == 40 && assigned.channel == 0 && assigned.number == 48 && assigned.offNumber == 49)
    #expect(assigned.offUsesNoteOn == true && assigned.onValue == 127 && assigned.offValue == 0)
    #expect(source.assigned(to: nil) == source)
    let global = ControllerFeedbackBinding(
        destination: 40, action: .master, kind: .control, channel: 3,
        number: 10, offValue: 0, onValue: 127)
    #expect(global.assigned(to: .b) == global)
}
