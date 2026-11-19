import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withManualProtocol(
    _ body: (ControllerMIDIConnection, UserDefaults) throws -> Void
) rethrows {
    let suite = "manual-protocol-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Unmapped MIDI", identity: .init(id: 10, device: 1, names: ["Unmapped MIDI"])),
        .init(id: 11, reference: 101, name: "Other MIDI", identity: .init(id: 11, device: 2, names: ["Other MIDI"])),
    ]
    input.select(10)
    try body(input, preferences)
}

@MainActor private func manualProtocolPacket(
    _ bytes: [UInt8], source: Int32 = 10, time: UInt64 = 1, to input: ControllerMIDIConnection
) {
    input.receiveBytes(bytes, source: source, timestamp: time)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueManualProtocolDecodesVendorInputAndRestoresWithoutBankState() throws {
    try withManualProtocol { input, preferences in
        let profile = try #require(ControllerFactoryProfile.matching(["SMK-25 II"]))
        input.applyFactoryProfile(profile)
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        manualProtocolPacket([0xF0, 0x35, 0x59, 0x10, 47, 0, 0xF7, 0xF0, 0x35, 0x59, 0x10, 94, 127, 0xF7], to: input)
        #expect(actions == [.playB])
        let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
        restored.sources = input.sources
        restored.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        manualProtocolPacket([0xF0, 0x35, 0x59, 0x10, 94, 127, 0xF7], to: restored)
        #expect(actions == [.playB, .playA])
    }
}

@Test @MainActor func controllerCatalogueManualProtocolKeepsTimedLoadAndTwoSourcesSeparate() throws {
    try withManualProtocol { input, _ in
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["CDJ-101"])))
        input.select(11)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["SMK-25 II"])))
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        manualProtocolPacket([0x90, 31, 127], time: 100, to: input)
        manualProtocolPacket([0x80, 31, 127], time: 110, to: input)
        manualProtocolPacket([0xF0, 0x35, 0x59, 0x10, 94, 127, 0xF7], source: 11, to: input)
        #expect(actions == [.loadA, .playA])
        actions.removeAll()
        manualProtocolPacket([0xF0, 0x35, 0x59, 0x10, 94, 127, 0xF7], to: input)
        manualProtocolPacket([0x90, 31, 127, 31, 0], source: 11, to: input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueManualProtocolOrdinaryAndLegacyReplacementClearVendorConversion() throws {
    let replacements: [(ControllerMIDIConnection) -> Void] = [
        { $0.applyFactoryProfile(.flx4) }, { $0.applyDDJFLX4Profile() }, { $0.applyDDJFLX10Profile() },
        { $0.applyDDJ1000Profile() }, { $0.applyDDJREV1Profile() }, { $0.applyDDJREV5Profile() },
    ]
    for replace in replacements {
        try withManualProtocol { input, preferences in
            input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["SMK-25 II"])))
            manualProtocolPacket([0xF0, 0x35, 0x59], to: input)
            replace(input)
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            manualProtocolPacket([0x10, 94, 127, 0xF7, 0x90, 11, 127, 11, 0], to: input)
            #expect(actions == [.playA])
            let stored = preferences.data(forKey: "controllers.midiInputProtocols.v1")
            if let stored { #expect((try JSONDecoder().decode([Int32: String].self, from: stored)).isEmpty) }
        }
    }
}

@Test @MainActor func controllerCatalogueManualProtocolClearReleasesCueAndForgetsFragmentsAndClicks() throws {
    try withManualProtocol { input, _ in
        let smk = try #require(ControllerFactoryProfile.matching(["SMK-25 II"]))
        input.applyFactoryProfile(smk)
        var values: [Double] = []
        input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
        manualProtocolPacket([0xF0, 0x35, 0x59, 0x10, 93, 127, 0xF7], to: input)
        input.clearBindings()
        #expect(values == [1, 0])
        input.applyFactoryProfile(smk)
        manualProtocolPacket([0xF0, 0x35, 0x59, 0x10, 93, 0, 0xF7], to: input)
        #expect(values == [1, 0])
        let cdj = try #require(ControllerFactoryProfile.matching(["CDJ-101"]))
        input.applyFactoryProfile(cdj)
        manualProtocolPacket([0x90, 31, 127], time: 100, to: input)
        input.clearBindings()
        input.applyFactoryProfile(cdj)
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        manualProtocolPacket([0x80, 31, 127], time: 110, to: input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueManualProtocolCannotOverrideKnownOrdinaryFactoryIdentity() throws {
    try withManualProtocol { input, _ in
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["SMK-25 II"])))
        input.sources = [
            .init(
                id: 10, reference: 100, name: "DJ2GO2 Touch",
                identity: .init(id: 10, device: 1, names: ["DJ2GO2 Touch"]))
        ]
        input.destinations = [
            .init(
                id: 20, reference: 200, name: "DJ2GO2 Touch",
                identity: .init(id: 20, device: 1, names: ["DJ2GO2 Touch"]))
        ]
        input.reconcileFactoryProfiles()
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        manualProtocolPacket([0xF0, 0x35, 0x59, 0x10, 94, 127, 0xF7], to: input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueManualProtocolRejectsUnknownOversizedAndUnownedSavedTags() throws {
    let cases = [
        try JSONEncoder().encode([Int32(10): "unknown"]),
        try JSONEncoder().encode([Int32(11): "smk25II"]),
        try JSONEncoder().encode(Dictionary(uniqueKeysWithValues: (0..<65).map { (Int32($0), "smk25II") })),
        Data(repeating: 32, count: 4097),
    ]
    for saved in cases {
        try withManualProtocol { input, preferences in
            input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["SMK-25 II"])))
            preferences.set(saved, forKey: "controllers.midiInputProtocols.v1")
            let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
            restored.sources = input.sources
            var actions: [ControllerAction] = []
            restored.onAction = { action, _ in actions.append(action) }
            manualProtocolPacket([0xF0, 0x35, 0x59, 0x10, 94, 127, 0xF7], to: restored)
            #expect(actions.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueManualProtocolReplacementPreservesOtherSourceCueOwnership() throws {
    try withManualProtocol { input, _ in
        let profile = try #require(ControllerFactoryProfile.matching(["SMK-25 II"]))
        input.applyFactoryProfile(profile)
        input.select(11)
        input.applyFactoryProfile(profile)
        var values: [Double] = []
        input.onAction = { action, value in if action == .cuePreviewA { values.append(value) } }
        let press: [UInt8] = [0xF0, 0x35, 0x59, 0x10, 93, 127, 0xF7]
        manualProtocolPacket(press, to: input)
        manualProtocolPacket(press, source: 11, to: input)
        input.applyDDJFLX4Profile()
        #expect(values == [1])
        input.select(10)
        input.clearBindings()
        #expect(values == [1, 0])
    }
}
