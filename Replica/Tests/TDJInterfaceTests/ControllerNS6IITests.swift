import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withNS6II(_ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void) rethrows {
    let suite = "ns6ii-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        },
        deckAvailability: { DeckID.allCases })
    input.sources = [.init(id: 10, reference: 100, name: "NS6II", identity: .init(id: 10, device: 1, names: ["NS6II"]))]
    input.destinations = [
        .init(id: 20, reference: 200, name: "NS6II", identity: .init(id: 20, device: 1, names: ["NS6II"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func ns6Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueNS6IIRetainsItsOwnIdentityAndPublishedSetup() throws {
    try withNS6II { input, packets in
        #expect(input.isInputActive(10))
        let profile = try #require(ControllerFactoryProfile.matching(["Numark NS6II"], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == 255 && data.outputs.count == 12)
        #expect(data.inputModes?.count == 4 && data.bankChanges?.count == 6)
        #expect(packets.count == 9 && packets.last == [0xF0, 0, 32, 127, 3, 1, 0xF7])
        #expect(ControllerFactoryProfile.matching(["NS6"]) != profile)
        #expect(ControllerFactoryProfile.matching(["NS6III"]) == nil)
        #expect(!data.inputs.contains { [.master, .monitor, .cueMix].contains($0.action) })
    }
}

@Test @MainActor func controllerCatalogueNS6IIRoutesDeckMixerAndGlobalLoadInputs() {
    withNS6II { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        ns6Packet([0x90, 0, 127, 0x92, 27, 127, 0x9F, 5, 127, 0xB3, 22, 127, 23, 127, 24, 127, 25, 127], to: input)
        #expect(targets.prefix(3) == [.init(.playA, deck: .a), .init(.cueA, deck: .c), .init(.loadB, deck: .d)])
        #expect(Set(targets.dropFirst(3).map(\.action)) == [.gainB, .highB, .midB, .lowB])
        #expect(targets.dropFirst(3).allSatisfy { $0.deck == .d })
    }
}

@Test @MainActor func controllerCatalogueNS6IISharedPadsRequireTheSelectedNativePage() {
    withNS6II { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        ns6Packet([0x94, 20, 127, 20, 0, 11, 127, 21, 127, 21, 0], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a)])
        targets.removeAll()
        ns6Packet([0x94, 16, 127, 20, 127, 25, 127, 26, 127, 27, 127], to: input)
        #expect(
            targets == [
                .init(.toggleFixedLoopA, deck: .a, argument: 1), .init(.toggleFixedLoopA, deck: .a, argument: 32),
            ])
        targets.removeAll()
        ns6Packet([0x94, 20, 0, 14, 127, 20, 127, 22, 127, 23, 127, 24, 127, 26, 127], to: input)
        #expect(targets.map(\.action) == [.loopInA, .loopEnableA, .loopA, .jumpForwardA, .loopDownA])
        targets.removeAll()
        ns6Packet([0x94, 20, 0, 2, 127, 20, 127], to: input)
        #expect(targets.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueNS6IIUSBReleaseClearsOnlyItsPhysicalShiftAndCue() {
    for release in [UInt8(0x9F), UInt8(0x8F)] {
        withNS6II { input, _ in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in
                if !target.action.isJog { events.append((target, value)) }
            }
            ns6Packet([0x90, 1, 127, 32, 127, 0x91, 1, 127, 32, 127], to: input)
            ns6Packet([release, 60, 0], to: input)
            #expect(
                events.map(\.0) == [
                    .init(.cuePreviewA, deck: .a), .init(.cuePreviewB, deck: .b), .init(.cuePreviewA, deck: .a),
                ])
            #expect(events.map(\.1) == [1, 1, 0])
            events.removeAll()
            ns6Packet([0x9F, 60, 127, 0x90, 0, 127, 0x91, 0, 127, 0x9F, 2, 127, 2, 0], to: input)
            #expect(events.map(\.0) == [.init(.playA, deck: .a)])
            ns6Packet([0x81, 32, 0, 0x9F, 2, 127, 0x81, 1, 0], to: input)
            #expect(events.suffix(2).map(\.0) == [.init(.loadA, deck: .a), .init(.cuePreviewB, deck: .b)])
        }
    }
}

@Test @MainActor func controllerCatalogueNS6IIBankChangeRetainsHeldShiftAndResetsOnlyItsPitchPair() {
    withNS6II { input, _ in
        var targets: [ControllerActionTarget] = []
        input.currentTargetValue = { [.tempoA, .tempoB].contains($0.action) ? 0.5 : nil }
        input.onTargetAction = { target, _ in if !target.action.isJog { targets.append(target) } }
        ns6Packet([0xB0, 9, 64, 41, 0, 0xB1, 9, 64, 41, 0], to: input)
        targets.removeAll()
        ns6Packet([0x90, 32, 127, 0x92, 8, 127, 0, 127, 0xB1, 9, 127, 41, 127], to: input)
        #expect(targets == [.init(.tempoB, deck: .b)])
        ns6Packet([0x80, 32, 0, 0x82, 0, 0, 0x92, 0, 127], to: input)
        #expect(targets.last == .init(.playA, deck: .c))
        targets.removeAll()
        ns6Packet([0xB2, 9, 127, 41, 127], to: input)
        #expect(targets.isEmpty)
        ns6Packet([0xB2, 9, 64, 41, 0], to: input)
        #expect(targets == [.init(.tempoA, deck: .c)])
    }
}

@Test @MainActor func controllerCatalogueNS6IIUSBReleaseDiscardsAnIncompletePair() {
    withNS6II { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if [.tempoA, .tempoB].contains(target.action) { targets.append(target) } }
        ns6Packet([0xB0, 9, 25, 0xB1, 9, 30], to: input)
        targets.removeAll()
        ns6Packet([0x9F, 60, 0, 0xB0, 41, 127, 0xB1, 41, 127], to: input)
        #expect(targets == [.init(.tempoB, deck: .b)])
    }
}

@Test @MainActor func controllerCatalogueNS6IIRetainsCountDirectionAndSourceResolution() {
    withNS6II { input, _ in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { target, value in jogs.append((target, value)) }
        ns6Packet([0xB0, 6, 1], to: input)
        ns6Packet([0xB2, 6, 127], to: input)
        #expect(jogs.map(\.0) == [.init(.jogA, deck: .a, argument: 1000), .init(.jogA, deck: .c, argument: 1000)])
        #expect(jogs.map(\.1) == [.relative(1), .relative(-1)])
    }
}

@Test func controllerCatalogueUSBReleaseReportsRequireValidDeclaredShiftChannels() throws {
    let shift: [String: Any] = [
        "action": "shift", "kind": "note", "channel": 0, "number": 32,
        "encoding": "absolute", "inverted": false, "shiftChannel": 0,
    ]
    func decode(_ channels: [Int]) throws -> ControllerProfileCatalogue {
        let profile: [String: Any] = [
            "id": "USB fixture", "aliases": ["USB fixture"], "inputs": [shift],
            "outputs": [], "startup": [], "shutdown": [], "autoSelect": false, "scope": "fixture", "source": "fixture",
            "bankChanges": [
                ["channel": 15, "number": 60, "onValue": 127, "decks": ["a", "c"], "releaseShiftChannels": channels]
            ],
        ]
        return try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [profile]]))
    }
    #expect(try decode([0]).profiles.count == 1)
    #expect(try decode([]).profiles.count == 1)
    for channels in [[0, 0], [1], [16], Array(0...16)] {
        #expect(throws: (any Error).self) { try decode(channels) }
    }
}
