import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private final class PadProbe {
    var packets: [([UInt8], Int32)] = []
    var failAt: Int?
    func send(_ bytes: [UInt8], destination: Int32) -> Bool {
        packets.append((bytes, destination))
        return packets.count != failAt
    }
}
@MainActor private func withNanoPad2(failAt: Int? = nil, _ body: (ControllerMIDIConnection, PadProbe) throws -> Void)
    rethrows
{
    let suite = "nanopad2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let probe = PadProbe(); probe.failAt = failAt
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { probe.send($0, destination: $1) },
        factoryInputConnector: { _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "nanoPAD2", identity: .init(id: 10, device: 1, names: ["nanoPAD2"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "nanoPAD2 CTRL", identity: .init(id: 20, device: 1, names: ["nanoPAD2 CTRL"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, probe)
}
@MainActor private func padPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}
@MainActor private func preparePad(_ input: ControllerMIDIConnection, channel: UInt8 = 0) {
    padPacket([0xF0, 0x42, 0x50, 1, channel, 0x2D, 0x12, 1, 0, 0, 0, 0, 1, 0, 0xF7], to: input)
    padPacket([0xF0, 0x42, 0x40 + channel, 0, 1, 0x12, 0, 0x40, 0, 3, 0xF7], to: input)
}
@MainActor private func padScene(_ input: ControllerMIDIConnection) { padPacket([0xBF, 57, 127, 57, 0], to: input) }

@Test @MainActor func controllerCatalogueNanoPad2KeepsIndependentIdentityProjectSetupAndSceneLamps() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["nanoPAD2"]))
    #expect(profile.selectsAutomatically && profile.definition?.inputs.count == 31)
    #expect(profile.definition?.outputs.isEmpty == true && profile.definition?.audioOutput == nil)
    for other in ["nanoPAD", "nanoKONTROL2", "nanoKEY2", "padKONTROL"] {
        #expect(ControllerFactoryProfile.matching([other]) != profile)
    }
    for channel: UInt8 in 0..<16 {
        withNanoPad2 { input, probe in
            #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20))
            #expect(probe.packets.map(\.0) == [ControllerKorgNativeDecoder.searchRequest])
            preparePad(input, channel: channel)
            #expect(input.isInputActive(10) && input.factoryOutputIsReady(20))
            #expect(probe.packets[1].0 == [0xF0, 0x42, 0x40 + channel, 0, 1, 0x12, 0, 0, 0, 1, 0xF7])
            for scene in 0..<4 {
                if scene > 0 { padScene(input) }
                #expect(
                    probe.packets.suffix(4).map(\.0)
                        == (0..<4).map { [0xBF, UInt8(121 + $0), $0 == scene ? UInt8(127) : 0] })
            }
            #expect(probe.packets.allSatisfy { $0.1 == 20 })
            input.stop()
            #expect(probe.packets.last?.0 == [0xF0, 0x42, 0x40 + channel, 0, 1, 0x12, 0, 0, 0, 0, 0xF7])
        }
    }
}

@Test @MainActor func controllerCatalogueNanoPad2EverySetupAndSceneLampFailureStaysInactive() {
    for failAt in 1...6 {
        withNanoPad2(failAt: failAt) { input, probe in
            preparePad(input, channel: 8)
            #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20))
            probe.failAt = nil
            input.reconcileFactoryProfiles()
            preparePad(input, channel: 8)
            #expect(input.isInputActive(10))
        }
    }
    withNanoPad2 { input, probe in
        preparePad(input, channel: 9)
        probe.failAt = probe.packets.count + 2
        padScene(input)
        #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20))
        #expect(probe.packets.last?.0 == [0xF0, 0x42, 0x49, 0, 1, 0x12, 0, 0, 0, 0, 0xF7])
    }
}

@Test @MainActor func controllerCatalogueNanoPad2MapsEveryFirstBankCueAndKeepsClearHeldAcrossScenes() {
    withNanoPad2 { input, _ in
        preparePad(input)
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for index: UInt8 in 0..<16 where index != 14 {
            events.removeAll()
            padPacket([0x91, 64 + index, 127, 0x81, 64 + index, 64], to: input)
            #expect(events.count == 1 && events.first?.action.hotcueSlot == Int(index / 2))
            #expect(events.first?.deck == (index % 2 == 0 ? .b : .a))
        }
        events.removeAll()
        padPacket([0x91, 78, 127, 65, 127, 0x81, 65, 64], to: input)
        #expect(events.isEmpty)
        padScene(input)
        padPacket([0x81, 78, 64], to: input)
        padScene(input); padScene(input); padScene(input)
        padPacket([0x91, 65, 127, 0x81, 65, 64], to: input)
        #expect(events == [.init(.hotcue1A, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueNanoPad2RoutesEveryReviewedLoopAndBlocksUnsupportedHeldMovesAndOtherBanks() {
    withNanoPad2 { input, _ in
        preparePad(input)
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        padScene(input)
        for index: UInt8 in 0..<16 { padPacket([0x91, 64 + index, 127, 0x81, 64 + index, 64], to: input) }
        #expect(events.isEmpty)
        padScene(input)
        for (index, action, deck, beats): (UInt8, ControllerAction, DeckID, Double?) in [
            (0, .loopDownB, .b, nil), (1, .loopDownA, .a, nil),
            (2, .fixedLoopB, .b, 1), (3, .fixedLoopA, .a, 1),
            (4, .fixedLoopB, .b, 2), (5, .fixedLoopA, .a, 2),
            (6, .fixedLoopB, .b, 4), (7, .fixedLoopA, .a, 4),
            (8, .loopUpB, .b, nil), (9, .loopUpA, .a, nil),
            (10, .loopInB, .b, nil), (11, .loopInA, .a, nil),
            (12, .loopOutB, .b, nil), (13, .loopOutA, .a, nil),
        ] {
            events.removeAll()
            padPacket([0x91, 64 + index, 127, 0x81, 64 + index, 64], to: input)
            #expect(events == [.init(action, deck: deck, argument: beats)])
        }
        padPacket([0x91, 66, 127], to: input)
        events.removeAll()
        padPacket([0x91, 64, 127, 0x81, 64, 64, 66, 64], to: input)
        #expect(events.isEmpty)
        padScene(input)
        for index: UInt8 in 0..<16 { padPacket([0x91, 64 + index, 127, 0x81, 64 + index, 64], to: input) }
        padPacket([0xBF, 9, 127, 10, 127, 11, 127, 0x92, 60, 127, 0xB2, 2, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueNanoPad2SceneChangesReleaseLearnedCueAndOverloadExitsMode() {
    withNanoPad2 { input, probe in
        preparePad(input, channel: 4)
        input.select(10)
        input.learning = .cuePreviewA
        padPacket([0x91, 65, 127, 0x81, 65, 64], to: input)
        var values: [Double] = []
        input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
        padPacket([0x91, 65, 127], to: input)
        padScene(input)
        #expect(values == [1, 0])
        padPacket([0x81, 65, 64], to: input)
        #expect(values == [1, 0])
        #expect(input.receiveBytes([0xBF, 57, 127], source: 10, limit: 0) == nil)
        #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20))
        #expect(probe.packets.last?.0 == [0xF0, 0x42, 0x44, 0, 1, 0x12, 0, 0, 0, 0, 0xF7])
    }
}
