import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let akiyamaModels = ["Akiyama Quattro", "Akiyama Quark SC", "Akiyama TTWO"]

@MainActor private func withAkiyamaChart(
    _ name: String, decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "akiyama-chart-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual chart profiles must not write hardware state."); return false
        }, deckAvailability: { decks })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    #expect(input.isInputActive(10) && !input.isInputActive(11))
    try body(input)
}

@MainActor private func akiyamaPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: akiyamaModels) @MainActor func controllerCatalogueAkiyamaChartIdentityStaysManualAndDistinct(
    _ name: String
) throws {
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    let data = try #require(profile.definition)
    let expected = name == akiyamaModels[0] ? 98 : name == akiyamaModels[1] ? 200 : 125
    #expect(profile.bindings(source: 10).count == expected)
    #expect(
        !profile.selectsAutomatically && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty
            && data.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    for other in akiyamaModels where other != name { #expect(ControllerFactoryProfile.matching([other]) != profile) }
    #expect(ControllerFactoryProfile.matching([name + " clone"]) != profile)
}

@Test(arguments: akiyamaModels) @MainActor func controllerCatalogueAkiyamaChartTransportAndCueKeepBothReleaseForms(
    _ name: String
) throws {
    try withAkiyamaChart(name) { input in
        let play: UInt8 = name == akiyamaModels[0] ? 51 : name == akiyamaModels[1] ? 52 : 47
        let cue: UInt8 = name == akiyamaModels[0] ? 50 : name == akiyamaModels[1] ? 53 : 46
        let sync: UInt8 = name == akiyamaModels[0] ? 49 : name == akiyamaModels[1] ? 54 : 45
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (channel, deck) in DeckID.allCases.enumerated() {
            let note: UInt8 = 0x90 + UInt8(channel)
            for (number, action): (UInt8, ControllerAction) in [(play, .playA), (sync, .syncA)] {
                events.removeAll(); akiyamaPacket([note, number, 127, number, 127, number, 0], input)
                #expect(events.map(\.0) == [.init(action.assigned(to: deck), deck: deck)])
            }
            for off: UInt8 in [note, note - 16] {
                events.removeAll(); akiyamaPacket([note, cue, 127, cue, 127, off, cue, off == note ? 0 : 127], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
        }
    }
}

@Test(arguments: akiyamaModels) @MainActor func controllerCatalogueAkiyamaChartShiftAndDeckCleanupStaySourceOwned(
    _ name: String
) throws {
    try withAkiyamaChart(name) { input in
        let quark = name == akiyamaModels[1]
        let cue: UInt8 = name == akiyamaModels[0] ? 50 : quark ? 53 : 46
        let alternate: UInt8 = name == akiyamaModels[0] ? 82 : quark ? 117 : 14
        let shift: UInt8 = name == akiyamaModels[0] ? 114 : quark ? 63 : 36
        let shiftStatus: UInt8 = quark ? 0x90 : 0x94
        let selector: UInt8 = name == akiyamaModels[0] ? 55 : quark ? 7 : 44
        var values: [Double] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        akiyamaPacket([0x90, cue, 127], input)
        akiyamaPacket([shiftStatus, shift, 127], input, source: 11)
        #expect(values == [1])
        akiyamaPacket([shiftStatus, shift, 127, 0x90, alternate, 127, alternate, 0], input)
        #expect(values == [1, 0])
        akiyamaPacket([shiftStatus, shift, 0, 0x90, cue, 127, selector, 127, selector, 0], input)
        #expect(values == [1, 0, 1, 0])
        akiyamaPacket([0x90, cue, 127], input)
        input.stop()
        #expect(values == [1, 0, 1, 0, 1, 0])
    }
}

@Test(arguments: akiyamaModels) @MainActor func controllerCatalogueAkiyamaChartMixerPickupUsesEachModelsOwnAddresses(
    _ name: String
) throws {
    try withAkiyamaChart(name) { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.allCases.enumerated() {
            let quattro = name == akiyamaModels[0]
            let channel: UInt8 = quattro ? 4 : UInt8(side)
            let numbers: [UInt8] =
                quattro
                ? [
                    33 + UInt8(side) * 6, 34 + UInt8(side) * 6, 35 + UInt8(side) * 6, 36 + UInt8(side) * 6,
                    38 + UInt8(side) * 6,
                ]
                : name == akiyamaModels[1] ? [9, 10, 11, 12, 59] : [50, 51, 52, 53, 55]
            for (index, number) in numbers.enumerated() {
                events.removeAll(); akiyamaPacket([0xB0 + channel, number, 0], input)
                #expect(events.isEmpty)
                akiyamaPacket([0xB0 + channel, number, 64], input); akiyamaPacket([0xB0 + channel, number, 127], input)
                let action: ControllerAction = [.gainA, .highA, .midA, .lowA, .levelA][index]
                #expect(
                    events.count == 2 && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) }
                        && events.last?.1 == 1)
            }
        }
    }
}

@Test(arguments: akiyamaModels) @MainActor
func controllerCatalogueAkiyamaChartHotCuesAndDirectLoadChannelsStayIndependent(_ name: String) throws {
    try withAkiyamaChart(name) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for (channel, deck) in DeckID.allCases.enumerated() {
            for slot in 0..<(name == akiyamaModels[1] ? 6 : 4) {
                let number = UInt8(
                    name == akiyamaModels[0] ? 40 + slot : name == akiyamaModels[1] ? 23 + 3 * slot : 32 + slot)
                events.removeAll(); akiyamaPacket([0x90 + UInt8(channel), number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.action.hotcueSlot == slot && events.first?.deck == deck)
            }
            let common = UInt8(name == akiyamaModels[0] ? 4 : name == akiyamaModels[1] ? channel : 4 + channel / 2)
            let load = UInt8(name == akiyamaModels[0] ? 97 + channel : name == akiyamaModels[1] ? 59 : 32 + channel % 2)
            events.removeAll(); akiyamaPacket([0x90 + common, load, 127, load, 0], input)
            #expect(events == [.init(ControllerAction.loadA.assigned(to: deck), deck: deck)])
        }
    }
}

@Test(arguments: akiyamaModels) @MainActor func controllerCatalogueAkiyamaChartKeepsFourDeckOptIn(_ name: String) throws
{
    try withAkiyamaChart(name, decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        let play: UInt8 = name == akiyamaModels[0] ? 51 : name == akiyamaModels[1] ? 52 : 47
        akiyamaPacket([0x92, play, 127, play, 0, 0x93, play, 127, play, 0], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueAkiyamaChartDisputedPitchJogAndTTWOFeedbackStayInactive() throws {
    for name in akiyamaModels {
        try withAkiyamaChart(name) { input in
            var jogs = 0
            input.onJogAction = { _, _ in jogs += 1 }
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if action == .tempoA || action == .crossfader { actions.append(action) } }
            akiyamaPacket([0xE0, 3, 64, 0xE4, 3, 127], input)
            if name == akiyamaModels[2] {
                akiyamaPacket([0xB0, 54, 64, 118, 127, 32, 65, 33, 63, 0xB4, 83, 127], input)
            }
            #expect(jogs == 0 && actions.isEmpty)
        }
    }
}
