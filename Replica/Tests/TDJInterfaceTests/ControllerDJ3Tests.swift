import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJ3(decks: [DeckID] = [.a, .b], _ body: (ControllerMIDIConnection) throws -> Void) rethrows
{
    let suite = "dj3-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "Faderfox DJ3", identity: .init(id: 10, device: 1, names: ["Faderfox DJ3"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func dj3Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDJ3KeepsNamedIdentityAndNoCopiedPotOrLampSetup() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Faderfox DJ3"], automaticOnly: true))
    #expect(!profile.hasAutomaticSplitOutput)
    for name in ["USB Audio Device", "Faderfox DJ2", "DJ2", "Faderfox DJ4"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 392 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(
        !data.inputs.contains {
            $0.action.isJog
                || [.highA, .highB, .midA, .midB, .lowA, .lowB, .filterKnobA, .filterKnobB].contains($0.action)
        })
}

@Test @MainActor func controllerCatalogueDJ3AcceptsFourSelectableChannelsAndKeepsCDOptIn() {
    for decks: [DeckID] in [[.a, .b], DeckID.allCases] {
        withDJ3(decks: decks) { input in
            #expect(input.isInputActive(10))
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            for channel: UInt8 in 0..<4 {
                dj3Packet(
                    [0x90 + channel, 89, 127, 89, 0, 93, 127, 93, 0, 105, 127, 105, 0, 109, 127, 109, 0], to: input)
            }
            #expect(events.map(\.deck) == (0..<4).flatMap { _ in decks.map { Optional($0) } })
            let count = events.count
            dj3Packet([0x94, 89, 127], to: input)
            #expect(events.count == count)
        }
    }
}

@Test @MainActor func controllerCatalogueDJ3OppositeBankReleasesPreserveHeldCueBendsAndPlay() {
    withDJ3(decks: DeckID.allCases) { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        dj3Packet([0x93, 90, 127, 72, 127, 73, 127, 89, 127, 0x83, 106, 127, 80, 127, 81, 127, 105, 127], to: input)
        #expect(events.suffix(3).map(\.1) == [0, 0, 0])
        #expect(events.suffix(3).map { $0.0.deck } == [.a, .a, .a])
        dj3Packet([0x93, 89, 127], to: input)
        #expect(events.filter { $0.0.action == .playA && $0.0.deck == .a && $0.1 == 1 }.count == 2)
    }
}

@Test @MainActor func controllerCatalogueDJ3KeepsIndependentRelativeTargetsAndExactBrowserCounts() {
    withDJ3(decks: DeckID.allCases) { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { _ in 0.5 }
        input.onTargetAction = { events.append(($0, $1)) }
        for number: UInt8 in [64, 72, 65, 73] {
            dj3Packet([0xB3, number, 1], to: input)
        }
        #expect(events.map { $0.0.deck } == [.a, .b, .c, .d])
        #expect(events.allSatisfy { $0.1 == 0.5 + 1.0 / 127 })
        events.removeAll()
        for number: UInt8 in [66, 74, 67, 75] { dj3Packet([0xB3, number, 127], to: input) }
        #expect(events.map { $0.0.deck } == [.a, .b, .c, .d])
        #expect(events.allSatisfy { $0.1 == 0.5 - 1.0 / 127 })
        events.removeAll()
        dj3Packet([0xB3, 96, 64], to: input)
        #expect(events.allSatisfy { $0.0.action == .browse })
        #expect(abs(events.reduce(0) { $0 + ($1.1 - 0.5) * 126 } - 64) < 0.000001)
    }
}

@Test @MainActor func controllerCatalogueDJ3KeepsDistinctLevelsPFLAndCuesWhileSharedPotsStayInactive() {
    withDJ3(decks: DeckID.allCases) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        dj3Packet([0xB3, 112, 127, 113, 127, 114, 127, 115, 127, 104, 127, 105, 127, 108, 127, 109, 127], to: input)
        #expect(Set(events.map(\.action)) == Set([.levelA, .levelB, .cueA, .cueB]))
        #expect(Set(events.compactMap(\.deck)) == Set(DeckID.allCases))
        events.removeAll()
        dj3Packet([0x93, 76, 127, 79, 127, 114, 127, 119, 127], to: input)
        #expect(events.map(\.deck) == [.a, .b, .c, .d])
        events.removeAll()
        dj3Packet([0xB3, 0, 127, 4, 127, 8, 127, 12, 127, 68, 65, 0x93, 36, 127], to: input)
        #expect(events.isEmpty)
    }
}
