import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRaneOneOriginal(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "rane-one-original-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Rane ONE", identity: .init(id: 10, device: 1, names: ["Rane ONE"])),
        .init(
            id: 11, reference: 101, name: "Rane ONE", identity: .init(id: 11, device: 2, names: ["Rane ONE"])),
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    let profile = try #require(ControllerFactoryProfile.matching(["Rane ONE"]))
    for source: Int32 in [10, 11] {
        input.select(source)
        input.applyFactoryProfile(profile)
    }
    try body(input)
}

@MainActor private func oneOriginalPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRaneOneOriginalKeepsIndependentManualIdentityAndMissingClassBoundaries() throws
{
    let profile = try #require(ControllerFactoryProfile.matching(["Rane ONE"]))
    let data = try #require(profile.definition)
    #expect(!profile.selectsAutomatically && data.inputs.count == 43)
    #expect(data.startup.isEmpty && data.shutdown.isEmpty && data.outputs.isEmpty && data.audioOutput == nil)
    #expect(
        !data.inputs.contains {
            $0.action.isJog || $0.action == .cuePreviewA
                || $0.action == .cuePreviewB
        })
    for name in ["RANE ONE MKII", "RANE FOUR", "RANE PERFORMER", "RANE SYSTEM ONE"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}

@Test @MainActor func controllerCatalogueRaneOneOriginalRoutesEveryIndependentNormalButtonAndBrowser() throws {
    try withRaneOneOriginal { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (channel, deck) in DeckID.primary.enumerated() {
            for (wire, number, action): (UInt8, UInt8, ControllerAction) in [
                (0, 0, .playA), (0, 6, .loadA), (0, 2, .syncA), (0, 13, .keylockA),
                (0, 12, .pitchBendDownA), (0, 11, .pitchBendUpA), (4, 63, .loopA), (4, 65, .reloopA),
                (4, 52, .loopDownA), (4, 53, .loopUpA), (4, 54, .loopInA),
            ] {
                events.removeAll()
                let lane = UInt8(channel) + wire
                oneOriginalPacket([0x90 + lane, number, 127, 0x80 + lane, number, 127], to: input)
                #expect(events.count == (action.isMomentary ? 2 : 1))
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
            events.removeAll()
            oneOriginalPacket([0xB0 + UInt8(channel), 0, 64], to: input)
            #expect(events.isEmpty)
            oneOriginalPacket([0xB0 + UInt8(channel), 0, 65], to: input)
            #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        }
    }
}

@Test @MainActor func controllerCatalogueRaneOneOriginalGlobalShiftRearmsNormalControlsWithoutInventingSyncOff() throws
{
    try withRaneOneOriginal { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { action, value in if !action.isJog { events.append((action, value)) } }
        oneOriginalPacket([0x90, 6, 127, 0x9F, 50, 127, 0x80, 6, 127, 0x9F, 50, 0], to: input)
        events.removeAll()
        oneOriginalPacket([0x90, 6, 127, 6, 0], to: input)
        #expect(events.map(\.0) == [.loadA])
        events.removeAll()
        oneOriginalPacket([0x9F, 50, 127, 0x90, 6, 127, 6, 0, 2, 127, 2, 0, 3, 127, 3, 0], to: input)
        #expect(events.isEmpty)
        events.removeAll()
        oneOriginalPacket([0x90, 6, 127, 6, 0], to: input, source: 11)
        #expect(events.map(\.0) == [.loadA])
        oneOriginalPacket([0x8F, 50, 127], to: input)
    }
}

@Test @MainActor func controllerCatalogueRaneOneOriginalHeldBendReleaseCrossesShiftAndUnknownTrafficStaysInactive()
    throws
{
    try withRaneOneOriginal { input in
        var values: [Double] = []
        var actions: [ControllerAction] = []
        input.onAction = { action, value in
            if action == .pitchBendDownA { values.append(value) }
            if !action.isJog { actions.append(action) }
        }
        oneOriginalPacket([0x90, 12, 127, 0x9F, 50, 127, 0x80, 12, 127, 0x8F, 50, 127], to: input)
        #expect(values == [1, 0])
        actions.removeAll()
        oneOriginalPacket(
            [
                0x90, 1, 127, 3, 127, 5, 127, 49, 127, 0x94, 55, 127, 0, 127, 20, 127, 100, 127,
                0xB0, 6, 127, 9, 127, 41, 127, 23, 127, 28, 127, 0xE0, 127, 127,
                0x92, 6, 127, 0x96, 63, 127,
            ], to: input)
        #expect(actions.isEmpty)
    }
}
