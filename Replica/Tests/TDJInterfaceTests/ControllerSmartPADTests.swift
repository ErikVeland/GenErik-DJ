import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSmartPAD(
    decks: [DeckID] = DeckID.allCases,
    _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "smartpad-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The SmartPAD input-only grid must not send packets."); return false
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "SmartPAD",
            identity: .init(id: id, device: UInt32(id), names: ["SmartPAD"]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func smartPADPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSmartPADOwnIdentityAndNoUnqualifiedHeldInputsOrWrites() throws {
    let p = try #require(ControllerFactoryProfile.matching(["SmartPAD"])); let d = try #require(p.definition)
    #expect(d.isValid && p.selectsAutomatically && d.role == "accessory" && !d.requiresPairedSetup)
    #expect(d.inputs.count == 60 && d.inputs.allSatisfy { !$0.action.isMomentary })
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    for other in ["SmartPAD II", "MIDIPLUS SmartPAD II", "KIKPAD", "CleverPad", "Launchpad S", "APC MINI"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    withSmartPAD { _ in }
}

@Test @MainActor func controllerCatalogueSmartPADAllSixtyDefaultClipPadsKeepTheirQuadrants() {
    withSmartPAD { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (index, deck) in DeckID.allCases.enumerated() {
            let left = UInt8(index % 2 * 4); let bottom = UInt8(index < 2 ? 112 : 48)
            for (n, action): (UInt8, ControllerAction) in [
                (bottom + left, .playA), (bottom + left + 2, .syncA), (bottom + left + 3, .loadA),
                (bottom - 16 + left, .cueA), (bottom - 16 + left + 1, .loopInA),
                (bottom - 16 + left + 2, .loopOutA), (bottom - 16 + left + 3, .reloopA),
            ] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll(); smartPADPacket([0x90, n, 1, n, 127, off, n, off == 0x80 ? 127 : 0], input)
                    #expect(events == [.init(action.assigned(to: deck), deck: deck)])
                }
            }
            for slot in 0..<8 {
                let n = bottom - 32 - UInt8(slot / 4 * 16) + left + UInt8(slot % 4)
                events.removeAll(); smartPADPacket([0x90, n, 64, n, 127, n, 0], input)
                #expect(events.count == 1 && events.first?.deck == deck && events.first?.action.hotcueSlot == slot)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueSmartPADKeepsSourcesSeparateAndDisconnectDoesNotRepeatPlay() {
    withSmartPAD { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        smartPADPacket([0x90, 112, 127], input)
        smartPADPacket([0x90, 112, 127, 112, 0], input, source: 11)
        smartPADPacket([0x90, 112, 127], input)
        #expect(events.count == 2 && events.allSatisfy { $0 == .init(.playA, deck: .a) })
        smartPADPacket([0x80, 112, 127], input); smartPADPacket([0x90, 112, 127, 112, 0], input)
        #expect(events.count == 3)
        input.stop(); #expect(events.filter { $0.action == .playA }.count == 3)
    }
}

@Test @MainActor func controllerCatalogueSmartPADCDRequiresOptIn() {
    withSmartPAD(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for n: UInt8 in [48, 50, 51, 32, 33, 34, 35, 16, 0, 52, 54, 55, 36, 37, 38, 39, 20, 4] {
            smartPADPacket([0x90, n, 127, n, 0], input)
        }
        #expect(events.isEmpty)
        smartPADPacket([0x90, 112, 127, 112, 0, 116, 127, 116, 0], input)
        #expect(events == [.init(.playA, deck: .a), .init(.playB, deck: .b)])
    }
}

@Test @MainActor func controllerCatalogueSmartPADHeldCueCellsOtherModesEncodersAndSceneButtonsStayInactive() {
    withSmartPAD { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for n: UInt8 in [49, 53, 113, 117] { smartPADPacket([0x90, n, 127, n, 0], input) }
        for ch: UInt8 in [1, 2, 4] {
            for n: UInt8 in [0, 20, 32, 48, 64, 80, 83, 112, 119, 127] {
                smartPADPacket([0x90 + ch, n, 127, 0x80 + ch, n, 0], input)
            }
        }
        for n: UInt8 in [0, 7, 8, 16, 23, 32, 48, 55, 64, 80, 96, 112, 119, 127] {
            smartPADPacket([0xB0, n, 127], input)
        }
        for n: UInt8 in [8, 15, 24, 31, 120, 127] { smartPADPacket([0x90, n, 127, n, 0], input) }
        #expect(events.isEmpty)
    }
}
