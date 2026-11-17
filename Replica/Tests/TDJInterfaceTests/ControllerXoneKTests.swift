import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func attachXone(_ input: ControllerMIDIConnection, source: Int32 = 10, name: String = "XONE:K2") {
    input.sources = [
        .init(id: source, reference: 100, name: name, identity: .init(id: source, device: 1, names: [name]))
    ]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
}

@MainActor private func xonePacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@MainActor private func withXone(_ body: (ControllerMIDIConnection, UserDefaults) throws -> Void) rethrows {
    let suite = "xone-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    attachXone(input)
    try body(input, preferences)
}

@Test @MainActor func controllerCatalogueXoneFamilyMatchesOnlyPublishedFactoryIdentitiesAndFeedback() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["XONE:K1"], automaticOnly: true))
    for name in ["Allen & Heath Xone:K2", "Allen and Heath Xone K3", "XONE:K3"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == profile)
    }
    #expect(ControllerFactoryProfile.matching(["XONE:K4"], automaticOnly: true) == nil)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 53 && data.outputs.count == 14)
    #expect(data.inputs.allSatisfy { $0.channel == 14 })
    #expect(!profile.hasAutomaticSplitOutput)
    for output in profile.feedback(destination: 20) {
        #expect(output.message(value: 1) == [0x9E, output.number, 127])
        #expect(output.message(value: 0) == [0x8E, output.number, 127])
    }
}

@Test @MainActor func controllerCatalogueXoneLoadModifierCannotTogglePlayAndKeepsShiftOwnership() {
    withXone { input, _ in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        xonePacket([0x9E, 41, 127, 0x8E, 41, 127], to: input)
        xonePacket([0x9E, 15, 127, 41, 127, 0x8E, 41, 127], to: input)
        #expect(actions == [.playA])
        xonePacket([0x9E, 14, 127, 41, 127, 0x8E, 41, 127, 15, 127], to: input)
        xonePacket([0x9E, 42, 127, 0x8E, 42, 127], to: input)
        #expect(actions == [.playA, .loadA, .loadB])
        xonePacket([0x8E, 14, 127, 0x9E, 41, 127, 0x8E, 41, 127], to: input)
        #expect(actions == [.playA, .loadA, .loadB, .playA])
    }
}

@Test @MainActor func controllerCatalogueXoneFixedCuePageBlocksShiftAndOtherHardwareLayouts() {
    withXone { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        xonePacket(
            [
                0x9E, 37, 127, 0x8E, 37, 127, 0x9E, 15, 127, 37, 127, 0x8E, 37, 127,
                15, 127, 0x9E, 37, 127, 0x8E, 37, 127, 0x9E, 26, 127,
            ], to: input)
        #expect(targets == [.init(.hotcue1A, deck: .a), .init(.hotcue1A, deck: .a), .init(.hotcue4B, deck: .b)])
        targets.removeAll()
        xonePacket([0x9D, 41, 127, 0x9E, 48, 127, 0xBE, 0, 1, 4, 127, 16, 127], to: input)
        #expect(targets.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueXoneLowEQRearmsPickupAfterUnsupportedShiftControl() {
    withXone { input, _ in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .lowA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .lowA { values.append(value) } }
        xonePacket([0xBE, 13, 0], to: input)
        #expect(values.isEmpty)
        xonePacket([0xBE, 13, 64], to: input)
        #expect(values.count == 1)
        xonePacket([0x9E, 15, 127, 0xBE, 13, 127, 0x8E, 15, 127, 0xBE, 13, 127], to: input)
        #expect(values.count == 1)
        xonePacket([0xBE, 13, 64], to: input)
        #expect(values.count == 2)
    }
}

@Test @MainActor func controllerCatalogueXoneModifiersStayLocalToTheirPhysicalSource() {
    withXone { input, _ in
        let name = "XONE:K1"
        input.sources.append(
            .init(id: 11, reference: 101, name: name, identity: .init(id: 11, device: 2, names: [name])))
        input.destinations.append(
            .init(id: 21, reference: 201, name: name, identity: .init(id: 21, device: 2, names: [name])))
        input.reconcileFactoryProfiles()
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        xonePacket([0x9E, 14, 127], to: input)
        xonePacket([0x9E, 41, 127], to: input, source: 11)
        xonePacket([0x9E, 41, 127], to: input)
        #expect(actions == [.playA, .loadA])
    }
}

@Test @MainActor func controllerCatalogueXoneCustomReconnectRetainsComposedLoadAndShiftScopes() {
    withXone { input, preferences in
        input.select(10)
        input.learning = .master
        xonePacket([0xBF, 100, 64], to: input)
        let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
        attachXone(restored, source: 11)
        var actions: [ControllerAction] = []
        restored.onTargetAction = { target, _ in actions.append(target.action) }
        xonePacket(
            [
                0x9E, 15, 127, 41, 127, 0x8E, 41, 127, 0x9E, 14, 127, 0x8E, 15, 127,
                0x9E, 41, 127,
            ], to: restored, source: 11)
        #expect(actions == [.loadA])
    }
}

@Test @MainActor func controllerCatalogueXoneDisconnectClearsDeclaredLightsAndCueContacts() throws {
    let suite = "xone-cleanup-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        })
    attachXone(input)
    #expect(packets.first == [0x9E, 12, 127])
    var contacts: [Double] = []
    input.onTargetAction = { target, value in if target.action == .cuePreviewA { contacts.append(value) } }
    xonePacket([0x9E, 45, 127], to: input)
    input.sources = []
    input.reconcileFactoryProfiles()
    #expect(contacts == [1, 0])
    let shutdown = try #require(ControllerFactoryProfile.matching(["XONE:K2"])?.definition?.shutdown)
    #expect(Array(packets.suffix(shutdown.count)) == shutdown)
}
