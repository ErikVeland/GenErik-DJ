import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSR2(
    decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "sr2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "DDJ-SR2", identity: .init(id: 10, device: 1, names: ["DDJ-SR2"])),
        .init(id: 11, reference: 101, name: "DDJ-SR2", identity: .init(id: 11, device: 2, names: ["DDJ-SR2"])),
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DDJ-SR2"])))
    try body(input)
}

@MainActor private func sr2Packet(_ bytes: [UInt8], source: Int32 = 10, to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSR2KeepsManualUnknownBankAndAllFourNormalTargets() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DDJ-SR2"]))
    #expect(!profile.selectsAutomatically && profile.definition?.inputs.count == 202)
    #expect(ControllerFactoryProfile.matching(["DDJ-SR2"], automaticOnly: true) == nil)
    #expect(profile != ControllerFactoryProfile.matching(["DDJ-SR"]))
    for decks in [DeckID.primary, DeckID.allCases] {
        try withSR2(decks: decks) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
            sr2Packet([0x96, 70, 127, 70, 0, 71, 127, 71, 0], to: input)
            #expect(events.isEmpty)
            for (channel, deck) in zip(UInt8(0)...3, DeckID.allCases) {
                events.removeAll()
                let status = 0x90 + channel
                sr2Packet([status, channel < 2 ? 85 : 86, 127], to: input)
                sr2Packet([0x96, channel % 2 == 0 ? 70 : 71, 127, channel % 2 == 0 ? 70 : 71, 0], to: input)
                sr2Packet([status, 11, 127, 11, 0, 12, 127, 12, 0, 88, 127, 88, 0, 26, 127, 26, 0], to: input)
                let base: [ControllerAction] = [.loadA, .playA, .cuePreviewA, .cuePreviewA, .syncA, .keylockA]
                let expected = decks.contains(deck) ? base.map { $0.assigned(to: deck) } : []
                #expect(events.map(\.action) == expected)
                #expect(events.allSatisfy { $0.deck == deck })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueSR2DispatchesEveryNormalButtonAndCuePad() throws {
    try withSR2 { input in
        let definition = try #require(ControllerFactoryProfile.matching(["DDJ-SR2"])?.definition)
        let buttons = definition.inputs.filter {
            $0.action.isButton && $0.action != .shift && ![.loadA, .loadB].contains($0.action) && $0.releaseOnly != true
        }
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for button in buttons {
            events.removeAll()
            sr2Packet([0x90 + button.channel, button.number, 127, button.number, 0], to: input)
            #expect(
                events == Array(repeating: button.binding(source: 10).target, count: button.action.isMomentary ? 2 : 1))
        }
    }
}

@Test @MainActor func controllerCatalogueSR2KeepsAllTwentyEightExplicitPairsAndNormalJogDirections() throws {
    try withSR2 { input in
        let definition = try #require(ControllerFactoryProfile.matching(["DDJ-SR2"])?.definition)
        let pairs = definition.inputs.filter { $0.encoding == .paired14Bit }
        #expect(pairs.count == 28)
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for pair in pairs {
            let low = try #require(pair.lowNumber)
            for value: UInt8 in [0, 127] {
                events.removeAll()
                sr2Packet([0xB0 + pair.channel, pair.number, value, low, value], to: input)
                #expect(events.count == 1 && events.first?.0 == pair.binding(source: 10).target)
                #expect(events.first?.1 == Double(value) / 127)
            }
        }
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        sr2Packet([0xB0, 34, 65], to: input)
        sr2Packet([0xB0, 35, 63], to: input)
        sr2Packet([0xB0, 33, 66], to: input)
        #expect(jogs.map { $0.0.action } == [.jogA, .jogA, .wheelJogA])
        #expect(jogs.map(\.1) == [.relative(1), .relative(-1), .relative(2)])
    }
}

@Test @MainActor func controllerCatalogueSR2PreservesPhysicalShiftAcrossBankChangesAndShiftedReleases() throws {
    try withSR2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        sr2Packet([0x90, 85, 127, 12, 127, 63, 127, 0x80, 72, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewA] && events.map(\.1) == [1, 0])
        events.removeAll()
        sr2Packet([0x92, 86, 127, 11, 127, 11, 0], to: input)
        #expect(events.isEmpty)
        sr2Packet([0x92, 63, 0, 11, 127, 11, 0], to: input)
        #expect(events.map(\.0) == [.init(.playA, deck: .c)])
        events.removeAll()
        sr2Packet([0x90, 54, 127, 63, 127, 0x80, 103, 127, 0x90, 63, 0], to: input)
        sr2Packet(
            [0x97, 0, 127, 0x90, 63, 127, 0x87, 8, 127, 0x97, 8, 127, 0x90, 63, 0, 0x97, 0, 127, 0, 0], to: input)
        #expect(
            events.filter { $0.0.action.hotcueSlot != nil }.map(\.0) == [
                .init(.hotcue1A, deck: .a), .init(.hotcue1A, deck: .a),
            ])
        #expect(events.filter { $0.0.action == .jogTouchA }.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueSR2SelectorBoundariesReleaseOnlyTheirSideAndSource() throws {
    try withSR2 { input in
        input.select(11)
        input.learning = .cuePreviewB
        sr2Packet([0x90, 12, 127, 12, 0], source: 11, to: input)
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if target.action.isMomentary { events.append((target, value)) } }
        sr2Packet([0x90, 85, 127, 12, 127, 0x91, 12, 127], to: input)
        sr2Packet([0x90, 12, 127], source: 11, to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewB, .cuePreviewB])
        sr2Packet([0x92, 86, 0], to: input)
        #expect(events.map(\.1) == [1, 1, 1])
        sr2Packet([0x90, 87, 127], to: input)
        #expect(events.map(\.1) == [1, 1, 1, 0])
        #expect(events.last?.0 == .init(.cuePreviewA, deck: .a))
        sr2Packet([0x80, 12, 127], source: 11, to: input)
        #expect(events.map(\.1) == [1, 1, 1, 0, 0])
        #expect(events.last?.0 == .init(.cuePreviewB))
        sr2Packet([0x81, 12, 127], to: input)
        #expect(events.last?.0 == .init(.cuePreviewB, deck: .b) && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueSR2RejectsRawLoadInjectionAndForgetsBankOnReconnectAndOverload() throws {
    try withSR2 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        sr2Packet([0x90, 85, 127, 126, 127, 126, 0, 0x96, 88, 127, 89, 127], to: input)
        #expect(actions.isEmpty)
        let sources = input.sources
        input.setInputActive(10, active: false)
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.select(10)
        sr2Packet([0x96, 70, 127, 70, 0], to: input)
        #expect(actions.isEmpty)
        #expect(input.receiveBytes([0x90, 85, 127, 11, 127], source: 10, limit: 1) == nil)
        #expect(actions.isEmpty && input.status.contains("overload"))
    }
}
