import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDJ2GO2Touch(_ body: (ControllerMIDIConnection, () -> [[UInt8]]) throws -> Void) rethrows {
    let suite = "dj2go2-touch-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, destination in
            #expect(destination == 20)
            packets.append(bytes)
            return true
        })
    let name = "DJ2GO2 Touch MIDI"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input, { packets })
}

@MainActor private func dj2go2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueDJ2GO2TouchKeepsItsIdentitySetupAndShutdown() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJ2GO2 Touch MIDI"], automaticOnly: true))
    #expect(profile.rawValue == "Numark DJ2GO2 Touch")
    #expect(profile.definition?.inputs.count == 45)
    #expect(profile.feedback(destination: 20).count == 14)
    #expect(ControllerFactoryProfile.matching(["DJ2GO2"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["DJ2GO Touch"], automaticOnly: true) == nil)
    withDJ2GO2Touch { input, packets in
        #expect(input.isInputActive(10))
        let query: [UInt8] = [0xF0, 0, 1, 0x3F, 0x3C, 0x48, 0xF7]
        #expect(packets() == [query])
        input.reconcileFactoryProfiles()
        #expect(packets().count == 1)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        #expect(packets().count == 15)
        #expect(packets().dropFirst().allSatisfy { $0.count == 3 && $0[2] == 0 })
        input.sources = sources
        input.reconcileFactoryProfiles()
        #expect(packets().last == query)
    }
}

@Test @MainActor func controllerCatalogueDJ2GO2TouchKeepsRaw64PositiveAndItsPublishedResolution() {
    withDJ2GO2Touch { input, _ in
        var counts: [Double] = []
        input.onJogAction = { target, motion in
            #expect(target == .init(.jogA, deck: .a, argument: 236))
            if case .relative(let value) = motion { counts.append(value) }
        }
        for raw in [UInt8(0), 1, 63, 64, 65, 127] {
            dj2go2Packet([0xB0, 6, raw], to: input)
            input.flushPendingActions()
        }
        #expect(counts == [1, 63, 64, -63, -1])
    }
}

@Test @MainActor func controllerCatalogueDJ2GO2TouchUsesFactoryGainBrowserAndTempoMeanings() {
    withDJ2GO2Touch { input, _ in
        var values: [(ControllerAction, Double)] = []
        input.onAction = { action, value in values.append((action, value)) }
        for raw in [UInt8(0), 1, 2, 63, 64, 127] {
            dj2go2Packet([0xBF, 0, raw], to: input)
            input.flushPendingActions()
        }
        #expect(values.map(\.0) == [.browse, .browse])
        #expect(values.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        values.removeAll()
        dj2go2Packet([0x9F, 6, 127, 2, 127, 3, 127, 0xB0, 22, 127, 9, 0, 0xB1, 22, 0], to: input)
        input.flushPendingActions()
        #expect(Array(values.prefix(3)).map(\.0) == [.openGroup, .loadA, .loadB])
        #expect(values.first { $0.0 == .gainA }?.1 == 1)
        #expect(values.first { $0.0 == .gainB }?.1 == 0)
        #expect(values.first { $0.0 == .tempoA }?.1 == 0)
        #expect(!values.contains { [.filterKnobA, .filterKnobB, .levelA, .levelB].contains($0.0) })
    }
}

@Test @MainActor func controllerCatalogueDJ2GO2TouchKeepsCueLoopAndUnsupportedPadRangesSeparate() {
    withDJ2GO2Touch { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        dj2go2Packet([0x94, 1, 127, 0x95, 4, 127, 17, 127, 20, 127, 33, 127, 34, 127, 35, 127], to: input)
        #expect(
            targets == [
                .init(.hotcue1A, deck: .a), .init(.hotcue4B, deck: .b),
                .init(.toggleFixedLoopB, deck: .b, argument: 1), .init(.toggleFixedLoopB, deck: .b, argument: 8),
                .init(.loopInB, deck: .b), .init(.loopOutB, deck: .b), .init(.reloopB, deck: .b),
            ])
        targets.removeAll()
        dj2go2Packet([0x94, 9, 127, 12, 127, 36, 127, 49, 127, 52, 127], to: input)
        input.flushPendingActions()
        #expect(targets.isEmpty)
    }
}

@Test func controllerCatalogueDJ2GO2TouchEncodingsRejectNonControlMessages() throws {
    for encoding in ["dj2go2Jog", "signedStep"] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "fixture", "aliases": ["fixture"],
                    "inputs": [
                        [
                            "action": "jogA", "kind": "note",
                            "channel": 0, "number": 6, "encoding": encoding, "inverted": false,
                        ]
                    ],
                    "outputs": [], "startup": [], "shutdown": [], "autoSelect": true, "scope": "fixture",
                    "source": "fixture",
                ]
            ],
        ])
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
    }
}
