import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withT10(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "t10-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The supplemental T10 profile must not send hardware packets.")
            return false
        })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "DJControl T10", identity: .init(id: 10, device: 1, names: ["DJControl T10"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "DJControl T10", identity: .init(id: 20, device: 1, names: ["DJControl T10"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DJControl T10"])))
    #expect(input.bindingCount == 85)
    try body(input)
}

@MainActor private func t10Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueT10KeepsSupplementalButtonsAndEightCuesPerDeckSeparate() throws {
    try withT10 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for (side, deck) in DeckID.primary.enumerated() {
            let channel = UInt8(side + 1)
            for (number, action): (UInt8, ControllerAction) in [
                (12, .cueA), (13, .loadA), (5, .syncA), (9, .loopInA), (10, .loopOutA), (44, .loopA),
            ] {
                events.removeAll()
                t10Packet([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
            for slot: UInt8 in 0..<8 {
                events.removeAll()
                t10Packet([0x95 + channel, slot, 127, slot, 0], input)
                #expect(events.count == 1 && events.first?.deck == deck && events.first?.action.hotcueSlot == Int(slot))
            }
            events.removeAll()
            t10Packet([0xB0 + channel, 14, 2], input)
            #expect(events.count == 1 && events.first?.action == .loopSizeA.assigned(to: deck))
        }
    }
}

@Test @MainActor func controllerCatalogueT10OwnShiftGuardsGainKeylockAndLibraryWithoutCrossingSides() throws {
    try withT10 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        t10Packet([0x91, 4, 127, 0x94, 82, 127, 82, 0, 9, 127, 9, 0, 10, 127, 10, 0], input)
        #expect(events.map(\.action) == [.keylockA, .loopDownA, .loopUpA])
        events.removeAll()
        t10Packet([0x91, 13, 127, 13, 0, 0x92, 13, 127, 13, 0], input)
        #expect(events.map(\.action) == [.loadB])
        events.removeAll()
        t10Packet([0xB4, 5, 64], input)
        t10Packet([0xB4, 5, 127], input)
        #expect(events.map(\.action) == [.gainA, .gainA])
        events.removeAll()
        t10Packet([0xB4, 15, 1], input)
        t10Packet([0x94, 81, 127, 81, 0, 0x92, 81, 127, 81, 0], input)
        #expect(events.map(\.action) == [.browse, .browsePreviousGroup, .openGroup])
        events.removeAll()
        t10Packet([0x81, 4, 127, 0x91, 13, 127, 13, 0], input)
        #expect(events.map(\.action) == [.loadA])
    }
}

@Test @MainActor func controllerCatalogueT10UsesDistinctNormalAndShiftMixerWiresWithoutSamplerVolume() throws {
    try withT10 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for (side, deck) in DeckID.primary.enumerated() {
            let channel = UInt8(side + 1)
            for (number, action): (UInt8, ControllerAction) in [
                (0, .levelA), (1, .filterKnobA), (2, .lowA), (3, .midA), (4, .highA), (5, .gainA),
            ] {
                events.removeAll()
                t10Packet([0xB0 + channel, number, 64], input)
                t10Packet([0xB0 + channel, number, 127], input)
                #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
            }
        }
        events.removeAll()
        t10Packet([0xB4, 0, 127, 0xB5, 0, 127, 0xB0, 13, 127], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueT10LeavesCoupledMotorTransportAndHardwareWritesInactive() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJControl T10"]))
    let data = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
    #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty && data.audioOutput == nil)
    #expect(AudioOutputDevice(name: "DJControl T10", wired: true).automaticSplitOutputName == nil)
    for name in ["DJControl Inpulse T7", "DJControl Inpulse 200 MK3", "DJControl T10 clone"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    try withT10 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, value in
            if !(action.isJog && value == 0.5) { actions.append(action) }
        }
        for channel: UInt8 in [1, 2, 4, 5] {
            t10Packet(
                [0x90 + channel, 6, 127, 6, 0, 7, 127, 7, 0, 8, 127, 8, 0, 0xB0 + channel, 8, 127, 9, 1, 10, 1], input)
        }
        input.stop()
        #expect(actions.isEmpty)
    }
}
