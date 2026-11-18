import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixDeck(
    _ model: String, decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "mixdeck-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    let name = "MixDeck " + model
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    if model == "Express" {
        #expect(!input.isInputActive(10))
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    } else {
        #expect(input.isInputActive(10))
    }
    try body(input)
}

@MainActor private func mixDeckPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMixDeckModelsKeepIndependentIdentityAndFeedbackAddresses() throws {
    let express = try #require(ControllerFactoryProfile.matching(["MixDeck Express"]))
    let quad = try #require(ControllerFactoryProfile.matching(["MixDeck Quad"], automaticOnly: true))
    #expect(express != quad && !express.selectsAutomatically)
    for (profile, count) in [(express, 26), (quad, 49)] {
        let data = try #require(profile.definition)
        #expect(data.inputs.count == count && data.outputs.count == 4)
        #expect(data.startup.isEmpty && !profile.hasAutomaticSplitOutput)
        #expect(!data.inputs.contains { $0.action == .syncA || $0.action == .syncB || $0.action.hotcueSlot != nil })
        let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewB })
        #expect(cue.message(value: 1) == [0x91, 49, 127])
        #expect(cue.message(value: 0) == [0x91, 49, 0])
    }
    #expect(ControllerFactoryProfile.matching(["MixDeck"]) != express)
    #expect(ControllerFactoryProfile.matching(["MixDeck"]) != quad)
}

@Test @MainActor func controllerCatalogueMixDeckTransportAndBothCueReleaseFormsUseTheirOwnNotes() throws {
    for (name, play, cue, load, bend) in [
        ("Express", UInt8(61), UInt8(63), UInt8(78), UInt8(58)), ("Quad", 58, 56, 70, 61),
    ] {
        try withMixDeck(name) { input in
            var events: [(ControllerAction, Double)] = []
            input.onAction = { events.append(($0, $1)) }
            mixDeckPacket(
                [0x90, play, 127, cue, 127, cue, 0, cue, 127, 0x80, cue, 127, 0x91, load, 127, bend, 127, bend, 0],
                to: input)
            #expect(
                events.map(\.0) == [
                    .playA, .cuePreviewA, .cuePreviewA, .cuePreviewA, .cuePreviewA, .loadB, .pitchBendUpB,
                    .pitchBendUpB,
                ])
            #expect(events.map(\.1) == [1, 1, 0, 1, 0, 1, 1, 0])
        }
    }
}

@Test @MainActor func controllerCatalogueMixDeckJogDirectionsPitchAndBrowsingFollowIndependentSources() throws {
    for name in ["Express", "Quad"] {
        try withMixDeck(name) { input in
            var events: [(ControllerAction, Double)] = []
            input.onAction = { events.append(($0, $1)) }
            mixDeckPacket([0xE0, 0, 0], to: input)
            #expect(events.last?.0 == .tempoA && events.last?.1 == 1)
            mixDeckPacket([0xE0, 127, 127], to: input)
            #expect(events.last?.1 == 0)
            mixDeckPacket([0xB0, 34, 1], to: input)
            #expect(events.last?.0 == .jogA)
            #expect(name == "Express" ? (events.last?.1 ?? 0) > 0.5 : (events.last?.1 ?? 1) < 0.5)
            mixDeckPacket([0xB0, 33, 1], to: input)
            #expect(events.last?.0 == .browse && events.last?.1 == 0.5 + 1.0 / 126)
            mixDeckPacket([0xB1, 33, 0], to: input)
            #expect(events.last?.1 == 0.5 - 1.0 / 126)
        }
    }
}

@Test @MainActor func controllerCatalogueMixDeckExpressDoesNotMapItsAnalogueMixerOrOtherModes() throws {
    try withMixDeck("Express") { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in events.append(action) }
        mixDeckPacket([0xB0, 7, 127, 8, 127, 13, 127, 17, 127, 0x90, 68, 127, 69, 127], to: input)
        #expect(events.isEmpty)
        mixDeckPacket([0x90, 80, 127, 0x80, 80, 127, 0x91, 55, 127, 54, 127, 53, 127, 75, 127], to: input)
        #expect(events == [.jogTouchA, .jogTouchA, .loopInB, .loopOutB, .reloopB, .openGroup])
    }
}

@Test @MainActor func controllerCatalogueMixDeckQuadUsesFactoryMixerChannelAndFourExplicitTargets() throws {
    try withMixDeck("Quad") { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        mixDeckPacket([0xB0, 13, 127, 19, 127, 8, 127, 24, 127], to: input)
        #expect(
            Set(events)
                == Set([
                    .init(.levelA, deck: .a), .init(.levelB, deck: .b), .init(.levelA, deck: .c),
                    .init(.levelB, deck: .d),
                ]))
        events.removeAll()
        mixDeckPacket([0xB1, 13, 127, 19, 127, 8, 127, 24, 127], to: input)
        #expect(events.isEmpty)
        mixDeckPacket([0xB0, 7, 127, 18, 127, 66, 127], to: input)
        #expect(Set(events.map(\.action)) == Set([.crossfader, .cueMix, .monitor]))
    }
    try withMixDeck("Quad", decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        mixDeckPacket([0xB0, 8, 127, 24, 127, 12, 127, 28, 127], to: input)
        #expect(events.isEmpty)
    }
}
