import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withCDJ101(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "cdj101-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "CDJ-101", identity: .init(id: 10, device: 1, names: ["CDJ-101"])),
        .init(id: 11, reference: 101, name: "CDJ-101", identity: .init(id: 11, device: 2, names: ["CDJ-101"])),
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func cdj101Packet(
    _ bytes: [UInt8], source: Int32 = 10, time: UInt64 = 1, to input: ControllerMIDIConnection
) {
    input.receiveBytes(bytes, source: source, timestamp: time)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueCDJ101AllocatesPlayersAndKeepsShortClickOwnershipSeparate() {
    withCDJ101 { input in
        #expect(input.playerDeck(source: 10) == .a && input.playerDeck(source: 11) == .b)
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        cdj101Packet([0x90, 31, 127], time: 100, to: input)
        cdj101Packet([0x81, 31, 127], source: 11, time: 110, to: input)
        #expect(events.isEmpty)
        cdj101Packet([0x90, 31, 0], time: 120, to: input)
        cdj101Packet([0x91, 31, 127], source: 11, time: 200, to: input)
        cdj101Packet([0x81, 31, 127], source: 11, time: 210, to: input)
        #expect(events == [.init(.loadA, deck: .a), .init(.loadB, deck: .b)])
        events.removeAll()
        cdj101Packet([0x90, 126, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueCDJ101NormalShiftCueAndBrowserKeepTheirSourceContracts() {
    withCDJ101 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        cdj101Packet([0x90, 42, 127, 42, 0, 43, 127, 31, 127, 0x80, 43, 127, 0x90, 42, 127, 42, 0], to: input)
        #expect(events.map { $0.0.action } == [.playA, .cuePreviewA, .cuePreviewA, .syncA])
        #expect(events.map(\.1) == [1, 1, 0, 1])
        events.removeAll()
        cdj101Packet([0xB0, 56, 65], to: input)
        cdj101Packet([0xB0, 56, 64], to: input)
        #expect(events.map { $0.0.action } == [.browseGroups, .browseGroups])
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        cdj101Packet([0x90, 31, 0], time: 300_000_001, to: input)
        events.removeAll()
        cdj101Packet([0xB0, 56, 65], to: input)
        cdj101Packet([0xB0, 56, 127], to: input)
        #expect(events.map { $0.0.action } == [.browse, .browse])
    }
}

@Test @MainActor func controllerCatalogueCDJ101PreservesCountResolutionAndFullPitchRange() {
    withCDJ101 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var pitch: [Double] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, value in if target.action == .tempoB { pitch.append(value) } }
        cdj101Packet([0xB1, 54, 67], source: 11, to: input)
        cdj101Packet([0xB1, 53, 62], source: 11, to: input)
        #expect(
            jogs.map { $0.0 } == [
                .init(.jogB, deck: .b, argument: 193.05), .init(.wheelJogB, deck: .b, argument: 193.05),
            ])
        #expect(jogs.map(\.1) == [.relative(3), .relative(-2)])
        for (lsb, msb): (UInt8, UInt8) in [(0, 0), (0, 64), (127, 127)] {
            cdj101Packet([0xE1, lsb, msb], source: 11, to: input)
        }
        #expect(pitch == [1, 1 - 8192.0 / 16383, 0])
    }
}

@Test @MainActor func controllerCatalogueCDJ101ResetsClickOnReconnectAndRejectsExpandedOverloadBeforeDispatch() {
    withCDJ101 { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        cdj101Packet([0x90, 31, 127], time: 100, to: input)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        cdj101Packet([0x90, 31, 0], time: 110, to: input)
        #expect(actions.isEmpty)
        #expect(input.receiveBytes([0x90, 31, 127, 31, 0], source: 10, limit: 2, timestamp: 200) == nil)
        #expect(actions.isEmpty)
        #expect(input.status.contains("overload"))
    }
}
