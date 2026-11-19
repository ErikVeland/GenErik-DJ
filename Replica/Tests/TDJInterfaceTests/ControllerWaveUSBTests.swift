import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withWaveUSB(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "wave-usb-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DJControlWave"
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.destinations = [20, 21].map { id in
        .init(
            id: id, reference: UInt32(id + 200), name: name,
            identity: .init(id: id, device: UInt32(id - 10), names: [name]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func wavePacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueWaveUSBIdentityAndSelectedLampsStayIndependent() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJControlWave"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 42 && data.outputs.count == 14 && data.audioOutput == nil)
    #expect(data.startup.count == 14 && data.startup == data.shutdown)
    for lamp in profile.feedback(destination: 20) {
        #expect(lamp.message(value: 1) == [0x90, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90, lamp.number, 0])
        #expect(lamp.number < 48)
    }
    for sibling in ["Universal DJ", "DJControl Instinct P8", "DJControlWave clone"] {
        #expect(ControllerFactoryProfile.matching([sibling], automaticOnly: true) != profile)
    }
}

@Test @MainActor func controllerCatalogueWaveUSBComposesBothModeKeysAndKeepsShiftLoadsOnBothDecks() throws {
    for order: [UInt8] in [[16, 34], [34, 16]] {
        for off: UInt8 in [0x80, 0x90] {
            try withWaveUSB { input in
                var actions: [ControllerAction] = []
                input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
                wavePacket(
                    [
                        0x90, order[0], 127, order[1], 127, off, order[0], off == 0x80 ? 127 : 0, 0x90, 13, 127, 13, 0,
                        31, 127, 31, 0,
                    ], input)
                #expect(actions == [.loadA, .loadB])
                actions.removeAll()
                wavePacket([off, order[1], off == 0x80 ? 127 : 0, 0x90, 13, 127, 13, 0, 31, 127, 31, 0], input)
                #expect(actions == [.playA, .playB])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueWaveUSBTransportCuesAndLoopLibraryLayersRetainEdges() throws {
    try withWaveUSB { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (offset, deck): (UInt8, DeckID) in [(0, .a), (18, .b)] {
            for (base, action): (UInt8, ControllerAction) in [(13, .playA), (14, .syncA), (17, .loopA)] {
                events.removeAll()
                wavePacket([0x90, base + offset, 127, base + offset, 127, base + offset, 0], input)
                #expect(events.map(\.0.action) == [action.assigned(to: deck)])
            }
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                wavePacket([0x90, 15 + offset, 127, 15 + offset, 127, off, 15 + offset, off == 0x80 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
            }
            for slot: UInt8 in 0..<3 {
                events.removeAll()
                wavePacket([0x90, 7 + slot + offset, 127, 7 + slot + offset, 127, 7 + slot + offset, 0], input)
                #expect(events.count == 1 && events.first?.0.action.hotcueSlot == Int(slot))
            }
        }
        for number: UInt8 in [20, 21] {
            events.removeAll()
            for value: UInt8 in [0, 1, 127] { wavePacket([0xB0, number, value], input) }
            #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
            #expect(events.allSatisfy { $0.0.action == (number == 20 ? .loopSizeA : .loopSizeB) })
        }
        wavePacket([0x90, 16, 127], input)
        events.removeAll()
        for number: UInt8 in [20, 21] {
            wavePacket([0xB0, number, 1], input)
            wavePacket([0xB0, number, 127], input)
        }
        wavePacket([0x90, 17, 127, 17, 0, 35, 127, 35, 0], input)
        #expect(events.map(\.0.action) == [.browse, .browse, .browse, .browse, .openGroup, .openGroup])
        events.removeAll()
        wavePacket([0x90, 7, 127, 7, 0, 25, 127, 25, 0, 14, 127, 14, 0], input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueWaveUSBContactWheelAndModeCleanupStaySourceLocal() throws {
    try withWaveUSB { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        var touches: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .jogTouchA || target.action == .jogTouchB { touches.append((target, value)) }
        }
        for side in 0..<2 {
            jogs.removeAll()
            wavePacket([0xB0, UInt8(18 + side), 1], input)
            #expect(jogs.isEmpty)
            wavePacket([0x90, UInt8(18 + 18 * side), 127], input)
            for value: UInt8 in [1, 63, 64, 127] { wavePacket([0xB0, UInt8(18 + side), value], input) }
            #expect(jogs.map(\.1) == [.relative(1), .relative(63), .relative(-64), .relative(-1)])
            #expect(jogs.allSatisfy { $0.0.argument == 512 && $0.0.deck == DeckID.primary[side] })
            jogs.removeAll()
            wavePacket([0xB0, UInt8(18 + side), 1], input, source: 11)
            #expect(jogs.isEmpty)
            wavePacket([0x80, UInt8(18 + 18 * side), 127], input)
            jogs.removeAll()
            wavePacket([0xB0, UInt8(16 + side), 127], input)
            #expect(jogs.map(\.1) == [.relative(-1)] && jogs.first?.0.argument == 512)
        }
        touches.removeAll()
        wavePacket([0x90, 18, 127], input)
        wavePacket([0x90, 18, 127], input, source: 11)
        wavePacket([0x90, 16, 127], input)
        #expect(touches.map(\.1) == [1])
        wavePacket([0x90, 34, 127], input, source: 11)
        #expect(touches.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueWaveUSBMixerAndInvertedPitchKeepPickupAcrossShift() throws {
    try withWaveUSB { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for shifted in [false, true] {
            wavePacket([0x90, 16, shifted ? 127 : 0], input)
            for (deck, numbers): (DeckID, [UInt8]) in [(.a, [2, 4, 7, 8, 9]), (.b, [3, 5, 10, 11, 12])] {
                for (index, number) in numbers.enumerated() {
                    events.removeAll()
                    let inverted = index == 0
                    wavePacket([0xB0, number, inverted ? 127 : 0], input)
                    #expect(events.isEmpty)
                    wavePacket([0xB0, number, 64], input)
                    wavePacket([0xB0, number, inverted ? 0 : 127], input)
                    #expect(events.count == 2 && events.allSatisfy { $0.0.deck == deck } && events.last?.1 == 1)
                }
            }
        }
        for number: UInt8 in [1, 6] {
            events.removeAll()
            wavePacket([0xB0, number, 0], input)
            #expect(events.isEmpty)
            wavePacket([0xB0, number, 64], input)
            wavePacket([0xB0, number, 127], input)
            #expect(events.count == 2 && events.last?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCatalogueWaveUSBCleanupClearsSelectedLampsWithoutRingWrites() throws {
    let suite = "wave-usb-cleanup-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, id in
            #expect(id == 20); packets.append(bytes); return true
        })
    let name = "DJControlWave"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    let data = try #require(ControllerFactoryProfile.matching([name])?.definition)
    #expect(packets == data.startup)
    var values: [Double] = []
    input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
    wavePacket([0x90, 15, 127], input)
    packets.removeAll()
    input.stop()
    #expect(values == [1, 0] && packets == data.shutdown)
    #expect(packets.allSatisfy { $0.count == 3 && $0[0] == 0x90 && $0[1] < 48 })
}
