import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withG2V(
    sender: @escaping ([UInt8], Int32) -> Bool = { _, _ in true },
    _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "g2v-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: sender)
    input.sources = [
        .init(id: 10, reference: 100, name: "G2V Audio", identity: .init(id: 10, device: 1, names: ["G2V Audio"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "G2V Audio", identity: .init(id: 20, device: 1, names: ["G2V Audio"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func g2vPacket(_ bytes: [UInt8], source: Int32 = 10, to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueG2VKeepsIndependentIdentityAndSourceLamps() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["G2V Audio"], automaticOnly: true))
    #expect(profile.rawValue == "Gemini G2V" && !profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["G4V Audio"]) != profile)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 86 && data.outputs.count == 8)
    #expect(!data.inputs.contains { $0.kind == .pitch || $0.targetDeck == .c || $0.targetDeck == .d })
    let outputs = profile.feedback(destination: 20)
    #expect(!outputs.contains { $0.action == .syncA || $0.action == .syncB })
    let pfl = try #require(outputs.first { $0.action == .cueB })
    #expect(pfl.message(value: 1) == [0x93, 14, 127])
    #expect(pfl.message(value: 0) == [0x93, 14, 0])
    #expect(!data.startup.contains { $0.first == 0xF0 })
}

@Test @MainActor func controllerCatalogueG2VDispatchesBothDecksAndOnlyReviewedChannels() {
    withG2V { input in
        #expect(input.isInputActive(10))
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        g2vPacket(
            [
                0x90, 1, 127, 2, 127, 0x80, 2, 127, 0x91, 4, 127, 5, 127, 0x93, 1, 127, 2, 127, 13, 127, 14, 127, 17,
                127,
            ], to: input)
        #expect(
            events.map(\.action) == [
                .playA, .cuePreviewA, .cuePreviewA, .syncB, .keylockB, .loadA, .loadB, .cueA, .cueB, .openGroup,
            ])
        events.removeAll()
        g2vPacket([0x94, 1, 127, 0x95, 2, 127, 0x92, 9, 127, 0x90, 3, 127, 35, 127, 17, 127], to: input)
        g2vPacket([0x90, 1, 127], source: 99, to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueG2VKeepsPitchCrossfaderAndEncoderDirections() {
    withG2V { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        for (packet, action, value): ([UInt8], ControllerAction, Double) in [
            ([0xB0, 1, 0], .tempoA, 1), ([0xB1, 1, 127], .tempoB, 0),
            ([0xB3, 25, 127], .crossfader, 0), ([0xB3, 25, 0], .crossfader, 1),
            ([0xB3, 30, 64], .browse, 0.5 - 1.0 / 126), ([0xB3, 30, 65], .browse, 0.5 + 1.0 / 126),
        ] {
            g2vPacket(packet, to: input)
            #expect(events.last?.0 == action && events.last?.1 == value)
        }
        var jogs: [ControllerMIDIValue] = []
        input.onJogAction = { _, value in jogs.append(value) }
        g2vPacket([0xB0, 6, 63], to: input)
        g2vPacket([0xB1, 6, 65], to: input)
        #expect(jogs == [.relative(-1), .relative(1)])
        g2vPacket([0x90, 37, 127, 0x80, 37, 127, 0x91, 37, 127, 37, 0], to: input)
        #expect(events.suffix(4).map(\.0) == [.jogTouchA, .jogTouchA, .jogTouchB, .jogTouchB])
        #expect(events.suffix(4).map(\.1) == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueG2VKeepsIndependentMixerAddresses() {
    withG2V { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in events.append(action) }
        g2vPacket(
            [
                0xB3, 1, 127, 2, 127, 9, 127, 10, 127, 5, 127, 6, 127, 13, 127, 14, 127, 17, 127, 18, 127, 21, 127, 22,
                127, 26, 127, 27, 127, 28, 127,
            ], to: input)
        #expect(
            Set(events)
                == Set([
                    .gainA, .gainB, .highA, .highB, .midA, .midB, .lowA, .lowB, .filterKnobA, .filterKnobB, .levelA,
                    .levelB, .cueMix, .master, .monitor,
                ]))
    }
}

@Test @MainActor func controllerCatalogueG2VPadModesAndShiftStayPerDeckWithReviewedLights() {
    var packets: [[UInt8]] = []
    withG2V(sender: { bytes, _ in
        packets.append(bytes); return true
    }) { input in
        packets.removeAll()
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        g2vPacket([0x90, 9, 127, 40, 127, 0x80, 17, 0, 0x90, 9, 127, 0x91, 16, 127], to: input)
        #expect(events.map(\.action) == [.hotcue1A, .hotcue8B])
        g2vPacket([0x90, 28, 127, 9, 127, 0x80, 9, 0], to: input)
        #expect(events.last?.action == .toggleFixedLoopA)
        #expect(Array(packets.suffix(4)) == [27, 28, 29, 30].map { [0x90, UInt8($0), $0 == 28 ? 127 : 0] })
        g2vPacket([0x90, 29, 127, 10, 127, 30, 127, 11, 127], to: input)
        #expect(events.count == 3)
        g2vPacket([0x90, 40, 0, 27, 127, 9, 0, 9, 127], to: input)
        #expect(events.last?.action == .hotcue1A)
    }
}

@Test @MainActor func controllerCatalogueG2VModeStateSurvivesDiscoveryAndResetsOnReconnect() {
    withG2V { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in events.append(action) }
        g2vPacket([0x90, 28, 127, 9, 127, 0x80, 9, 0], to: input)
        input.reconcileFactoryProfiles()
        g2vPacket([0x90, 10, 127, 0x80, 10, 0], to: input)
        #expect(events == [.toggleFixedLoopA, .toggleFixedLoopA])
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        g2vPacket([0x90, 9, 127], to: input)
        #expect(events.last == .hotcue1A)
    }
}

@Test func controllerCatalogueG2VDecoderStaysRestrictedToBrowserCC() throws {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 { url.deleteLastPathComponent() }
    url.appendPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json")
    let bundled = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let profiles = try #require(bundled["profiles"] as? [[String: Any]])
    var object = try #require(profiles.first { ($0["id"] as? String) == "Gemini G2V" })
    let inputs = try #require(object["inputs"] as? [[String: Any]])
    let index = try #require(inputs.firstIndex { ($0["encoding"] as? String) == "g2vBrowse" })
    for replacement in [["kind": "note"], ["action": "jogA"]] {
        var changed = inputs
        changed[index].merge(replacement) { _, new in new }
        object["inputs"] = changed
        let invalid = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(!invalid.isValid)
    }
}
