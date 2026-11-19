import Foundation
import TDJCore
import Testing

@testable import TDJInterface

/**
 * Supplies synthetic manufacturer-format assignments, not a physical controller capture.
 */
func controllerOriginalNanoSceneFixture(offset: UInt8 = 0, toggle: Bool = false, global: UInt8 = 7) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: 256)
    data[12] = 15
    data[224] = 255
    for block in 0..<9 {
        let base = 16 + block * 23
        data[base] = UInt8(block)
        data.replaceSubrange((base + 1)...(base + 8), with: [1, offset + 1, 0, 127, 1, offset + 2, 0, 127])
        data.replaceSubrange((base + 9)...(base + 15), with: [1, offset + 3, 0, 127, 0, 0, toggle ? 1 : 0])
        data.replaceSubrange((base + 16)...(base + 22), with: [2, offset + 4, 0, 127, 0, 0, toggle ? 1 : 0])
    }
    var packed: [UInt8] = []
    for start in stride(from: 0, to: data.count, by: 7) {
        let block = Array(data[start..<min(start + 7, data.count)])
        var mask: UInt8 = 0
        for (bit, byte) in block.enumerated() { mask |= ((byte >> 7) & 1) << bit }
        packed += [mask] + block.map { $0 & 127 }
    }
    return [0xF0, 0x42, 0x50, 1, global, 0x2D, 4, 1, 0, 0, 0, 0, 1, 0, 0xF7]
        + [0xF0, 0x42, 0x40 + global, 0, 1, 4, 0, 0x7F, 0x7F, 2, 2, 0x26, 0x40] + packed + [0xF7]
}

@MainActor private final class SceneProbe {
    var packets: [([UInt8], Int32)] = []
    var failAt: Int?
    func send(_ bytes: [UInt8], to destination: Int32) -> Bool {
        packets.append((bytes, destination))
        return packets.count != failAt
    }
}

@MainActor private func withOriginalNanoScene(
    paired: Bool = true, two: Bool = false, decks: [DeckID] = DeckID.allCases, failAt: Int? = nil,
    _ body: (ControllerMIDIConnection, SceneProbe) throws -> Void
) throws {
    let suite = "nano-original-scene-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let probe = SceneProbe()
    probe.failAt = failAt
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { probe.send($0, to: $1) },
        deckAvailability: { decks }, factoryInputConnector: { _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "nanoKONTROL", identity: .init(id: 10, device: 1, names: ["nanoKONTROL"]))
    ]
    if paired {
        input.destinations = [
            .init(
                id: 20, reference: 200, name: "nanoKONTROL MIDI 1",
                identity: .init(id: 20, device: 1, names: ["nanoKONTROL MIDI 1"]))
        ]
    }
    if two {
        input.sources.append(
            .init(
                id: 11, reference: 101, name: "nanoKONTROL", identity: .init(id: 11, device: 2, names: ["nanoKONTROL"]))
        )
        input.destinations.append(
            .init(
                id: 21, reference: 201, name: "nanoKONTROL MIDI 1",
                identity: .init(id: 21, device: 2, names: ["nanoKONTROL MIDI 1"])))
    }
    input.reconcileFactoryProfiles()
    try body(input, probe)
}

@MainActor private func originalNanoPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalNanoSceneRequiresPairedReadOnlyHandshakeAndFreshReconnect() throws {
    try withOriginalNanoScene { input, probe in
        #expect(!input.isInputActive(10) && probe.packets.map(\.0) == [ControllerNanoKontrolSceneDecoder.searchRequest])
        let fixture = controllerOriginalNanoSceneFixture()
        originalNanoPacket(Array(fixture.dropFirst(15)), to: input)
        #expect(!input.isInputActive(10))
        originalNanoPacket(Array(fixture.prefix(15)), to: input)
        #expect(probe.packets.last?.0 == [0xF0, 0x42, 0x47, 0, 1, 4, 0, 0x1F, 0x10, 0, 0xF7])
        #expect(!input.isInputActive(10))
        originalNanoPacket(Array(fixture.dropFirst(15)), to: input)
        #expect(input.isInputActive(10) && input.factoryOutputIsReady(20))
        input.reconcileFactoryProfiles()
        #expect(probe.packets.count == 2)
        let sources = input.sources, destinations = input.destinations
        input.stop()
        #expect(probe.packets.count == 2 && !input.isInputActive(10))
        input.sources = sources
        input.destinations = destinations
        input.reconcileFactoryProfiles()
        #expect(probe.packets.count == 3 && !input.isInputActive(10))
        originalNanoPacket(Array(fixture.dropFirst(15)), to: input)
        #expect(!input.isInputActive(10))
        originalNanoPacket(fixture, to: input)
        #expect(input.isInputActive(10) && probe.packets.count == 4)
    }
    try withOriginalNanoScene(paired: false) { input, probe in
        originalNanoPacket(controllerOriginalNanoSceneFixture(), to: input)
        #expect(!input.isInputActive(10) && probe.packets.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueOriginalNanoSceneRoutesEveryPhysicalMixerSlotAndButtonTypeWithDeckOptIn()
    throws
{
    for decks in [DeckID.primary, DeckID.allCases] {
        for toggle in [false, true] {
            try withOriginalNanoScene(decks: decks) { input, _ in
                originalNanoPacket(controllerOriginalNanoSceneFixture(toggle: toggle), to: input)
                input.currentTargetValue = { _ in 0.5 }
                var events: [(ControllerActionTarget, Double)] = []
                input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
                for (index, deck) in DeckID.allCases.enumerated() {
                    for (channel, number, action): (UInt8, UInt8, ControllerAction) in [
                        (UInt8(index), 1, .levelA), (UInt8(index), 2, .filterKnobA), (UInt8(index + 4), 2, .gainA),
                    ] {
                        events.removeAll()
                        originalNanoPacket([0xB0 + channel, number, 64], to: input)
                        originalNanoPacket([0xB0 + channel, number, 127], to: input)
                        #expect(events.count == (decks.contains(deck) ? 2 : 0))
                        #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    }
                    for (status, number, action): (UInt8, UInt8, ControllerAction) in [
                        (0xB0 + UInt8(index), 3, toggle ? .cueStateA : .cueA),
                        (0x90 + UInt8(index), 4, toggle ? .keylockStateA : .keylockA),
                    ] {
                        events.removeAll()
                        originalNanoPacket([status, number, 127, number, 0], to: input)
                        #expect(events.count == (decks.contains(deck) ? (toggle ? 2 : 1) : 0))
                        #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    }
                }
                for (index, action) in [ControllerAction.master, .monitor, .cueMix, .crossfader].enumerated() {
                    events.removeAll()
                    originalNanoPacket([0xB4 + UInt8(index), 1, 64], to: input)
                    originalNanoPacket([0xB4 + UInt8(index), 1, 0], to: input)
                    #expect(events.map(\.1) == [64.0 / 127, 0])
                    #expect(events.allSatisfy { $0.0.action == action })
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalNanoSceneChangesResetPickupAndKeepSourcesIndependent() throws {
    try withOriginalNanoScene(two: true) { input, _ in
        originalNanoPacket(controllerOriginalNanoSceneFixture(), to: input)
        originalNanoPacket(controllerOriginalNanoSceneFixture(), to: input, source: 11)
        var target = 0.5
        input.currentTargetValue = { _ in target }
        var values: [Double] = []
        input.onAction = { action, value in if action == .levelA { values.append(value) } }
        originalNanoPacket([0xB0, 1, 64], to: input)
        originalNanoPacket([0xB0, 1, 127], to: input)
        #expect(values.count == 2)
        originalNanoPacket([0xF0, 0x42, 0x47, 0, 1, 4, 0, 0x5F, 0x4F, 1, 0xF7], to: input)
        #expect(!input.isInputActive(10) && input.isInputActive(11))
        originalNanoPacket(Array(controllerOriginalNanoSceneFixture(offset: 40).dropFirst(15)), to: input)
        #expect(input.isInputActive(10))
        target = 0.25
        values.removeAll()
        originalNanoPacket([0xB0, 1, 127, 41, 127], to: input)
        #expect(values.isEmpty)
        originalNanoPacket([0xB0, 41, 0], to: input)
        originalNanoPacket([0xB0, 41, 127], to: input)
        #expect(values == [0, 1])
    }
}

@Test @MainActor func controllerCatalogueOriginalNanoSceneReadFailuresStayClosedAndRetryWithoutWrites() throws {
    for failAt in [1, 2] {
        try withOriginalNanoScene(failAt: failAt) { input, probe in
            originalNanoPacket(controllerOriginalNanoSceneFixture(), to: input)
            #expect(!input.isInputActive(10))
            probe.failAt = nil
            input.reconcileFactoryProfiles()
            originalNanoPacket(controllerOriginalNanoSceneFixture(), to: input)
            #expect(input.isInputActive(10))
            #expect(
                probe.packets.allSatisfy { packet, _ in
                    packet == ControllerNanoKontrolSceneDecoder.searchRequest
                        || packet == [0xF0, 0x42, 0x47, 0, 1, 4, 0, 0x1F, 0x10, 0, 0xF7]
                })
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalNanoSceneKeepsSavedRawMappingsUntilExplicitReplacement() throws {
    for overCapacity in [false, true] {
        let suite = "nano-scene-legacy-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var bindings = [
            ControllerBinding(
                source: 10, group: nil, channel: 0, kind: .control, number: 99, parameter: nil, noteNumber: nil,
                action: .crossfader, encoding: nil, inverted: nil, shifted: nil)
        ]
        if overCapacity {
            bindings += (0..<225).map {
                ControllerBinding(
                    source: 11, group: nil, channel: UInt8($0 / 128), kind: .control, number: UInt8($0 % 128),
                    parameter: nil, noteNumber: nil, action: .levelB, encoding: nil, inverted: nil, shifted: nil)
            }
        }
        let saved = try JSONEncoder().encode(bindings)
        preferences.set(saved, forKey: "controllers.midiBindings.v1")
        preferences.set(try JSONEncoder().encode([Int32(10)]), forKey: "controllers.midiActiveInputs.v1")
        let probe = SceneProbe()
        let input = ControllerMIDIConnection(
            preferences: preferences, factoryPacketSender: { probe.send($0, to: $1) },
            factoryInputConnector: { _ in true })
        input.sources = [
            .init(
                id: 10, reference: 100, name: "nanoKONTROL", identity: .init(id: 10, device: 1, names: ["nanoKONTROL"]))
        ]
        input.destinations = [
            .init(
                id: 20, reference: 200, name: "nanoKONTROL", identity: .init(id: 20, device: 1, names: ["nanoKONTROL"]))
        ]
        input.reconcileFactoryProfiles()
        #expect(input.isInputActive(10) && input.factoryOutputIsReady(20) && probe.packets.isEmpty)
        #expect(preferences.data(forKey: "controllers.midiBindings.v1") == saved)
        input.currentTargetValue = { _ in 0.5 }
        var values: [Double] = []
        input.onAction = { action, value in if action == .crossfader { values.append(value) } }
        originalNanoPacket([0xB0, 99, 64], to: input)
        originalNanoPacket([0xB0, 99, 127], to: input)
        #expect(values == [64.0 / 127, 1])
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["nanoKONTROL"])))
        if overCapacity {
            #expect(preferences.data(forKey: "controllers.midiBindings.v1") == saved && probe.packets.isEmpty)
            #expect(input.isInputActive(10))
        } else {
            #expect(input.bindingCount == 32 && !input.isInputActive(10) && !input.factoryOutputIsReady(20))
            #expect(probe.packets.map(\.0) == [ControllerNanoKontrolSceneDecoder.searchRequest])
            originalNanoPacket(controllerOriginalNanoSceneFixture(), to: input)
            #expect(input.isInputActive(10))
        }
    }
}

@Test @MainActor func controllerCatalogueXDJANKeepsSavedRawMappingsUntilExplicitReplacement() throws {
    for overCapacity in [false, true] {
        let suite = "xdjan-legacy-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var bindings = [
            ControllerBinding(
                source: 10, group: nil, channel: 0, kind: .control, number: 99, parameter: nil, noteNumber: nil,
                action: .crossfader, encoding: nil, inverted: nil, shifted: nil)
        ]
        if overCapacity {
            bindings += (0..<158).map {
                ControllerBinding(
                    source: 11, group: nil, channel: UInt8($0 / 128), kind: .control, number: UInt8($0 % 128),
                    parameter: nil, noteNumber: nil, action: .levelB, encoding: nil, inverted: nil, shifted: nil)
            }
        }
        let saved = try JSONEncoder().encode(bindings)
        preferences.set(saved, forKey: "controllers.midiBindings.v1")
        preferences.set(try JSONEncoder().encode([Int32(10)]), forKey: "controllers.midiActiveInputs.v1")
        let probe = SceneProbe()
        let input = ControllerMIDIConnection(
            preferences: preferences, factoryPacketSender: { probe.send($0, to: $1) },
            factoryInputConnector: { _ in true })
        input.sources = [
            .init(
                id: 10, reference: 100, name: "XDJ-AN", identity: .init(id: 10, device: 1, names: ["XDJ-AN"]))
        ]
        input.destinations = [
            .init(
                id: 20, reference: 200, name: "XDJ-AN", identity: .init(id: 20, device: 1, names: ["XDJ-AN"]))
        ]
        input.reconcileFactoryProfiles()
        #expect(input.isInputActive(10) && input.factoryOutputIsReady(20) && probe.packets.isEmpty)
        #expect(preferences.data(forKey: "controllers.midiBindings.v1") == saved)
        input.currentTargetValue = { _ in 0.5 }
        var values: [Double] = []
        input.onAction = { action, value in if action == .crossfader { values.append(value) } }
        originalNanoPacket([0xB0, 99, 64], to: input)
        originalNanoPacket([0xB0, 99, 127], to: input)
        #expect(values == [64.0 / 127, 1])
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["XDJ-AN"])))
        if overCapacity {
            #expect(preferences.data(forKey: "controllers.midiBindings.v1") == saved && probe.packets.isEmpty)
            #expect(input.isInputActive(10))
        } else {
            #expect(input.bindingCount == 99 && !input.isInputActive(10) && !input.factoryOutputIsReady(20))
            #expect(probe.packets.isEmpty)
            originalNanoPacket([0xB0, 100, 127, 0xB1, 100, 127], to: input)
            #expect(input.isInputActive(10))
        }
    }
}
