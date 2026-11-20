import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withVCI380(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "vci380-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The input-only VCI-380 core must not send packets."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "VCI-380",
            identity: .init(id: id, device: UInt32(id), names: ["VCI-380"]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func vci380Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueVCI380OwnIdentityAndInputOnlyContract() throws {
    let p = try #require(ControllerFactoryProfile.matching(["VCI-380"])); let d = try #require(p.definition)
    #expect(d.isValid && p.selectsAutomatically && !d.requiresPairedSetup)
    #expect(d.inputs.count == 44 && d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty)
    #expect(d.inputModes?.allSatisfy { $0.initial == nil && $0.onValue == nil && $0.offValue == nil } == true)
    for other in ["Vestax MIDI In", "Vestax MIDI Out", "VCI-100", "VCI-300", "VCI-400"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    withVCI380 { _ in }
}

@Test @MainActor func controllerCatalogueVCI380TransportBothCueReleasesAndShiftedKeylockLoad() {
    withVCI380 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(7, .a), (8, .b)] {
            let on: UInt8 = 0x90 + ch
            for (n, action): (UInt8, ControllerAction) in [(23, .playA), (19, .syncA)] {
                events.removeAll(); vci380Packet([on, n, 1, n, 127, n, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll();
                    vci380Packet([on, 22, velocity, 22, velocity, off + ch, 22, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
            events.removeAll(); vci380Packet([on + 2, 10, 127, 10, 0, 27, 127, 27, 0], input)
            #expect(events.map { $0.0.action } == [ControllerAction.loadA.assigned(to: deck)])
            events.removeAll()
            for _ in 0..<2 {
                vci380Packet([on, 12, 127, on + 2, 27, 127, on, 12, 0, 27, 0], input)
            }
            #expect(
                events.map { $0.0.action } == Array(repeating: ControllerAction.keylockA.assigned(to: deck), count: 2))
        }
    }
}

@Test @MainActor func controllerCatalogueVCI380PadsRequireKnownModeAndSamplerInvalidatesOnlyItsDeck() {
    withVCI380 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        vci380Packet([0x97, 60, 127, 60, 0, 0x98, 60, 127, 60, 0], input); #expect(events.isEmpty)
        for ch: UInt8 in [7, 8] {
            vci380Packet([0x90 + ch, 56, 1, 56, 0], input)
            for slot: UInt8 in 0..<8 {
                events.removeAll(); vci380Packet([0x90 + ch, 60 + slot, 127, 60 + slot, 127, 60 + slot, 0], input)
                #expect(events.count == 1)
                #expect(events.first?.action.hotcueSlot == Int(slot) && events.first?.deck == (ch == 7 ? .a : .b))
            }
        }
        for mode: UInt8 in [57, 58, 59] {
            events.removeAll(); vci380Packet([0x97, mode, 127, mode, 0, 60, 127, 60, 0], input)
            #expect(events.isEmpty)
        }
        vci380Packet([0x97, 56, 127, 56, 0, 12, 127, 0x99, 56, 127, 56, 0, 0x97, 12, 0], input)
        input.reconcileFactoryProfiles(); events.removeAll()
        vci380Packet([0x97, 60, 127, 60, 0, 0x98, 67, 127, 67, 0], input)
        #expect(events == [.init(.hotcue8B, deck: .b)])
        events.removeAll(); vci380Packet([0x97, 56, 1, 56, 0, 60, 1, 60, 0], input)
        #expect(events == [.init(.hotcue1A, deck: .a)])
        events.removeAll(); vci380Packet([0x97, 60, 127, 60, 0], input, source: 11); #expect(events.isEmpty)
        let sources = input.sources; input.sources = []; input.reconcileFactoryProfiles()
        input.sources = sources; input.reconcileFactoryProfiles()
        vci380Packet([0x97, 60, 127, 60, 0], input); #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueVCI380DirectPFLAndTwelveMixerControlsPreservePickup() {
    withVCI380 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(7, .a), (8, .b)] {
            events.removeAll(); vci380Packet([0x90 + ch, 10, 127, 10, 0], input)
            #expect(
                events.map(\.1) == [1, 0]
                    && events.allSatisfy { $0.0 == .init(ControllerAction.cueStateA.assigned(to: deck), deck: deck) })
            for (n, action): (UInt8, ControllerAction) in [
                (9, .gainA), (72, .highA), (71, .midA), (70, .lowA), (7, .levelA),
            ] {
                events.removeAll(); vci380Packet([0xB0 + ch, n, 0], input); #expect(events.isEmpty)
                vci380Packet([0xB0 + ch, n, 64], input); vci380Packet([0xB0 + ch, n, 127], input)
                #expect(
                    events.count == 2 && events.last?.0 == .init(action.assigned(to: deck), deck: deck)
                        && events.last?.1 == 1)
            }
        }
        for (n, action): (UInt8, ControllerAction) in [(8, .crossfader), (88, .cueMix)] {
            events.removeAll(); vci380Packet([0xB7, n, 0], input); #expect(events.isEmpty)
            vci380Packet([0xB7, n, 64], input); vci380Packet([0xB7, n, 127], input)
            #expect(events.count == 2 && events.last?.0.action == action && events.last?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCatalogueVCI380ShiftKeepsOtherDeckAndOtherSourceContacts() {
    withVCI380 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        vci380Packet([0x97, 22, 127, 0x98, 22, 127], input)
        vci380Packet([0x97, 22, 127], input, source: 11); events.removeAll()
        vci380Packet([0x97, 12, 127, 23, 127, 23, 0], input); #expect(events.isEmpty)
        vci380Packet([0x87, 22, 127], input, source: 11)
        #expect(events.count == 1 && events.first?.0.action == .cuePreviewA && events.first?.1 == 0)
        vci380Packet([0x98, 23, 127, 23, 0], input); #expect(events.last?.0.action == .playB)
        vci380Packet([0x98, 12, 1], input); #expect(events.last?.0.action == .cuePreviewB && events.last?.1 == 0)
        events.removeAll(); vci380Packet([0x97, 12, 0, 22, 1, 22, 0], input)
        #expect(events.map(\.1) == [1.0 / 127, 0])
    }
}

@Test @MainActor func controllerCatalogueVCI380AmbiguousAndUnsupportedWiresRemainInactive() {
    withVCI380 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in [7, 8, 9, 10] {
            vci380Packet([0xB0 + ch, 13, 127, 45, 127, 69, 1, 85, 1, 86, 127, 87, 127, 91, 127], input)
        }
        vci380Packet([0x97, 1, 127, 11, 127, 68, 127, 0x99, 60, 127, 60, 0], input)
        vci380Packet([0x90, 23, 127, 0x9B, 22, 127], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueVCI380ShiftRearmsOnlyItsMixerDeckAndKeepsGlobalCrossfader() {
    withVCI380 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, n): (UInt8, UInt8) in [(7, 7), (8, 7), (7, 8)] {
            vci380Packet([0xB0 + ch, n, 64], input); vci380Packet([0xB0 + ch, n, 127], input)
        }
        events.removeAll(); vci380Packet([0x97, 12, 127, 0xB7, 7, 0], input)
        #expect(events.isEmpty)
        vci380Packet([0xB8, 7, 0], input); #expect(events.last?.0.action == .levelB && events.last?.1 == 0)
        vci380Packet([0xB7, 8, 0], input); #expect(events.last?.0.action == .crossfader && events.last?.1 == 0)
        events.removeAll(); vci380Packet([0x97, 12, 0, 0xB7, 7, 0], input); #expect(events.isEmpty)
        vci380Packet([0xB7, 7, 64], input); #expect(events.count == 1 && events.last?.0.action == .levelA)
        events.removeAll(); vci380Packet([0xB7, 7, 0], input, source: 11); #expect(events.isEmpty)
    }
}
