import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withJogvision(_ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void) rethrows {
    let suite = "jogvision-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes)
            return true
        })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "DJControl Jogvision",
            identity: .init(id: 10, device: 1, names: ["DJControl Jogvision"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "DJControl Jogvision",
            identity: .init(id: 20, device: 1, names: ["DJControl Jogvision"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func jogvisionPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueJogvisionSetsScratchModeRequestsStateAndUsesExactIdentity() throws {
    try withJogvision { input, packets in
        #expect(input.isInputActive(10))
        #expect(packets == [[0xB0, 126, 127], [0x90, 70, 127], [0xB0, 127, 127]])
        let profile = try #require(ControllerFactoryProfile.matching(["DJControl Jogvision"], automaticOnly: true))
        let definition = try #require(profile.definition)
        #expect(definition.inputs.count == 61 && definition.outputs.count == 26)
        #expect(definition.shutdown == [[0xB0, 126, 0], [0x90, 70, 0]])
        #expect(ControllerFactoryProfile.matching(["DJControl Jogvision MK2"], automaticOnly: true) == nil)
        #expect(!definition.inputs.contains { $0.channel == 0 && $0.kind == .control && $0.number == 79 })
    }
}

@Test @MainActor func controllerCatalogueJogvisionRetainsCountResolutionAndIndependentTempoPairs() {
    withJogvision { input, _ in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var events: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { target, motion in jogs.append((target, motion)) }
        input.onTargetAction = { target, value in events.append((target, value)) }
        jogvisionPacket([0xB0, 65, 1, 0xB1, 64, 127, 0xB0, 2, 0, 0xB1, 2, 127, 0xB0, 34, 0, 0xB1, 34, 127], to: input)
        jogs.sort { $0.0.action.rawValue < $1.0.action.rawValue }
        events.sort { $0.0.action.rawValue < $1.0.action.rawValue }
        #expect(jogs.map(\.0) == [.init(.jogA, deck: .a, argument: 400), .init(.wheelJogB, deck: .b, argument: 400)])
        #expect(jogs.map(\.1) == [.relative(1), .relative(-1)])
        #expect(events.map(\.0) == [.init(.tempoA, deck: .a), .init(.tempoB, deck: .b)])
        #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueJogvisionGuardsBothModifiersAndReleasesShiftedCue() {
    withJogvision { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        jogvisionPacket([0x90, 49, 127, 86, 127, 54, 127, 54, 0], to: input)
        #expect(events.map(\.0.action) == [.cuePreviewA, .cuePreviewA])
        #expect(events.map(\.1) == [1, 0])
        events.removeAll()
        jogvisionPacket([0x90, 87, 127, 0x80, 86, 0, 0x90, 81, 127, 0x91, 81, 127], to: input)
        #expect(events.map(\.0) == [.init(.loadB, deck: .b)])
        events.removeAll()
        jogvisionPacket([0x80, 81, 0, 87, 0, 0x90, 81, 127], to: input)
        #expect(events.map(\.0) == [.init(.loadA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueJogvisionKeepsSampleAndDeletePagesSeparateFromHotCues() {
    withJogvision { input, _ in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        jogvisionPacket(
            [
                0x90, 16, 127, 23, 127, 24, 127, 31, 127, 32, 127, 39, 127,
                0x91, 0, 127, 1, 127, 2, 127, 0xB1, 68, 1,
            ], to: input)
        #expect(events.map(\.action) == [.hotcue1A, .hotcue8A, .loopDownB, .loopB, .loopUpB, .loopSizeB])
        #expect(events.suffix(4).allSatisfy { $0.deck == .b })
    }
}
