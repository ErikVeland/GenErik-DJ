import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withXWDJ1(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "xwdj1-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "XW-DJ1", identity: .init(id: 10, device: 1, names: ["XW-DJ1"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "XW-DJ1", identity: .init(id: 20, device: 1, names: ["XW-DJ1"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func xwdj1Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueXWDJ1UsesIndependentTransportAndBothCueReleaseForms() {
    withXWDJ1 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if !target.action.isJog { events.append((target, value)) }
        }
        for (channel, deck) in DeckID.primary.enumerated() {
            let channel = UInt8(channel)
            for (number, action): (UInt8, ControllerAction) in [
                (42, .playA), (43, .cueSetA), (45, .syncA), (41, .hotcue1A), (40, .hotcue2A),
                (39, .hotcue3A), (35, .loopDownA), (36, .loopA), (37, .loopUpA),
            ] {
                events.removeAll()
                xwdj1Packet([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                xwdj1Packet([0x90 + channel, 44, 127, 44, 127, off + channel, 44, off == 0x80 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueXWDJ1SharedShiftRetiresContactsAndSelectsOnlyNativeShiftActions() {
    withXWDJ1 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if !target.action.isJog { events.append((target, value)) }
        }
        xwdj1Packet([0x90, 59, 127, 0x91, 44, 127, 0x90, 46, 127], input)
        #expect(events.map(\.1) == [1, 1, 0, 0])
        #expect(Set(events.suffix(2).map(\.0.deck)) == [.a, .b])
        events.removeAll()
        for channel: UInt8 in [0, 1] {
            xwdj1Packet([0x90 + channel, 42, 127, 42, 0, 45, 127, 45, 0, 35, 127, 35, 0, 37, 127, 37, 0], input)
        }
        #expect(
            events.map(\.0.action) == [.loadA, .keylockA, .loopInA, .loopOutA, .loadB, .keylockB, .loopInB, .loopOutB])
        events.removeAll()
        xwdj1Packet([0x90, 39, 127, 39, 0, 43, 127, 43, 0, 44, 127, 44, 0, 36, 127, 36, 0], input)
        #expect(events.isEmpty)
        xwdj1Packet([0xB2, 16, 65], input)
        xwdj1Packet([0xB2, 17, 63], input)
        #expect(events.map(\.0.action) == [.browse, .browse])
        #expect(events.first?.1 == 0.5 + 1.0 / 126 && events.last?.1 == 0.5 - 1.0 / 126)
        events.removeAll()
        xwdj1Packet([0x80, 46, 127, 0x90, 42, 127, 42, 0], input)
        #expect(events.map(\.0.action) == [.playA])
    }
}

@Test @MainActor func controllerCatalogueXWDJ1RetainsSharedJogChannelsAndBothFaderOrientations() {
    withXWDJ1 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.primary.enumerated() {
            events.removeAll()
            xwdj1Packet([0xB2, UInt8(16 + side), 65], input)
            #expect(events.count == 1 && events.first?.0.deck == deck && events.first?.0.argument == 300)
            #expect(events.first?.1 == 0.625)
            xwdj1Packet([0xB2, UInt8(16 + side), 63], input)
            #expect(events.last?.1 == 0.375)
        }
        for channel: UInt8 in [0, 1] {
            events.removeAll()
            xwdj1Packet([0xB0 + channel, 16, 64], input)
            xwdj1Packet([0xB0 + channel, 16, 127], input)
            #expect(events.map(\.0.action) == [.crossfader, .crossfader] && events.last?.1 == 1)
        }
        for (status, number, action): (UInt8, UInt8, ControllerAction) in [
            (0xB0, 19, .filterKnobA), (0xB1, 19, .filterKnobB), (0xB1, 17, .master), (0xB0, 18, .monitor),
        ] {
            events.removeAll()
            xwdj1Packet([status, number, 64], input)
            xwdj1Packet([status, number, 127], input)
            #expect(events.map(\.0.action) == [action, action] && events.last?.1 == 1)
        }
        events.removeAll()
        xwdj1Packet([0x90, 32, 127, 33, 127, 34, 127, 0xB0, 20, 127, 0xB1, 20, 127, 0x92, 42, 127], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueXWDJ1KeepsItsOwnLampsAndDocumentedSplitAudioIdentity() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["XW-DJ1"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 41 && data.outputs.count == 14)
    #expect(data.startup.isEmpty && data.shutdown.isEmpty && profile.hasAutomaticSplitOutput)
    let lamps = profile.feedback(destination: 20)
    #expect(lamps.count == 14)
    for lamp in lamps {
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
    for name in ["XW-DJ1", "Casio XW-DJ1 Audio out", "Casio XW-DJ1 Audio out (CoreAudio)"] {
        #expect(AudioOutputDevice(name: name, wired: true).automaticSplitOutputName == profile.rawValue)
        #expect(AudioOutputDevice(name: name, wired: false).automaticSplitOutputName == nil)
    }
    for name in ["XW-J1", "Casio XW-J1", "Vestax Spin2", "Casio MIDI In", "Casio MIDI Out", "XW-DJ1 clone"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
}
