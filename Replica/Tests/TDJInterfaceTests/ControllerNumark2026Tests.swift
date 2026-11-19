import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withNumark2026(
    _ name: String, sender: @escaping ([UInt8], Int32) -> Bool = { _, _ in true },
    _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "numark-2026-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: sender)
    input.sources = [
        .init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name])),
        .init(id: 11, reference: 101, name: name, identity: .init(id: 11, device: 2, names: [name])),
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name])),
        .init(id: 21, reference: 201, name: name, identity: .init(id: 21, device: 2, names: [name])),
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func numark2026Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueNumark2026StartupQueriesOnlyPairedDevicesWithoutLightsOrAudioAssumptions()
    throws
{
    for name in ["Numark MixTrack Go", "Numark Party Mix III"] {
        var packets: [([UInt8], Int32)] = []
        try withNumark2026(
            name,
            sender: {
                packets.append(($0, $1)); return true
            }
        ) { input in
            for destination: Int32 in [20, 21] {
                #expect(
                    packets.filter { $0.1 == destination }.map(\.0) == [
                        [0xF0, 0x7E, 0x7F, 6, 1, 0xF7], [0xF0, 0, 0x20, 0x7F, 3, 1, 0xF7],
                    ])
            }
            input.reconcileFactoryProfiles()
            #expect(packets.count == 4)
            input.stop()
            #expect(packets.count == 4)
        }
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.shutdown.isEmpty == true)
        #expect(profile.definition?.audioOutput == nil)
        for other in ["Party Mix II", "Party Mix Live", "Party Mix Pro", "Mixtrack Pro", "DJ2GO2 Touch"] {
            #expect(ControllerFactoryProfile.matching([other]) != profile)
        }
    }
}

@Test @MainActor func controllerCatalogueNumark2026EachNormalButtonKeepsItsModelAndDeckAddress() throws {
    for name in ["Numark MixTrack Go", "Numark Party Mix III"] {
        try withNumark2026(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.primary.enumerated() {
                let channel = UInt8(index)
                var buttons: [(UInt8, UInt8, ControllerAction)] = [
                    (channel, 0, .playA), (channel, 1, .cuePreviewA), (15, channel + 2, .loadA),
                ]
                if name.hasSuffix("Go") { buttons += [(channel, 2, .syncA), (channel, 27, .cueA)] }
                for (wire, number, action) in buttons {
                    for release: UInt8 in [0x80, 0x90] {
                        events.removeAll()
                        numark2026Packet(
                            [0x90 + wire, number, 127, release + wire, number, release == 0x80 ? 127 : 0], to: input)
                        #expect(events.count == (action.isMomentary ? 2 : 1))
                        #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueNumark2026PairedTempoMixerAndBrowserKeepSourceDirections() throws {
    for name in ["Numark MixTrack Go", "Numark Party Mix III"] {
        try withNumark2026(name) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (index, deck) in DeckID.primary.enumerated() {
                let status = UInt8(0xB0 + index)
                events.removeAll()
                numark2026Packet([status, 41, 127], to: input)
                #expect(events.isEmpty)
                numark2026Packet([status, 9, 64, 41, 0], to: input)
                #expect(events.last?.1 == 1 - 8192.0 / 16383)
                numark2026Packet([status, 9, 0, 41, 0], to: input)
                #expect(events.last?.1 == 1)
                numark2026Packet([status, 9, 127, 41, 127], to: input)
                #expect(events.last?.1 == 0)
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.tempoA.assigned(to: deck), deck: deck) })
                var knobs: [(UInt8, ControllerAction)] = [(22, .levelA), (26, .filterKnobA)]
                if name.hasSuffix("III") { knobs += [(23, .highA), (24, .midA), (25, .lowA)] }
                for (number, action) in knobs {
                    events.removeAll()
                    numark2026Packet([status, number, 64], to: input)
                    numark2026Packet([status, number, 127], to: input)
                    #expect(events.map(\.1) == [64.0 / 127, 1])
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                }
            }
            for (number, action): (UInt8, ControllerAction) in [(10, .master), (12, .monitor), (8, .crossfader)] {
                events.removeAll()
                numark2026Packet([0xBF, number, 64], to: input)
                numark2026Packet([0xBF, number, 0], to: input)
                #expect(events.map(\.1) == [64.0 / 127, 0])
                #expect(events.allSatisfy { $0.0.action == action })
            }
            events.removeAll()
            numark2026Packet([0xBF, 0, 127], to: input)
            numark2026Packet([0xBF, 0, 1], to: input)
            #expect(events.map(\.1) == [0.5 - 1.0 / 126, 0.5 + 1.0 / 126])
            #expect(events.allSatisfy { $0.0.action == .browse })
        }
    }
}

@Test @MainActor func controllerCatalogueNumark2026ShiftedReleasesRearmAndRespectLastCueOwner() throws {
    for name in ["Numark MixTrack Go", "Numark Party Mix III"] {
        try withNumark2026(name) { input in
            var values: [Double] = []
            var actions: [ControllerAction] = []
            input.onAction = { action, value in
                if action == .cuePreviewA { values.append(value) }
                if !action.isJog { actions.append(action) }
            }
            numark2026Packet([0x90, 1, 127], to: input)
            numark2026Packet([0x90, 1, 127], to: input, source: 11)
            numark2026Packet([0x80, 5, 127], to: input)
            #expect(values == [1])
            numark2026Packet([0x90, 5, 0], to: input, source: 11)
            #expect(values == [1, 0])
            numark2026Packet([0x90, 0, 127, 0x80, 4, 127], to: input)
            actions.removeAll()
            numark2026Packet([0x90, 0, 127, 0, 0], to: input)
            #expect(actions == [.playA])
            actions.removeAll()
            numark2026Packet([0x90, 4, 127, 5, 127, 0x9F, 72, 127, 73, 127], to: input)
            #expect(actions.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueNumark2026GoJogIsIndependentAndPrototypeModesStayInactive() throws {
    for name in ["Numark MixTrack Go", "Numark Party Mix III"] {
        try withNumark2026(name) { input in
            var turns: [Double] = []
            var actions: [ControllerAction] = []
            input.onJogAction = { target, value in
                #expect(target.argument == 242)
                if case .relative(let counts) = value { turns.append(counts) }
            }
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            numark2026Packet([0xB0, 6, 1], to: input)
            numark2026Packet([0xB0, 6, 127], to: input)
            #expect(turns == (name.hasSuffix("Go") ? [1, -1] : []))
            for channel: UInt8 in [4, 5] {
                for number: UInt8 in [0, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31] {
                    numark2026Packet([0x90 + channel, number, 127, number, 0], to: input)
                }
            }
            numark2026Packet([0xBF, 1, 1, 0x9F, 7, 127, 70, 127, 71, 127, 0xB0, 28, 127], to: input)
            if name.hasSuffix("III") {
                numark2026Packet([0x90, 2, 127, 27, 127, 80, 127, 0x91, 2, 127, 27, 127, 80, 127], to: input)
            }
            #expect(actions.isEmpty)
        }
    }
}
