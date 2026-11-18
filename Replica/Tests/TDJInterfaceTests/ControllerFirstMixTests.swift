import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withFirstMix(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "firstmix-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Gemini FirstMix"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func firstMixPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueFirstMixKeepsOriginalIdentityAndBoundedLights() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Gemini FirstMix"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 25 && data.outputs.count == 8)
    #expect(data.startup.count == 48 && data.shutdown.count == 10)
    #expect(data.startup.suffix(2) == [[0x90, 0x48, 100], [0x90, 0x35, 100]])
    #expect(!profile.hasAutomaticSplitOutput)
    for name in ["Gemini FirstMix I/O", "Gemini FirstMix IO", "Gemini FirstMix Pro", "USB Audio Device"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
    #expect(!data.inputs.contains { [.tempoA, .tempoB, .levelA, .levelB, .master].contains($0.action) })
}

@Test @MainActor func controllerCatalogueFirstMixKeepsCuePFLAndLoadSeparate() {
    withFirstMix { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        firstMixPacket([0x90, 0x3B, 127, 0x43, 127, 0x4A, 127, 0x80, 0x3B, 64], to: input)
        firstMixPacket([0x90, 0x42, 127, 0x45, 127, 0x4C, 127, 0x42, 0, 0x4B, 127, 0x34, 127], to: input)
        #expect(
            events.map { $0.0.action } == [
                .cuePreviewA, .cueA, .playA, .cuePreviewA, .cuePreviewB, .cueB, .playB, .cuePreviewB, .loadA, .loadB,
            ])
        #expect(events.map { $0.1 } == [1, 1, 1, 0, 1, 1, 1, 0, 1, 1])
        events.removeAll()
        firstMixPacket(
            [0x90, 0x4F, 127, 0x0D, 127, 0x40, 127, 0x47, 127, 0x48, 127, 0x35, 127, 0x91, 0x3B, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueFirstMixRequiresFullTouchAndKeepsSigned180CountJogs() {
    withFirstMix { input in
        var touches: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .jogTouchA { touches.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        firstMixPacket([0xB0, 0x19, 1, 0x90, 0x4D, 126, 0xB0, 0x19, 2], to: input)
        #expect(touches.isEmpty && jogs.isEmpty)
        firstMixPacket([0x90, 0x4D, 127, 0xB0, 0x19, 3, 0x19, 127], to: input)
        #expect(touches == [1])
        #expect(jogs.count == 1 && jogs.first?.0 == .init(.jogA, deck: .a, argument: 180))
        #expect(jogs.first?.1 == .relative(2))
        firstMixPacket([0xB0, 0x19, 64], to: input)
        #expect(jogs.last?.1 == .relative(-64))
        firstMixPacket([0x80, 0x4D, 127, 0xB0, 0x19, 2], to: input)
        #expect(touches == [1, 0] && jogs.count == 2)
        firstMixPacket([0x90, 0x4E, 127, 0xB0, 0x18, 1], to: input)
        #expect(jogs.last?.0 == .init(.jogB, deck: .b, argument: 180))
    }
}

@Test @MainActor func controllerCatalogueFirstMixRetainsPublishedMixerAssignmentsAndPickup() {
    withFirstMix { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.currentTargetValue = { $0.action == .gainA ? 0.5 : nil }
        firstMixPacket([0xB0, 0x16, 0], to: input)
        #expect(events.isEmpty)
        firstMixPacket(
            [0xB0, 0x16, 64, 0x08, 1, 0x10, 2, 0x14, 3, 0x1C, 4, 0x09, 5, 0x11, 6, 0x15, 7, 0x17, 8, 0x0A, 0], to: input
        )
        #expect(
            Set(events.map { $0.0.action }) == [
                .gainA, .highA, .midA, .lowA, .gainB, .highB, .midB, .lowB, .cueMix, .crossfader,
            ])
        #expect(events.first { $0.0.action == .crossfader }?.1 == 1)
        events.removeAll()
        firstMixPacket([0xB0, 0x1A, 2], to: input)
        #expect(events.last?.0.action == .browse && (events.last?.1 ?? 0) > 0.5)
        firstMixPacket([0xB0, 0x1A, 127], to: input)
        #expect((events.last?.1 ?? 1) < 0.5)
    }
}

@Test @MainActor func controllerCatalogueFirstMixDisconnectClearsOwnedLightsAndReleasesTouch() throws {
    let suite = "firstmix-lifecycle-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        })
    let name = "Gemini FirstMix"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    let data = try #require(ControllerFactoryProfile.matching([name])?.definition)
    #expect(packets == data.startup)
    var touches: [Double] = []
    input.onTargetAction = { target, value in if target.action == .jogTouchA { touches.append(value) } }
    firstMixPacket([0x90, 0x4D, 127], to: input)
    packets.removeAll()
    input.sources = []
    input.reconcileFactoryProfiles()
    #expect(touches == [1, 0])
    #expect(packets == data.shutdown)
}
