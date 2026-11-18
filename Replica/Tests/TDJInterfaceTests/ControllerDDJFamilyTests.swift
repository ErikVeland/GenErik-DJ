import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let ddjFamilyNames = ["DDJ-SX3", "DDJ-SX2", "DDJ-SX", "DDJ-RX", "DDJ-RZ", "DDJ-RZX"]

@MainActor private func withDDJFamily(_ name: String, body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "ddj-family-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { DeckID.allCases })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func ddjPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerDDJFamilyMatchesModelsAndKeepsDocumentedLimits() throws {
    for name in ddjFamilyNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.rawValue == "Pioneer " + name)
        #expect(!profile.isPlayer)
        #expect(profile.definition?.startup.isEmpty == (name == "DDJ-SX3"))
        let inputs = profile.bindings(source: 10)
        if ["DDJ-SX", "DDJ-SX2", "DDJ-SX3", "DDJ-RX"].contains(name) {
            #expect(!inputs.contains { [.master, .monitor, .cueMix].contains($0.action) })
        }
        if name == "DDJ-SX" { #expect(!inputs.contains { $0.action == .filterKnobB && $0.targetDeck == .d }) }
        if name == "DDJ-RZX" { #expect(!inputs.contains { $0.action == .seekA || $0.action == .seekB }) }
    }
    for name in ["DDJ-SX4", "DDJ-SX3 clone", "DDJ-RZX2", "DDJ-SR2"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
}

@Test @MainActor func controllerDDJFamilyRoutesFourDeckTransportPadsLoopsAndLoad() {
    for name in ddjFamilyNames {
        withDDJFamily(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            for (channel, deck) in zip(UInt8(0)..<4, DeckID.allCases) {
                ddjPacket(
                    [0x90 | channel, 11, 127, 88, 127, 26, 127, 84, 127, 20, 127, 16, 127, 17, 127, 80, 127], to: input)
                ddjPacket([0x90 | (7 + channel), 7, 127, 0x96, 70 + channel, 127], to: input)
                let actions: [ControllerAction] =
                    deck.leftSide
                    ? [.playA, .syncA, .keylockA, .cueA, .loopA, .loopInA, .loopOutA, .reloopA, .hotcue8A, .loadA]
                    : [.playB, .syncB, .keylockB, .cueB, .loopB, .loopInB, .loopOutB, .reloopB, .hotcue8B, .loadB]
                #expect(Array(targets.suffix(10)) == actions.map { .init($0, deck: deck) })
            }
            #expect(targets.count == 40)
        }
    }
}

@Test @MainActor func controllerDDJFamilyDecodesBothPlatterModesAndShiftTouchRelease() {
    for name in ddjFamilyNames {
        withDDJFamily(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            ddjPacket([0x90, 54, 127, 0xB0, 34, 65], to: input)
            input.flushPendingActions()
            ddjPacket([0xB0, 35, 63], to: input)
            input.flushPendingActions()
            ddjPacket([0x80, 103, 0], to: input)
            #expect(
                received.map(\.0) == [
                    .init(.jogTouchA, deck: .a), .init(.jogA, deck: .a), .init(.jogA, deck: .a),
                    .init(.jogTouchA, deck: .a),
                ])
            #expect(received.map(\.1) == [1, 0.625, 0.375, 0])
        }
    }
}

@Test @MainActor func controllerDDJFamilyKeepsLinearNeedleZeroAndBypassesSoftTakeover() {
    for name in ddjFamilyNames where name != "DDJ-RZX" {
        withDDJFamily(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.currentTargetValue = { _ in 0.5 }
            input.onTargetAction = { target, value in received.append((target, value)) }
            ddjPacket([0xB0, 3, 0], to: input)
            input.flushPendingActions()
            ddjPacket([0xB0, 3, 127], to: input)
            input.flushPendingActions()
            #expect(received.map(\.0) == [.init(.seekA, deck: .a), .init(.seekA, deck: .a)])
            #expect(received.map(\.1) == [0, 1])
        }
    }
}

@Test @MainActor func controllerDDJFamilyKeepsMixerPairsBrowseAndFeedbackSeparate() throws {
    for name in ddjFamilyNames {
        withDDJFamily(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            ddjPacket([0xB2, 19, 127, 51, 127], to: input)
            input.flushPendingActions()
            ddjPacket([0xB6, 64, 127, 0x96, 72, 127], to: input)
            #expect(received.map(\.0) == [.init(.levelA, deck: .c), .init(.browse), .init(.loadA, deck: .c)])
            #expect(received.first?.1 == 1)
            #expect(received[1].1 < 0.5)
        }
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        let lights = profile.feedback(destination: 20)
        #expect(lights.contains { $0.action == .playB && $0.targetDeck == .d && $0.channel == 3 && $0.number == 11 })
        #expect(lights.contains { $0.action.hotcueSlot != nil } == (name == "DDJ-SX"))
    }
}
