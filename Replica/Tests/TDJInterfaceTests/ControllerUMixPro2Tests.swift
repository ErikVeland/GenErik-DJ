import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func attachUMix(_ input: ControllerMIDIConnection, source: Int32 = 10) {
    let name = "U-Mix Control Pro 2"
    input.sources = [
        .init(id: source, reference: 100, name: name, identity: .init(id: source, device: 1, names: [name]))
    ]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
}

@MainActor private func withUMix(_ body: (ControllerMIDIConnection, UserDefaults) throws -> Void) rethrows {
    let suite = "umix-pro2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    attachUMix(input)
    try body(input, preferences)
}

@MainActor private func umixPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueUMixPro2KeepsDistinctModelAddressesAndSyncLEDPolarity() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["U-Mix Control Pro 2"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 54 && data.outputs.count == 20)
    #expect(data.startup.count == 12 && data.shutdown.count == 20)
    #expect(!profile.hasAutomaticSplitOutput)
    for name in ["U-Mix Control 2", "U-Mix Control Pro"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
    let sync = try #require(profile.feedback(destination: 20).first { $0.action == .syncA })
    #expect(sync.message(value: 1) == [0x90, 3, 100] && sync.message(value: 0) == [0x90, 3, 0])
    withUMix { input, _ in
        var actions: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in actions.append(target) }
        umixPacket([0x90, 2, 127, 0x91, 2, 127, 0x92, 5, 127, 6, 127], to: input)
        #expect(
            actions == [
                .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.loadA, deck: .a), .init(.loadB, deck: .b),
            ])
    }
}

@Test @MainActor func controllerCatalogueUMixPro2ContactRequiresFullValueAndKeepsBothJogAddresses() {
    withUMix { input, _ in
        var contacts: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .jogTouchA { contacts.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        umixPacket([0x90, 22, 126], to: input)
        #expect(contacts.isEmpty)
        umixPacket([0x90, 22, 127, 0xB0, 22, 65], to: input)
        umixPacket([0xB0, 23, 63, 0x90, 22, 126], to: input)
        #expect(contacts == [1, 0])
        #expect(jogs.map { $0.0.action } == [.jogA, .wheelJogA])
        #expect(jogs.map { $0.1 } == [.relative(1), .relative(-1)] && jogs.allSatisfy { $0.0.argument == 340 })
        input.receive(.init(kind: .note, channel: 0, number: 22, value: 65535, maximum: 65535), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 22, value: 65534, maximum: 65535), source: 10)
        #expect(contacts == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueUMixPro2PitchKeepsExactCentrePickupAndSourcePolarity() {
    withUMix { input, _ in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        umixPacket([0xE0, 0, 0], to: input)
        #expect(values.isEmpty)
        umixPacket([0xE0, 0, 64], to: input)
        umixPacket([0xE0, 127, 127], to: input)
        #expect(values == [0.5, 0])
    }
}

@Test @MainActor func controllerCatalogueUMixPro2DeleteChannelReleasesRearmCuesWithoutDeleting() {
    withUMix { input, _ in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        umixPacket([0x90, 9, 127, 0x83, 9, 127, 0x93, 9, 127, 0x90, 9, 127], to: input)
        #expect(actions == [.hotcue1A, .hotcue1A])
    }
}

@Test @MainActor func controllerCatalogueUMixPro2CustomReconnectRetainsFullContactEncoding() {
    withUMix { input, preferences in
        input.select(10)
        input.learning = .cueA
        umixPacket([0x9F, 100, 127], to: input)
        let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
        attachUMix(restored, source: 11)
        var contacts: [Double] = []
        restored.onTargetAction = { target, value in if target.action == .jogTouchA { contacts.append(value) } }
        umixPacket([0x90, 22, 126, 22, 127, 22, 126], to: restored, source: 11)
        #expect(contacts == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueUMixPro2NativePitchFeedbackReflectsHoldsAndLaterOwnership() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    withUMix { input, _ in
        input.onTargetAction = { target, value in
            model.applyController(target.action, value: value, targetDeck: target.deck)
        }
        umixPacket([0x90, 5, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1.04 && model.controllerValue(.pitchBendUpA) == 1)
        umixPacket([0x90, 4, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        #expect(model.controllerValue(.pitchBendUpA) == 1 && model.controllerValue(.pitchBendDownA) == 1)
        model.perform(.rate, deck: .a, value: 1.02)
        #expect(model.controllerValue(.pitchBendUpA) == 0 && model.controllerValue(.pitchBendDownA) == 0)
        umixPacket([0x80, 4, 127, 5, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1.02 && model.playbackSnapshot?.a.synced == true)
    }
}
