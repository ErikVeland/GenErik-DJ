import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func attachCMDMicro(_ input: ControllerMIDIConnection, second: Bool = false) {
    let name = "CMD Micro"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    if second {
        input.sources.append(
            .init(id: 11, reference: 101, name: name, identity: .init(id: 11, device: 2, names: [name])))
        input.destinations.append(
            .init(id: 21, reference: 201, name: name, identity: .init(id: 21, device: 2, names: [name])))
    }
    input.reconcileFactoryProfiles()
}

@MainActor private func withCMDMicro(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "cmd-micro-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    attachCMDMicro(input)
    try body(input)
}

@MainActor private func cmdPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@MainActor private func withCMDPlayback(
    _ body: (ReplicaModel, ControllerMIDIConnection) async throws -> Void
) async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    model.load(trackID: track.id, deck: .b)
    await model.flushWrites()
    let suite = "cmd-playback-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    attachCMDMicro(input)
    input.onJogAction = { model.applyControllerJog($0, motion: $1) }
    input.onTargetAction = { target, value in
        model.applyController(target.action, value: value, targetDeck: target.deck, argument: target.argument)
    }
    try await body(model, input)
}

@Test @MainActor func controllerCatalogueCMDMicroRetainsFixedAddressesAndSourceLEDValues() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["CMD Micro"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 32 && data.outputs.count == 4)
    #expect(data.startup.isEmpty && data.shutdown.count == 4)
    #expect(data.outputs.allSatisfy { $0.onValue == 1 && $0.offValue == 0 && $0.offUsesNoteOn })
    #expect(ControllerFactoryProfile.matching(["CMD Micro 2"], automaticOnly: true) == nil)
    #expect(!profile.hasAutomaticSplitOutput)
    withCMDMicro { input in
        #expect(input.isInputActive(10))
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        cmdPacket(
            [0x90, 23, 127, 39, 127, 20, 127, 37, 127, 18, 127, 19, 127, 34, 127, 36, 127, 48, 127, 49, 127], to: input)
        #expect(
            targets == [
                .init(.playA, deck: .a), .init(.playB, deck: .b),
                .init(.loadA, deck: .a), .init(.loadB, deck: .b),
                .init(.toggleFixedLoopA, deck: .a, argument: 4), .init(.toggleFixedLoopA, deck: .a, argument: 8),
                .init(.toggleFixedLoopB, deck: .b, argument: 4), .init(.toggleFixedLoopB, deck: .b, argument: 8),
                .init(.browsePreviousGroup), .init(.browseNextGroup),
            ])
    }
}

@Test @MainActor func controllerCatalogueCMDMicroTouchAnd128CountJogsKeepBothReleaseForms() {
    for release: UInt8 in [0x90, 0x80] {
        withCMDMicro { input in
            var touches: [(ControllerActionTarget, Double)] = []
            var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
            input.onTargetAction = { target, value in if target.action.isMomentary { touches.append((target, value)) } }
            input.onJogAction = { jogs.append(($0, $1)) }
            cmdPacket([0x90, 1, 127, 2, 127, 0xB0, 17, 65, 33, 63, release, 1, 0, 2, 0], to: input)
            #expect(touches.map(\.1) == [1, 1, 0, 0])
            #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 128 })
            #expect(jogs.first { $0.0.deck == .a }?.1 == .relative(1))
            #expect(jogs.first { $0.0.deck == .b }?.1 == .relative(-1))
        }
    }
}

@Test @MainActor func controllerCatalogueCMDMicroTempoKeepsExactCentreInversionAndPickup() {
    withCMDMicro { input in
        var tempos: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { tempos.append(value) } }
        cmdPacket([0xB0, 16, 127], to: input)
        #expect(tempos.isEmpty)
        cmdPacket([0xB0, 16, 64], to: input)
        cmdPacket([0xB0, 16, 0], to: input)
        #expect(tempos == [0.5, 1])
    }
}

@Test @MainActor func controllerCatalogueCMDMicroHeldBendRetainsMultipleSourceOwnership() {
    withCMDMicro { input in
        attachCMDMicro(input, second: true)
        #expect(input.isInputActive(10) && input.isInputActive(11))
        var events: [Double] = []
        input.onTargetAction = { target, value in if target.action == .pitchBendUpA { events.append(value) } }
        cmdPacket([0x90, 17, 127], to: input)
        cmdPacket([0x90, 17, 127], to: input, source: 11)
        cmdPacket([0x80, 17, 127], to: input)
        #expect(events == [1])
        cmdPacket([0x90, 17, 0], to: input, source: 11)
        #expect(events == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueCMDMicroNativeHeldBendKeepsSyncAndRestoresGridPhase() async throws {
    try await withCMDPlayback { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        _ = model.playback.core.renderOffline(frames: 1024)
        model.refreshPlayback()
        let sync = model.playbackSnapshot?.a.synced
        let tempo = model.deckTempoPercent(deck: .a)
        let first = try #require(model.playbackSnapshot?.a.sourceFrame)
        cmdPacket([0x90, 17, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1.04)
        let audio = model.playback.core.renderOffline(frames: 4096)
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        model.refreshPlayback()
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > first)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == sync)
        cmdPacket([0x90, 16, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        cmdPacket([0x80, 17, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 0.96)
        cmdPacket([0x90, 16, 0], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        #expect(model.playbackSnapshot?.a.synced == sync && model.deckTempoPercent(deck: .a) == tempo)
        let snapshot = try #require(model.playbackSnapshot)
        let timing = try #require(model.timing(.a))
        let phase = timing.beat(atFrame: snapshot.a.sourceFrame) - snapshot.masterBeat
        #expect(abs(phase - phase.rounded()) < 0.0001)
    }
}

@Test @MainActor func controllerCatalogueCMDMicroDisconnectRestoresBothHeldDirectionsWithoutPausing() async throws {
    try await withCMDPlayback { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        model.pressPlay(deck: .b, vinylStop: false)
        for _ in 0..<32 where model.playbackSnapshot?.b.phase != .playing {
            _ = model.playback.core.renderOffline(frames: 8192)
            model.refreshPlayback()
        }
        #expect(model.playbackSnapshot?.b.phase == .playing)
        cmdPacket([0x90, 17, 127, 32, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1.04)
        #expect(model.playbackSnapshot?.b.performanceRate == 0.96)
        input.sources = []
        input.reconcileFactoryProfiles()
        #expect(model.playbackSnapshot?.a.performanceRate == 1 && model.playbackSnapshot?.b.performanceRate == 1)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.b.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.b.synced == true)
    }
}

@Test @MainActor func controllerCatalogueCMDMicroQueuedStartAllowsHeldReleaseAndIgnoresNewPress() async throws {
    try await withCMDPlayback { model, input in
        cmdPacket([0x90, 33, 127], to: input)
        #expect(model.playbackSnapshot?.b.performanceRate == 1.04)
        model.pressPlay(deck: .a, vinylStop: false)
        model.pressPlay(deck: .b, vinylStop: false)
        #expect(model.playbackSnapshot?.b.phase == .queued)
        cmdPacket([0x90, 32, 127], to: input)
        #expect(model.playbackSnapshot?.b.performanceRate == 1.04)
        input.sources = []
        input.reconcileFactoryProfiles()
        #expect(model.playbackSnapshot?.b.performanceRate == 1)
        #expect(model.playbackSnapshot?.b.phase == .queued && model.playbackSnapshot?.b.synced == true)
        for _ in 0..<32 where model.playbackSnapshot?.b.phase != .playing {
            _ = model.playback.core.renderOffline(frames: 8192)
            model.refreshPlayback()
        }
        #expect(model.playbackSnapshot?.b.phase == .playing && model.playbackSnapshot?.b.performanceRate == 1)
    }
}

@Test @MainActor func controllerCatalogueCMDMicroOldBendReleaseCannotOverrideLaterTouchOrRate() async throws {
    try await withCMDPlayback { model, input in
        cmdPacket([0x90, 17, 127], to: input)
        model.perform(.touch, deck: .a, value: 2000, touchRate: 0, followsPosition: true)
        cmdPacket([0x90, 17, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true && model.playbackSnapshot?.a.performanceRate == 0)
        cmdPacket([0x90, 16, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true && model.playbackSnapshot?.a.performanceRate == 0)
        model.perform(.touch, deck: .a, enabled: false)
        model.perform(.rate, deck: .a, value: 0.92)
        cmdPacket([0x80, 16, 0], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 0.92 && model.playbackSnapshot?.a.touchActive == false)
        cmdPacket([0x90, 17, 127], to: input)
        model.perform(.rate, deck: .a, value: 1.02)
        cmdPacket([0x80, 17, 0], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1.02)
        model.perform(.rate, deck: .a, value: 1)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}
