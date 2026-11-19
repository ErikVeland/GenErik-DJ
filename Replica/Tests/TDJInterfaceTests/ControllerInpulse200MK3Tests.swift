import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withInpulse200MK3(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "inpulse200mk3-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "DJControl Inpulse 200 Mk3",
            identity: .init(id: 10, device: 1, names: ["DJControl Inpulse 200 Mk3"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "DJControl Inpulse 200 Mk3",
            identity: .init(id: 20, device: 1, names: ["DJControl Inpulse 200 Mk3"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func inpulse200MK3Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueInpulse200MK3UsesItsOwnTransportAndFourCuePads() {
    withInpulse200MK3 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if !target.action.isJog { events.append((target, value)) }
        }
        for (side, deck) in DeckID.primary.enumerated() {
            let channel = UInt8(side + 1)
            for (number, action): (UInt8, ControllerAction) in [
                (7, .playA), (5, .syncA), (12, .cueA), (13, .loadA), (3, .loopA),
            ] {
                events.removeAll()
                inpulse200MK3Packet([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                inpulse200MK3Packet([0x90 + channel, 6, 127, off + channel, 6, off == 0x80 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
            for slot: UInt8 in 0..<4 {
                events.removeAll()
                let status = 0x95 + channel
                inpulse200MK3Packet(
                    [status, slot, 127, slot, 0, slot + 8, 127, slot + 8, 0, slot, 127, slot, 0], input)
                #expect(
                    events.count == 2 && events.allSatisfy { $0.0.deck == deck && $0.0.action.hotcueSlot == Int(slot) })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueInpulse200MK3MapsThreeBandEQAndShiftedGainWithoutHardwareVolumeDuplication() {
    withInpulse200MK3 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for (side, deck) in DeckID.primary.enumerated() {
            for (channel, number, action): (UInt8, UInt8, ControllerAction) in [
                (UInt8(side + 1), 0, .levelA), (UInt8(side + 1), 1, .filterKnobA),
                (UInt8(side + 1), 2, .lowA), (UInt8(side + 1), 4, .midA), (UInt8(side + 1), 5, .highA),
                (UInt8(side + 4), 1, .filterKnobA), (UInt8(side + 4), 2, .lowA),
                (UInt8(side + 4), 4, .highA), (UInt8(side + 4), 5, .gainA),
            ] {
                events.removeAll()
                inpulse200MK3Packet([0xB0 + channel, number, 64], input)
                inpulse200MK3Packet([0xB0 + channel, number, 127], input)
                #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
            }
        }
        events.removeAll()
        inpulse200MK3Packet([0xB0, 3, 127, 4, 127, 64, 127, 65, 127, 0xB4, 0, 127, 0xB5, 0, 127], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueInpulse200MK3UsesFactory512CountMagnitudeAndQualifiedShiftReleases() {
    withInpulse200MK3 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (side, deck) in DeckID.primary.enumerated() {
            let channel = UInt8(side + 1)
            for (number, action): (UInt8, ControllerAction) in [(9, .wheelJogA), (10, .jogA)] {
                events.removeAll()
                inpulse200MK3Packet([0xB0 + channel, number, 2], input)
                inpulse200MK3Packet([0xB0 + channel, number, 126], input)
                #expect(events.map(\.1) == [0.75, 0.25])
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck, argument: 512) })
            }
            events.removeAll()
            inpulse200MK3Packet([0x90 + channel, 6, 127, 0x90 + channel + 3, 6, 0], input)
            #expect(events.map(\.1) == [1, 0])
            inpulse200MK3Packet([0x90 + channel, 8, 127, 0x90 + channel + 3, 3, 127], input)
            #expect(events.contains { $0.0.deck == deck && $0.0.action.isMomentary && $0.1 == 0 })
        }
    }
}

@Test @MainActor func controllerCatalogueInpulse200MK3OwnsOnlyReviewedLampsAndItsClassCompliantSplitRoute() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJControl Inpulse 200 Mk3"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 65 && data.outputs.count == 18 && profile.hasAutomaticSplitOutput)
    #expect(data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(!data.inputs.contains { [.shift, .master, .monitor, .cueMix].contains($0.action) })
    #expect(data.outputs.allSatisfy { $0.onValue == 127 && $0.offValue == 0 && [1, 2, 6, 7].contains($0.channel) })
    #expect(
        AudioOutputDevice(name: "DJControl Inpulse 200 Mk3", wired: true).automaticSplitOutputName == profile.rawValue)
    #expect(AudioOutputDevice(name: "DJControl Inpulse 200 Mk3", wired: false).automaticSplitOutputName == nil)
    for name in [
        "DJControl Inpulse 200", "DJControl Inpulse 200 MK2", "DJControl Inpulse 300 MK2", "Inpulse 200 MK3 clone",
    ] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
}
