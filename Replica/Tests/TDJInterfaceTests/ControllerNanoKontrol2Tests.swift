import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private final class NanoProbe {
    var packets: [([UInt8], Int32)] = []
    var failAt: Int?
    func send(_ bytes: [UInt8], to destination: Int32) -> Bool {
        packets.append((bytes, destination))
        return packets.count != failAt
    }
}

@MainActor private func withNanoKontrol2(
    paired: Bool = true, two: Bool = false, failAt: Int? = nil, decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection, NanoProbe) throws -> Void
) rethrows {
    let suite = "nanokontrol2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let probe = NanoProbe()
    probe.failAt = failAt
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { probe.send($0, to: $1) },
        deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "nanoKONTROL2", identity: .init(id: 10, device: 1, names: ["nanoKONTROL2"]))
    ]
    if paired {
        input.destinations = [
            .init(
                id: 20, reference: 200, name: "nanoKONTROL2 CTRL",
                identity: .init(id: 20, device: 1, names: ["nanoKONTROL2 CTRL"]))
        ]
    }
    if two {
        input.sources.append(
            .init(
                id: 11, reference: 101, name: "nanoKONTROL2",
                identity: .init(id: 11, device: 2, names: ["nanoKONTROL2"])))
        input.destinations.append(
            .init(
                id: 21, reference: 201, name: "nanoKONTROL2 CTRL",
                identity: .init(id: 21, device: 2, names: ["nanoKONTROL2 CTRL"])))
    }
    input.reconcileFactoryProfiles()
    try body(input, probe)
}

@MainActor private func nanoPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@MainActor private func prepareNano(_ input: ControllerMIDIConnection, channel: UInt8 = 0, source: Int32 = 10) {
    nanoPacket([0xF0, 0x42, 0x50, 1, channel, 0x2D, 0x13, 1, 0, 0, 0, 0, 1, 0, 0xF7], to: input, source: source)
    nanoPacket([0xF0, 0x42, 0x40 + channel, 0, 1, 0x13, 0, 0x40, 0, 3, 0xF7], to: input, source: source)
}

@Test @MainActor func controllerCatalogueNanoKontrol2SearchesPairedOutputAndWaitsForEveryGlobalChannelAcknowledgement()
{
    for channel: UInt8 in 0..<16 {
        withNanoKontrol2 { input, probe in
            #expect(probe.packets.map(\.0) == [ControllerNanoKontrol2Decoder.searchRequest])
            #expect(probe.packets.map(\.1) == [20])
            #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20))
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            nanoPacket([0xBF, 64, 127, 64, 0], to: input)
            #expect(actions.isEmpty)
            prepareNano(input, channel: channel)
            #expect(input.isInputActive(10) && input.factoryOutputIsReady(20))
            #expect(
                probe.packets.map(\.0) == [
                    ControllerNanoKontrol2Decoder.searchRequest,
                    [0xF0, 0x42, 0x40 + channel, 0, 1, 0x13, 0, 0, 0, 1, 0xF7],
                ])
            nanoPacket([0xBF, 64, 127, 64, 0], to: input)
            #expect(actions == [.cueA])
            input.stop()
            #expect(probe.packets.last?.0 == [0xF0, 0x42, 0x40 + channel, 0, 1, 0x13, 0, 0, 0, 0, 0xF7])
            #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20))
        }
    }
}

@Test @MainActor func controllerCatalogueNanoKontrol2SendFailuresStayInactiveUntilExplicitRetry() {
    for failAt in [1, 2] {
        withNanoKontrol2(failAt: failAt) { input, probe in
            prepareNano(input, channel: 7)
            #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20))
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            nanoPacket([0xBF, 64, 127, 64, 0], to: input)
            #expect(actions.isEmpty)
            probe.failAt = nil
            input.reconcileFactoryProfiles()
            prepareNano(input, channel: 7)
            #expect(input.isInputActive(10) && input.factoryOutputIsReady(20))
        }
    }
}

@Test @MainActor func controllerCatalogueNanoKontrol2MissingOutputAndManualSetupStayBlocked() throws {
    try withNanoKontrol2(paired: false) { input, probe in
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["nanoKONTROL2"])))
        prepareNano(input)
        #expect(probe.packets.isEmpty && !input.isInputActive(10))
        #expect(input.bindingCount == 0)
        #expect(input.status == "Controller setup needs a paired MIDI input and output.")
    }
}

@Test @MainActor func controllerCatalogueNanoKontrol2FixedMixerKeepsFadersIndependentAndBlocksHeldModifiers() {
    for decks in [DeckID.primary, DeckID.allCases] {
        withNanoKontrol2(decks: decks) { input, _ in
            prepareNano(input)
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.allCases.enumerated() {
                events.removeAll()
                nanoPacket([0xBF, UInt8(index), 64], to: input)
                nanoPacket([0xBF, UInt8(index), 127], to: input)
                nanoPacket([0xBF, UInt8(64 + index), 127, UInt8(64 + index), 0], to: input)
                #expect(events.count == (decks.contains(deck) ? 3 : 0))
                #expect(
                    events.filter { $0.0.action != .cueA && $0.0.action != .cueB }.allSatisfy {
                        $0.0 == .init(ControllerAction.levelA.assigned(to: deck), deck: deck)
                    })
                #expect(
                    events.last?.0
                        == (decks.contains(deck) ? .init(ControllerAction.cueA.assigned(to: deck), deck: deck) : nil))
            }
            for guardNote: UInt8 in 60...62 {
                events.removeAll()
                nanoPacket([0xBF, guardNote, 127, 64, 127, 64, 0], to: input)
                #expect(events.isEmpty)
                nanoPacket([0xBF, 0, 0], to: input)
                #expect(events.last?.0.action == .levelA)
                nanoPacket([0xBF, guardNote, 0, 64, 127, 64, 0], to: input)
                #expect(events.last?.0.action == .cueA)
            }
            events.removeAll()
            nanoPacket([0xBF, 18, 64], to: input)
            nanoPacket([0xBF, 18, 127], to: input)
            #expect(events.map { $0.0.action } == [.cueMix, .cueMix])
        }
    }
}

@Test @MainActor func controllerCatalogueNanoKontrol2SourcesExitAndReapplyHaveIndependentPreparation() throws {
    try withNanoKontrol2(two: true) { input, probe in
        prepareNano(input, channel: 3)
        #expect(input.isInputActive(10) && !input.isInputActive(11))
        prepareNano(input, channel: 11, source: 11)
        #expect(input.isInputActive(11))
        nanoPacket([0xF0, 0x42, 0x43, 0, 1, 0x13, 0, 0x40, 0, 2, 0xF7], to: input)
        #expect(!input.isInputActive(10) && input.isInputActive(11))
        #expect(!input.factoryOutputIsReady(20) && input.factoryOutputIsReady(21))
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["nanoKONTROL2"])))
        #expect(probe.packets.last?.0 == ControllerNanoKontrol2Decoder.searchRequest)
        prepareNano(input, channel: 3)
        #expect(input.isInputActive(10) && input.isInputActive(11))
        input.stop()
        #expect(probe.packets.suffix(2).map(\.0).contains([0xF0, 0x42, 0x43, 0, 1, 0x13, 0, 0, 0, 0, 0xF7]))
        #expect(probe.packets.suffix(2).map(\.0).contains([0xF0, 0x42, 0x4B, 0, 1, 0x13, 0, 0, 0, 0, 0xF7]))
    }
}

@Test @MainActor func controllerCatalogueNanoKontrol2CoreLampsAndIdentityKeepOriginalNanoSeparate() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["nanoKONTROL2"]));
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 12 && data.outputs.count == 4 && profile.selectsAutomatically)
    #expect(data.audioOutput == nil && data.shutdown.isEmpty)
    for other in ["nanoKONTROL", "nanoKONTROL Studio", "nanoPAD2", "nanoKEY2"] {
        #expect(ControllerFactoryProfile.matching([other]) != profile)
    }
    for (index, lamp) in profile.feedback(destination: 20).enumerated() {
        #expect(lamp.isValid && lamp.targetDeck == DeckID.allCases[index])
        #expect(lamp.message(value: 1) == [0xBF, UInt8(64 + index), 127])
        #expect(lamp.message(value: 0) == [0xBF, UInt8(64 + index), 0])
    }
}

@Test @MainActor func controllerCatalogueNanoKontrol2ExitReleasesOnlyOwnedLearnedCueAndOverloadStopsPreparation() {
    withNanoKontrol2(two: true) { input, probe in
        prepareNano(input, channel: 5)
        prepareNano(input, channel: 9, source: 11)
        for source: Int32 in [10, 11] {
            input.select(source)
            input.learning = .cuePreviewA
            nanoPacket([0xBF, 64, 127, 64, 0], to: input, source: source)
        }
        var values: [Double] = []
        input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
        nanoPacket([0xBF, 64, 127], to: input)
        nanoPacket([0xBF, 64, 127], to: input, source: 11)
        nanoPacket([0xF0, 0x42, 0x45, 0, 1, 0x13, 0, 0x40, 0, 2, 0xF7], to: input)
        #expect(values == [1])
        nanoPacket([0xBF, 64, 0], to: input, source: 11)
        #expect(values == [1, 0])
        #expect(input.receiveBytes([0xBF, 0, 64], source: 11, limit: 0) == nil)
        #expect(!input.isInputActive(10) && !input.isInputActive(11))
        #expect(input.status == "Controller input overload. Reconnect to continue.")
        #expect(probe.packets.last?.0 == [0xF0, 0x42, 0x49, 0, 1, 0x13, 0, 0, 0, 0, 0xF7])
    }
}

@Test @MainActor func controllerCatalogueNanoKontrol2ClearingLearnedMappingsExitsModeAndRequiresFreshSetup() {
    withNanoKontrol2 { input, probe in
        prepareNano(input, channel: 12)
        input.select(10)
        input.learning = .cuePreviewA
        nanoPacket([0xBF, 64, 127, 64, 0], to: input)
        #expect(input.bindingCount == 12 && input.bindingName(.cuePreviewA) != "Unassigned")
        input.clearBindings()
        #expect(input.bindingCount == 0 && !input.isInputActive(10) && !input.factoryOutputIsReady(20))
        #expect(probe.packets.last?.0 == [0xF0, 0x42, 0x4C, 0, 1, 0x13, 0, 0, 0, 0, 0xF7])
        prepareNano(input, channel: 12)
        #expect(!input.isInputActive(10))
        input.setInputActive(10, active: true)
        #expect(probe.packets.last?.0 == ControllerNanoKontrol2Decoder.searchRequest)
        prepareNano(input, channel: 12)
        #expect(input.isInputActive(10) && input.factoryOutputIsReady(20))
    }
}
