import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalNS6(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "original-ns6-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { DeckID.allCases })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "Numark NS6",
            identity: .init(id: id, device: UInt32(id), names: ["Numark NS6"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching(["Numark NS6"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    #expect(input.bindingCount == 198)
    try body(input)
}

@MainActor private func ns6Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalNS6CyclicPairsPrimeWrapAndKeepDeckAndSourceState() throws {
    try withOriginalNS6 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { target, value in if case .relative(let count) = value { events.append((target, count)) } }
        for (index, deck) in DeckID.allCases.enumerated() {
            let status = 0xB1 + UInt8(index)
            events.removeAll()
            ns6Packet([status, 32, 127, 0, 127, 32, 126], input)
            #expect(events.isEmpty)
            ns6Packet([status, 0, 0, 32, 2], input)
            ns6Packet([status, 0, 127, 32, 126], input)
            #expect(events.map(\.1) == [4, -4])
            #expect(
                events.allSatisfy {
                    $0.0 == .init(ControllerAction.jogA.assigned(to: deck), deck: deck, argument: 3600)
                })
        }
        events.removeAll()
        ns6Packet([0xB1, 0, 0, 32, 2], input, source: 11)
        #expect(events.isEmpty)
        ns6Packet([0xB1, 0, 0, 0xB0, 80, 0, 0xB1, 32, 3], input)
        #expect(events.isEmpty)
        ns6Packet([0xB1, 0, 0, 32, 4], input)
        #expect(events.isEmpty)
        ns6Packet([0xB1, 0, 0, 32, 5], input)
        #expect(events.map(\.1) == [1])
        ns6Packet([0xB2, 0, 0, 32, 2], input)
        #expect(events.last?.0.deck == .b && events.last?.1 == 4)
    }
}

@Test @MainActor func controllerCatalogueOriginalNS6CueBendsAndLayerReportsKeepOwnershipAndRightShift() throws {
    try withOriginalNS6 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (index, deck) in DeckID.allCases.enumerated() {
            let status = 0x91 + UInt8(index)
            for number: UInt8 in [16, 24, 25] {
                for off: UInt8 in [0x81, 0x91] {
                    events.removeAll()
                    ns6Packet(
                        [status, number, 127, number, 127, off + UInt8(index), number, off == 0x81 ? 127 : 0], input)
                    #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
        events.removeAll()
        ns6Packet([0x91, 16, 127, 0x93, 16, 127, 0x92, 16, 127], input)
        ns6Packet([0x91, 16, 127], input, source: 11)
        ns6Packet([0xB0, 80, 3], input)
        #expect(events.map(\.0.deck) == [.a, .c, .b, .c])
        ns6Packet([0x81, 16, 127], input, source: 11)
        #expect(events.last?.0.deck == .a && events.last?.1 == 0)
        ns6Packet([0xB0, 81, 0], input)
        #expect(events.last?.0.deck == .b && events.last?.1 == 0)
        events.removeAll()
        ns6Packet([0x92, 18, 127, 19, 127, 19, 0, 0x94, 19, 127, 19, 0, 0x91, 19, 127, 19, 0], input)
        #expect(events.count == 1 && events.first?.0.action == .hotcue1A)
        ns6Packet([0x94, 18, 0, 19, 127, 19, 0], input)
        #expect(events.last?.0.deck == .d && events.last?.0.action == .hotcue1B)
    }
}

@Test @MainActor func controllerCatalogueOriginalNS6MixerMSBsAndNormalButtonsKeepDistinctBuses() throws {
    try withOriginalNS6 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        let levels: [UInt8] = [8, 13, 19, 24], gains: [UInt8] = [12, 17, 23, 28]
        for (index, deck) in DeckID.allCases.enumerated() {
            let channel = UInt8(index + 1)
            for (number, action): (UInt8, ControllerAction) in [(levels[index], .levelA), (gains[index], .gainA)] {
                events.removeAll()
                ns6Packet([0xB0, number, 0], input)
                #expect(events.isEmpty)
                ns6Packet([0xB0, number, 64], input)
                ns6Packet([0xB0, number, 127], input)
                #expect(
                    events.map(\.1) == [64.0 / 127, 1]
                        && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
            events.removeAll()
            ns6Packet([0xB0 + channel, 33, 127, 1, 64], input)
            ns6Packet([0xB0 + channel, 1, 127], input)
            #expect(
                events.first?.0 == .init(ControllerAction.tempoA.assigned(to: deck), deck: deck) && events.last?.1 == 0)
            for number: UInt8 in [17, 15, 27, index % 2 == 0 ? 14 : 12] {
                events.removeAll()
                ns6Packet([0x90 + channel, number, 127, number, 127, 0x80 + channel, number, 127], input)
                #expect(events.count == 1 && events.first?.0.deck == deck)
            }
        }
        events.removeAll()
        ns6Packet([0xB0, 68, 1], input)
        ns6Packet([0xB0, 68, 127], input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        ns6Packet([0x90, 8, 127, 8, 0, 6, 127, 6, 0], input)
        #expect(events.suffix(2).map(\.0.action) == [.openGroup, .browsePreviousGroup])
    }
}

@Test @MainActor func controllerCatalogueOriginalNS6HasOnlyQualifiedManualLampsAndNoTestModeOrSiblingAlias() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Numark NS6"]))
    let definition = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && definition.inputs.count == 99 && definition.outputs.count == 32)
    #expect(definition.startup.isEmpty && definition.shutdown.isEmpty && definition.audioOutput == nil)
    let light = try #require(profile.feedback(destination: 20).first { $0.action == .hotcue5B && $0.targetDeck == .d })
    #expect(light.message(value: 1) == [0xB4, 15, 127] && light.message(value: 0) == [0xB4, 15, 0])
    for name in ["NS6II", "NS7", "NS7II", "NS7III"] { #expect(ControllerFactoryProfile.matching([name]) != profile) }
    try withOriginalNS6 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for channel: UInt8 in 1...4 {
            for number: UInt8 in [26, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43] {
                ns6Packet([0x90 + channel, number, 127, number, 0], input)
            }
            ns6Packet([0xB0 + channel, 2, 127, 33, 127], input)
        }
        #expect(actions.isEmpty)
    }
}
