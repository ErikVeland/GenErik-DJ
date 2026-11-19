import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMF3D(decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void)
    throws
{
    let suite = "mf3d-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Midi Fighter 3D",
            identity: .init(id: id, device: UInt32(id), names: ["Midi Fighter 3D"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11) && writes == 0)
    let p = try #require(ControllerFactoryProfile.matching(["Midi Fighter 3D"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 128 && writes == 0); try body(input)
}

@MainActor private func mf3dPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMF3DOwnManualIdentityAndOptionalArcadeColours() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Midi Fighter 3D"])); let d = try #require(p.definition)
    #expect(
        d.isValid && !p.selectsAutomatically && d.role == "accessory" && d.inputs.count == 64 && d.outputs.count == 52)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    for other in ["Midi Fighter Spectra", "Midi Fighter 64", "Midi Fighter Pro", "Midi Fighter Twister"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    for lamp in p.feedback(destination: 20) {
        let on: UInt8 =
            [.cuePreviewA, .cuePreviewB].contains(lamp.action)
            ? 84 : [.syncA, .syncB].contains(lamp.action) || lamp.action.hotcueSlot != nil ? 80 : 76
        #expect(lamp.channel == 2 && lamp.number >= 36 && lamp.number <= 99)
        #expect(
            lamp.message(value: 1) == [0x92, lamp.number, on] && lamp.message(value: 0) == [0x92, lamp.number, 67])
    }
    try withMF3D { _ in }
}

@Test @MainActor func controllerCatalogueMF3DAllFourBanksEightHotCuesAndNativeRoles() throws {
    try withMF3D { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (bank, deck) in DeckID.allCases.enumerated() {
            let base = UInt8(36 + 16 * bank)
            for slot in 0..<8 {
                let n = base + UInt8(slot); events.removeAll()
                mf3dPacket([0x92, n, 127, n, 127, 0x82, n, 127], input)
                #expect(events.count == 1 && events.first?.deck == deck && events.first?.action.hotcueSlot == slot)
            }
            for (offset, action): (UInt8, ControllerAction) in [
                (8, .playA), (10, .syncA), (11, .loadA), (12, .cueA), (13, .loopInA), (14, .loopOutA), (15, .reloopA),
            ] {
                let n = base + offset; events.removeAll(); mf3dPacket([0x92, n, 127, n, 127, n, 0], input)
                #expect(events == [.init(action.assigned(to: deck), deck: deck)])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMF3DSoftCueRetainsBothReleaseForms() throws {
    try withMF3D { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (bank, deck) in DeckID.allCases.enumerated() {
            let n = UInt8(45 + 16 * bank)
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x82, 0x92] {
                    events.removeAll();
                    mf3dPacket([0x92, n, velocity, n, velocity, off, n, off == 0x82 ? 127 : 0], input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0] && events.allSatisfy { $0.0.deck == deck })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMF3DBankSelectorsReleaseOnlyTheirSourceAndIgnoreLateOffs() throws {
    try withMF3D { input in
        var events: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target.deck, value)) }
        }
        for bank: UInt8 in 0..<4 {
            for velocity: UInt8 in [1, 64, 127] {
                events.removeAll(); mf3dPacket([0x92, 45, 127], input)
                mf3dPacket([0x93, bank, velocity], input)
                #expect(events.map(\.1) == [1, 0])
                mf3dPacket([0x92, 61, 127, 0x83, bank, 127, 0x93, bank, 0, 0x82, 45, 127], input)
                #expect(events.map(\.1) == [1, 0, 1] && events.last?.0 == .b)
                mf3dPacket([0x82, 61, 127], input)
            }
        }
        events.removeAll(); mf3dPacket([0x92, 45, 127], input); mf3dPacket([0x92, 45, 127], input, source: 11)
        mf3dPacket([0x93, 1, 127, 0x92, 61, 127], input)
        #expect(events.map(\.1) == [1, 1] && events.last?.0 == .b)
        mf3dPacket([0x82, 45, 127], input); #expect(events.count == 2)
        mf3dPacket([0x82, 45, 127], input, source: 11); #expect(events.last?.0 == .a && events.last?.1 == 0)
        input.stop(); #expect(events.last?.0 == .b && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueMF3DUpperBanksRequireOptIn() throws {
    try withMF3D(decks: DeckID.primary) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for n: UInt8 in 68...99 { mf3dPacket([0x92, n, 127, n, 0], input) }
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMF3DIgnoresDuplicateCCsMotionAndForeignNotes() throws {
    try withMF3D { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        mf3dPacket([0x92, 45, 127], input); events.removeAll()
        mf3dPacket(
            [
                0xB5, 45, 127, 45, 0, 0xB3, 0, 127, 1, 127, 45, 127, 0xB4, 45, 127, 0x93, 4, 127, 17, 127, 20, 127, 29,
                127, 0x91, 45, 127, 0xA2, 45, 127,
            ], input)
        #expect(events.isEmpty)
        mf3dPacket([0x82, 45, 127], input); #expect(events.count == 1 && events.last?.1 == 0)
    }
}
