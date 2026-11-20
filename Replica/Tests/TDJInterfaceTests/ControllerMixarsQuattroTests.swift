import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixarsQuattro(
    decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "mixars-quattro-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual QUATTRO subset must not send packets."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Mixars Quattro",
            identity: .init(id: id, device: UInt32(id), names: ["Mixars Quattro"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Mixars Quattro"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 218 && input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func mixarsQuattroPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMixarsQuattroOwnManualIdentityWithoutAudioOrOutput() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Mixars QUATTRO"])); let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.role == "accessory" && d.inputs.count == 109)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["Mixars Quattro"], automaticOnly: true) == nil)
    for other in ["Reloop Quattro", "Mixars DUO", "Mixars DUO MKII", "Mixars PRIMO"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    try withMixarsQuattro { _ in }
}

@Test @MainActor func controllerCatalogueMixarsQuattroAllCuePadsAndBankReleaseAliases() throws {
    try withMixarsQuattro { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (index, deck) in DeckID.allCases.enumerated() {
            let ch = UInt8(index + 4)
            for (slot, n) in [UInt8(96), 100, 97, 101, 98, 102, 99, 103].enumerated() {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    mixarsQuattroPacket(
                        [0x90 + ch, n, 1, n, 127, off + (ch ^ 2), n, off == 0x80 ? 127 : 0, 0x90 + ch, n, 64, n, 0],
                        input)
                    #expect(events.count == 2 && events.allSatisfy { $0.deck == deck && $0.action.hotcueSlot == slot })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMixarsQuattroTransportFixedLoopSizingLoadsAndSync() throws {
    try withMixarsQuattro { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (index, deck) in DeckID.allCases.enumerated() {
            let ch = UInt8(index + 4)
            for (n, action): (UInt8, ControllerAction) in [
                (27, .playA), (64, .toggleFixedLoopA), (25, .loopDownA), (24, .loopUpA),
            ] {
                events.removeAll()
                mixarsQuattroPacket([0x90 + ch, n, 127, 0x80 + (ch ^ 2), n, 127, 0x90 + ch, n, 1, n, 0], input)
                #expect(
                    events.count == 2 && events.allSatisfy { $0.deck == deck && $0.action == action.assigned(to: deck) }
                )
                if action == .toggleFixedLoopA { #expect(events.allSatisfy { $0.argument == 4 }) }
            }
            events.removeAll(); mixarsQuattroPacket([0x9F, UInt8(2 + index), 127, UInt8(2 + index), 0], input)
            #expect(events == [.init(ControllerAction.loadA.assigned(to: deck), deck: deck)])
        }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            events.removeAll(); mixarsQuattroPacket([0x90 + ch, 2, 127, 3, 0, 2, 1, 2, 0], input)
            #expect(
                events.count == 2
                    && events.allSatisfy { $0 == .init(ControllerAction.syncA.assigned(to: deck), deck: deck) })
        }
    }
}

@Test @MainActor func controllerCatalogueMixarsQuattroShiftComposesPhysicalSidesAndKeepsSourcesSeparate() throws {
    try withMixarsQuattro { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        mixarsQuattroPacket([0x90, 32, 127, 0x91, 32, 127, 0x94, 27, 127, 27, 0], input)
        #expect(events.isEmpty)
        mixarsQuattroPacket([0x94, 27, 127, 27, 0], input, source: 11)
        #expect(events == [.init(.playA, deck: .a)])
        events.removeAll(); mixarsQuattroPacket([0x82, 32, 127, 0x94, 27, 127, 27, 0], input)
        #expect(events.isEmpty)
        mixarsQuattroPacket([0x83, 32, 127, 0x94, 27, 127, 27, 0], input)
        #expect(events == [.init(.playA, deck: .a)])
        events.removeAll(); mixarsQuattroPacket([0x92, 32, 1, 0x94, 96, 127, 96, 0, 0xBf, 0, 65], input)
        #expect(events.isEmpty)
        mixarsQuattroPacket([0x90, 32, 0, 0x94, 96, 127, 96, 0], input)
        #expect(events == [.init(.hotcue1A, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueMixarsQuattroFlippedBrowseAndCDOptIn() throws {
    try withMixarsQuattro(decks: DeckID.primary) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        mixarsQuattroPacket([0xBF, 0, 65], input); mixarsQuattroPacket([0xBF, 0, 63], input)
        #expect(events.map(\.1) == [0.5 - 1.0 / 126, 0.5 + 1.0 / 126] && events.allSatisfy { $0.0.action == .browse })
        events.removeAll()
        for ch: UInt8 in [6, 7] {
            mixarsQuattroPacket([0x90 + ch, 27, 127, 27, 0, 96, 127, 96, 0, 64, 127, 64, 0], input)
        }
        mixarsQuattroPacket([0x9F, 4, 127, 4, 0, 5, 127, 5, 0], input); #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMixarsQuattroNumberedCueMixerAndOtherModesStayInactive() throws {
    try withMixarsQuattro { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 0..<4 {
            mixarsQuattroPacket(
                [0xB0 + ch, 22, 127, 23, 127, 24, 127, 25, 127, 28, 127, 60, 127, 0x90 + ch, 27, 127], input)
            mixarsQuattroPacket([0x94 + ch, 26, 127, 26, 0, 35, 127, 104, 127, 112, 127, 120, 127], input)
        }
        mixarsQuattroPacket([0xBF, 8, 127, 40, 127, 28, 127, 0x92, 2, 127, 0x93, 2, 127], input)
        #expect(events.isEmpty)
    }
}
