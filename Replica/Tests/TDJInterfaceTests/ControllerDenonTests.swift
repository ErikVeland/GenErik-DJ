import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMC4000(body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "mc4000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "MC4000", identity: .init(id: 10, device: 1, names: ["MC4000"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "MC4000", identity: .init(id: 20, device: 1, names: ["MC4000"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func mc4000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueMC4000UsesFactoryDeckAndGlobalChannels() throws {
    for name in ["MC4000", "Denon MC4000", "Denon DJ MC4000"] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.definition?.startup.first == [240, 0, 2, 11, 127, 1, 96, 0, 4, 4, 1, 0, 0, 247])
        #expect(
            profile.feedback(destination: 20).allSatisfy { $0.kind == .note && $0.onValue == 127 && $0.offValue == 0 })
    }
    withMC4000 { input in
        var received: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in received.append(target) }
        mc4000Packet([0x90, 0, 127, 0x91, 0, 127, 13, 127, 0x9F, 2, 127, 3, 127], to: input)
        #expect(
            received == [
                .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.keylockB, deck: .b), .init(.loadA, deck: .a),
                .init(.loadB, deck: .b),
            ])
    }
    #expect(ControllerFactoryProfile.matching(["MC4000 clone"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueMC4000KeepsWorkingTempoPairAndSignedJog() {
    withMC4000 { input in
        var received: [(ControllerAction, Double)] = []
        input.onAction = { action, value in received.append((action, value)) }
        mc4000Packet([0xB1, 9, 127, 41, 127, 6, 127], to: input)
        input.flushPendingActions()
        #expect(received.first { $0.0 == .tempoB }?.1 == 0)
        #expect(received.first { $0.0 == .jogB }?.1 == 0.375)
        mc4000Packet([0xB1, 9, 0, 41, 0], to: input)
        input.flushPendingActions()
        #expect(received.last?.0 == .tempoB)
        #expect(received.last?.1 == 1)
    }
}

@Test @MainActor func controllerCatalogueMC4000KeepsShiftedManualLoopsSeparate() {
    withMC4000 { input in
        var received: [ControllerAction] = []
        input.onAction = { action, _ in received.append(action) }
        mc4000Packet([0x94, 50, 127, 0x9F, 50, 127, 0x91, 0, 127, 0x94, 56, 127, 0x95, 57, 127], to: input)
        #expect(received == [.loopA, .loopInA, .loopOutB])
        mc4000Packet([0x8F, 50, 0, 0x81, 0, 0, 0x91, 0, 127], to: input)
        #expect(received.last == .playB)
    }
}

@Test @MainActor func controllerCatalogueMC4000RejectsUnsupportedPadsAndReleasesHeldTouch() {
    withMC4000 { input in
        var received: [(ControllerAction, Double)] = []
        input.onAction = { action, value in received.append((action, value)) }
        mc4000Packet(
            [0x94, 20, 127, 0x9A, 127, 127, 0x94, 20, 127, 0x90, 11, 127, 6, 127, 0x9F, 50, 127, 0x80, 6, 0], to: input)
        #expect(received.map(\.0) == [.jogTouchA, .jogTouchA])
        #expect(received.map(\.1) == [1, 0])
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        mc4000Packet([0x90, 0, 127], to: input)
        #expect(received.last?.0 == .playA)
    }
}
