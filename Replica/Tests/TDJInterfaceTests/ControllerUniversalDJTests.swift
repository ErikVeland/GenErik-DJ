import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withUniversalDJ(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "universal-dj-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DJHERCULESMIX Universal DJ"
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

@MainActor private func universalPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueUniversalDJReconciledIdentityAndLampMessagesStayBounded() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJHERCULESMIX Universal DJ"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 111 && data.outputs.count == 30 && data.audioOutput == nil)
    #expect(data.startup.count == 30 && data.startup == data.shutdown)
    for light in profile.feedback(destination: 20) {
        #expect(light.message(value: 1) == [0x90 + light.channel, light.number, 127])
        #expect(light.message(value: 0) == [0x90 + light.channel, light.number, 0])
    }
    for sibling in ["DJControlWave", "DJControl Instinct P8", "Périphérique MIDI USB", "Universal DJ clone"] {
        #expect(ControllerFactoryProfile.matching([sibling], automaticOnly: true) != profile)
    }
}

@Test @MainActor func controllerCatalogueUniversalDJBothPublishedPitchFamiliesKeepPickupPolarityAndSourceIsolation()
    throws
{
    try withUniversalDJ { input in
        input.currentTargetValue = { _ in 0.5 }
        var values: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .tempoA || target.action == .tempoB { values.append((target, value)) }
        }
        for (side, deck) in DeckID.primary.enumerated() {
            for (high, low): (UInt8, UInt8) in [
                (UInt8(1 + side), UInt8(33 + side)), (UInt8(55 + side), UInt8(71 + side)),
            ] {
                values.removeAll()
                universalPacket([0xB0, high, 0, low, 0], input)
                #expect(values.isEmpty)
                for raw in [8192, 16383, 0] {
                    universalPacket([0xB0, high, UInt8(raw >> 7), low, UInt8(raw & 127)], input)
                }
                #expect(values.map(\.1) == [1 - 8192.0 / 16383, 0, 1])
                #expect(values.allSatisfy { $0.0.deck == deck })
            }
        }
    }
    try withUniversalDJ { input in
        input.currentTargetValue = { _ in 0.5 }
        var values: [Double] = []
        input.onAction = { action, value in if action == .tempoA { values.append(value) } }
        universalPacket([0xB0, 1, 64], input)
        values.removeAll()
        universalPacket([0xB0, 71, 127], input)
        universalPacket([0xB0, 33, 127], input, source: 11)
        #expect(values.isEmpty)
        universalPacket([0xB0, 33, 127], input)
        #expect(values == [1 - 8319.0 / 16383])
    }
}

@Test @MainActor func controllerCatalogueUniversalDJTransportAndShiftRetireOnlyTheirOwnDeckAndSource() throws {
    try withUniversalDJ { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (channel, deck) in [(UInt8(0), DeckID.a), (1, .b)] {
            for number: UInt8 in [65, 67, 81, 83] {
                events.removeAll()
                universalPacket([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0.deck == deck)
            }
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                universalPacket([0x90 + channel, 66, 127, 66, 127, off + channel, 74, off == 0x80 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0])
            }
        }
        events.removeAll()
        universalPacket([0x90, 66, 127, 0x91, 66, 127], input)
        universalPacket([0x90, 66, 127], input, source: 11)
        universalPacket([0x90, 68, 127], input)
        #expect(events.filter { $0.0.deck == .a }.map(\.1) == [1])
        #expect(events.filter { $0.0.deck == .b }.map(\.1) == [1])
        universalPacket([0x90, 68, 127], input, source: 11)
        #expect(events.filter { $0.0.deck == .a }.map(\.1) == [1, 0])
        universalPacket([0x91, 68, 127], input)
        #expect(events.filter { $0.0.deck == .b }.map(\.1) == [1, 0])
        events.removeAll()
        universalPacket([0x90, 73, 127, 73, 0, 74, 127, 74, 0, 75, 127, 75, 0, 84, 127, 84, 0], input)
        #expect(events.isEmpty)
        universalPacket([0x90, 68, 0, 65, 127, 65, 0], input)
        #expect(events.map(\.0.action) == [.playA])
    }
}

@Test @MainActor func controllerCatalogueUniversalDJ512CountContactAndWheelStreamsRemainSeparate() throws {
    try withUniversalDJ { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        for side in 0..<2 {
            jogs.removeAll()
            universalPacket([0xB0, UInt8(50 + side), 1], input)
            #expect(jogs.isEmpty)
            for touch: UInt8 in [82, 85] {
                universalPacket([0x90 + UInt8(side), touch, 127], input)
                jogs.removeAll()
                for value: UInt8 in [1, 63, 64, 127] { universalPacket([0xB0, UInt8(50 + side), value], input) }
                #expect(jogs.map(\.1) == [.relative(1), .relative(63), .relative(-64), .relative(-1)])
                #expect(jogs.allSatisfy { $0.0.deck == DeckID.primary[side] && $0.0.argument == 512 })
                jogs.removeAll()
                universalPacket([0xB0, UInt8(50 + side), 1], input, source: 11)
                #expect(jogs.isEmpty)
                universalPacket([0x80 + UInt8(side), touch, 127], input)
            }
            jogs.removeAll()
            universalPacket([0xB0, UInt8(48 + side), 127], input)
            #expect(jogs.map(\.1) == [.relative(-1)] && jogs.first?.0.argument == 512)
        }
    }
}

@Test @MainActor func controllerCatalogueUniversalDJMixerUsesReconciledFactoryRowsAndPickup() throws {
    try withUniversalDJ { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (deck, numbers): (DeckID, [UInt8]) in [(.a, [57, 59, 60, 61]), (.b, [58, 62, 63, 64])] {
            for (index, number) in numbers.enumerated() {
                events.removeAll()
                let inverted = index > 0
                universalPacket([0xB0, number, inverted ? 127 : 0], input)
                #expect(events.isEmpty)
                universalPacket([0xB0, number, 64], input)
                universalPacket([0xB0, number, inverted ? 0 : 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0.deck == deck })
                #expect(events.last?.1 == 1)
            }
        }
        events.removeAll()
        universalPacket([0xB0, 65, 64], input)
        #expect(events.map(\.0.action) == [.crossfader])
    }
}

@Test @MainActor func controllerCatalogueUniversalDJEightCuesAndLoopsKeepTheirOwnShiftedFunctions() throws {
    try withUniversalDJ { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (channel, deck) in [(UInt8(0), DeckID.a), (1, .b)] {
            for slot in 0..<8 {
                events.removeAll()
                universalPacket([0x90 + channel, UInt8(17 + slot), 127, UInt8(17 + slot), 0], input)
                #expect(events.count == 1 && events.first?.0.action.hotcueSlot == slot && events.first?.0.deck == deck)
                events.removeAll()
                universalPacket([0x90 + channel, UInt8(49 + slot), 127, UInt8(49 + slot), 0], input)
                #expect(events.first?.0.argument == [0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8][slot])
            }
            events.removeAll()
            for value: UInt8 in [1, 127] { universalPacket([0xB0, 86 + 8 * channel, value], input) }
            #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
            universalPacket([0x90 + channel, 68, 127], input)
            for (index, action) in [ControllerAction.loopInA, .loopOutA, .loopDownA, .loopUpA, .loopA].enumerated() {
                events.removeAll()
                universalPacket([0x90 + channel, UInt8(57 + index), 127, UInt8(57 + index), 0], input)
                #expect(events.map(\.0.action) == [action.assigned(to: deck)])
            }
            for number: UInt8 in [81 + 8 * channel, 83 + 8 * channel, 85 + 8 * channel, 87 + 8 * channel] {
                events.removeAll()
                universalPacket([0xB0, number, 1], input)
                #expect(
                    events.last?.0.action == ControllerAction.gainA.assigned(to: deck)
                        && events.last?.1 == 0.5 + 1.0 / 127)
            }
            events.removeAll()
            universalPacket([0x90 + channel, 17, 127, 17, 0, 25, 127, 25, 0, 49, 127, 49, 0], input)
            #expect(events.isEmpty)
            universalPacket([0x90 + channel, 68, 0], input)
        }
        events.removeAll()
        universalPacket([0xB0, 54, 1], input)
        universalPacket([0xB0, 54, 127], input)
        universalPacket([0x90, 92, 127, 92, 0], input)
        #expect(events.map(\.0.action) == [.browse, .browse, .openGroup])
    }
}

@Test @MainActor func controllerCatalogueUniversalDJDisconnectReleasesContactsAndClearsOnlySelectedLamps() throws {
    let suite = "universal-dj-cleanup-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, id in
            #expect(id == 20); packets.append(bytes); return true
        })
    let name = "Universal DJ"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    let data = try #require(ControllerFactoryProfile.matching([name])?.definition)
    #expect(packets == data.startup)
    var events: [(ControllerAction, Double)] = []
    input.onAction = { action, value in if action.isMomentary { events.append((action, value)) } }
    universalPacket([0x90, 66, 127, 0x91, 82, 127], input)
    packets.removeAll()
    input.sources = []
    input.reconcileFactoryProfiles()
    #expect(events.filter { $0.0 == .cuePreviewA }.map(\.1) == [1, 0])
    #expect(events.filter { $0.0 == .jogTouchB }.map(\.1) == [1, 0])
    #expect(packets == data.shutdown)
}
