import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginal200(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original200-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DJControl Inpulse 200"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func original200Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalInpulse200KeepsPhysicalBandsSetupAndAudioLayout() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJControl Inpulse 200"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 97 && data.outputs.count == 22)
    #expect(data.startup == [[0x91, 3, 127], [0x92, 3, 127], [0x90, 4, 5], [0xB0, 127, 127]])
    #expect(!data.inputs.contains { [.master, .monitor, .midA, .midB].contains($0.action) })
    #expect(profile.hasAutomaticSplitOutput)
    #expect(AudioOutputDevice(name: "DJControl Inpulse 200", wired: true).automaticSplitOutputName == profile.rawValue)
    #expect(AudioOutputDevice(name: "DJControl Inpulse 200", wired: false).automaticSplitOutputName == nil)
    #expect(ControllerFactoryProfile.matching(["DJControl Inpulse 200 MK3"], automaticOnly: true) != profile)
}

@Test @MainActor func controllerCatalogueOriginalInpulse200MixerPairsRetainLowBitsAndLocalShiftPickup() {
    withOriginal200 { input in
        var values: [ControllerActionTarget: Double] = [:]
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { values[$0] = $1 }
        original200Packet([0xB1, 0, 64, 32, 1, 8, 64, 40, 0], to: input)
        #expect(values[.init(.levelA, deck: .a)] == 8193.0 / 16383)
        #expect(values[.init(.tempoA, deck: .a)] == 1 - 8192.0 / 16383)
        values.removeAll()
        original200Packet([0x91, 4, 127, 0xB4, 0, 127, 32, 127, 8, 0, 40, 0, 0xB2, 4, 127, 36, 127], to: input)
        #expect(values == [.init(.highB, deck: .b): 1])
        original200Packet([0x81, 4, 0, 0xB1, 40, 127, 8, 0, 40, 0], to: input)
        #expect(values[.init(.tempoA, deck: .a)] == nil)
    }
}

@Test @MainActor func controllerCatalogueOriginalInpulse200KeepsConfirmedShiftReleaseAndSeparatePadPages() {
    withOriginal200 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        original200Packet(
            [
                0x91, 6, 127, 7, 127, 0x96, 0, 127, 0x91, 4, 127,
                0x94, 6, 127, 7, 127, 6, 0, 7, 0, 0x96, 8, 127, 8, 0,
                0x81, 4, 0, 0x91, 7, 127, 0x96, 0, 127, 16, 127, 32, 127, 48, 127,
            ], to: input)
        #expect(events.filter { $0.0.action == .cuePreviewA }.map(\.1) == [1, 0])
        #expect(events.filter { $0.0.action == .playA }.count == 2)
        #expect(events.filter { $0.0.action == .hotcue1A }.count == 2)
        #expect(events.count == 7)
        #expect(events.filter { $0.0.action == .clearHotcue1A }.count == 1)
    }
}

@Test @MainActor func controllerCatalogueOriginalInpulse200JogsRetainFactoryMagnitudesAndShiftScale() {
    withOriginal200 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        original200Packet([0xB1, 10, 2, 0xB2, 9, 126], to: input)
        #expect(jogs.first { $0.0.action == .jogA }?.1 == .relative(2))
        #expect(jogs.first { $0.0.action == .wheelJogB }?.1 == .relative(-2))
        #expect(jogs.allSatisfy { $0.0.argument == 248 })
        jogs.removeAll()
        original200Packet([0x91, 4, 127, 0xB4, 10, 1, 0xB2, 10, 1], to: input)
        #expect(jogs.first { $0.0.deck == .a }?.0.argument == 62)
        #expect(jogs.first { $0.0.deck == .b }?.0.argument == 248)
    }
}

@Test @MainActor func controllerCatalogueOriginalInpulse200LoopButtonsKeepDistinctPressAndReleaseActions() {
    withOriginal200 { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        original200Packet(
            [
                0x91, 9, 127, 4, 127, 0x94, 9, 0, 9, 127,
                0x81, 4, 0, 0x91, 9, 0, 9, 127, 10, 127, 11, 127,
            ], to: input)
        #expect(
            targets == [
                .init(.loopInA, deck: .a), .init(.loopDownA, deck: .a),
                .init(.loopInA, deck: .a), .init(.loopOutOrExitA, deck: .a),
                .init(.fixedLoopA, deck: .a, argument: 4),
            ])
    }
}

@Test @MainActor func controllerCatalogueOriginalInpulse200ManualLoopExitLongInAndScratchPreserveSync() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    let suite = "original200-playback-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DJControl Inpulse 200"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    input.onJogAction = { model.applyControllerJog($0, motion: $1) }
    input.onTargetAction = { target, value in
        model.applyController(target.action, value: value, targetDeck: target.deck, argument: target.argument)
    }
    let sync = model.playbackSnapshot?.a.synced
    original200Packet([0x91, 9, 127, 9, 0], to: input)
    model.jump(48000, deck: .a)
    original200Packet([0x91, 10, 127], to: input)
    #expect(model.playbackSnapshot?.a.loopEnabled == true)
    original200Packet([0x91, 10, 0, 10, 127], to: input)
    #expect(model.playbackSnapshot?.a.loopEnabled == false)
    original200Packet([0x91, 11, 127, 11, 0, 11, 127], to: input)
    #expect(model.playbackSnapshot?.a.loopEnabled == true)
    #expect(model.performance.loopBeats(for: .a) == 4)
    original200Packet([0x91, 10, 0, 10, 127, 8, 127, 0xB1, 10, 1], to: input)
    try await Task.sleep(for: .milliseconds(80))
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    let frame = try #require(model.playbackSnapshot?.a.sourceFrame)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -100) - frame) <= 1)
    original200Packet([0x81, 8, 0], to: input)
    _ = model.playback.core.renderOffline(frames: 4096)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.synced == sync)
}
