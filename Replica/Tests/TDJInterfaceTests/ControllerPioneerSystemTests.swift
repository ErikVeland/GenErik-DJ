import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let pioneerSystemNames = ["XDJ-AZ", "XDJ-RX3", "XDJ-XZ", "DDJ-FLX6", "DDJ-FLX6-GT", "DDJ-800", "DDJ-SB3"]

@MainActor private func withPioneerSystem(
    _ name: String, decks: (() -> [DeckID])? = nil,
    body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "pioneer-system-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let controller = ControllerMIDIConnection(preferences: preferences, deckAvailability: decks)
    controller.sources = [
        .init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))
    ]
    controller.reconcileFactoryProfiles()
    try body(controller)
}

@MainActor private func pioneerPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerPioneerSystemsMatchExactModelsWithoutGuessingVariants() throws {
    for name in pioneerSystemNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(!profile.isPlayer)
        #expect(profile.bindings(source: 10).allSatisfy { $0.anyChannel != true })
        #expect(profile.definition?.startup.isEmpty == true)
    }
    for name in ["DDJ-FLX6-GT clone", "DDJ-SB2 clone", "DDJ-800SRT", "XDJ-AZ clone", "XDJ-RX4"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
    #expect(ControllerFactoryProfile.matching(["XDJ-AZ", "XDJ-XZ"], automaticOnly: true) == nil)
    let flx6 = try #require(ControllerFactoryProfile.matching(["DDJ-FLX6"]))
    #expect(!flx6.bindings(source: 10).contains { $0.action == .keylockA || $0.action == .keylockB })
}

@Test @MainActor func controllerPioneerSystemsDispatchDocumentedDecksAndBlockInactiveDecks() {
    for name in pioneerSystemNames {
        let play: UInt8 = name.hasPrefix("XDJ") ? 0 : 11
        withPioneerSystem(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            for channel: UInt8 in 0..<4 { pioneerPacket([0x90 | channel, play, 127], to: input) }
            #expect(targets == [.init(.playA, deck: .a), .init(.playB, deck: .b)])
        }
        withPioneerSystem(name, decks: { DeckID.allCases }) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            for channel: UInt8 in 0..<4 { pioneerPacket([0x90 | channel, play, 127], to: input) }
            #expect(
                targets == [
                    .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.playA, deck: .c), .init(.playB, deck: .d),
                ])
        }
    }
}

@Test @MainActor func controllerPioneerSystemsUseSeparateHotCuePadLayouts() {
    for name in pioneerSystemNames {
        withPioneerSystem(name, decks: { DeckID.allCases }) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            for channel: UInt8 in 0..<4 {
                let club = name.hasPrefix("XDJ")
                let pad = name == "XDJ-AZ" || club ? 5 + channel : name == "DDJ-SB3" ? 7 + channel : 7 + 2 * channel
                pioneerPacket([0x90 | pad, 0, 127], to: input)
                pioneerPacket([0x90 | (name == "XDJ-AZ" ? pad + 4 : pad), name == "XDJ-AZ" ? 57 : 7, 127], to: input)
            }
            let expected: [ControllerActionTarget] = DeckID.allCases.flatMap { deck in
                [
                    .init(deck.leftSide ? .hotcue1A : .hotcue1B, deck: deck),
                    .init(deck.leftSide ? .hotcue8A : .hotcue8B, deck: deck),
                ]
            }
            #expect(targets == expected)
        }
    }
}

@Test @MainActor func controllerPioneerSystemsDecodeHighResolutionAndModelSpecificMixerDirection() throws {
    for name in pioneerSystemNames {
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        let tempo = try #require(profile.bindings(source: 10).first { $0.action == .tempoA })
        #expect(tempo.mode == .paired14Bit)
        var state = ControllerMIDIValueState()
        var decoder = ControllerMIDIDecoder()
        let msb = try #require(decoder.append([0xB0, 0, 65]).first)
        let lsb = try #require(decoder.append([0xB0, 32, 7]).first)
        #expect(state.decode(msb, encoding: tempo.mode, number: tempo.number) == .absolute(Double(65 * 128) / 16383))
        #expect(
            state.decode(lsb, encoding: tempo.mode, number: tempo.number) == .absolute(Double(65 * 128 + 7) / 16383))
        withPioneerSystem(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            if name.hasPrefix("XDJ") {
                pioneerPacket([0xB4, 17, 0], to: input)
            } else {
                pioneerPacket([0xB0, 19, 0, 51, 0], to: input)
            }
            input.flushPendingActions()
            #expect(received.count == 1)
            #expect(received.first?.0 == .init(.levelA, deck: .a))
            #expect(received.first?.1 == (name == "XDJ-AZ" ? 1 : 0))
        }
    }
}

@Test @MainActor func controllerPioneerSystemsReleaseTouchesAndDiscardQueuedControlsWhenCapacityShrinks() {
    var decks = DeckID.allCases
    withPioneerSystem("DDJ-FLX6", decks: { decks }) { input in
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        pioneerPacket([0x92, 54, 127, 0xB2, 19, 127, 51, 127], to: input)
        decks = DeckID.primary
        input.flushPendingActions()
        pioneerPacket([0x82, 54, 0, 0x92, 11, 127, 0xB2, 19, 0, 51, 0], to: input)
        input.flushPendingActions()
        #expect(received.map(\.0) == [.init(.jogTouchA, deck: .c), .init(.jogTouchA, deck: .c)])
        #expect(received.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerPioneerSystemsKeepBrowseBeforeLoadAndAcceptFirstHeadphonePress() {
    for name in pioneerSystemNames {
        withPioneerSystem(name) { input in
            let club = name.hasPrefix("XDJ")
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            pioneerPacket(club ? [0xB4, 70, 127] : [0x90, 84, 127], to: input)
            pioneerPacket(club ? [0xB0, 79, 127, 0x90, 81, 127] : [0xB6, 64, 127, 0x96, 70, 127], to: input)
            #expect(received.map(\.0) == [.init(.cueA, deck: .a), .init(.browse), .init(.loadA, deck: .a)])
            #expect(received.count == 3)
            #expect(received[1].1 < 0.5)
        }
    }
}

@Test @MainActor func controllerPioneerSystemsKeepLoopMessagesAndFeedbackModelSpecific() throws {
    for name in pioneerSystemNames {
        withPioneerSystem(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            if name == "DDJ-SB3" {
                pioneerPacket([0x90, 20, 127, 18, 127, 19, 127, 80, 127], to: input)
                #expect(
                    targets == [
                        .init(.loopA, deck: .a), .init(.loopDownA, deck: .a), .init(.loopUpA, deck: .a),
                        .init(.reloopA, deck: .a),
                    ])
            } else {
                let club = name.hasPrefix("XDJ")
                pioneerPacket(
                    [0x90, club ? 6 : 16, 127, club ? 7 : 17, 127, club ? 8 : 77, 127, club ? 69 : 20, 127], to: input)
                #expect(
                    targets == [
                        .init(.loopInA, deck: .a), .init(.loopOutA, deck: .a), .init(.reloopA, deck: .a),
                        .init(.fixedLoopA, deck: .a, argument: 4),
                    ])
            }
        }
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        let feedback = profile.feedback(destination: 20)
        #expect(
            feedback.contains {
                $0.action == .playA && $0.channel == 0 && $0.number == (name.hasPrefix("XDJ") ? 0 : 11)
            })
        if name != "DDJ-SB3" { #expect(!feedback.contains { $0.action.hotcueSlot != nil }) }
        if name == "XDJ-AZ" || name == "XDJ-XZ" { #expect(!feedback.contains { $0.action == .cueA }) }
    }
}
