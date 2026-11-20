import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withVirtualityPlay(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "virtuality-play-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual PLAY input must not configure hardware."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "VIRTUALITY-PLAY",
            identity: .init(id: id, device: UInt32(id), names: ["VIRTUALITY-PLAY"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Audiophony PLAY"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 16)
    try body(input)
}

@MainActor private func virtualityPlayPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueVirtualityPlayManualIdentityKeepsUnknownModesInactive() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Audiophony PLAY"]))
    let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == 8 && p.isPlayer && !p.selectsAutomatically)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["VIRTUALITY-PLAY"]) == p)
    #expect(ControllerFactoryProfile.matching(["VIRTUALITY-PLAY"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["PLAY"]) != p)
    #expect(ControllerFactoryProfile.matching(["CDMP700"]) != p)
    #expect(ControllerFactoryProfile.matching(["Audiophony CDX6"]) != p)
    #expect(p.feedback(destination: 20).isEmpty)
    try withVirtualityPlay { _ in }
}

@Test @MainActor func controllerCatalogueVirtualityPlayButtonsRearmOnBothReleaseFormsAcrossChannels() throws {
    try withVirtualityPlay { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 0..<16 {
            for (n, action): (UInt8, ControllerAction) in [
                (53, .playA), (29, .keylockA), (38, .loopInA), (37, .loopOutOrExitA), (36, .reloopA),
            ] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    virtualityPlayPacket(
                        [0x90 + ch, n, 127, n, 127, off + ch, n, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0], input)
                    #expect(events == Array(repeating: .init(action, deck: .a), count: 2))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueVirtualityPlayHeldCueAndBendsUsePositiveVelocitiesAndBothReleases() throws {
    try withVirtualityPlay { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for ch: UInt8 in 0..<16 {
            for (n, action): (UInt8, ControllerAction) in [
                (52, .cuePreviewA), (33, .pitchBendDownA), (32, .pitchBendUpA),
            ] {
                for velocity: UInt8 in [1, 64, 127] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll()
                        virtualityPlayPacket(
                            [0x90 + ch, n, velocity, n, 127, off + ch, n, off == 0x80 ? 127 : 0], input)
                        #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                        #expect(events.allSatisfy { $0.0 == .init(action, deck: .a) })
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueVirtualityPlayRelayOnlyRetiresItsOwnSourceHolds() throws {
    try withVirtualityPlay { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for relay: UInt8 in [47, 56] {
            virtualityPlayPacket([0x90, 52, 127], input)
            virtualityPlayPacket([0x9F, 52, 127], input, source: 11)
            events.removeAll()
            virtualityPlayPacket([0x98, relay, 127, relay, 0], input)
            #expect(events.isEmpty)
            virtualityPlayPacket([0x8F, 52, 127], input, source: 11)
            #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
            events.removeAll()
            virtualityPlayPacket([0x90, 33, 127, 0x8F, relay, 127], input)
            #expect(events.map(\.0) == Array(repeating: .init(.pitchBendDownA, deck: .a), count: 2))
            #expect(events.map(\.1) == [1, 0])
            events.removeAll()
        }
    }
}

@Test @MainActor func controllerCatalogueVirtualityPlayUnqualifiedControlsAndForeignSourcesStayInactive() throws {
    try withVirtualityPlay { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        var jogs = 0; input.onJogAction = { _, _ in jogs += 1 }
        for ch: UInt8 in 0..<16 {
            for n: UInt8 in [
                24, 25, 26, 27, 28, 30, 31, 34, 35, 39, 40, 41, 42, 43, 44, 45, 46, 48, 49, 50, 51, 54, 55, 57, 58, 59,
            ] {
                virtualityPlayPacket([0x90 + ch, n, 127, n, 0], input)
            }
            for n: UInt8 in [14, 20, 21, 25, 26] {
                virtualityPlayPacket([0xB0 + ch, n, 0, n, 64, n, 127], input)
            }
            virtualityPlayPacket([0xE0 + ch, 0, 64], input)
        }
        virtualityPlayPacket([0x90, 53, 127, 52, 127], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 53, value: 127), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty && jogs == 0)
    }
}
