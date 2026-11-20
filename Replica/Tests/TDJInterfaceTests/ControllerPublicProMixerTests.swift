import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withPublicProMixer(
    _ name: String, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "public-promixer-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual public mapping subset must not write hardware state.")
            return false
        })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    for source: Int32 in [10, 11] {
        input.select(source)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    }
    try body(input)
}

@MainActor private func publicProMixerPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCataloguePublicProMixerRetainsTransportEdgesAndBothHeldCueReleaseForms() throws {
    for (name, play, cue, sync): (String, UInt8, UInt8, UInt8) in [
        ("Akai Pro AFX", 49, 50, 51), ("Mixtrack Edge", 59, 51, 64),
    ] {
        try withPublicProMixer(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
            for (channel, deck) in [(UInt8(1), DeckID.a), (2, .b)] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    publicProMixerPacket(
                        [0x90 + channel, cue, 127, cue, 127, off + channel, cue, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [1, 0] && events.allSatisfy { $0.0.deck == deck })
                }
                for number in [play, sync] {
                    events.removeAll()
                    publicProMixerPacket([0x90 + channel, number, 127, number, 127, number, 0], input)
                    #expect(events.count == 1 && events.first?.0.deck == deck)
                }
            }
        }
    }
}

@Test @MainActor func controllerCataloguePublicProMixerKeepsSourceHoldsAndModeCleanupIndependent() throws {
    for (name, cue): (String, UInt8) in [("Akai Pro AFX", 50), ("Mixtrack Edge", 51)] {
        try withPublicProMixer(name) { input in
            var values: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in
                if target.action == .cuePreviewA || target.action == .cuePreviewB { values.append((target, value)) }
            }
            publicProMixerPacket([0x91, cue, 127], input)
            publicProMixerPacket([0x91, cue, 127], input, source: 11)
            publicProMixerPacket(name == "Akai Pro AFX" ? [0x91, 23, 127, 23, 0] : [0x90, 38, 127, 38, 0], input)
            #expect(values.map(\.1) == [1])
            publicProMixerPacket([0x81, cue, 127], input, source: 11)
            #expect(values.map(\.1) == [1, 0])
            publicProMixerPacket([0x92, cue, 127], input)
            input.stop()
            #expect(values.suffix(2).map(\.1) == [1, 0] && values.last?.0.deck == .b)
        }
    }
}

@Test @MainActor func controllerCataloguePublicAFXKeepsSixCuesEightFixedLoopsAndStrictBrowse() throws {
    try withPublicProMixer("Akai Pro AFX") { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for channel: UInt8 in [1, 2] {
            for slot: UInt8 in 0..<6 { publicProMixerPacket([0x90 + channel, 29 + slot, 127, 29 + slot, 0], input) }
            #expect(events.suffix(6).compactMap(\.action.hotcueSlot) == Array(0..<6))
            for slot: UInt8 in 0..<8 { publicProMixerPacket([0x90 + channel, 37 + slot, 127, 37 + slot, 0], input) }
            #expect(events.suffix(8).compactMap(\.argument) == [0.25, 0.5, 1, 2, 4, 8, 16, 32])
        }
        events.removeAll()
        for value: UInt8 in [0, 1, 127, 2, 126, 64] { publicProMixerPacket([0xB1, 9, value], input) }
        #expect(events.map(\.action) == [.browse, .browse])
        events.removeAll()
        publicProMixerPacket([0x91, 28, 127, 28, 127, 28, 0], input)
        #expect(events == [.init(.loadA, deck: .a)])
    }
}

@Test @MainActor func controllerCataloguePublicEdgeShiftSuppressesAlternateActionsAndRearmsNormalButtons() throws {
    try withPublicProMixer("Mixtrack Edge") { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        publicProMixerPacket([0x91, 59, 127, 0x90, 38, 127, 0x81, 59, 127, 0x92, 47, 127, 47, 0, 0x90, 38, 0], input)
        #expect(events.map(\.action) == [.playA])
        publicProMixerPacket([0x91, 59, 127, 59, 0, 0x92, 47, 127, 47, 0], input)
        #expect(events.map(\.action) == [.playA, .playA, .hotcue1B])
        events.removeAll()
        input.currentTargetValue = { _ in 0.5 }
        publicProMixerPacket([0xB1, 8, 64], input)
        publicProMixerPacket([0xB1, 8, 127, 0xB0, 1, 64], input)
        #expect(events.first?.action == .levelA)
        #expect(Set(events.dropFirst().map(\.action)) == [.levelA, .crossfader])
        #expect(events.count == 3)
        events.removeAll()
        for value: UInt8 in [0, 1, 127, 2, 126, 64] { publicProMixerPacket([0xB2, 38, value], input) }
        #expect(events.map(\.action) == [.browse, .browse])
    }
}

@Test @MainActor func controllerCataloguePublicProMixerRejectsUnqualifiedWiresAndNeverSendsHardwareWrites() throws {
    for (name, count) in [("Akai Pro AFX", 44), ("Mixtrack Edge", 51)] {
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        let data = try #require(profile.definition)
        #expect(!profile.selectsAutomatically && data.inputs.count == count && data.outputs.isEmpty)
        #expect(data.startup.isEmpty && data.shutdown.isEmpty && data.audioOutput == nil)
        try withPublicProMixer(name) { input in
            var actions: [ControllerAction] = []
            input.onAction = { action, value in if !(action.isJog && value == 0.5) { actions.append(action) } }
            for number: UInt8 in 101...108 { publicProMixerPacket([0xB0, number, 127], input) }
            publicProMixerPacket([0x93, 49, 127, 49, 0, 0xB0, 37, 127, 0xB1, 37, 1, 39, 1, 40, 1, 41, 1], input)
            input.stop()
            #expect(actions.isEmpty)
        }
        for other in ["AMX", "Mixtrack Pro", "AFX clone", "Mixtrack Edge clone"] {
            #expect(ControllerFactoryProfile.matching([other]) != profile)
        }
    }
}
