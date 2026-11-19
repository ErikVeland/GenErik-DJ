import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private final class XDJANProbe {
    var packets: [([UInt8], Int32)] = []
    var fails = false
    func send(_ bytes: [UInt8], _ destination: Int32) -> Bool {
        packets.append((bytes, destination))
        return !fails
    }
}

@MainActor private func withXDJAN(
    paired: Bool = true, _ body: (ControllerMIDIConnection, XDJANProbe) throws -> Void
) throws {
    let suite = "xdjan-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let probe = XDJANProbe()
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { probe.send($0, $1) },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "XDJ-AN",
            identity: .init(id: id, device: UInt32(id), names: ["XDJ-AN"]))
    }
    if paired {
        input.destinations = [20, 21].map { id in
            .init(
                id: id, reference: UInt32(id + 200), name: "XDJ-AN",
                identity: .init(id: id, device: UInt32(id - 10), names: ["XDJ-AN"]))
        }
    }
    input.reconcileFactoryProfiles()
    try body(input, probe)
}

@MainActor private func anPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueXDJANPairedOwnershipGatesInputAndNeverWritesOnStop() throws {
    for paired in [true, false] {
        try withXDJAN(paired: paired) { input, probe in
            #expect(!input.isInputActive(10) && probe.packets.isEmpty)
            var events: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { events.append(action) } }
            anPacket([0x90, 0, 127, 0xB0, 100, 127], input)
            #expect(events.isEmpty && probe.packets.isEmpty)
            anPacket([0xB1, 100, 127, 0x91, 0, 127], input)
            #expect(events.isEmpty && input.isInputActive(10) == paired)
            #expect(!input.isInputActive(11))
            if paired {
                #expect(probe.packets.count == 1 && probe.packets[0].0 == [0xB4, 101, 0] && probe.packets[0].1 == 20)
                #expect(input.factoryOutputIsReady(20) && !input.factoryOutputIsReady(21))
                anPacket([0x91, 0, 127, 0], input)
                #expect(events == [.playB])
            }
            let count = probe.packets.count
            input.stop()
            #expect(probe.packets.count == count && !input.isInputActive(10))
        }
    }
}

@Test @MainActor func controllerCatalogueXDJANModeLossReleasesCueAndDoesNotFightHardwareChoice() throws {
    try withXDJAN { input, probe in
        anPacket([0xB0, 100, 127, 0xB1, 100, 127], input)
        var events: [(ControllerAction, Double)] = []
        input.onAction = { action, value in if !action.isJog { events.append((action, value)) } }
        anPacket([0x90, 1, 127], input)
        anPacket([0xB4, 101, 127], input)
        #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewA] && events.map(\.1) == [1, 0])
        #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20) && probe.packets.count == 1)
        events.removeAll()
        anPacket([0x90, 0, 127, 0xB0, 100, 127, 0xB1, 100, 127], input)
        #expect(events.isEmpty && probe.packets.count == 1)
        anPacket([0xB4, 101, 0], input)
        #expect(input.isInputActive(10))
        anPacket([0x90, 1, 127], input)
        anPacket([0xB1, 100, 0], input)
        #expect(events.map(\.1) == [1, 0] && !input.isInputActive(10))
        anPacket([0xB1, 100, 127], input)
        #expect(input.isInputActive(10) && probe.packets.count == 2)
    }
}

@Test @MainActor func controllerCatalogueXDJANRejectsStaleBatchAndFailedSendThenRetriesFresh() throws {
    try withXDJAN { input, probe in
        anPacket([0xB0, 100, 127, 0xB1, 100, 127, 0xB0, 100, 0], input)
        #expect(probe.packets.isEmpty && !input.isInputActive(10))
        probe.fails = true
        anPacket([0xB0, 100, 127], input)
        #expect(probe.packets.count == 1 && !input.isInputActive(10) && !input.factoryOutputIsReady(20))
        probe.fails = false
        input.reconcileFactoryProfiles()
        anPacket([0xB1, 100, 127], input)
        #expect(!input.isInputActive(10))
        anPacket([0xB0, 100, 127], input)
        #expect(input.isInputActive(10) && probe.packets.count == 2)
        let sources = input.sources, destinations = input.destinations
        input.stop()
        input.sources = sources
        input.destinations = destinations
        input.reconcileFactoryProfiles()
        #expect(!input.isInputActive(10) && probe.packets.count == 2)
        anPacket([0xB1, 100, 127], input)
        #expect(!input.isInputActive(10))
        anPacket([0xB0, 100, 127], input)
        #expect(input.isInputActive(10) && probe.packets.count == 3)
    }
}

@Test @MainActor func controllerCatalogueXDJANCueShiftAndPadPagesStaySideLocal() throws {
    try withXDJAN { input, _ in
        anPacket([0xB0, 100, 127, 0xB1, 100, 127], input)
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for channel: UInt8 in [0, 1] {
            let deck: DeckID = channel == 0 ? .a : .b
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                anPacket([0x90 + channel, 1, 127, off + channel, 1, off == 0x80 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
            for page: UInt8 in [0, 2, 6] {
                for slot: UInt8 in 0..<8 {
                    events.removeAll()
                    anPacket([0x95 + channel, page * 8 + slot, 127, page * 8 + slot, 0], input)
                    #expect(events.count == 1 && events.first?.0.deck == deck)
                    let argument: Double? =
                        page == 0
                        ? nil
                        : (page == 2 ? [-1, 1, -2, 2, -4, 4, -8, 8] : [0.25, 0.5, 1, 2, 4, 8, 16, 32])[Int(slot)]
                    #expect(events.first?.0.argument == argument)
                }
            }
        }
        events.removeAll()
        anPacket([0x90, 1, 127, 0x91, 1, 127, 0x90, 63, 127], input)
        #expect(events.map(\.1) == [1, 1, 0] && events.last?.0.deck == .a)
        anPacket([0x90, 5, 0, 0x97, 0, 127, 0, 0, 0x91, 1, 0], input)
        #expect(events.map(\.1) == [1, 1, 0, 0] && events.last?.0.deck == .b)
        anPacket([0x90, 63, 0], input)
        events.removeAll()
        anPacket([0x90, 1, 127, 80, 127], input)
        #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueXDJANMixerAndWireEncodingsRemainIndependent() throws {
    try withXDJAN { input, _ in
        anPacket([0xB0, 100, 127, 0xB1, 100, 127], input)
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in events.append((target, value)) }
        for (index, deck) in DeckID.primary.enumerated() {
            let channel = UInt8(index)
            for (number, action) in zip(
                index == 0 ? [1, 2, 3, 4, 5, 17] : [6, 7, 8, 9, 10, 18],
                [ControllerAction.gainA, .highA, .midA, .lowA, .filterKnobA, .levelA])
            {
                events.removeAll()
                anPacket([0xB4, UInt8(number), 64], input)
                anPacket([0xB4, UInt8(number), 127], input)
                #expect(events.map(\.1) == [64.0 / 127, 1])
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
            events.removeAll()
            anPacket([0xB4, 70 + channel, 127, 70 + channel, 127, 70 + channel, 0], input)
            #expect(events.count == 1 && events.first?.0.action == .cueA.assigned(to: deck))
            events.removeAll()
            anPacket([0xB0 + channel, 32, 127, 0, 64, 32, 0, 0, 127, 32, 127], input)
            #expect(events.last?.0.action == .tempoA.assigned(to: deck) && events.last?.1 == 1)
            events.removeAll()
            anPacket([0xB0 + channel, 28, 0, 28, 1], input)
            anPacket([0xB0 + channel, 28, 127], input)
            #expect(events.map(\.1) == [0, 1] && events.allSatisfy { $0.0.action == .seekA.assigned(to: deck) })
        }
        events.removeAll()
        anPacket([0xB0, 79, 1], input)
        anPacket([0xB0, 79, 127], input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        events.removeAll()
        anPacket([0xB0, 46, 127, 0x95, 8, 127, 24, 127, 32, 127, 40, 127, 56, 127], input)
        #expect(events.isEmpty)
    }
}

@Test func controllerCatalogueXDJANBankMetadataRetainsABoundedThirtyTwoEntries() throws {
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent(
            "Sources/TDJInterface/Resources/factory-controller-profiles.json")
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
    let profiles = try #require(root["profiles"] as? [[String: Any]])
    var profile = try #require(profiles.first { $0["id"] as? String == "AlphaTheta XDJ-AN" })
    for count in [32, 33] {
        profile["bankChanges"] = (0..<count).map {
            ["channel": 0, "number": $0, "onValue": 127, "decks": ["a"]] as [String: Any]
        }
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [profile]])
        if count == 32 {
            #expect(try ControllerProfileCatalogue.decode(data).profiles.count == 1)
        } else {
            #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
        }
    }
}

@Test @MainActor func controllerCatalogueXDJANModeLossDropsOwnedQueuedMovementAndPreservesOtherSources() throws {
    try withXDJAN { input, _ in
        for source: Int32 in [10, 11] { anPacket([0xB0, 100, 127, 0xB1, 100, 127], input, source: source) }
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        input.receiveBytes([0xB0, 33, 65], source: 10)
        anPacket([0xB4, 101, 127], input)
        #expect(events.isEmpty)
        anPacket([0xB4, 101, 0], input)
        input.receiveBytes([0xB4, 17, 64], source: 10)
        input.receiveBytes([0xB4, 17, 64, 17, 100], source: 11)
        anPacket([0xB4, 101, 127], input)
        #expect(events.map(\.0) == [.levelA] && events.map(\.1) == [100.0 / 127])
        #expect(input.isInputActive(11))
    }
}

@Test @MainActor func controllerCatalogueXDJANModeLossSubtractsOnlyItsMixedJogContribution() throws {
    try withXDJAN { input, _ in
        for source: Int32 in [10, 11] { anPacket([0xB0, 100, 127, 0xB1, 100, 127], input, source: source) }
        var events: [(ControllerAction, Double)] = []
        var counts: [Double] = []
        input.onAction = { events.append(($0, $1)) }
        input.onJogAction = { _, value in if case .relative(let count) = value { counts.append(count) } }
        input.receiveBytes([0xB0, 33, 65], source: 10)
        input.receiveBytes([0xB0, 33, 66], source: 11)
        anPacket([0xB4, 101, 127], input)
        #expect(counts == [2] && events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueXDJANPadModeReleasePreservesANewHeldCue() throws {
    try withXDJAN { input, _ in
        anPacket([0xB0, 100, 127, 0xB1, 100, 127], input)
        var values: [Double] = []
        input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
        anPacket([0x90, 80, 127, 1, 127, 0x80, 80, 127], input)
        #expect(values == [1])
        anPacket([0x80, 1, 127], input)
        #expect(values == [1, 0])
    }
}
