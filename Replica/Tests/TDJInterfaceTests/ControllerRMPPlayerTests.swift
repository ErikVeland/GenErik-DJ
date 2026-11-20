import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let rmpNames = ["Reloop RMP-3", "Reloop RMP-2.5a"]
private let rmpButtons: [[(ControllerAction, UInt8, UInt8)]] = [
    [
        (.playA, 1, 64), (.cuePreviewA, 7, 70), (.loopInA, 22, 85), (.loopOutA, 46, 109), (.reloopA, 34, 97),
        (.keylockA, 20, 83), (.pitchBendDownA, 8, 71), (.pitchBendUpA, 2, 65),
    ],
    [
        (.playA, 6, 69), (.cuePreviewA, 7, 70), (.loopInA, 12, 75), (.loopOutA, 13, 76), (.reloopA, 11, 74),
        (.keylockA, 19, 82), (.pitchBendDownA, 21, 84), (.pitchBendUpA, 20, 83),
    ],
]
private let rmpCues: [[(UInt8, UInt8)]] = [
    [(28, 91), (10, 73), (16, 79), (15, 78)], [(27, 90), (25, 88), (26, 89), (15, 78)],
]

@MainActor private func withRMP(
    _ name: String, decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "rmp-player-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The RMP preset input core must not write to hardware."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11, 12, 13].map { id in
        .init(
            id: id, reference: UInt32(id), name: name,
            identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    for (index, source) in [Int32(10), 11, 12, 13].enumerated() {
        #expect(input.isInputActive(source) == (index < decks.count))
        #expect(input.playerDeck(source: source) == (index < decks.count ? decks[index] : nil))
    }
    try body(input)
}

@MainActor private func rmpPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRMPPlayersKeepSeparateManufacturerIdentitiesAndNoWrites() throws {
    for (index, name) in rmpNames.enumerated() {
        let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
        #expect(d.isValid && p.selectsAutomatically && p.isPlayer && d.inputs.count == 38)
        #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
        for alias in index == 0 ? ["RMP-3B", "RMP-3H"] : ["RMP-25", "RMP-25H", "RMP-2.5 Alpha"] {
            #expect(ControllerFactoryProfile.matching([alias]) == p)
        }
        for other in [rmpNames[1 - index], "RMP-3 Alpha", "RMP-4"] {
            #expect(ControllerFactoryProfile.matching([other]) != p)
        }
        withRMP(name) { _ in }
    }
}

@Test @MainActor func controllerCatalogueRMPPlayersNormalButtonsAndShiftedReleaseAliasesRearm() {
    for (index, name) in rmpNames.enumerated() {
        withRMP(name) { input in
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for (action, n, release) in rmpButtons[index] where !action.isMomentary {
                events.removeAll(); rmpPacket([0x9F, release, 127], input); #expect(events.isEmpty)
                rmpPacket([0x9F, n, 127, n, 127, release, 0, n, 1, 0x8F, n, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == .init(action, deck: .a) })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueRMPPlayersCueAndBendsKeepBothReleaseFormsAcrossAllChannels() {
    for (index, name) in rmpNames.enumerated() {
        withRMP(name) { input in
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for ch: UInt8 in 0..<16 {
                for (action, n, release) in rmpButtons[index] where action.isMomentary {
                    for velocity: UInt8 in [1, 64, 127] {
                        for off: UInt8 in [0x80, 0x90] {
                            events.removeAll();
                            rmpPacket(
                                [0x90 + ch, n, velocity, n, velocity, off + ch, release, off == 0x80 ? 127 : 0], input)
                            #expect(
                                events.map(\.1) == [Double(velocity) / 127, 0]
                                    && events.allSatisfy { $0.0 == .init(action, deck: .a) })
                        }
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueRMPPlayersEightHotCuesRearmAcrossEitherPhysicalLayer() {
    for (index, name) in rmpNames.enumerated() {
        withRMP(name) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            for (slot, pair) in rmpCues[index].enumerated() {
                for (n, release, target) in [(pair.0, pair.1, slot), (pair.1, pair.0, slot + 4)] {
                    events.removeAll(); rmpPacket([0x90, n, 127, n, 127, 0x9F, release, 0, 0x90, n, 1, n, 0], input)
                    #expect(events.count == 2 && events.allSatisfy { $0.deck == .a && $0.action.hotcueSlot == target })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueRMPPlayersSourcesOwnAssignmentsAcrossChannelsAndCDOptIn() {
    for name in rmpNames {
        withRMP(name) { input in
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            for (index, source) in [Int32(10), 11, 12, 13].enumerated() {
                rmpPacket([0x9F, 7, 127], input, source: source)
                #expect(
                    events.last?.0
                        == .init(
                            ControllerAction.cuePreviewA.assigned(to: DeckID.allCases[index]),
                            deck: DeckID.allCases[index]))
            }
            events.removeAll(); rmpPacket([0x80, 70, 127], input)
            #expect(events.count == 1 && events.first?.0.deck == .a && events.first?.1 == 0)
            rmpPacket([0x81, 70, 127], input, source: 11); #expect(events.last?.0.deck == .b && events.last?.1 == 0)
        }
        withRMP(name, decks: DeckID.primary) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            rmpPacket([0x90, 7, 127], input, source: 12); rmpPacket([0x90, 7, 127], input, source: 13)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueRMPPlayersNoteNavigationAndInactiveVariableFormats() {
    for (index, name) in rmpNames.enumerated() {
        withRMP(name) { input in
            var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
            let folders: [UInt8] = index == 0 ? [13, 19] : [4, 5]
            for (n, action): (UInt8, ControllerAction) in [
                (50, .browseNext), (51, .browsePrevious), (113, .browseNextGroup), (114, .browsePreviousGroup),
                (folders[0], .browseNextGroup), (folders[1], .browsePreviousGroup),
            ] {
                events.removeAll(); rmpPacket([0x9F, n, 127, n, 127, 0x8F, n, 127], input)
                #expect(events == [.init(action), .init(action)])
            }
            events.removeAll()
            rmpPacket(
                [0xBF, 50, 65, 53, 65, 55, 65, 57, 65, 116, 127, 0xEF, 0, 64, 0x9F, 66, 127, 66, 0, 24, 127, 24, 0],
                input)
            #expect(events.isEmpty)
        }
    }
}
