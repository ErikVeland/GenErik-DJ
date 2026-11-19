import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withControllerCuePlayback(
    _ name: String = "DJ2GO2 Touch", manual: Bool = false, ports: [String] = [],
    setupClock: @escaping () -> UInt64 = { DispatchTime.now().uptimeNanoseconds },
    prepareInput: ((ControllerMIDIConnection) -> Void)? = nil,
    _ body: (ReplicaModel, ControllerMIDIConnection) async throws -> Void
)
    async throws
{
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.configureControllerMIDI()
    let suite = "cue-preview-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, factorySetupClock: setupClock)
    input.sources = [
        .init(
            id: 10, reference: 100, name: name,
            identity: .init(id: 10, device: 1, names: [name], portNames: ports))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: name,
            identity: .init(id: 20, device: 1, names: [name], portNames: ports))
    ]
    input.onTargetAction = model.controllerInput.onTargetAction
    input.onJogAction = model.controllerInput.onJogAction
    input.reconcileFactoryProfiles()
    prepareInput?(input)
    if manual {
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    } else {
        #expect(input.isInputActive(10))
    }
    try await body(model, input)
}

@MainActor private func cuePreviewPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueFirstMixNativeScratchCountsThenRestoresGridAndKeepsSync() async throws {
    try await withControllerCuePlayback("Gemini FirstMix") { model, input in
        cuePreviewPacket([0x90, 0x4D, 127, 0xB0, 0x19, 2], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        let expected = sampleRate * 1.8 * 2 / 180
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - expected) <= 1)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 0x4D, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == false)
        #expect(abs(model.playbackSnapshot?.a.sourceFrame ?? -1) <= 1)
    }
}

@Test @MainActor func controllerCatalogueDiscoverNativeTempoStepsRetainSyncAndPermanentChoice() async throws {
    try await withControllerCuePlayback("Ion Discover DJ") { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let firstFrame = try #require(model.playbackSnapshot?.a.sourceFrame)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        let original = model.deckTempoPercent(deck: .a)
        cuePreviewPacket([0x90, 0x44, 127, 0x44, 127], to: input)
        #expect(abs(model.deckTempoPercent(deck: .a) - original - 0.1) < 0.000001)
        cuePreviewPacket([0x80, 0x44, 0], to: input)
        #expect(abs(model.deckTempoPercent(deck: .a) - original - 0.1) < 0.000001)
        cuePreviewPacket([0x90, 0x44, 127, 0x44, 0], to: input)
        #expect(abs(model.deckTempoPercent(deck: .a) - original - 0.2) < 0.000001)
        cuePreviewPacket([0x90, 0x43, 127, 0x43, 0], to: input)
        #expect(abs(model.deckTempoPercent(deck: .a) - original - 0.1) < 0.000001)
        #expect(model.playbackSnapshot?.a.synced == true)
        model.setSync(false, deck: .a)
        let freeTempo = model.deckTempoPercent(deck: .a)
        cuePreviewPacket([0x90, 0x43, 127, 0x43, 0], to: input)
        #expect(abs(model.deckTempoPercent(deck: .a) - freeTempo + 0.1) < 0.000001)
        #expect(model.playbackSnapshot?.a.synced == false)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > firstFrame)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        model.setDeckTempo(percent: 50, deck: .a)
        model.applyController(.tempoUpA, value: 1)
        #expect(abs(model.deckTempoPercent(deck: .a) - 50) < 0.000001)
        model.setDeckTempo(percent: -50, deck: .a)
        model.applyController(.tempoDownA, value: 1)
        #expect(abs(model.deckTempoPercent(deck: .a) + 50) < 0.000001)
    }
}

@Test @MainActor func controllerCatalogueDiscoverNativeScratchUsesSourceScaleAndRestoresGrid() async throws {
    try await withControllerCuePlayback("Ion Discover DJ") { model, input in
        cuePreviewPacket([0x90, 0x4D, 127, 0xB0, 0x19, 3], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        let expected = sampleRate * 1.8 * 3 / 518.4
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - expected) <= 1)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 0x4D, 0], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
        #expect(abs(model.playbackSnapshot?.a.sourceFrame ?? -1) <= 1)
    }
}

@Test @MainActor func controllerCatalogueDiscoverProNativeWheelAndHeldBendKeepPlaybackAndSync() async throws {
    try await withControllerCuePlayback("Ion Discover DJ Pro") { model, input in
        cuePreviewPacket([0xB0, 0x19, 1], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(abs(model.playbackSnapshot?.a.sourceFrame ?? -1) <= 1)
        #expect(model.playbackSnapshot?.a.synced == true)
        model.setSync(false, deck: .a)
        cuePreviewPacket([0xB0, 0x19, 1], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 / 128) <= 1)
        cuePreviewPacket([0xB0, 0x4E, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        model.setSync(true, deck: .a)
        model.pressPlay(deck: .a, vinylStop: false)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let firstFrame = try #require(model.playbackSnapshot?.a.sourceFrame)
        let tempo = model.deckTempoPercent(deck: .a)
        cuePreviewPacket([0x90, 0x44, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1.04)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > firstFrame)
        cuePreviewPacket([0x80, 0x44, 0], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true && model.deckTempoPercent(deck: .a) == tempo)
    }
}

@Test @MainActor func controllerCatalogueDJM101NativeMixerAndPFLKeepPlaybackAndSync() async throws {
    try await withControllerCuePlayback("DJ-Tech DJM-101") { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let firstFrame = try #require(model.playbackSnapshot?.a.sourceFrame)
        cuePreviewPacket([0xB0, 65, 127, 74, 64, 0x90, 33, 127], to: input)
        #expect(model.playbackSnapshot?.a.mixer.volume == 1)
        #expect(model.playbackSnapshot?.a.mixer.high == 128.0 / 127)
        #expect(model.playbackSnapshot?.a.mixer.cue == true)
        cuePreviewPacket([0x90, 33, 0, 33, 127, 0xB0, 65, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.mixer.volume == 0 && model.playbackSnapshot?.a.mixer.cue == false)
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > firstFrame)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueRX221BankAndPCExitReleaseOnlyControllerOwnedTouches() async throws {
    try await withControllerCuePlayback("XDJ-RX") { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0xB2, 102, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
        cuePreviewPacket([0x90, 32, 127, 0xB0, 16, 65], to: input)
        #expect(model.controllerJogTouched.contains(.a))
        cuePreviewPacket([0xB0, 100, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false && !model.controllerJogTouched.contains(.a))
        model.perform(.touch, deck: .a, value: 0, touchRate: 0, followsPosition: true)
        cuePreviewPacket([0xB0, 102, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        model.perform(.touch, deck: .a, enabled: false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueRDJ2IENativeScratchAndIdempotentLoopKeepSync() async throws {
    try await withControllerCuePlayback("DIGITALJOCKEY2") { model, input in
        cuePreviewPacket([0x90, 24, 127, 54, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90, 29, 127, 0xB0, 11, 66], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 * 2 / 148) <= 1)
        cuePreviewPacket([0x80, 29, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90, 17, 127, 17, 0, 17, 127, 17, 0], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90, 18, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueCuePreviewPlaysWhileHeldThenReturnsWithoutChangingSync() async throws {
    try await withControllerCuePlayback { model, input in
        let origin = try #require(model.playbackSnapshot?.a.sourceFrame)
        let synced = model.playbackSnapshot?.a.synced
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        let audio = model.playback.core.renderOffline(frames: 4096)
        #expect(audio.left.contains { abs($0) > 0.001 } || audio.right.contains { abs($0) > 0.001 })
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.sourceFrame ?? 0 > origin)
        cuePreviewPacket([0x80, 1, 0], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == false)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - origin) <= 1)
        #expect(model.playbackSnapshot?.a.synced == synced)
    }
}

@Test @MainActor func controllerCatalogueCuePreviewPlayLatchesAndLaterReleaseKeepsPlaying() async throws {
    try await withControllerCuePlayback { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 0, 127, 0x80, 1, 0], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueCuePreviewDisconnectAndPlayingPressReturnToCue() async throws {
    try await withControllerCuePlayback { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == false)
        #expect(model.controllerCueContacts[.a] == nil)
        input.sources = sources
        input.reconcileFactoryProfiles()
        cuePreviewPacket([0x90, 0, 127], to: input)
        _ = model.playback.core.renderOffline(frames: 8192)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true)
        var received: [(ControllerAction, Double)] = []
        let dispatch = input.onTargetAction
        input.onTargetAction = { target, value in
            received.append((target.action, value)); dispatch?(target, value)
        }
        #expect(!model.preparingTrack.contains(.a))
        #expect(model.playback.core.snapshot()?.a.touchActive == false)
        #expect(model.playback.core.snapshot()?.a.braking == false)
        #expect(model.playback.core.snapshot()?.a.loopRolling == false)
        cuePreviewPacket([0x90, 1, 127, 0x80, 1, 0], to: input)
        #expect(received.map(\.0) == [.cuePreviewA, .cuePreviewA])
        #expect(received.map(\.1) == [1, 0])
        _ = model.playback.core.renderOffline(frames: 512)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == false, "Cue park status: \(model.status)")
        #expect(abs(model.playbackSnapshot?.a.sourceFrame ?? -1) <= 1)
        model.perform(.touch, deck: .a, value: 0, touchRate: 0)
        cuePreviewPacket([0x90, 1, 127, 0x80, 1, 0], to: input)
        #expect(model.controllerCueContacts[.a] == nil)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        model.perform(.touch, deck: .a, enabled: false)
    }
}

@Test @MainActor func controllerCatalogueCuePreviewOldReleaseCannotTouchAReplacementTrack() async throws {
    try await withControllerCuePlayback { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        let old = try #require(model.playbackSnapshot?.a.generation)
        try model.playback.perform(.touch, deck: .a, enabled: false)
        model.refreshPlayback()
        model.load(trackID: try #require(model.library.tracks.first).id, deck: .a)
        await model.flushWrites()
        #expect(model.playbackSnapshot?.a.generation != old)
        model.perform(.touch, deck: .a, value: 0, touchRate: 0)
        cuePreviewPacket([0x80, 1, 0], to: input)
        #expect(model.controllerCueContacts[.a] == nil)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        model.perform(.touch, deck: .a, enabled: false)
    }
}

@Test @MainActor func controllerCatalogueCuePreviewReleaseDoesNotStopAPlatterTakeover() async throws {
    try await withControllerCuePlayback { model, input in
        cuePreviewPacket([0x90, 1, 127, 6, 127], to: input)
        #expect(model.controllerCueContacts[.a] == nil)
        #expect(model.controllerJogTouched.contains(.a))
        cuePreviewPacket([0x80, 1, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 6, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueCuePreviewReleaseDoesNotStopAWaveformTakeover() async throws {
    try await withControllerCuePlayback { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        model.perform(.touch, deck: .a, value: 0, touchRate: 0, followsPosition: true)
        #expect(model.controllerCueContacts[.a] == nil)
        cuePreviewPacket([0x80, 1, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        model.perform(.touch, deck: .a, enabled: false)
    }
}

@Test @MainActor func controllerCatalogueCuePreviewCanCueBWhileAPlays() async throws {
    try await withControllerCuePlayback { model, input in
        model.load(trackID: try #require(model.library.tracks.first).id, deck: .b)
        await model.flushWrites()
        cuePreviewPacket([0x90, 0, 127], to: input)
        _ = model.playback.core.renderOffline(frames: 512)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true)
        cuePreviewPacket([0x91, 1, 127], to: input)
        #expect(model.playbackSnapshot?.b.touchActive == true)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        cuePreviewPacket([0x81, 1, 0], to: input)
        _ = model.playback.core.renderOffline(frames: 512)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.b.touchActive == false)
        #expect(model.playbackSnapshot?.b.phase.active == false)
        #expect(model.playbackSnapshot?.a.phase.active == true)
    }
}

@Test @MainActor func controllerCataloguePioneerFLX4CuePreviewUsesTheNativePlayer() async throws {
    try await withControllerCuePlayback("DDJ-FLX4") { model, input in
        let sync = model.playbackSnapshot?.a.synced
        cuePreviewPacket([0x90, 12, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        let audio = model.playback.core.renderOffline(frames: 4096)
        #expect(audio.left.contains { abs($0) > 0.001 } || audio.right.contains { abs($0) > 0.001 })
        cuePreviewPacket([0x90, 12, 0], to: input)
        _ = model.playback.core.renderOffline(frames: 512)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == false)
        #expect(model.playbackSnapshot?.a.synced == sync)
    }
}

@Test @MainActor func controllerCatalogueOrphanControllerTouchReleaseDoesNotEndWaveform() async throws {
    try await withControllerCuePlayback("NS4FX") { model, input in
        model.perform(.touch, deck: .a, value: 0, touchRate: 0, followsPosition: true)
        cuePreviewPacket([0x80, 6, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        model.perform(.touch, deck: .a, enabled: false)
    }
}

@Test @MainActor func controllerCatalogueNS4FXBankReleaseKeepsTheOtherCueAndNewWaveformTouch() async throws {
    try await withControllerCuePlayback("NS4FX") { model, input in
        model.load(trackID: try #require(model.library.tracks.first).id, deck: .b)
        await model.flushWrites()
        cuePreviewPacket([0x91, 1, 127, 0x90, 6, 127, 0xB0, 6, 1], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let otherFrame = try #require(model.playbackSnapshot?.b.sourceFrame)
        cuePreviewPacket([0x92, 8, 127], to: input)
        _ = model.playback.core.renderOffline(frames: 512)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.b.touchActive == true)
        #expect(model.playbackSnapshot?.b.sourceFrame ?? 0 > otherFrame)
        model.perform(.touch, deck: .a, value: 0, touchRate: 0, followsPosition: true)
        cuePreviewPacket([0x80, 6, 0], to: input)
        try await Task.sleep(for: .milliseconds(80))
        #expect(model.playbackSnapshot?.a.touchActive == true)
        #expect(model.playbackSnapshot?.b.touchActive == true)
        cuePreviewPacket([0x81, 1, 0], to: input)
        model.perform(.touch, deck: .a, enabled: false)
    }
}

@Test @MainActor func controllerCatalogueMixstreamCounterMovesOnlyByDecodedCountsAndStopsHeld() async throws {
    try await withControllerCuePlayback("MixstreamPro") { model, input in
        cuePreviewPacket([0x92, 33, 127, 0xB2, 77, 100, 77, 101, 77, 102], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 512)
        model.refreshPlayback()
        let expected = (model.track(.a)?.analysis.sampleRate ?? 0) * 0.02
        #expect(model.playbackSnapshot?.a.touchActive == true)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - expected) <= 1)
        cuePreviewPacket([0x82, 33, 0], to: input)
        _ = model.playback.core.renderOffline(frames: 512)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == false)
    }
}

@Test @MainActor func controllerCatalogueDDJ1000NormalSyncAndLoopReachNativePlayback() async throws {
    try await withControllerCuePlayback("DDJ-1000") { model, input in
        #expect(model.playbackSnapshot?.a.synced == true)
        cuePreviewPacket([0x90, 88, 127], to: input)
        #expect(model.playbackSnapshot?.a.synced == false)
        cuePreviewPacket([0xB0, 0, 64, 32, 0], to: input)
        cuePreviewPacket([0xB0, 0, 95, 32, 127], to: input)
        #expect(abs(model.deckTempoPercent(deck: .a) - 4) < 0.01)
        cuePreviewPacket([0x90, 88, 0, 88, 127], to: input)
        #expect(model.playbackSnapshot?.a.synced == true)
        let keylock = model.playbackSnapshot?.a.keylock
        cuePreviewPacket([0x90, 26, 127], to: input)
        #expect(model.playbackSnapshot?.a.keylock != keylock)
        cuePreviewPacket([0x90, 20, 127], to: input)
        let state = try #require(model.playbackSnapshot?.a)
        let grid = try #require(model.timing(.a))
        #expect(state.loopEnabled)
        #expect(abs(state.loopEnd - state.loopStart - grid.span(beats: 4, from: state.loopStart)) <= 1)
        #expect(state.synced)
        #expect(!state.phase.active)
    }
}

@Test @MainActor func controllerCatalogueJogvisionCueModifierReleaseAndCountJogReachNativePlayback() async throws {
    try await withControllerCuePlayback("DJControl Jogvision") { model, input in
        cuePreviewPacket([0x90, 49, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 86, 127, 54, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x80, 86, 0, 0x90, 85, 127, 0xB0, 65, 2], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 * 2 / 400) <= 1)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 85, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueInpulse300MK2RetainsJogIntentAcrossShiftResolutionChange() async throws {
    try await withControllerCuePlayback("DJControl Inpulse 300 MK2") { model, input in
        cuePreviewPacket([0x91, 8, 127, 0xB1, 10, 1], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        cuePreviewPacket([0x94, 8, 127, 0xB4, 10, 1], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        let expected = sampleRate * 1.8 * 5 / 248
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - expected) <= 1)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x84, 8, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueInpulse200MK2NativeJogStopsAndPreservesSync() async throws {
    try await withControllerCuePlayback("DJControl Inpulse 200 MK2") { model, input in
        cuePreviewPacket([0x91, 8, 127, 0xB1, 10, 1], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 / 1024) <= 1)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x81, 8, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueBeatmixFactoryJogCountsStopAndPreserveSync() async throws {
    try await withControllerCuePlayback("Beatmix 4 MK2") { model, input in
        cuePreviewPacket([0x91, 63, 127, 0xB1, 96, 2], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 * 2 / 800) <= 1)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x81, 127, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMC2000NativeJogUsesFactoryTouchAndPreservesSync() async throws {
    try await withControllerCuePlayback("Denon MC2000") { model, input in
        cuePreviewPacket([0x90, 81, 64, 0xB0, 81, 65], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 / 1024) <= 1)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 87, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMixon4NativeJogUsesItsDeckChannelAndPreservesSync() async throws {
    try await withControllerCuePlayback("Mixon 4") { model, input in
        cuePreviewPacket([0x94, 7, 127, 0xB4, 6, 65], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 / 1024) <= 1)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x84, 7, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueDicerOrangeCueUsesNativePlaybackWithoutScriptTimers() async throws {
    try await withControllerCuePlayback("Novation Dicer") { model, input in
        cuePreviewPacket([0x9C, 61, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > 0)
        cuePreviewPacket([0x8C, 61, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.sourceFrame == 0)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueNS6IIUSBReleaseFinishesNativeCueAndScratchWithoutChangingSync() async throws {
    try await withControllerCuePlayback("NS6II") { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > 0)
        cuePreviewPacket([0x9F, 60, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.sourceFrame == 0)
        cuePreviewPacket([0x9F, 60, 127, 0x90, 6, 127, 0xB0, 6, 1], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 / 1000) <= 1)
        cuePreviewPacket([0x9F, 60, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueN4NativeHeadphoneStateLoopEnableAndBankReleaseRemainIdempotent() async throws {
    try await withControllerCuePlayback("Numark N4") { model, input in
        cuePreviewPacket([0x90, 49, 127, 49, 127], to: input)
        #expect(model.controllerValue(.cueStateA) == 1)
        cuePreviewPacket([0x90, 49, 0], to: input)
        #expect(model.controllerValue(.cueStateA) == 0)
        cuePreviewPacket([0x91, 21, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        let start = model.playbackSnapshot?.a.loopStart
        let end = model.playbackSnapshot?.a.loopEnd
        cuePreviewPacket([0x91, 21, 0, 21, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        #expect(model.playbackSnapshot?.a.loopStart == start && model.playbackSnapshot?.a.loopEnd == end)
        cuePreviewPacket([0x91, 22, 127, 16, 127], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.sourceFrame ?? 0 > 0)
        cuePreviewPacket([0xB0, 80, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.sourceFrame == 0)
        cuePreviewPacket([0x91, 44, 127, 0xB1, 32, 1], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let rate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - rate * 1.8 / 600) <= 1)
        cuePreviewPacket([0xB0, 80, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueNEONCuesAndManualLoopToggleReachNativePlayback() async throws {
    try await withControllerCuePlayback("Reloop NEON") { model, input in
        cuePreviewPacket([0x97, 16, 127, 23, 127], to: input)
        #expect(model.controllerValue(.hotcue1A) == 1 && model.controllerValue(.hotcue8A) == 1)
        cuePreviewPacket([0x97, 120, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x97, 120, 0, 120, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        cuePreviewPacket([0x97, 126, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x97, 112, 127, 24, 127, 96, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueCompactVestaxCueAnd300CountScratchReachNativePlayback() async throws {
    for name in ["Typhoon", "Spin"] {
        try await withControllerCuePlayback(name) { model, input in
            cuePreviewPacket([0x90, 53, 127], to: input)
            _ = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(model.playbackSnapshot?.a.sourceFrame ?? 0 > 0)
            cuePreviewPacket([0x80, 53, 99], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == false)
            #expect(model.playbackSnapshot?.a.sourceFrame == 0)
            cuePreviewPacket([0x90, 46, 127, 0xB0, 16, 65], to: input)
            try await Task.sleep(for: .milliseconds(80))
            _ = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            let rate = try #require(model.track(.a)?.analysis.sampleRate)
            #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - rate * 1.8 / 300) <= 1)
            cuePreviewPacket([0x80, 46, 127], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == false)
            #expect(model.playbackSnapshot?.a.synced == true)
        }
    }
}

@Test @MainActor func controllerCatalogueRP8000MIDIOnlyCueAndLoopPadsReachNativePlayback() async throws {
    try await withControllerCuePlayback("RP-8000") { model, input in
        cuePreviewPacket([0x90, 0, 127, 7, 127, 8, 127], to: input)
        #expect(model.controllerValue(.hotcue1A) == 1 && model.controllerValue(.hotcue8A) == 1)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        #expect(model.performance.loopBeats(for: .a) == 0.25)
        cuePreviewPacket([0x90, 8, 0, 15, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        #expect(model.performance.loopBeats(for: .a) == 32)
        cuePreviewPacket([0x90, 15, 0, 15, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueScratchNativeMixerPadsAndPulseLoopsPreserveSync() async throws {
    try await withControllerCuePlayback("Numark Scratch") { model, input in
        cuePreviewPacket([0x94, 20, 127, 63, 127], to: input)
        #expect(model.controllerValue(.hotcue1A) == 1)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x94, 63, 0, 63, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        cuePreviewPacket([0x94, 63, 0, 63, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90, 27, 127, 27, 127], to: input)
        #expect(model.controllerValue(.cueStateA) == 1)
        cuePreviewPacket([0x80, 27, 127], to: input)
        #expect(model.controllerValue(.cueStateA) == 0)
        let size = model.performance.loopBeats(for: .a)
        cuePreviewPacket([0x94, 53, 1, 53, 1], to: input)
        #expect(model.performance.loopBeats(for: .a) == size * 4)
        cuePreviewPacket([0x94, 7, 127, 23, 127], to: input)
        #expect(model.controllerValue(.hotcue4A) == 0)
        cuePreviewPacket([0xB0, 23, 0], to: input)
        cuePreviewPacket([0xB0, 23, 127], to: input)
        #expect(model.playbackSnapshot?.a.mixer.high == 2)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueOriginalDJ2GoCueFeedbackTracksOwnedContactAndGeneration() async throws {
    try await withControllerCuePlayback("Numark DJ2GO") { model, input in
        #expect(model.controllerValue(.cuePreviewA) == 0)
        let sync = model.playbackSnapshot?.a.synced
        let generation = try #require(model.playbackSnapshot?.a.generation)
        cuePreviewPacket([0x90, 0x33, 127], to: input)
        #expect(model.controllerValue(.cuePreviewA) == 1)
        let audio = model.playback.core.renderOffline(frames: 4096)
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(audio.left.contains { abs($0) > 0.001 } || audio.right.contains { abs($0) > 0.001 })
        model.refreshPlayback()
        model.controllerCueContacts[.a] = .init(generation: generation &+ 1, frame: 0)
        #expect(model.controllerValue(.cuePreviewA) == 0)
        model.controllerCueContacts[.a] = .init(generation: generation, frame: 0)
        cuePreviewPacket([0x80, 0x33, 127], to: input)
        #expect(model.controllerValue(.cuePreviewA) == 0)
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.synced == sync)
    }
}

@Test @MainActor func controllerCatalogueOriginal300NativeLoopDisableIsIdempotentAndRetainsSync() async throws {
    try await withControllerCuePlayback("Hercules DJControl Inpulse 300") { model, input in
        let sync = model.playbackSnapshot?.a.synced
        cuePreviewPacket([0x91, 9, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        let start = model.playbackSnapshot?.a.loopStart
        cuePreviewPacket([0x81, 9, 127, 0x91, 9, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true && model.playbackSnapshot?.a.loopStart == start)
        cuePreviewPacket([0x91, 10, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        cuePreviewPacket([0x81, 10, 127, 0x91, 10, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false && model.playbackSnapshot?.a.synced == sync)
    }
}

@Test(arguments: ["Numark Total Control", "Numark Omni Control"]) @MainActor
func controllerCatalogueTotalOmniNativeInReplacesAnOldLoopBeforeOutCreatesANewOne(_ name: String) async throws {
    try await withControllerCuePlayback(name) { model, input in
        let sync = model.playbackSnapshot?.a.synced
        model.applyController(.fixedLoopA, value: 1, argument: 4)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90, 73, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        model.applyController(.seekA, value: 0.5)
        cuePreviewPacket([0x90, 74, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        #expect((model.playbackSnapshot?.a.loopEnd ?? 0) > (model.playbackSnapshot?.a.loopStart ?? 0))
        cuePreviewPacket([0x80, 74, 127, 0x90, 74, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false && model.playbackSnapshot?.a.synced == sync)
    }
}

@Test @MainActor func controllerCatalogueKAOSSNativeSyncCancelIsIdempotentAndSurvivesCueReleaseAndReload() async throws
{
    try await withControllerCuePlayback("Korg KAOSS DJ") { model, input in
        #expect(model.playbackSnapshot?.a.synced == true)
        cuePreviewPacket([0x97, 30, 127, 26, 127, 29, 127], to: input)
        #expect(model.playbackSnapshot?.a.synced == false)
        let before = try #require(model.playbackSnapshot?.a)
        cuePreviewPacket([0x97, 29, 0, 29, 127], to: input)
        #expect(model.playbackSnapshot?.a.synced == false)
        #expect(model.playbackSnapshot?.a.sourceFrame == before.sourceFrame)
        #expect(model.playbackSnapshot?.a.phase == before.phase)
        cuePreviewPacket([0x97, 30, 0, 29, 0, 26, 0], to: input)
        #expect(model.playbackSnapshot?.a.synced == false && model.playbackSnapshot?.a.touchActive == false)
        let track = try #require(model.library.tracks.first)
        let generation = try #require(model.playbackSnapshot?.a.generation)
        model.load(trackID: track.id, deck: .a)
        await model.flushWrites()
        #expect(model.playbackSnapshot?.a.generation != generation)
        #expect(model.playbackSnapshot?.a.synced == false)
        cuePreviewPacket([0x97, 29, 127], to: input)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueRDJ2ControllerNativeWheelNeverStartsTouchAndLoopsKeepSync() async throws {
    try await withControllerCuePlayback("DIGITAL JOCKEY") { model, input in
        cuePreviewPacket([0x90, 29, 127, 0xB0, 11, 65], to: input)
        try await Task.sleep(for: .milliseconds(80))
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == false)
        cuePreviewPacket([0x90, 17, 127, 17, 0, 17, 127, 17, 0], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90, 18, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        #expect(model.playbackSnapshot?.a.synced == true)
        cuePreviewPacket([0x90, 24, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 24, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueRadiusNativeScratchTapReleaseAndLoopKeepSync() async throws {
    try await withControllerCuePlayback("Radius 2000 MIDI 1") { model, input in
        cuePreviewPacket([0x90, 38, 127, 0xB0, 53, 66], to: input)
        try await Task.sleep(for: .milliseconds(80))
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 * 2 / 990) <= 1)
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        cuePreviewPacket([0x90, 101, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90, 2, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        #expect(model.playbackSnapshot?.a.synced == true)
        cuePreviewPacket([0x90, 48, 127, 111, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueOriginalDJ2GO2NativeWheelCueAndLoopKeepSync() async throws {
    try await withControllerCuePlayback("DJ2GO2 (DJ2GO2)") { model, input in
        cuePreviewPacket([0x90, 6, 127, 0xB0, 6, 1], to: input)
        try await Task.sleep(for: .milliseconds(80))
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == false)
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 1, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x94, 19, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x94, 35, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueTM8NativeScratchBankAndLaterTouchKeepSync() async throws {
    try await withControllerCuePlayback("Terminal Mix 8") { model, input in
        cuePreviewPacket([0x90, 7, 127, 0xB0, 7, 66], to: input)
        try await Task.sleep(for: .milliseconds(80))
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        let expected = sampleRate * 1.8 * 2 / ControllerCountJogMotion.defaultResolution
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - expected) <= 1)
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        cuePreviewPacket([0x92, 32, 127], to: input)
        #expect(!model.controllerJogTouched.contains(.a))
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90, 4, 127, 68, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        model.perform(.touch, deck: .a, value: 0, touchRate: 0, followsPosition: true)
        cuePreviewPacket([0x90, 32, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        model.perform(.touch, deck: .a, enabled: false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMixtrackQuadNativeScratchBendAndBankKeepSync() async throws {
    try await withControllerCuePlayback("MixTrack Quad") { model, input in
        cuePreviewPacket([0x91, 77, 127, 0xB1, 37, 2], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 * 2 / 600) <= 1)
        cuePreviewPacket([0x91, 77, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        model.pressPlay(deck: .a, vinylStop: false)
        cuePreviewPacket([0x91, 67, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 0.96)
        cuePreviewPacket([0x91, 97, 127, 67, 0], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
        cuePreviewPacket([0x90, 78, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueIMixNativeNoteScratchReleaseAndCueKeepSync() async throws {
    try await withControllerCuePlayback("DJ-Tech i-Mix Reload", manual: true) { model, input in
        cuePreviewPacket([0x90, 50, 127, 96, 127, 96, 127, 96, 0, 0x80, 97, 127], to: input)
        try await Task.sleep(for: .milliseconds(80))
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 * 2 / 148) <= 1)
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        cuePreviewPacket([0x90, 50, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(!model.controllerJogTouched.contains(.a))
        cuePreviewPacket([0x90, 11, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 11, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMCX8000NativeCueLoopAndShiftedBendReleaseKeepSync() async throws {
    try await withControllerCuePlayback("Denon DJ MCX8000") { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 5, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        model.pressPlay(deck: .a, vinylStop: false)
        cuePreviewPacket([0x90, 12, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 0.96)
        cuePreviewPacket([0x80, 44, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        cuePreviewPacket([0x94, 50, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMix101NativeUnheldWheelAndCueKeepSync() async throws {
    try await withControllerCuePlayback("Mix-101 MIDI 1", manual: true) { model, input in
        cuePreviewPacket([0xB0, 19, 65], to: input)
        try await Task.sleep(for: .milliseconds(80))
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90, 3, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 3, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueTEK2NativeSharedWireMovesOnceThenReleasesTouchAndCue() async throws {
    try await withControllerCuePlayback("TEK2", manual: true) { model, input in
        cuePreviewPacket([0x90, 40, 127, 0xB0, 8, 66], to: input)
        try await Task.sleep(for: .milliseconds(80))
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 * 2 / 100) <= 1)
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        cuePreviewPacket([0x90, 40, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(!model.controllerJogTouched.contains(.a))
        cuePreviewPacket([0x90, 33, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 33, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueKDJ500NativeCueAndFixedEightBeatLoopKeepSync() async throws {
    try await withControllerCuePlayback("KDJ500", manual: true) { model, input in
        cuePreviewPacket([0x90, 14, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 14, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90, 3, 127], to: input)
        #expect(model.performance.loopBeats(for: .a) == 8)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90, 3, 0, 3, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        model.pressPlay(deck: .a, vinylStop: false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueUMixControl2NativeShiftReleaseAndFactoryLoopKeepSync() async throws {
    try await withControllerCuePlayback("U-MIX CONTROL 2") { model, input in
        cuePreviewPacket([0x90, 1, 127, 0x92, 2, 127, 0x83, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(!model.controllerJogTouched.contains(.a))
        cuePreviewPacket([0x92, 2, 0], to: input)
        model.setLoopSize(8, deck: .a)
        cuePreviewPacket([0x90, 13, 127, 0xB0, 13, 127], to: input)
        #expect(model.performance.loopBeats(for: .a) == 4)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        model.pressPlay(deck: .a, vinylStop: false)
        cuePreviewPacket([0x90, 4, 127, 0x92, 2, 127, 0x83, 4, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueOriginalUMixProNativeTouchRimAndShiftReleaseKeepSync() async throws {
    try await withControllerCuePlayback("U-MIX CONTROL PRO") { model, input in
        cuePreviewPacket([0x90, 22, 127, 0xB0, 22, 66, 23, 127], to: input)
        try await Task.sleep(for: .milliseconds(80))
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(
            abs(
                (model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 * 2
                    / ControllerCountJogMotion.defaultResolution) <= 1)
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        cuePreviewPacket([0x92, 2, 127, 0x83, 22, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(!model.controllerJogTouched.contains(.a))
        cuePreviewPacket([0x92, 2, 0, 0x90, 1, 127, 0x80, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMixtourNativeCueModeReleaseAndLoopKeepSync() async throws {
    try await withControllerCuePlayback("Mixtour") { model, input in
        cuePreviewPacket([0x90, 11, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 5, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        model.setLoopSize(8, deck: .a)
        cuePreviewPacket([0x90, 9, 127, 6, 127, 72, 127], to: input)
        #expect(model.performance.loopBeats(for: .a) == 4)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90, 72, 0, 6, 0, 12, 127], to: input)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueBeatpad2NativeTouchShiftCleanupAndFourBeatLoopKeepSync() async throws {
    try await withControllerCuePlayback("Beatpad 2") { model, input in
        cuePreviewPacket([0x90, 99, 127, 0xB0, 99, 66], to: input)
        try await Task.sleep(for: .milliseconds(80))
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(
            abs(
                (model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate * 1.8 * 2
                    / ControllerCountJogMotion.defaultResolution) <= 1)
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        cuePreviewPacket([0x90, 28, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(!model.controllerJogTouched.contains(.a))
        cuePreviewPacket([0x90, 28, 0, 94, 127, 0x80, 94, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        model.setLoopSize(8, deck: .a)
        cuePreviewPacket([0x92, 8, 127], to: input)
        #expect(model.performance.loopBeats(for: .a) == 4)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMixtourProNativeManualCueKeepsReleaseAndSavedSync() async throws {
    try await withControllerCuePlayback("Mixtour Pro", manual: true) { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 1, 127, 0x90, 0, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueTweakerNativeDeckShiftCueKeepsReleaseAndSync() async throws {
    try await withControllerCuePlayback("Tweaker", ports: ["Tweaker MIDI 1"]) { model, input in
        cuePreviewPacket([0x90, 19, 127, 35, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 19, 0, 0x80, 35, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90, 35, 127], to: input)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueT7NativeManualCueBendAndFixedLoopKeepSync() async throws {
    try await withControllerCuePlayback("DJControl Inpulse T7", manual: true) { model, input in
        cuePreviewPacket([0x91, 6, 127, 0x84, 6, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x91, 7, 127, 83, 127], to: input)
        #expect((model.playbackSnapshot?.a.performanceRate ?? 1) > 1)
        cuePreviewPacket([0x84, 83, 127], to: input)
        #expect(model.playbackSnapshot?.a.performanceRate == 1)
        cuePreviewPacket([0x96, 20, 127], to: input)
        #expect(model.performance.loopBeats(for: .a) == 4)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueBuddyNativeManualCueKeepsReleaseAndSavedSync() async throws {
    try await withControllerCuePlayback("Reloop Buddy", manual: true) { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 5, 127, 0x90, 0, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueSlateNativeTouchAndCueRestoreGridAndSavedSync() async throws {
    try await withControllerCuePlayback("SLATE Audio") { model, input in
        cuePreviewPacket([0x90, 57, 127, 0xB0, 4, 65], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 57, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
        cuePreviewPacket([0x90, 2, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 2, 0, 1, 127], to: input)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueSlateFourNativeCuePreservesSavedSync() async throws {
    try await withControllerCuePlayback("SLATE4 Audio") { model, input in
        cuePreviewPacket([0x90, 2, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 2, 127, 0x90, 1, 127], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueNDX500NativeCueBendAndTouchKeepSavedSync() async throws {
    try await withControllerCuePlayback("Numark NDX500") { model, input in
        cuePreviewPacket([0x93, 5, 127, 24, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x83, 5, 127, 24, 127, 0x93, 25, 127, 0xB3, 34, 62], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x83, 25, 127, 0x93, 6, 127], to: input)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueRaneFourNativeManualCueReleasesAcrossBankAndKeepsSavedSync() async throws {
    try await withControllerCuePlayback("RANE FOUR Control", manual: true) { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x82, 5, 127, 0x90, 0, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCataloguePartyMixLiveNativeTouchAndCueKeepSavedSync() async throws {
    try await withControllerCuePlayback("Party Mix Live") { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 1, 127, 0x90, 6, 127, 0xB0, 6, 1], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 6, 0, 0, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMixDeckNativeCueTouchAndPlayKeepSavedSync() async throws {
    for (name, cue, touch, play) in [
        ("MixDeck Express", UInt8(63), UInt8(80), UInt8(61)), ("MixDeck Quad", 56, 89, 58),
    ] {
        try await withControllerCuePlayback(name, manual: name.hasSuffix("Express")) { model, input in
            cuePreviewPacket([0x90, cue, 127], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x80, cue, 127, 0x90, touch, 127, 0xB0, 34, 1], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x90, touch, 0, play, 127], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == false)
            let samples = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true)
            #expect(model.playbackSnapshot?.a.synced == true)
        }
    }
}

@Test @MainActor func controllerCatalogueMixon8NativeManualCueReleasesAcrossBankAndKeepsSavedSync() async throws {
    try await withControllerCuePlayback("Reloop Mixon 8 Pro", manual: true) { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x82, 5, 127, 0x90, 0, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueStealthNativeCueAndSensorlessWheelKeepSavedSync() async throws {
    try await withControllerCuePlayback("Stealth Control") { model, input in
        cuePreviewPacket([0x90, 51, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 51, 127, 0xB0, 24, 1, 0x90, 67, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCataloguePartyMixLiveNativePadsSetExactLoopsAndKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Party Mix Live") { model, input in
        cuePreviewPacket([0x94, 20, 127, 0x84, 20, 0], to: input)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        cuePreviewPacket([0x94, 14, 127], to: input)
        for (pad, beats) in [(UInt8(20), 1.0), (21, 2), (22, 4), (23, 8)] {
            cuePreviewPacket([0x94, pad, 127, 0x84, pad, 0], to: input)
            let state = try #require(model.playbackSnapshot?.a)
            let grid = try #require(model.timing(.a))
            #expect(state.loopEnabled)
            #expect(abs(state.loopEnd - state.loopStart - grid.span(beats: beats, from: state.loopStart)) <= 1)
            #expect(state.synced)
            let samples = model.playback.core.renderOffline(frames: 512)
            #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
            model.refreshPlayback()
        }
        let end = model.playbackSnapshot?.a.loopEnd
        cuePreviewPacket([0x94, 11, 127, 20, 127, 0x84, 20, 0, 0x94, 15, 127, 21, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnd == end)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueG2VNativeTouchCueAndEightLoopsKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("G2V Audio") { model, input in
        cuePreviewPacket([0x90, 2, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 2, 127, 0x90, 37, 127, 0xB0, 6, 65], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 37, 0, 9, 127, 0x80, 9, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        cuePreviewPacket([0x90, 28, 127], to: input)
        for (slot, beats) in [0.125, 0.25, 0.5, 1, 2, 4, 8, 16].enumerated() {
            let pad = UInt8(slot + 9)
            cuePreviewPacket([0x90, pad, 127, 0x80, pad, 0], to: input)
            let state = try #require(model.playbackSnapshot?.a)
            let grid = try #require(model.timing(.a))
            #expect(state.loopEnabled)
            #expect(abs(state.loopEnd - state.loopStart - grid.span(beats: beats, from: state.loopStart)) <= 1)
            #expect(state.synced)
            let samples = model.playback.core.renderOffline(frames: 512)
            #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
            model.refreshPlayback()
        }
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueRMP4NativeShiftReleasesAndSevenLoopsKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("RMP-4") { model, input in
        cuePreviewPacket([0x90, 75, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x83, 107, 127, 0x90, 91, 127, 0xB0, 1, 65], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x83, 123, 127, 0x90, 0, 127, 0x80, 0, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        for (slot, beats) in [0.125, 0.25, 0.5, 1, 2, 4, 8].enumerated() {
            let pad = UInt8(slot + 79)
            cuePreviewPacket([0x90, pad, 127, 0x80, pad, 0], to: input)
            let state = try #require(model.playbackSnapshot?.a)
            let grid = try #require(model.timing(.a))
            #expect(state.loopEnabled)
            #expect(abs(state.loopEnd - state.loopStart - grid.span(beats: beats, from: state.loopStart)) <= 1)
            #expect(state.synced)
            let samples = model.playback.core.renderOffline(frames: 512)
            #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
            model.refreshPlayback()
        }
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueIDJ3NativeCueTouchAndFourLoopsKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("iDJ3") { model, input in
        cuePreviewPacket([0x90, 51, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 51, 127, 0x90, 78, 127, 0xB0, 25, 1], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 78, 0, 59, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        for (pad, beats) in [(UInt8(97), 1.0), (83, 2), (84, 4), (85, 8)] {
            cuePreviewPacket([0x90, pad, 127, 0x80, pad, 0], to: input)
            let state = try #require(model.playbackSnapshot?.a)
            let grid = try #require(model.timing(.a))
            #expect(state.loopEnabled)
            #expect(abs(state.loopEnd - state.loopStart - grid.span(beats: beats, from: state.loopStart)) <= 1)
            #expect(state.synced)
            let samples = model.playback.core.renderOffline(frames: 512)
            #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
            model.refreshPlayback()
        }
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueStudio2ANativeCueTouchAndHotCueKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Studio 2A") { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 1, 127, 0x90, 3, 127, 0xB0, 3, 65], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90, 3, 0, 10, 127, 0x80, 10, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueReloopTouchNativeManualCueAndContactKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Reloop TOUCH", manual: true) { model, input in
        cuePreviewPacket([0x91, 35, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x83, 99, 127, 0x91, 63, 127, 0xB1, 96, 65], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x83, 63, 127, 0x91, 36, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueSeventyOwnerTransportAndLoopsKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Rane Seventy MIDI", manual: true) { model, input in
        cuePreviewPacket([0x94, 103, 127, 0x84, 103, 0, 0x94, 97, 127], to: input)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        let samples = model.playback.core.renderOffline(frames: 2048)
        cuePreviewPacket([0x84, 97, 127, 0x94, 64, 127, 0x84, 64, 0], to: input)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        let state = try #require(model.playbackSnapshot?.a)
        #expect(state.phase.active && state.synced && state.loopEnabled)
        #expect(state.loopEnd > state.loopStart)
    }
}

@Test @MainActor func controllerCatalogueNVManualCueReleasesAcrossShiftBankAndKeepsAudioAndSync() async throws {
    try await withControllerCuePlayback("Numark NV", manual: true) { model, input in
        cuePreviewPacket([0x91, 32, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x93, 13, 127, 0x83, 32, 127, 13, 127, 0x91, 33, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueDJ3NativeCueAcrossBankAndPlayKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Faderfox DJ3") { model, input in
        cuePreviewPacket([0x93, 90, 127, 72, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x83, 106, 127, 80, 127, 0x93, 89, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueRMX90NativeMixerAndPFLKeepPlaybackAndSync() async throws {
    try await withControllerCuePlayback("RMX-90DVS", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let firstFrame = try #require(model.playbackSnapshot?.a.sourceFrame)
        cuePreviewPacket([0xB0, 6, 127, 2, 64, 0x90, 2, 127], to: input)
        #expect(model.playbackSnapshot?.a.mixer.volume == 1)
        #expect(model.playbackSnapshot?.a.mixer.high == 128.0 / 127)
        #expect(model.playbackSnapshot?.a.mixer.cue == true)
        cuePreviewPacket([0x80, 2, 127, 0x90, 2, 127, 0xB0, 6, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.mixer.volume == 0 && model.playbackSnapshot?.a.mixer.cue == false)
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > firstFrame)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueDJ202ManualCueAcrossShiftBankKeepsNativeAudioAndSync() async throws {
    try await withControllerCuePlayback("DJ-202", manual: true) { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x9F, 0, 127, 0x82, 5, 127, 0x8F, 0, 127, 0x90, 0, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0xB0, 28, 127, 58, 127, 0x90, 27, 127], to: input)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.mixer.volume == 1 && model.playbackSnapshot?.a.mixer.cue == true)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueDJ505ManualCueAcrossShiftBankKeepsNativeAudioAndSync() async throws {
    try await withControllerCuePlayback("DJ-505", manual: true) { model, input in
        cuePreviewPacket([0x90, 1, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x9F, 0, 127, 0x82, 5, 127, 0x8F, 0, 127, 0x90, 0, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0xB0, 28, 127, 58, 127, 0x90, 27, 127], to: input)
        let samples = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(samples.left.allSatisfy(\.isFinite) && samples.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.mixer.volume == 1 && model.playbackSnapshot?.a.mixer.cue == true)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMM1NativeMixerAndPFLKeepPlaybackAndSync() async throws {
    try await withControllerCuePlayback("CMD MM-1") { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let firstFrame = try #require(model.playbackSnapshot?.a.sourceFrame)
        cuePreviewPacket([0xB4, 49, 127, 7, 64, 0x94, 49, 127], to: input)
        #expect(model.playbackSnapshot?.a.mixer.volume == 1)
        #expect(model.playbackSnapshot?.a.mixer.high == 128.0 / 127)
        #expect(model.playbackSnapshot?.a.mixer.cue == true)
        cuePreviewPacket([0x94, 49, 0, 49, 127, 0xB4, 49, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.mixer.volume == 0 && model.playbackSnapshot?.a.mixer.cue == false)
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > firstFrame)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueFixedMixersNativeLevelsPFLAndRelativeGainKeepPlaybackAndSync() async throws {
    for name in ["SMC-Mixer", "iControls"] {
        try await withControllerCuePlayback(name) { model, input in
            input.currentTargetValue = model.controllerInput.currentTargetValue
            model.pressPlay(deck: .a, vinylStop: false)
            _ = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            let firstFrame = try #require(model.playbackSnapshot?.a.sourceFrame)
            let firstGain = try #require(model.playbackSnapshot?.a.mixer.gain)
            let note: UInt8 = name == "SMC-Mixer" ? 29 : 9
            cuePreviewPacket([0xE1, 127, 127, 0x90, note, 127], to: input)
            #expect(model.playbackSnapshot?.a.mixer.volume == 1 && model.playbackSnapshot?.a.mixer.cue == true)
            cuePreviewPacket([0xB0, 17, 1], to: input)
            #expect((model.playbackSnapshot?.a.mixer.gain ?? 0) > firstGain)
            cuePreviewPacket([0x90, note, 0, note, 127, 0xE1, 0, 0], to: input)
            let audio = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.mixer.volume == 0 && model.playbackSnapshot?.a.mixer.cue == false)
            #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > firstFrame)
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        }
    }
}

@Test @MainActor func controllerCatalogueSMK25NativeSysexCueBankReleaseAndPlayKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("SMK-25 II") { model, input in
        let track = try #require(model.library.tracks.first)
        model.load(trackID: track.id, deck: .b)
        await model.flushWrites()
        input.receiveBytes([0xF0, 0x35, 0x59, 0x10, 93, 127, 0xF7], source: 10)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0xF0, 0x35, 0x59, 0x10, 47, 0, 0xF7], source: 10)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0xF0, 0x35, 0x59, 0x10, 93, 127, 0xF7], source: 10)
        #expect(model.playbackSnapshot?.b.touchActive == true)
        input.receiveBytes([0xF0, 0x35, 0x59, 0x10, 93, 0, 0xF7, 0xF0, 0x35, 0x59, 0x10, 94, 127, 0xF7], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.b.touchActive == false && model.playbackSnapshot?.b.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.b.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMIDIFighterClassicNativeCueSetAndRecallKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Midi Fighter Classic") { model, input in
        model.cue(slot: 0, deck: .a, delete: true)
        #expect(model.controllerValue(.hotcue1A) == 0)
        cuePreviewPacket([0x92, 44, 125, 0x82, 44, 125], to: input)
        #expect(model.controllerValue(.hotcue1A) == 1)
        model.pressPlay(deck: .a, vinylStop: false)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        cuePreviewPacket([0x92, 44, 127, 44, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMIDIFighterTwisterNativeMixerAndPFLKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Midi Fighter Twister") { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let first = try #require(model.playbackSnapshot?.a.sourceFrame)
        cuePreviewPacket([0xB0, 8, 127, 1, 64, 0xB1, 8, 127], to: input)
        #expect(model.playbackSnapshot?.a.mixer.volume == 1 && model.playbackSnapshot?.a.mixer.high == 128.0 / 127)
        #expect(model.playbackSnapshot?.a.mixer.cue == true)
        cuePreviewPacket([0xB1, 8, 0, 8, 127, 0xB0, 8, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.mixer.volume == 0 && model.playbackSnapshot?.a.mixer.cue == false)
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0) > first)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueOriginalMiniNativePagesKeepCuePlayAudioAndSync() async throws {
    try await withControllerCuePlayback("Launchpad Mini") { model, input in
        model.cue(slot: 0, deck: .a, delete: true)
        cuePreviewPacket([0x90, 16, 127, 16, 0], to: input)
        #expect(model.controllerValue(.hotcue1A) == 1)
        cuePreviewPacket([0x90, 0, 127, 0, 0], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true)
        cuePreviewPacket([0x90, 24, 127, 24, 0, 0, 127, 0, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueRGBLaunchpadNativeCuePlayLoopKeepAudioAndSync() async throws {
    for name in ["Launchpad MK2", "Launchpad Mini MK3"] {
        try await withControllerCuePlayback(name, ports: name.hasSuffix("MK3") ? ["LPMiniMK3 MIDI"] : []) {
            model, input in
            cuePreviewPacket([0x90, 21, 127], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x90, 11, 127, 11, 0, 21, 0], to: input)
            _ = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == true)
            cuePreviewPacket([0x90, 63, 127, 63, 0], to: input)
            model.refreshPlayback()
            #expect(model.playbackSnapshot?.a.loopEnabled == true)
            cuePreviewPacket([0x90, 43, 127, 43, 0], to: input)
            let audio = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.loopEnabled == false)
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        }
    }
}

@Test @MainActor func controllerCatalogueCDJ101NativeSourceTicksCuePlayKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("CDJ-101") { model, input in
        input.receiveBytes([0x90, 32, 127, 0xB0, 54, 67], source: 10)
        input.flushPendingActions()
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        let expected = sampleRate * 60 / (45 * 143) * 3
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - expected) <= 1)
        input.receiveBytes([0x80, 32, 127, 0x90, 43, 127], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x90, 42, 127, 42, 0, 43, 0], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueManualProtocolNativeVendorCuePlayKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("SMK-25 II") { model, input in
        input.sources = [
            .init(
                id: 10, reference: 100, name: "Unmapped MIDI",
                identity: .init(id: 10, device: 1, names: ["Unmapped MIDI"]))
        ]
        input.destinations = []
        input.reconcileFactoryProfiles()
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["SMK-25 II"])))
        input.receiveBytes([0xF0, 0x35, 0x59, 0x10, 93, 127, 0xF7], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0xF0, 0x35, 0x59, 0x10, 94, 127, 0xF7, 0xF0, 0x35, 0x59, 0x10, 93, 0, 0xF7], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueSR2NativeSelectorCueReleaseAndPlayKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("DDJ-SR2", manual: true) { model, input in
        input.receiveBytes([0x90, 12, 127], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x92, 86, 127], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == false)
        input.receiveBytes([0x90, 85, 127, 11, 127, 11, 0], source: 10)
        input.flushPendingActions()
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true)
        input.receiveBytes([0x90, 85, 0, 0x92, 86, 127], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueKeyLabNativeMMCPulsesAndMixerKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("KeyLab 88") { model, input in
        input.receiveBytes([0xF0, 0x7F, 0x7F, 6, 1, 0xF7], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0xF0, 0x7F, 0x7F, 6, 2, 0xF7, 0xB0, 75, 64], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        input.receiveBytes([0xF0, 0x7F, 0x7F, 6, 1, 0xF7], source: 10)
        input.flushPendingActions()
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == false && model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueKontrolOneNativeDeckSwitchReleasesCueAndKeepsAudioAndSync() async throws {
    try await withControllerCuePlayback("Kontrol One") { model, input in
        input.receiveBytes([0x90, 28, 127], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0xB1, 33, 64], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == false)
        input.receiveBytes([0x90, 27, 127, 27, 0, 31, 127, 0xB0, 32, 127, 0x80, 31, 127], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == true)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueSpectraNativeCuesKeepAudioAndSyncAcrossBankChanges() async throws {
    try await withControllerCuePlayback("Midi Fighter Spectra") { model, input in
        model.cue(slot: 0, deck: .a, delete: true)
        #expect(model.controllerValue(.hotcue1A) == 0)
        input.receiveBytes([0x92, 60, 127, 0x82, 60, 127], source: 10)
        input.flushPendingActions()
        #expect(model.controllerValue(.hotcue1A) == 1)
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0x93, 0, 127, 0x92, 37, 127, 37, 0, 0x93, 1, 127, 0x92, 60, 127, 0x82, 60, 127], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueDUONativeCueBanksKeepAudioAndSync() async throws {
    for name in ["Mixars DUO", "Mixars DUO MKII"] {
        try await withControllerCuePlayback(name, manual: true) { model, input in
            model.cue(slot: 0, deck: .a, delete: true)
            #expect(model.controllerValue(.hotcue1A) == 0)
            input.receiveBytes([0x94, 20, 127, 20, 0, 27, 127, 27, 0], source: 10)
            input.flushPendingActions()
            #expect(model.controllerValue(.hotcue1A) == 1 && model.controllerValue(.hotcue8A) == 1)
            model.pressPlay(deck: .a, vinylStop: false)
            input.receiveBytes([0x9F, 33, 127, 33, 0, 0x94, 20, 127, 20, 0], source: 10)
            input.flushPendingActions()
            let audio = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
            #expect(model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCatalogueP1NanoNativeCueModeBoundariesKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Icon P1-Nano MIDI 1", manual: true) { model, input in
        input.receiveBytes([0x90, 93, 127], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x90, 26, 127], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == false)
        input.receiveBytes([0x90, 24, 127, 94, 127, 94, 0, 50, 127, 50, 0, 0xE0, 0, 64], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueDDM4000NativeMixerKeepsAudioAndSync() async throws {
    try await withControllerCuePlayback("Behringer DDM4000", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0xB0, 4, 64, 5, 64, 6, 64, 7, 127, 21, 0, 0x90, 63, 127, 63, 0], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerTimedSetupSCS3mNativeMixerKeepsAudioAndSync() async throws {
    var now: UInt64 = 0
    try await withControllerCuePlayback(
        "Stanton SCS.3m", setupClock: { now }, prepareInput: { input in
            for _ in 0..<5 {
                now += 20_000_000
                input.advanceFactorySetups()
            }
        }
    ) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0xB0, 0, 64, 2, 64, 4, 64, 6, 64, 8, 127, 10, 0, 0x90, 8, 127, 8, 0], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueBCR2000NativeKeylockStatePreservesOrderedIntentAudioAndSync() async throws {
    try await withControllerCuePlayback("Behringer BCR2000") { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        for enabled in [false, true, true, false, false, true, false] {
            let value: UInt8 = enabled ? 127 : 0
            input.receiveBytes([0xB0, 65, value], source: 10)
            input.flushPendingActions()
            #expect(model.playback.requestedKeylock(.a) == enabled)
        }
        input.receiveBytes([0xB0, 9, 64, 10, 64, 11, 64, 12, 64], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.keylock == false)
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueSC5000MNativeHeldCueLayerAndMotorNoiseKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Denon DJ SC5000M PRIME", manual: true) { model, input in
        input.receiveBytes([0x90, 2, 127], source: 10)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x90, 11, 127, 11, 0, 0x80, 2, 127], source: 10)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0x90, 11, 127, 11, 0, 1, 127, 1, 0], source: 10)
        for _ in 0..<100 {
            input.receiveBytes([0xB0, 17, 64, 49, 64, 54, 1, 55, 0, 0xE0, 0, 64, 0x90, 40, 127], source: 10)
        }
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCataloguePrimePlayersNativeCuePlayKeepAudioAndSync() async throws {
    for name in ["Denon DJ SC6000 PRIME", "Denon DJ SC6000M PRIME", "Denon DJ SC5000 PRIME"] {
        try await withControllerCuePlayback(name, manual: true) { model, input in
            input.receiveBytes([0x90, 2, 127], source: 10)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x90, 11, 127, 11, 0, 0x80, 2, 127], source: 10)
            #expect(model.playbackSnapshot?.a.touchActive == false)
            input.receiveBytes([0x90, 11, 127, 11, 0, 1, 127, 1, 0], source: 10)
            input.flushPendingActions()
            let audio = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
            #expect(model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCatalogueRaneOneMK2NativeLoopsBendAndExplicitSyncOffKeepAudioFinite() async throws {
    try await withControllerCuePlayback("Rane ONE MKII", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        model.setLoopSize(4, deck: .a)
        cuePreviewPacket([0x94, 63, 127, 63, 0, 52, 127, 52, 0, 53, 127, 53, 0], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90, 12, 127, 12, 0], to: input)
        try await Task.sleep(for: .milliseconds(80))
        #expect(model.playbackSnapshot?.a.synced == true)
        cuePreviewPacket([0x9F, 50, 127, 0x90, 3, 127, 3, 0], to: input)
        #expect(model.playbackSnapshot?.a.synced == false)
        cuePreviewPacket([0x8F, 50, 127, 0x90, 2, 127, 2, 0, 0, 127, 1, 127], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueNanoKontrol2NativeMixerKeepsAudioAndSyncAfterAcknowledgedSetup() async throws {
    try await withControllerCuePlayback("Korg nanoKONTROL2", prepareInput: { input in
        input.receiveBytes([0xF0, 0x42, 0x50, 1, 6, 0x2D, 0x13, 1, 0, 0, 0, 0, 1, 0, 0xF7], source: 10)
        input.receiveBytes([0xF0, 0x42, 0x46, 0, 1, 0x13, 0, 0x40, 0, 3, 0xF7], source: 10)
    }) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0xBF, 0, 127, 18, 64, 64, 127, 64, 0], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.mixer.cue == true)
        #expect(abs((model.playbackSnapshot?.cueBlend ?? 0) - 64.0 / 127) < 0.001)
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueNanoPad2NativeCueAndLoopKeepAudioAndSyncAfterAcknowledgedSetup() async throws {
    try await withControllerCuePlayback("Korg nanoPAD2", prepareInput: { input in
        input.receiveBytes([0xF0, 0x42, 0x50, 1, 10, 0x2D, 0x12, 1, 0, 0, 0, 0, 1, 0, 0xF7], source: 10)
        input.receiveBytes([0xF0, 0x42, 0x4A, 0, 1, 0x12, 0, 0x40, 0, 3, 0xF7], source: 10)
    }) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0x91, 65, 127, 0x81, 65, 64], source: 10)
        input.receiveBytes([0xBF, 57, 127, 57, 0, 57, 127, 57, 0, 0x91, 67, 127, 0x81, 67, 64], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCataloguePrime4NativeCueDeckBoundariesAndPlayKeepAudioAndSync() async throws {
    for name in ["Denon DJ PRIME 4", "Denon DJ PRIME 4+"] {
        try await withControllerCuePlayback(name, manual: true) { model, input in
            input.receiveBytes([0x94, 9, 127], source: 10)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x9F, 30, 127, 30, 0, 0x84, 9, 127], source: 10)
            #expect(model.playbackSnapshot?.a.touchActive == false)
            input.receiveBytes([0x9F, 28, 127, 28, 0, 0x94, 10, 127, 10, 0], source: 10)
            input.flushPendingActions()
            let audio = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
            #expect(model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCatalogueMP2015NativeMixerKeepsAudioAndSync() async throws {
    try await withControllerCuePlayback("Rane MP2015", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0xB0, 1, 64, 3, 64, 5, 64, 7, 64, 4, 127, 43, 64, 0x90, 19, 127, 19, 0], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueRaneOneOriginalNativePlayLoopBendAndSyncKeepAudioFinite() async throws {
    try await withControllerCuePlayback("Rane ONE", manual: true) { model, input in
        cuePreviewPacket([0x90, 0, 127, 0, 0], to: input)
        model.setLoopSize(4, deck: .a)
        cuePreviewPacket([0x94, 63, 127, 63, 0, 52, 127, 52, 0, 53, 127, 53, 0], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90, 12, 127, 12, 0], to: input)
        try await Task.sleep(for: .milliseconds(80))
        cuePreviewPacket([0x90, 3, 127, 3, 0], to: input)
        #expect(model.playbackSnapshot?.a.synced == true)
        model.setSync(false, deck: .a)
        cuePreviewPacket([0x90, 2, 127, 2, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCataloguePrimeAIONativeCuePlayMixerAndLoopKeepAudioAndSync() async throws {
    for name in ["Denon DJ PRIME GO", "Denon DJ PRIME 2"] {
        try await withControllerCuePlayback(name, manual: name.hasSuffix("2")) { model, input in
            cuePreviewPacket([0x92, 9, 127], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x82, 9, 127, 0x92, 10, 127, 10, 0], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == false)
            cuePreviewPacket([0xB0, 3, 64, 4, 64, 6, 64, 8, 64, 14, 127, 0xBF, 12, 64], to: input)
            if name.hasSuffix("GO") {
                model.setLoopSize(4, deck: .a)
                cuePreviewPacket([0x92, 39, 127, 39, 0], to: input)
                #expect(model.playbackSnapshot?.a.loopEnabled == true)
            }
            let audio = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        }
    }
}

@Test @MainActor func controllerCatalogueEngineFixedNativeMixerAndTransportKeepAudioAndSync() async throws {
    for name in ["Denon DJ SC Live 2", "Denon DJ SC Live 4", "Numark Mixstream Pro Go"] {
        try await withControllerCuePlayback(name, manual: true) { model, input in
            if name.hasSuffix("4") { model.pressPlay(deck: .a, vinylStop: false) }
            else {
                cuePreviewPacket([0x92, 9, 127], to: input)
                #expect(model.playbackSnapshot?.a.touchActive == true)
                cuePreviewPacket([0x82, 9, 127, 0x92, 10, 127, 10, 0], to: input)
            }
            cuePreviewPacket([0xB0, 3, 64, 4, 64, 6, 64, 8, 64, 14, 127, 0x90, 13, 127, 13, 0], to: input)
            let audio = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
            #expect(model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCatalogueRDJ2MasterNativeCuePlayMixerAndLoopKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("Reloop Digital Jockey 2 Master Edition", manual: true) { model, input in
        cuePreviewPacket([0x90, 24, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 24, 127, 0x90, 25, 127, 25, 0], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0xB0, 2, 64, 3, 64, 4, 64, 5, 64, 6, 127, 17, 64], to: input)
        model.setLoopSize(4, deck: .a)
        cuePreviewPacket([0x90, 17, 127, 17, 0], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueSP404NativeSyncAndPFLStatesStayIdempotentDuringRealAudio() async throws {
    try await withControllerCuePlayback("Roland SP-404MKII", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        for enabled in [false, false, true, true, false, true] {
            cuePreviewPacket([0xB0, 22, enabled ? 127 : 0, 23, enabled ? 127 : 0], to: input)
            #expect(model.playbackSnapshot?.a.synced == enabled)
            #expect(model.playbackSnapshot?.a.mixer.cue == enabled)
            #expect(model.controllerValue(.syncStateA) == (enabled ? 1 : 0))
        }
        cuePreviewPacket([0xB0, 7, 64, 8, 64, 24, 127, 24, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueEuphoniaNativeLatchedPFLAndMixerKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("AlphaTheta Euphonia", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        for enabled in [false, false, true, true, false, true] {
            cuePreviewPacket([0x90, 10, enabled ? 127 : 0], to: input)
            #expect(model.playbackSnapshot?.a.mixer.cue == enabled)
        }
        cuePreviewPacket([0xB0, 1, 64, 2, 64, 3, 64, 4, 64, 17, 127, 27, 64], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueNumark2026NativeCuePlayTempoAndMixerKeepAudioAndSync() async throws {
    for name in ["Numark MixTrack Go", "Numark Party Mix III"] {
        try await withControllerCuePlayback(name) { model, input in
            cuePreviewPacket([0x90, 1, 127], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x80, 5, 127, 0x90, 0, 127, 0, 0], to: input)
            #expect(model.playbackSnapshot?.a.touchActive == false)
            cuePreviewPacket([0xB0, 22, 127, 26, 64, 9, 64, 41, 0, 0xBF, 8, 64], to: input)
            if name.hasSuffix("Go") {
                cuePreviewPacket([0x90, 80, 127, 0xB0, 6, 1, 6, 127, 0x80, 80, 127], to: input)
            }
            let audio = model.playback.core.renderOffline(frames: 4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
            #expect(model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalNanoSceneNativeMixerAndLatchedStatesKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("nanoKONTROL", prepareInput: { input in
        input.receiveBytes(controllerOriginalNanoSceneFixture(toggle: true), source: 10)
        input.flushPendingActions()
    }) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0xB0, 1, 127, 2, 64, 3, 127, 0xB4, 2, 64], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.mixer.cue == true)
        input.receiveBytes([0xB0, 3, 0, 0x90, 4, 127, 4, 0], source: 10)
        input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.mixer.cue == false && model.playbackSnapshot?.a.keylock == false)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueCRSSNativeCueRecallKeepsAudioAndSyncWithoutMotorCommands() async throws {
    try await withControllerCuePlayback("PLX-CRSS12") { model, input in
        #expect(model.playbackSnapshot?.a.synced == true)
        cuePreviewPacket([0x97, 0, 127, 0, 0], to: input)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true)
        cuePreviewPacket([0x90, 48, 127, 0x97, 8, 127, 8, 0, 0x90, 48, 0], to: input)
        cuePreviewPacket([0x90, 0, 127, 0, 0, 1, 127, 1, 0, 0xB0, 16, 127, 48, 127], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueMK4NativeCueLoopsAndRelativePitchKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("DJ Console Mk4",manual: true) { model,input in
        cuePreviewPacket([0x90,14,127],to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,14,127],to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        model.pressPlay(deck: .a,vinylStop: false)
        cuePreviewPacket([0x90,2,127,2,0],to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90,2,127,2,0],to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        input.currentTargetValue = { model.controllerValue($0.action, targetDeck: $0.deck) }
        cuePreviewPacket([0xB0,50,1,48,1,48,127],to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueA9NativeMixerAndTogglePFLKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("DJM-A9",manual: true) { model,input in
        model.pressPlay(deck: .a,vinylStop: false)
        input.currentTargetValue = { model.controllerValue($0.action,targetDeck: $0.deck) }
        cuePreviewPacket([0x90,10,127,10,127],to: input)
        #expect(model.playbackSnapshot?.a.mixer.cue == true)
        cuePreviewPacket([0x90,10,0,10,0],to: input)
        #expect(model.playbackSnapshot?.a.mixer.cue == false)
        cuePreviewPacket([0xB0,2,64,3,64,4,64,5,64,11,64,17,127,17,0,18,127,18,0],to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueSLABNativePageShiftCueAndLoopsKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("SLAB") { model,input in
        cuePreviewPacket([0x97,109,127],to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,70,127,0x98,109,0],to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90,70,0,94,127,94,0,0x97,44,127,44,0],to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x96,85,127,85,0],to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x97,44,127,44,0],to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        input.currentTargetValue = { model.controllerValue($0.action,targetDeck: $0.deck) }
        cuePreviewPacket([0xB0,16,1,0xB6,14,64,46,0,0xA7,12,127],to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueA7NativeFaderAndTogglePFLKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("DJM-A7",manual: true) { model,input in
        model.pressPlay(deck: .a,vinylStop: false)
        input.currentTargetValue = { model.controllerValue($0.action,targetDeck: $0.deck) }
        cuePreviewPacket([0x90,10,127,10,127],to: input)
        #expect(model.playbackSnapshot?.a.mixer.cue == true)
        cuePreviewPacket([0x90,10,0,10,0],to: input)
        #expect(model.playbackSnapshot?.a.mixer.cue == false)
        cuePreviewPacket([0xB0,17,64,17,127,2,64,3,64,4,64,5,64,11,64],to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueXDJANNativeCueModeLossAndLoopKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("XDJ-AN", prepareInput: {
        $0.receiveBytes([0xB0,100,127,0xB1,100,127],source: 10)
    }) { model,input in
        input.receiveBytes([0x90,1,127],source: 10)
        input.flushPendingActions()
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0xB4,101,127],source: 10)
        input.flushPendingActions()
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(!input.isInputActive(10))
        input.receiveBytes([0xB4,101,0,0x90,0,127,0,0,0x95,51,127,51,0],source: 10)
        input.flushPendingActions()
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueREV7NativeTransportLoopAndShiftBendKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("DDJ-REV7",manual: true) { model,input in
        cuePreviewPacket([0x90,11,127,11,0,20,127,20,0],to: input)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90,58,127,0x96,63,127,0x90,93,0,0x96,63,0],to: input)
        cuePreviewPacket([0xB0,34,65,34,63,0x90,115,127,115,0,35,5],to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueIgniteNativeLoopBendAndClockKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("RMX-IGNITE",manual: true) { model,input in
        model.pressPlay(deck: .a,vinylStop: false)
        cuePreviewPacket([0x90,55,127,55,0,4,127,0x80,4,127],to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        input.currentTargetValue = { model.controllerValue($0.action,targetDeck: $0.deck) }
        cuePreviewPacket([0xB0,21,64,22,64,23,64,25,64,0xF8,0x90,57,127,57,0],to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueUltraNativeCueReturnAndGuardedScratchKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("DJControl Mix Ultra") { model,input in
        cuePreviewPacket([0x91,6,127,6,0],to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x91,7,127,7,0,8,127,0xB1,10,1],to: input)
        cuePreviewPacket([0x91,4,127,0x94,8,0,0x91,4,0],to: input)
        cuePreviewPacket([0x91,5,0,5,127,5,0,0x94,5,127,5,0,0x92,12,127,12,0],to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x91,6,127,6,0],to: input)
        #expect(model.playbackSnapshot?.a.phase.active == false && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueAIRPlusNativeCueAndModeCleanupKeepAudioAndSavedSync() async throws {
    try await withControllerCuePlayback("DJControl AIR+") { model,input in
        cuePreviewPacket([0x90,18,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,18,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90,17,127,17,0,27,127,0xB0,104,1],to:input)
        cuePreviewPacket([0x90,20,127,84,127,20,0,84,0],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.currentTargetValue = { model.controllerValue($0.action,targetDeck:$0.deck) }
        cuePreviewPacket([0xB0,5,64,37,0,6,64,38,0,7,64,39,0,102,1,0x90,64,127,64,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueAIRPlusBothStreamsScratchAtCorroboratedResolutionAndRestoreSync() async throws {
    for number: UInt8 in [102,104] {
        try await withControllerCuePlayback("DJControl AIR+") { model,input in
            cuePreviewPacket([0x90,27,127,0xB0,number,2],to:input)
            try await Task.sleep(for:.milliseconds(80))
            _ = model.playback.core.renderOffline(frames:4096)
            model.refreshPlayback()
            let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
            #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - sampleRate*1.8*2/765) <= 1)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x80,27,127],to:input)
            #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.synced == true)
            _ = model.playback.core.renderOffline(frames:4096)
            model.refreshPlayback()
            #expect(model.playbackSnapshot?.a.phase.active == false)
            #expect(abs(model.playbackSnapshot?.a.sourceFrame ?? -1) <= 1)
        }
    }
}

@Test @MainActor func controllerCatalogue4SetNativeCueBendAndScratchKeepAudioAndSync() async throws {
    try await withControllerCuePlayback("DJ 4Set",manual:true) { model,input in
        cuePreviewPacket([0x90,13,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,13,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90,26,127,0xB0,1,2],to:input)
        try await Task.sleep(for:.milliseconds(80))
        _ = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-sampleRate*1.8*2/250)<=1)
        cuePreviewPacket([0x90,18,127,0x80,26,127,0x90,14,127,14,0,30,127,0x80,30,127],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueOriginalNS6CyclicScratchUses3600CountsAndRestoresSync() async throws {
    try await withControllerCuePlayback("Numark NS6",manual:true) { model,input in
        cuePreviewPacket([0x91,16,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x81,16,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x91,44,127,0xB1,0,0,32,0],to:input)
        cuePreviewPacket([0xB1,0,0,32,2],to:input)
        try await Task.sleep(for:.milliseconds(80))
        _ = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-sampleRate*1.8*2/3600)<=1)
        cuePreviewPacket([0xB0,80,1,0x91,17,127,17,0,25,127,0x81,25,127],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueOriginalMC6000ScratchUses2000CountsAndReleasesVelocity64() async throws {
    try await withControllerCuePlayback("DN-MC6000",manual:true) { model,input in
        cuePreviewPacket([0x90,66,64],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,66,64],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90,81,64,0xB0,81,66],to:input)
        try await Task.sleep(for:.milliseconds(80))
        _ = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-sampleRate*1.8*2/2000)<=1)
        cuePreviewPacket([0x90,3,64,67,64,67,0,12,64,0x80,12,64],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueSpin2SharedNativeScratchUsesProvisional375ScaleAndRestoresSync() async throws {
    for name in ["Vestax Spin2","Casio XW-J1"] {
        try await withControllerCuePlayback(name,manual:true) { model,input in
            cuePreviewPacket([0x90,47,127],to:input)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x80,47,127],to:input)
            #expect(model.playbackSnapshot?.a.touchActive == false)
            cuePreviewPacket([0x90,59,127,0xB2,16,65],to:input)
            try await Task.sleep(for:.milliseconds(80))
            _ = model.playback.core.renderOffline(frames:4096)
            model.refreshPlayback()
            let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
            #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-sampleRate*1.8/375)<=1)
            cuePreviewPacket([0x92,32,127,32,0,0x90,46,127,46,0],to:input)
            let audio = model.playback.core.renderOffline(frames:4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
            #expect(model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCataloguePrimoSourceReportRestoresSyncAfterHeldBendInRealAudio() async throws {
    try await withControllerCuePlayback("Mixars PRIMO",manual:true) { model,input in
        cuePreviewPacket([0x90,0,127,0,0,12,127],to:input)
        let before = model.playback.core.renderOffline(frames:4096)
        #expect(before.left.allSatisfy(\.isFinite) && before.right.allSatisfy(\.isFinite))
        cuePreviewPacket([0xB0,34,0],to:input)
        _ = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueOriginalBeatMixScratchAndModeCleanupRestoreSavedSync() async throws {
    try await withControllerCuePlayback("Reloop BeatMix") { model,input in
        cuePreviewPacket([0x90,46,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,46,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90,63,127,0xB0,36,66],to:input)
        try await Task.sleep(for:.milliseconds(80))
        _ = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect((model.playbackSnapshot?.a.sourceFrame ?? -1)>0)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,36,127,47,127,47,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueVCM100BothChannelChoicesReleaseCueAndBendsInRealAudio() async throws {
    for channel:UInt8 in [0,1] {
        try await withControllerCuePlayback("Vestax VCM-100",manual:true) { model,input in
            cuePreviewPacket([0x90+channel,52,127],to:input)
            #expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x80+channel,52,127],to:input)
            #expect(model.playbackSnapshot?.a.touchActive == false)
            cuePreviewPacket([0x90+channel,50,127,50,0,78,127,0x80+channel,78,127],to:input)
            let audio = model.playback.core.renderOffline(frames:4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
            #expect(model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCatalogueXWDJ1Manufacturer300CountScratchAndShiftCleanupPreserveSync() async throws {
    try await withControllerCuePlayback("Casio XW-DJ1") { model,input in
        cuePreviewPacket([0x90,44,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,44,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90,59,127,0xB2,16,65],to:input)
        try await Task.sleep(for:.milliseconds(80))
        _ = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-sampleRate*1.8/300)<=1)
        cuePreviewPacket([0x90,46,127,46,0,42,127,42,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueInpulse200MK3Factory512CountScratchAndModeCleanupPreserveSync() async throws {
    try await withControllerCuePlayback("Hercules DJControl Inpulse 200 MK3") { model,input in
        cuePreviewPacket([0x91,6,127,0x84,6,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x91,8,127,0xB1,10,2],to:input)
        try await Task.sleep(for:.milliseconds(80))
        _ = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-sampleRate*1.8*2/512)<=1)
        cuePreviewPacket([0x94,3,127,3,0,0x91,7,127,7,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueT10SupplementalMixerKeepsTouchStartedAudioFiniteAndSynced() async throws {
    try await withControllerCuePlayback("Hercules DJControl T10",manual:true) { model,input in
        input.onTargetAction?(.init(.playA,deck:.a),1)
        cuePreviewPacket([0xB1,0,64,1,64,2,64,3,64,4,64,5,64],to:input)
        cuePreviewPacket([0x96,0,127,0,0,0x91,4,127,0xB4,5,64,0x81,4,127],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueXone96ManualFaderAndCueStateKeepAudioFiniteAndSynced() async throws {
    try await withControllerCuePlayback("Allen & Heath Xone:96",manual:true) { model,input in
        input.onTargetAction?(.init(.playA,deck:.a),1)
        cuePreviewPacket([0xBF,0,100,5,64,0x9F,0,127,0,127],to:input)
        #expect(model.controllerValue(.cueA) == 1)
        cuePreviewPacket([0x8F,0,127],to:input)
        #expect(model.controllerValue(.cueA) == 0)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueXoneFaderSubsetsKeepTouchStartedAudioFiniteAndSynced() async throws {
    for (name,number):(String,UInt8) in [("Allen & Heath Xone:PX5",0),("Allen & Heath Xone:24C",5)] {
        try await withControllerCuePlayback(name,manual:true) { model,input in
            input.onTargetAction?(.init(.playA,deck:.a),1)
            cuePreviewPacket([0xBF,number,100,4,64],to:input)
            let audio = model.playback.core.renderOffline(frames:4096)
            model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
            #expect(model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCatalogueVMS5ManualBankChangeRetiresCueAndRestoresSyncInRealAudio() async throws {
    try await withControllerCuePlayback("American Audio VMS5",manual:true) { model,input in
        cuePreviewPacket([0x90,13,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,14,127,14,0],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90,14,127,14,0,79,127,0xB0,49,0,48,10,49,0,48,11],to:input)
        try await Task.sleep(for:.milliseconds(80))
        _ = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-sampleRate*1.8/2730)<=1)
        cuePreviewPacket([0x90,14,127,14,0,14,127,14,0,12,127,12,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueVMS41TraktorMixerKeepsTouchStartedAudioFiniteAndSynced() async throws {
    try await withControllerCuePlayback("American Audio VMS4.1 Traktor",manual:true) { model,input in
        input.onTargetAction?(.init(.playA,deck:.a),1)
        input.currentTargetValue = {model.controllerValue($0.action,targetDeck:$0.deck)}
        cuePreviewPacket([0xB0,4,127,1,64,2,64,3,64],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCataloguePublicAFXModeChangeRetiresCueAndRestoresSyncInRealAudio() async throws {
    try await withControllerCuePlayback("Akai Pro AFX",manual:true) { model,input in
        cuePreviewPacket([0x91,50,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x91,23,127,23,0,49,127,49,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCataloguePublicEdgeShiftRetiresCueAndRestoresSyncInRealAudio() async throws {
    try await withControllerCuePlayback("Numark Mixtrack Edge",manual:true) { model,input in
        cuePreviewPacket([0x91,51,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,38,127,38,0,0x91,59,127,59,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueDJMS3DirectCueAndSourcePickupPreserveRealAudioSync() async throws {
    try await withControllerCuePlayback("Pioneer DJM-S3",manual:true) {model,input in
        input.onTargetAction?(.init(.playA,deck:.a),1)
        cuePreviewPacket([0xB0,70,127,70,127,70,0,17,127,0x90,53,127,53,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueLegacyDockIonHeldCueAndPlayRestoreRealAudioSync() async throws {
    try await withControllerCuePlayback("ION iDJ2GO", manual: true) { model, input in
        cuePreviewPacket([0x90, 51, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, 51, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90, 59, 127, 59, 0, 67, 127, 67, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueLegacyDockPhilipsSeparateCueActionsPreserveRealAudioSync() async throws {
    try await withControllerCuePlayback("Philips M1X DJ", manual: true) { model, input in
        cuePreviewPacket([0x91, 1, 127, 1, 0], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        cuePreviewPacket([0x91, 3, 127, 3, 0], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        cuePreviewPacket([0x91, 2, 127, 2, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Pioneer DJM-900NXS", "Pioneer DJM-850", "Pioneer DJM-750MK2", "Pioneer DJM-900SRT", "Pioneer DJM-750", "Pioneer DJM-250MK2", "Pioneer DJM-2000", "Pioneer DJM-2000NXS"]) @MainActor
func controllerCatalogueLegacyDJMDirectCueKeepsAppStartedRealAudioSynced(_ name: String) async throws {
    try await withControllerCuePlayback(name, manual: true) { model, input in
        input.onTargetAction?(.init(.playA, deck: .a), 1)
        let cue: UInt8 = name.hasSuffix("900SRT") ? 71 : 70
        let level: UInt8 = name.hasSuffix("900SRT") ? 18 : 17
        cuePreviewPacket([0xB0, cue, 127, cue, 127, cue, 0, level, 127], to: input)
        if name.hasSuffix("900SRT") { cuePreviewPacket([0x90, 57, 127, 57, 0], to: input) }
        if name.hasSuffix("250MK2") { cuePreviewPacket([0x90, 53, 127, 53, 0], to: input) }
        if name.hasSuffix("750MK2") { cuePreviewPacket([0x90, 53, 127, 53, 0], to: input) }
        let audio = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueLegacyPioneerT1AlternateCueReleaseRestoresRealAudioSync() async throws {
    try await withControllerCuePlayback("Pioneer DJM-T1",manual:true) {model,input in
        cuePreviewPacket([0x90,11,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,125,127,0x90,3,127,3,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueLegacyPioneerMEPSpeedTouchAndBendRestoreRealAudioSync() async throws {
    try await withControllerCuePlayback("Pioneer MEP-7000") {model,input in
        cuePreviewPacket([0x90,1,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,1,127,0x90,0,127,0,0,32,127,0xB0,16,127],to:input)
        _ = model.playback.core.renderOffline(frames:4096)
        cuePreviewPacket([0xB0,16,64,0x80,32,127,0x90,20,127,20,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueInstinctP8ModeCleanupRestoresRealAudioSync() async throws {
    try await withControllerCuePlayback("Hercules DJControl Instinct P8") {model,input in
        cuePreviewPacket([0x90,34,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,99,127,99,0,33,127,33,0,97,127,0xB0,105,3],to:input)
        _ = model.playback.core.renderOffline(frames:4096)
        cuePreviewPacket([0x90,48,127,48,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueUniversalDJShiftContactCleanupRestoresRealAudioSync() async throws {
    try await withControllerCuePlayback("Hercules Universal DJ") {model,input in
        cuePreviewPacket([0x90,66,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,68,127,68,0,65,127,65,0,82,127,0xB0,50,3],to:input)
        _ = model.playback.core.renderOffline(frames:4096)
        cuePreviewPacket([0x90,68,127,68,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueWaveUSBModeContactCleanupRestoresRealAudioSync() async throws {
    try await withControllerCuePlayback("Hercules DJControlWave") {model,input in
        cuePreviewPacket([0x90,15,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,16,127,16,0,13,127,13,0,18,127,0xB0,18,3],to:input)
        _ = model.playback.core.renderOffline(frames:4096)
        cuePreviewPacket([0x90,34,127,34,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueTwitchBasicStripAndBankCleanupRestoreRealAudioSync() async throws {
    try await withControllerCuePlayback("Twitch") { model,input in
        cuePreviewPacket([0x97,22,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x87,22,127,0x97,23,127,23,0,71,1,0xB7,53,3],to:input)
        _ = model.playback.core.renderOffline(frames:4096)
        cuePreviewPacket([0x97,0,127,0,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Akiyama Quattro","Akiyama Quark SC","Akiyama TTWO"])
@MainActor func controllerCatalogueAkiyamaChartShiftCleanupRestoresRealAudioSync(_ name: String) async throws {
    try await withControllerCuePlayback(name,manual:true) { model,input in
        let quark = name == "Akiyama Quark SC"
        let cue: UInt8 = name == "Akiyama Quattro" ? 50 : quark ? 53 : 46
        let play: UInt8 = name == "Akiyama Quattro" ? 51 : quark ? 52 : 47
        let shift: UInt8 = name == "Akiyama Quattro" ? 114 : quark ? 63 : 36
        let status: UInt8 = quark ? 0x90 : 0x94
        cuePreviewPacket([0x90,cue,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([status,shift,127,shift,0,0x90,play,127,play,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Novation Launchpad X","Novation Launchpad Pro MK3","Novation Launchpad Pro"])
@MainActor func controllerCatalogueProgrammerGridHeldCueAndPlayRestoreRealAudioSync(_ name: String) async throws {
    let port = name.hasSuffix(" X") ? "LPX MIDI" : "LPProMK3 MIDI"
    try await withControllerCuePlayback(name,manual:name == "Novation Launchpad Pro",ports:[port]) { model,input in
        cuePreviewPacket([0x90,12,1],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        _ = model.playback.core.renderOffline(frames:1024)
        cuePreviewPacket([0x80,12,127,0x90,11,127,11,0],to:input)
        let audio = model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueAPCMiniMK2ShiftCleanupRestoresRealAudioSync() async throws {
    try await withControllerCuePlayback("APC mini mk2",ports:["APC mini MK 2 (Control)"]) { model,input in
        cuePreviewPacket([0x90,1,1],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,122,127,122,0,0,127,0,0],to:input)
        let audio=model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments:["Akai APC40 MKII","Akai APC40"])
@MainActor func controllerCatalogueAPC40ModeOneCueAndShiftRestoreRealAudioSync(_ name:String)async throws {
    try await withControllerCuePlayback(name) { model,input in
        let mk2=name=="Akai APC40 MKII"
        let channel:UInt8=mk2 ? 0:1;let cue:UInt8=mk2 ? 33:57
        cuePreviewPacket([0x90+channel,cue,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        let play:UInt8=mk2 ? 32:57
        cuePreviewPacket([0x9F,98,127,98,0,0x90,play,127,play,0],to:input)
        let audio=model.playback.core.renderOffline(frames:4096)
        model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments:["Novation Launch Control 3","Novation LaunchControl XL3"])
@MainActor func controllerCatalogueLaunchControlDAWModeExitRestoresRealAudioSync(_ name:String)async throws {
    let port=name.hasSuffix("XL3") ? "Launch Control XL 3 DAW":"Launch Control 3 DAW"
    try await withControllerCuePlayback(name,ports:[port]){model,input in
        input.receiveBytes([0xB0,38,127],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0xB6,30,6],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0xB6,30,2,0xB0,37,127,37,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueLaunchControlTemplateSceneChangeRestoresRealAudioSync()async throws{
    try await withControllerCuePlayback("Novation Launch Control",ports:["Launch Control"],prepareInput:{input in input.receiveBytes(launchControlTemplateFixture(),source:10)}){model,input in
        input.receiveBytes([0x93,61,127],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([240,0,32,41,2,10,119,8,247],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([240,0,32,41,2,10,119,0,247],source:10)
        input.receiveBytes(launchControlTemplateFixture(),source:10)
        input.receiveBytes([0x93,60,127,60,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueLaunchControlXLTemplateChangeRestoresRealAudioSync()async throws{
    try await withControllerCuePlayback("Novation Launch Control XL",ports:["Launch Control XL"],prepareInput:{input in input.receiveBytes(launchControlXLTemplateFixture(),source:10)}){model,input in
        input.receiveBytes([0x94,61,127],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([240,0,32,41,2,17,119,8,247],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([240,0,32,41,2,17,119,0,247],source:10)
        input.receiveBytes(launchControlXLTemplateFixture(),source:10)
        input.receiveBytes([0x94,60,127,60,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test(arguments:["Akiyama Pulsar","Akiyama Tempus"])
@MainActor func controllerCatalogueRemainingAkiyamaNormalCueAndShiftKeepRealAudioSync(_ name:String)async throws{
    try await withControllerCuePlayback(name,manual:true){model,input in
        cuePreviewPacket([0x90,23,127],to:input);#expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,45,127],to:input);#expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90,45,0,24,127,24,0],to:input)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueRemainingAkiyamaSyncronCommonMixerKeepsRealAudioSync()async throws{
    try await withControllerCuePlayback("Akiyama Syncron",manual:true){model,input in
        model.pressPlay(deck:.a,vinylStop:false)
        cuePreviewPacket([0xB0,16,64,17,64,18,64,19,64,20,64,0xB4,48,64],to:input)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueOriginalMixDeckCueSetAndLoopPadsKeepRealAudioSync()async throws{
    try await withControllerCuePlayback("Numark MixDeck",manual:true){model,input in
        cuePreviewPacket([0x90,56,127],to:input);#expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,56,127,0x90,58,127,58,0],to:input)
        _=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true)
        cuePreviewPacket([0x90,57,127,57,0],to:input)
        #expect(model.playbackSnapshot?.a.phase.active == true)
        cuePreviewPacket([0x90,51,127,51,0],to:input)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.loopEnabled == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueMC1000NativeTransportLoopAndTempoKeepRealAudioSync()async throws{
    try await withControllerCuePlayback("Zomo MC-1000"){model,input in
        input.receiveBytes([0x90,14,127,14,0,12,127,12,0],source:10);input.flushPendingActions()
        input.receiveBytes([0xB0,5,64,0x90,10,127,10,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.loopEnabled == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments:["American Audio VERSADECK","Synq DMC-2000","CITRONIC MPX10"]) @MainActor
func controllerCatalogueLegacyUSBTransportCueAndManualLoopsKeepRealAudioSync(_ name:String)async throws{
    try await withControllerCuePlayback(name){model,input in
        input.receiveBytes([0x90,31,127],source:10);input.flushPendingActions();#expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x80,94,127,0x90,32,127,32,0,2,127,2,0],source:10);input.flushPendingActions()
        _=model.playback.core.renderOffline(frames:32768);model.refreshPlayback()
        input.receiveBytes([0x90,3,127,3,0,34,127,0x80,97,127],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.loopEnabled == true)
        #expect(model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueDJMTour1PrimaryMixerKeepsRealAudioAndSavedSync()async throws{
    try await withControllerCuePlayback("Pioneer DJM-TOUR1",manual:true){model,input in
        model.pressPlay(deck:.a,vinylStop:false)
        cuePreviewPacket([0xB0,1,64,2,64,3,64,4,64,5,64,17,64,70,127,70,0,24,64,26,64,27,64,11,64],to:input)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments:["Akai Pro AMX","ION ICUE","Reloop DIGITAL JOCKEY"]) @MainActor
func controllerCatalogueRemainingPublicTransportKeepsRealAudioAndSavedSync(_ name:String)async throws{
    try await withControllerCuePlayback(name,manual:true){model,input in
        let cue:UInt8=name=="Akai Pro AMX" ? 8:name=="ION ICUE" ? 51:23
        let play:UInt8=name=="Akai Pro AMX" ? 10:name=="ION ICUE" ? 67:25
        cuePreviewPacket([0x90,cue,127],to:input);#expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,cue,127,0x90,play,127,play,0],to:input)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments:["Denon DJ HC1000S","Denon DJ HC4500"]) @MainActor
func controllerCatalogueLegacyHCManufacturerPressureKeepsRealAudioAndSavedSync(_ name:String)async throws{
    try await withControllerCuePlayback(name){model,input in
        if name=="Denon DJ HC1000S"{
            cuePreviewPacket([0x90,96,64,23,64],to:input);#expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x81,96,64,0x90,96,64,24,64,24,0,0x80,96,64,0x90,29,64,29,0],to:input)
        }else{
            cuePreviewPacket([0x90,66,64],to:input);#expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x80,66,64,0x90,67,64,67,0],to:input)
        }
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        if name=="Denon DJ HC1000S"{#expect(model.playbackSnapshot?.a.loopEnabled == true)}
    }
}

@Test(arguments:["Numark NVII","Denon DJ PRIME GO+","American Audio DP2"]) @MainActor
func controllerCatalogueRecoveredPublicTransportKeepsRealAudioAndSavedSync(_ name:String)async throws{
    try await withControllerCuePlayback(name,manual:name != "American Audio DP2"){model,input in
        let channel:UInt8=name=="Numark NVII" ? 1:name=="Denon DJ PRIME GO+" ? 2:0
        let cue:UInt8=name=="Numark NVII" ? 32:name=="Denon DJ PRIME GO+" ? 9:25
        let play:UInt8=name=="Numark NVII" ? 33:name=="Denon DJ PRIME GO+" ? 10:26
        cuePreviewPacket([0x90+channel,cue,127],to:input);#expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80+channel,cue,127,0x90+channel,play,127,play,0],to:input)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments:["Denon DJ SC2900","Denon DJ S3900","Denon DJ S3700","Denon DJ S1200"]) @MainActor
func controllerCatalogueDenonLegacyPlayerKeepsRealAudioSavedSyncAndModeRelease(_ name:String)async throws{
    try await withControllerCuePlayback(name){model,input in
        cuePreviewPacket([0x95,66,64],to:input);#expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x9F,name=="Denon DJ S1200" || name=="Denon DJ S3700" ? 49:82,64,0x95,67,64,67,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments:["Denon DJ X1600","Synq PCM-1"]) @MainActor
func controllerCatalogueLegacyLayerNativeTransportKeepsRealAudioAndSavedSync(_ name:String)async throws{
    try await withControllerCuePlayback(name,manual:true){model,input in
        let cue:UInt8=name=="Denon DJ X1600" ? 69:25;let play:UInt8=name=="Denon DJ X1600" ? 68:26
        cuePreviewPacket([0x90,cue,64],to:input);#expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,cue,64,0x90,play,64,play,0],to:input)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments:["Rane SIXTY TWO","Rane SIXTY FOUR","Rane TTM57 MKII"]) @MainActor
func controllerCatalogueLegacyRaneMixerAndLoopsKeepRealAudioAndSavedSync(_ name:String)async throws{
    try await withControllerCuePlayback(name,manual:true){model,input in
        model.pressPlay(deck:.a,vinylStop:false)
        if name=="Rane TTM57 MKII"{cuePreviewPacket([0x94,50,127,50,0,0xBE,32,4],to:input)}
        else{cuePreviewPacket([0x90,name=="Rane SIXTY TWO" ? 29:28,127,name=="Rane SIXTY TWO" ? 29:28,0,0xB0,name=="Rane SIXTY TWO" ? 116:117,2],to:input)}
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.loopEnabled == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueRMPPlayersShiftedCueAndBendReleasesKeepRealAudioSync() async throws {
    for (name,play,bend,bendRelease):(String,UInt8,UInt8,UInt8) in [("Reloop RMP-3",1,8,71),("Reloop RMP-2.5a",6,21,84)] {
        try await withControllerCuePlayback(name) { model,input in
            input.receiveBytes([0x9F,7,1],source:10);input.flushPendingActions()
            #expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x9F,66,127,66,0],source:10);input.flushPendingActions()
            #expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x8F,70,127,0x9F,play,127,play,0,bend,127],source:10);input.flushPendingActions()
            input.receiveBytes([0x8F,bendRelease,127],source:10);input.flushPendingActions()
            let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCataloguePMX10ManualLoopKeepsRealAudioSync() async throws {
    try await withControllerCuePlayback("Gemini PMX10", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0x90, 35, 127, 35, 0, 0xB0, 36, 65, 0xB4, 66, 65], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.loopEnabled == true)
    }
}

@Test @MainActor func controllerCataloguePMX20ManualLoopAndCommonMixerKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("Gemini PMX20", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0x90, 35, 127, 35, 0, 0xB0, 36, 65, 49, 64], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.loopEnabled == true)
    }
}

@Test @MainActor func controllerCatalogueKUTManualMIDILevelAndMasterKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("Reloop KUT", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.currentTargetValue = { model.controllerValue($0.action, targetDeck: $0.deck) }
        for number: UInt8 in [5, 16] {
            for value: UInt8 in [0, 127, 64] {
                input.receiveBytes([0xBF, number, value], source: 10); input.flushPendingActions()
            }
        }
        input.receiveBytes([0x9F, 7, 127, 7, 0], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(abs((model.controllerValue(.levelA) ?? -1) - 64.0 / 127) < 0.000001)
        #expect(abs((model.controllerValue(.master) ?? -1) - 64.0 / 127) < 0.000001)
    }
}

@Test @MainActor func controllerCatalogueSmartPADClipPlayAndInactiveModesKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("SmartPAD") { model, input in
        input.receiveBytes([0x90, 112, 127, 112, 0, 113, 127, 113, 0, 0x91, 20, 127, 20, 0, 0xB0, 0, 127], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueMixarsQuattroManualPlayLoopAndComposedShiftKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("Mixars QUATTRO", manual: true) { model, input in
        input.receiveBytes([0x90, 32, 127, 0x94, 27, 127, 27, 0], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.phase.active == false)
        input.receiveBytes([0x82, 32, 127, 0x94, 27, 127, 27, 0, 64, 127, 64, 0], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueVCI380ShiftReleasesSoftCueAndKeepsRealAudioSync() async throws {
    try await withControllerCuePlayback("VCI-380") { model, input in
        input.receiveBytes([0x97, 22, 1], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x97, 12, 127], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0x87, 22, 127, 0x97, 12, 0, 23, 127, 23, 0, 0xB7, 7, 64], source: 10)
        input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueAPC20ShiftReleasesSoftCueAndKeepsRealAudioSync() async throws {
    try await withControllerCuePlayback("APC20") { model, input in
        input.receiveBytes([0x91, 57, 1], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x90, 81, 127], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0x81, 57, 127, 0x80, 81, 127, 0x90, 57, 127, 57, 0, 0xB0, 7, 64], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueAPC64ModeLossReleasesSoftCueThenSessionRestoresRealAudioSync() async throws {
    try await withControllerCuePlayback("APC64", ports: ["APC64 DAW (APC64)"], prepareInput: { input in
        input.receiveBytes([0xF0, 0x7E, 0, 6, 2, 0x47, 0x53, 0, 0x19, 1, 1, 0, 14, 0, 0xF7], source: 10)
    }) { model, input in
        input.receiveBytes([0x96, 1, 1], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0xF0, 0x47, 0, 0x53, 0x19, 0, 1, 2, 0xF7], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0xF0, 0x47, 0, 0x53, 0x19, 0, 1, 0, 0xF7], source: 10)
        input.receiveBytes([0x86, 1, 127, 0x96, 0, 127, 0, 0, 0xE0, 0, 64], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueAPCMiniOriginalShiftImmediatelyReleasesSoftCueAndKeepsRealAudioSync() async throws {
    try await withControllerCuePlayback("APC MINI") { model, input in
        input.receiveBytes([0x90, 1, 1], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x90, 98, 127], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0x80, 1, 127, 98, 127, 0x90, 0, 127, 0, 0, 0xB0, 48, 64], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueMF3DSelectorImmediatelyReleasesSoftCueAndKeepsRealAudioSync() async throws {
    try await withControllerCuePlayback("Midi Fighter 3D", manual: true) { model, input in
        input.receiveBytes([0x92, 45, 1], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x93, 1, 1], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0x82, 45, 127, 0x92, 44, 127, 44, 0], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueLaunchpadSKeepsSoftCueRealAudioAndSavedSync() async throws {
    try await withControllerCuePlayback("Launchpad S") { model, input in
        input.receiveBytes([0x90, 113, 1], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x80, 113, 127, 0x90, 112, 127, 112, 0], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueLPD8MK2KeepsRealAudioAndSavedSync() async throws {
    try await withControllerCuePlayback("Akai LPD8 MK2", manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        input.receiveBytes([0xB0, 36, 64, 37, 64, 38, 64, 39, 64, 0xA0, 36, 127, 0xC0, 0], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Akai MPD226", "Akai MPD232"]) @MainActor
func controllerCatalogueMPD2BitwigKeepsSoftCueRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name, manual: true) { model, input in
        input.receiveBytes([0x99, 45, 1], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0xB1, 40, 127, 0xB2, 40, 127], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x99, 52, 127, 52, 0, 0x89, 45, 127, 0x99, 44, 1, 44, 0], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueMPD218KeepsSoftCueRealAudioAndSavedSync() async throws {
    try await withControllerCuePlayback("Akai MPD218") { model, input in
        input.receiveBytes([0x99, 45, 1], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x99, 52, 127, 52, 0, 0x89, 45, 127], source: 10); input.flushPendingActions()
        input.receiveBytes([0x99, 44, 1, 44, 0, 0xB0, 3, 64], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueOrbitKeepsRealAudioAndSavedSync() async throws {
    try await withControllerCuePlayback("Numark Orbit") { model, input in
        input.receiveBytes([0x90, 45, 127], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x91, 36, 127, 36, 0, 0x80, 45, 127], source: 10); input.flushPendingActions()
        input.receiveBytes([0x90, 44, 127, 44, 0], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["JB Systems DJ KONTROL2", "JB Systems DJ KONTROL3"]) @MainActor
func controllerCatalogueJBKontrolKeepsRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name, manual: true) { model, input in
        cuePreviewPacket([0x90, 67, 127, 67, 0], to: input)
        cuePreviewPacket([0xB0, 11, 64], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["BeyondMusic (BMI) ABMA1", "BeyondMusic (BMI) ABMA3"]) @MainActor
func controllerCatalogueBMICoreKeepsRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name, manual: true) { model, input in
        if name.hasSuffix("3") {
            cuePreviewPacket([0x90, 51, 127], to: input); #expect(model.playbackSnapshot?.a.touchActive == true)
            cuePreviewPacket([0x80, 51, 127], to: input)
        }
        cuePreviewPacket([0x90, 67, 127, 67, 0, 109, 127, 109, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Audiophony CDX6", "CITRONIC MPCD-X3", "Stanton CMP.800", "Synq DMC-1000"]) @MainActor
func controllerCatalogueLegacySinglePlayerKeepsRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name, manual: !name.hasPrefix("Synq")) { model, input in
        input.receiveBytes([0x90, 46, 127], source: 10); input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x90, 69, 127, 0x80, 69, 127], source: 10); input.flushPendingActions()
        input.receiveBytes([0x90, 2, 127, 2, 0], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Numark NDX800", "Numark NDX900"]) @MainActor
func controllerCatalogueNDXLegacyKeepsRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name) { model, input in
        cuePreviewPacket([0x9B, 56, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes(name == "Numark NDX800" ? [0x8B, 56, 127] : [0x9F, 69, 64], source: 10); input.flushPendingActions()
        input.receiveBytes([0x9B, 58, 127, 58, 0, 0xEB, 0, 64], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Allen & Heath XONE 1D", "Allen & Heath XONE 2D", "Allen & Heath XONE 4D"]) @MainActor
func controllerCatalogueLegacyXoneAxesKeepRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name, manual: true) { model, input in
        model.pressPlay(deck: .a, vinylStop: false)
        let number: UInt8 = name == "Allen & Heath XONE 2D" ? 40 : 32
        cuePreviewPacket([0xBF, number, 1], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Denon DJ HD2500", "Stanton SCS.4DJ", "Gemini FirstMix I/O"]) @MainActor
func controllerCatalogueLegacyStandaloneKeepsRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name, manual: name == "Denon DJ HD2500") { model, input in
        let cue: UInt8 = name == "Denon DJ HD2500" ? 66 : name == "Stanton SCS.4DJ" ? 38 : 6
        let play: UInt8 = name == "Denon DJ HD2500" ? 67 : name == "Stanton SCS.4DJ" ? 36 : 7
        let pressure: UInt8 = name == "Denon DJ HD2500" ? 64 : 127
        cuePreviewPacket([0x90, cue, pressure], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80, cue, pressure, 0x90, play, pressure, play, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Reloop Contour Controller Edition", "Reloop Contour Interface Edition"]) @MainActor
func controllerCatalogueContourKeepsRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name) { model, input in
        cuePreviewPacket([0x90, 38, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x91, 6, 127, 0x90, 39, 127, 39, 0], source: 10); input.flushPendingActions()
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["American Audio 10MXR", "American Audio 14MXR", "American Audio 19MXR"]) @MainActor
func controllerCatalogueMXRKeepsRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name, manual: name == "American Audio 10MXR") { model, input in
        let ch: UInt8 = name == "American Audio 10MXR" ? 0 : 2
        cuePreviewPacket([0x90 + ch, 12, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x81 + ch, 12, 127, 0x90 + ch, 13, 127, 13, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments: ["Numark 4TRAK", "M-Audio Xponent"]) @MainActor
func controllerCatalogueLegacyPCDJKeepsRealAudioAndSavedSync(_ name: String) async throws {
    try await withControllerCuePlayback(name, manual: true) { model, input in
        let ch: UInt8 = name == "Numark 4TRAK" ? 1 : 0
        let cue: UInt8 = ch == 1 ? 16 : 35
        let play: UInt8 = ch == 1 ? 17 : 36
        cuePreviewPacket([0x90 + ch, cue, 127], to: input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80 + ch, cue, 127, 0x90 + ch, play, 127, play, 0], to: input)
        let audio = model.playback.core.renderOffline(frames: 4096); model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test(arguments:["Behringer CMD PL-1","Behringer CMD DC-1","Behringer CMD LC-1","Behringer CMD DV-1"]) @MainActor
func controllerCatalogueCMDNativeControlsKeepRealAudioAndSavedSync(_ name:String)async throws{
    try await withControllerCuePlayback(name,manual:name=="Behringer CMD DV-1"){model,input in
        if name=="Behringer CMD PL-1"{
            cuePreviewPacket([0x90,34,64],to:input);#expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x91,26,1,0x90,35,127,35,0,31,64,0xB0,31,69,0x80,31,64],source:10);input.flushPendingActions()
        }else{
            model.pressPlay(deck:.a,vinylStop:false)
            let ch:UInt8=name=="Behringer CMD DC-1" ? 5:name=="Behringer CMD LC-1" ? 7:6
            let pad:UInt8=name=="Behringer CMD DC-1" ? 48:name=="Behringer CMD LC-1" ? 32:92
            cuePreviewPacket([0x90+ch,pad,127,pad,0],to:input)
        }
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueJockeyRemixShiftedCueAndBendKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("Reloop Jockey 3 Remix",manual:true) { model,input in
        input.receiveBytes([0x90,25,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x80,88,127,0x90,26,127,26,0,41,127],source:10);input.flushPendingActions()
        input.receiveBytes([0x90,104,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueDJ707MManualBridgeCueShiftKeepsRealAudioSync() async throws {
    try await withControllerCuePlayback("Roland DJ-707M",manual:true) { model,input in
        input.receiveBytes([0x90,1,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x9F,0,127,0x90,5,127,0x80,5,127,0x9F,0,0,0x90,0,127,0,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueQuarkShiftedCueBendReleasesKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("Akiyama QUARK") { model,input in
        input.receiveBytes([0x90,53,1,63,127,63,0],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x80,117,127,0x90,52,127,52,0,50,127],source:10);input.flushPendingActions()
        input.receiveBytes([0x90,114,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueEncoreTAPCueAndBendReleasesKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("Encore 2000",manual:true) { model,input in
        input.receiveBytes([0x90,19,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x90,4,127],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        input.receiveBytes([0x80,82,127,0x90,4,0,23,127,23,0,8,127],source:10);input.flushPendingActions()
        input.receiveBytes([0x90,71,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueDDCShiftedCueAndBendReleasesKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("DDC2000") { model,input in
        input.receiveBytes([0x90,23,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x90,45,127,0x80,73,127,0x90,45,0,24,127,24,0,19,127],source:10);input.flushPendingActions()
        input.receiveBytes([0x90,69,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueCMXShiftedCueAndBendReleasesKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("CMX-2000",manual:true) {model,input in
        input.receiveBytes([0x90,37,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x90,9,127,0x80,87,127,0x90,9,0,38,127,38,0,26,127],source:10);input.flushPendingActions()
        input.receiveBytes([0x90,76,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueRadiusLegacyVariantsKeepRealAudioSync() async throws {
    for (name,manual,offset,tap):(String,Bool,UInt8,UInt8) in [("American Audio RADIUS 1000 (2009 factory mapping)",true,63,32),("American Audio RADIUS 1000",true,61,46),("American Audio RADIUS 3000",false,63,32)] {
        try await withControllerCuePlayback(name,manual:manual) {model,input in
            input.receiveBytes([0x90,48,1],source:10);input.flushPendingActions()
            #expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x90,tap,127,0x80,48+offset,127,0x90,tap,0,42,127,42,0,7,127],source:10);input.flushPendingActions()
            input.receiveBytes([0x90,7+offset,0],source:10);input.flushPendingActions()
            let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCatalogueDV2ManualMixerAndPFLKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("DV2 USB",manual:true) {model,input in
        model.pressPlay(deck:.a,vinylStop:false)
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for number:UInt8 in [58,55] {
            for value:UInt8 in [0,127,64] {
                input.receiveBytes([0xBF,number,value],source:10);input.flushPendingActions()
            }
        }
        input.receiveBytes([0x9F,9,127,9,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
        #expect(abs((model.controllerValue(.levelA) ?? -1)-64.0/127)<0.000001)
        #expect(abs((model.controllerValue(.master) ?? -1)-64.0/127)<0.000001)
        #expect(model.controllerValue(.cueA)==1)
    }
}


@Test @MainActor func controllerCatalogueDJinnCommonAndMode3KeepRealAudioSync() async throws {
    for (name,manual):(String,Bool) in [("Audiophony DJINN",false),("Audiophony DJINN (MIDI mode 3)",true)] {
        try await withControllerCuePlayback(name,manual:manual) {model,input in
            input.receiveBytes([0x90,31,1],source:10);input.flushPendingActions()
            #expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x80,94,127,0x90,32,127,32,0,34,127,97,0],source:10);input.flushPendingActions()
            if manual {
                input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
                for (ch,n):(UInt8,UInt8) in [(0,16),(1,49)] {
                    for value:UInt8 in [0,127,64] {
                        input.receiveBytes([0xB0+ch,n,value],source:10);input.flushPendingActions()
                    }
                }
            }
            let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
            if manual {#expect(abs((model.controllerValue(.levelA) ?? -1)-64.0/127)<0.000001)}
        }
    }
}


@Test @MainActor func controllerCatalogueAudiophonyFactoryVariantsKeepRealAudioSync() async throws {
    for name in ["Audiophony DJAZZ","Audiophony DJAM","Audiophony DJAM (CTRL MIDI mixer)"] {
        try await withControllerCuePlayback(name,manual:name.contains("CTRL MIDI")) {model,input in
            input.receiveBytes([0x90,23,1],source:10);input.flushPendingActions()
            #expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x90,45,127,0x80,73,127,0x90,45,0,24,127,24,0,19,127],source:10);input.flushPendingActions()
            input.receiveBytes([0x90,69,0],source:10);input.flushPendingActions()
            if name != "Audiophony DJAM" {
                input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
                for value:UInt8 in [0,127,64] {
                    input.receiveBytes([0xB0,7,value],source:10);input.flushPendingActions()
                }
            }
            let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        }
    }
}


@Test @MainActor func controllerCatalogueVirtualityPlayManualCueBendsKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("Audiophony PLAY",manual:true) {model,input in
        input.receiveBytes([0x90,52,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x80,52,127,0x90,53,127,53,0,33,127],source:10);input.flushPendingActions()
        input.receiveBytes([0x90,33,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueXone43CManualFaderAndCueStateKeepAudioSynced() async throws {
    try await withControllerCuePlayback("Xone:43C",manual:true) {model,input in
        model.pressPlay(deck:.a,vinylStop:false)
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for value:UInt8 in [0,127,64] {
            input.receiveBytes([0xBF,0,value],source:10);input.flushPendingActions()
        }
        input.receiveBytes([0x9F,77,127,77,127],source:10);input.flushPendingActions()
        #expect(model.controllerValue(.cueA) == 1)
        input.receiveBytes([0x8F,77,0],source:10);input.flushPendingActions()
        #expect(model.controllerValue(.cueA) == 0)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        #expect(abs((model.controllerValue(.levelA) ?? -1)-64.0/127)<0.0001)
    }
}


@Test @MainActor func controllerCatalogueNS7IIIEQManualKnobsKeepRealAudioSynced() async throws {
    try await withControllerCuePlayback("NS7III",manual:true) {model,input in
        model.pressPlay(deck:.a,vinylStop:false)
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for number:UInt8 in [9,10,11] {
            for value:UInt8 in [0,127,64] {
                input.receiveBytes([0xB0,number,value],source:10);input.flushPendingActions()
            }
        }
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        for action in [ControllerAction.lowA,.midA,.highA] {#expect(abs((model.controllerValue(action) ?? -1)-64.0/127)<0.0001)}
    }
}


@Test @MainActor func controllerCatalogueOriginalIMixCueBendsAndMixerKeepRealAudioSync() async throws {
    try await withControllerCuePlayback("DJ-Tech I-MIX",manual:true) {model,input in
        input.receiveBytes([0x90,13,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x80,13,127,0x90,20,127,20,0,14,127],source:10);input.flushPendingActions()
        input.receiveBytes([0x90,14,0],source:10);input.flushPendingActions()
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for value:UInt8 in [0,127,64] {input.receiveBytes([0xB0,67,value],source:10);input.flushPendingActions()}
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        #expect(abs((model.controllerValue(.levelA) ?? -1)-64.0/127)<0.0001)
    }
}


@Test @MainActor func controllerCatalogueABMA4CoreVariantsKeepCueBendsAndMixerAudioSynced() async throws {
    for name in ["BeyondMusic (BMI) ABMA4","JB Systems DJ KONTROL1"] {
        try await withControllerCuePlayback(name,manual:true) {model,input in
            input.receiveBytes([0x9F,51,1],source:10);input.flushPendingActions()
            #expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x80,51,127,0x94,67,127,67,0,121,127],source:10);input.flushPendingActions()
            input.receiveBytes([0x92,121,0],source:10);input.flushPendingActions()
            input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
            for value:UInt8 in [0,127,64] {input.receiveBytes([0xB8,8,value],source:10);input.flushPendingActions()}
            let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
            #expect(abs((model.controllerValue(.levelA) ?? -1)-64.0/127)<0.0001)
        }
    }
}


@Test @MainActor func controllerCatalogueG4VMixerKnobsKeepRealAudioSynced() async throws {
    try await withControllerCuePlayback("G4V",manual:true) {model,input in
        model.pressPlay(deck:.a,vinylStop:false)
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for number:UInt8 in [1,9,5,13,17,21] {
            for value:UInt8 in [0,127,64] {input.receiveBytes([0xB3,number,value],source:10);input.flushPendingActions()}
        }
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        for action in [ControllerAction.gainA,.highA,.midA,.lowA,.filterKnobA,.levelA] {#expect(abs((model.controllerValue(action) ?? -1)-64.0/127)<0.0001)}
    }
}


@Test @MainActor func controllerCatalogueG4VMixerHeldCueReleaseKeepsRealAudioSync() async throws {
    try await withControllerCuePlayback("G4V",manual:true) {model,input in
        input.receiveBytes([0x90,2,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x80,2,127,0x90,1,127,1,0],source:10);input.flushPendingActions()
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueDJ808ManualCueAndPairedMixerKeepAudioSynced() async throws {
    try await withControllerCuePlayback("DJ-808",manual:true) {model,input in
        input.receiveBytes([0x90,1,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x82,5,127,0x90,0,127,0,0],source:10);input.flushPendingActions()
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for (msb,lsb):(UInt8,UInt8) in [(22,52),(23,53),(24,54),(25,55),(28,58)] {
            for value:UInt8 in [0,127,64] {input.receiveBytes([0xB0,msb,value,lsb,0],source:10);input.flushPendingActions()}
        }
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        #expect(abs((model.controllerValue(.levelA) ?? -1)-8192.0/16383)<0.0001)
    }
}


@Test @MainActor func controllerCatalogueDJTechLegacyFactoryCueAndMixerKeepAudioSynced() async throws {
    for (name,dragon) in [("DRAGON TWO",true),("4MIX",false)] {
        try await withControllerCuePlayback(name,manual:true) {model,input in
            let cue:UInt8=dragon ? 22:11,play:UInt8=dragon ? 23:12
            input.receiveBytes([0x91,cue,1],source:10);input.flushPendingActions()
            #expect(model.playbackSnapshot?.a.touchActive == true)
            input.receiveBytes([0x83,dragon ? cue:75,127,0x91,play,127,play,0],source:10);input.flushPendingActions()
            if dragon {
                input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
                for value:UInt8 in [0,127,64] {input.receiveBytes([0xB1,9,value],source:10);input.flushPendingActions()}
                #expect(abs((model.controllerValue(.levelA) ?? -1)-64.0/127)<0.0001)
            }
            let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        }
    }
}


@Test @MainActor func controllerCatalogueGMXManualCueAndMixerKeepRealAudioSynced() async throws {
    try await withControllerCuePlayback("GMX",manual:true) {model,input in
        input.receiveBytes([0x90,2,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x80,2,127,0x90,1,127,1,0],source:10);input.flushPendingActions()
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for n:UInt8 in [1,3,5,7,9] {
            for value:UInt8 in [0,127,64] {input.receiveBytes([0xB3,n,value],source:10);input.flushPendingActions()}
        }
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        #expect(abs((model.controllerValue(.levelA) ?? -1)-64.0/127)<0.0001)
    }
}


@Test @MainActor func controllerCatalogueCueStopReturnsWithoutRemarkingOrChangingSync() async throws {
    try await withControllerCuePlayback {model,_ in
        let action=try #require(ControllerAction(rawValue:"cueStopA"))
        let sampleRate=try #require(model.track(.a)?.analysis.sampleRate)
        model.cuePoints[.a]=0;model.jump(sampleRate,deck:.a,quantized:false);model.refreshPlayback()
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0)>0)
        model.applyController(action,value:0);model.refreshPlayback()
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0)>0)
        model.applyController(action,value:1);model.refreshPlayback()
        #expect(model.cuePoints[.a] == 0 && abs(model.playbackSnapshot?.a.sourceFrame ?? -1)<=1)
        #expect(model.playbackSnapshot?.a.phase.active == false && model.playbackSnapshot?.a.synced == true)
        model.pressPlay(deck:.a,vinylStop:false);_ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true)
        model.applyController(action,value:1);_ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(model.cuePoints[.a] == 0 && abs(model.playbackSnapshot?.a.sourceFrame ?? -1)<=1)
        #expect(model.playbackSnapshot?.a.phase.active == false && model.playbackSnapshot?.a.synced == true)
        model.applyController(.cuePreviewA,value:1);model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        model.applyController(action,value:1);model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == false && model.playbackSnapshot?.a.synced == true)
    }
}


@Test @MainActor func controllerCatalogueDAPD2CoreDistinctCueControlsAndMixerKeepSync() async throws {
    try await withControllerCuePlayback("DAP KONTROL D2",manual:true) {model,input in
        input.receiveBytes([0x9F,59,1],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.touchActive == true)
        input.receiveBytes([0x80,59,127,0x94,67,127,67,0],source:10);input.flushPendingActions()
        _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.phase.active == true)
        input.receiveBytes([0x98,51,127,51,0],source:10);input.flushPendingActions()
        #expect(model.playbackSnapshot?.a.phase.active == false && model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.synced == true)
        input.receiveBytes([0x90,67,127,67,0],source:10);input.flushPendingActions()
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for value:UInt8 in [0,127,64] {input.receiveBytes([0xB7,8,value],source:10);input.flushPendingActions()}
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        #expect(abs((model.controllerValue(.levelA) ?? -1)-64.0/127)<0.0001)
    }
}

@Test @MainActor func controllerCatalogueCDMP7000OwnCueAnd128CountScratchRestoreSync() async throws {
    try await withControllerCuePlayback("Gemini CDMP-7000",manual:true) {model,input in
        cuePreviewPacket([0x90,1,1],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,1,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        cuePreviewPacket([0x90,24,127,0xB0,32,65],to:input)
        try await Task.sleep(for:.milliseconds(80))
        _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        let sampleRate=try #require(model.track(.a)?.analysis.sampleRate)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-sampleRate*1.8/128)<=1)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x90,24,0,2,127,2,0,4,127,4,0],to:input)
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for value:UInt8 in [0,127,64] {cuePreviewPacket([0xB0,33,value],to:input)}
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueRane72OwnerParameterPlayKeepsFiniteSyncedAudio() async throws {
    try await withControllerCuePlayback("Rane SEVENTY-TWO",manual:true) {model,input in
        cuePreviewPacket([0x94,40,127,40,0],to:input)
        let first=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        let start=try #require(model.playbackSnapshot?.a.sourceFrame)
        #expect(first.left.allSatisfy(\.isFinite) && first.right.allSatisfy(\.isFinite))
        cuePreviewPacket([0xBF,0,1,0,127],to:input)
        let second=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(second.left.allSatisfy(\.isFinite) && second.right.allSatisfy(\.isFinite))
        #expect((model.playbackSnapshot?.a.sourceFrame ?? 0)>start)
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueClearHotcueDeletesOnlyOnPressWithoutChangingTransport() async throws {
    try await withControllerCuePlayback {model,_ in
        let track=try #require(model.track(.a))
        model.performance.cues[track.id]=[:]
        for slot in 0..<8 {model.cue(slot:slot,deck:.a,quantized:false)}
        model.pressPlay(deck:.a,vinylStop:false)
        _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        try #require(model.playbackSnapshot?.a.phase.active == true)
        for slot in 0..<8 {
            let action=try #require(ControllerAction(rawValue:"clearHotcue\(slot+1)A"))
            let frame=try #require(model.playbackSnapshot?.a.sourceFrame)
            model.applyController(action,value:0)
            #expect(model.performance.cues[track.id]?[slot] != nil)
            model.applyController(action,value:1)
            #expect(model.performance.cues[track.id]?[slot] == nil)
            model.applyController(action,value:1)
            #expect(model.performance.cues[track.id]?[slot] == nil)
            for other in (slot+1)..<8 {#expect(model.performance.cues[track.id]?[other] != nil)}
            model.refreshPlayback()
            #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-frame)<=1)
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        }
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueMDJ900CueClearsAndTempoPreserveFiniteSyncedPlayback() async throws {
    try await withControllerCuePlayback("Gemini MDJ-900",manual:true) {model,input in
        let track=try #require(model.track(.a))
        cuePreviewPacket([0x90,1,1],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,1,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        model.performance.cues[track.id]=[:]
        for n:UInt8 in 38...41 {cuePreviewPacket([0x90,n,127,n,0],to:input)}
        try #require(model.playbackSnapshot?.a.phase.active == false)
        #expect((0..<4).allSatisfy{model.performance.cues[track.id]?[$0] != nil})
        cuePreviewPacket([0x90,42,127,42,0,2,127,2,0],to:input)
        #expect(model.performance.cues[track.id]?[0]==nil && model.performance.cues[track.id]?[1] != nil)
        _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        try #require(model.playbackSnapshot?.a.phase.active == true)
        cuePreviewPacket([0x90,43,127,43,0,18,127,18,0],to:input)
        #expect(model.performance.cues[track.id]?[1]==nil && model.performance.cues[track.id]?[2] != nil)
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for value:UInt8 in [0,127,64] {cuePreviewPacket([0xB0,1,value],to:input)}
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}

@Test @MainActor func controllerCatalogueReviewedClearProfilesDeleteOnlyTheirMarkerDuringPlayback() async throws {
    for name in ["Hercules DJControl Compact","Novation Dicer","MixVibes U-Mix Control Pro 2"] {
        try await withControllerCuePlayback(name,manual:true) {model,input in
            let track=try #require(model.track(.a))
            model.performance.cues[track.id]=[0:.init(frame:0),1:.init(frame:100)]
            model.pressPlay(deck:.a,vinylStop:false)
            _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            try #require(model.playbackSnapshot?.a.phase.active == true)
            let p=try #require(ControllerFactoryProfile.matching([name]))
            let b=try #require(p.bindings(source:10).first{$0.action == .clearHotcue1A && $0.targetDeck == .a})
            let before=try #require(model.playbackSnapshot?.a.sourceFrame)
            cuePreviewPacket([0x80+b.channel,b.number,127],to:input)
            #expect(model.performance.cues[track.id]?[0] != nil)
            cuePreviewPacket([0x90+b.channel,b.number,127,b.number,0],to:input)
            #expect(model.performance.cues[track.id]?[0]==nil && model.performance.cues[track.id]?[1] != nil)
            model.refreshPlayback();#expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-before)<=1)
            let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        }
    }
}

@Test @MainActor func controllerCatalogueReviewedPairProfilesDeleteOnlyTheirMarkerDuringPlayback() async throws {
    for name in ["Pioneer DDJ-SB3","Reloop Terminal Mix 2/4","Hercules DJControl Jogvision","Reloop NEON","DDJ-FLX10","DDJ-1000"] {
        try await withControllerCuePlayback(name,manual:true) {model,input in
            let track=try #require(model.track(.a))
            model.performance.cues[track.id]=[0:.init(frame:0),1:.init(frame:100)]
            model.pressPlay(deck:.a,vinylStop:false)
            _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            try #require(model.playbackSnapshot?.a.phase.active == true)
            let p=try #require(ControllerFactoryProfile.matching([name]))
            let b=try #require(p.bindings(source:10).first{$0.action == .clearHotcue1A && $0.targetDeck == .a})
            let before=try #require(model.playbackSnapshot?.a.sourceFrame)
            cuePreviewPacket([0x80+b.channel,b.number,127],to:input)
            #expect(model.performance.cues[track.id]?[0] != nil)
            cuePreviewPacket([0x90+b.channel,b.number,127,b.number,0],to:input)
            #expect(model.performance.cues[track.id]?[0]==nil && model.performance.cues[track.id]?[1] != nil)
            model.refreshPlayback();#expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-before)<=1)
            let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        }
    }
}


@Test @MainActor func controllerCatalogueMC4000FactoryPadsCueAndBendsKeepAudioSynced() async throws {
    try await withControllerCuePlayback("MC4000") { model,input in
        cuePreviewPacket([0x90,1,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,5,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == false)
        let track=try #require(model.track(.a))
        model.performance.cues[track.id]=[0:.init(frame:0),1:.init(frame:100)]
        model.pressPlay(deck:.a,vinylStop:false)
        _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        try #require(model.playbackSnapshot?.a.phase.active == true)
        let before=try #require(model.playbackSnapshot?.a.sourceFrame)
        cuePreviewPacket([0x94,28,127,28,0],to:input)
        model.refreshPlayback()
        #expect(model.performance.cues[track.id]?[0] == nil && model.performance.cues[track.id]?[1] != nil)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-before)<=1)
        for (note,alternate,action):(UInt8,UInt8,ControllerAction) in [(12,32,.pitchBendDownA),(11,33,.pitchBendUpA)] {
            cuePreviewPacket([0x90,note,127],to:input)
            #expect(model.controllerValue(action)==1)
            cuePreviewPacket([0x80,alternate,127],to:input)
            #expect(model.controllerValue(action)==0)
        }
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueMDJ1000OwnCoreKeepsRealAudioAndSavedSync() async throws {
    try await withControllerCuePlayback("MDJ-1000",manual:true) { model,input in
        cuePreviewPacket([0x90,1,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        cuePreviewPacket([0x80,1,127],to:input)
        #expect(model.playbackSnapshot?.a.touchActive == false && model.playbackSnapshot?.a.phase.active == false)
        let track=try #require(model.track(.a))
        model.performance.cues[track.id]=[0:.init(frame:0),1:.init(frame:100)]
        cuePreviewPacket([0x90,2,127,2,0],to:input)
        _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        try #require(model.playbackSnapshot?.a.phase.active == true)
        let before=try #require(model.playbackSnapshot?.a.sourceFrame)
        cuePreviewPacket([0x90,42,127,42,0],to:input)
        model.refreshPlayback()
        #expect(model.performance.cues[track.id]?[0] == nil && model.performance.cues[track.id]?[1] != nil)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-before)<=1)
        for (note,alternate,action):(UInt8,UInt8,ControllerAction) in [(18,24,.pitchBendDownA),(17,21,.pitchBendUpA)] {
            cuePreviewPacket([0x90,note,127],to:input);#expect(model.controllerValue(action)==1)
            cuePreviewPacket([0x80,alternate,127],to:input);#expect(model.controllerValue(action)==0)
        }
        input.currentTargetValue={model.controllerValue($0.action,targetDeck:$0.deck)}
        for value:UInt8 in [0,127,64] {cuePreviewPacket([0xB0,4,value],to:input)}
        #expect(abs((model.controllerValue(.filterKnobA) ?? -1)-64.0/127)<0.0001)
        cuePreviewPacket([0x90,34,127,34,0],to:input)
        #expect(model.performance.loopBeats(for:.a)==2 && model.playbackSnapshot?.a.loopEnabled == true)
        cuePreviewPacket([0x90,30,127,30,0],to:input)
        #expect(model.performance.loopBeats(for:.a)==0.125 && model.playbackSnapshot?.a.loopEnabled == true)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerCatalogueStudio4aHeldDeletePreservesRealPlaybackAndSavedSync() async throws {
    try await withControllerCuePlayback("Behringer CMD STUDIO 4a") { model,input in
        let track=try #require(model.track(.a))
        model.performance.cues[track.id]=[0:.init(frame:0),1:.init(frame:100)]
        model.pressPlay(deck:.a,vinylStop:false)
        _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        try #require(model.playbackSnapshot?.a.phase.active == true)
        let before=try #require(model.playbackSnapshot?.a.sourceFrame)
        cuePreviewPacket([0x90,42,127,34,127,0x80,42,127,34,127],to:input)
        model.refreshPlayback()
        #expect(model.performance.cues[track.id]?[0] == nil && model.performance.cues[track.id]?[1] != nil)
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-before)<=1)
        let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
        #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
        #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
    }
}


@Test @MainActor func controllerBuiltinPioneerClearsDeleteWithoutMovingRealPlaybackOrSavedSync() async throws {
    for name in ["DDJ-FLX4","DDJ-400","DDJ-FLX2","DDJ-REV1","DDJ-REV5"] {
        try await withControllerCuePlayback(name) { model,input in
            let track=try #require(model.track(.a))
            model.performance.cues[track.id]=[0:.init(frame:0),1:.init(frame:100)]
            model.pressPlay(deck:.a,vinylStop:false)
            _ = model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            try #require(model.playbackSnapshot?.a.phase.active == true)
            let before=try #require(model.playbackSnapshot?.a.sourceFrame)
            cuePreviewPacket([0x88,0,127],to:input)
            #expect(model.performance.cues[track.id]?[0] != nil)
            cuePreviewPacket([0x90,63,127,0x98,0,127,0x80,63,127,0x87,0,127],to:input)
            model.refreshPlayback()
            #expect(model.performance.cues[track.id]?[0] == nil && model.performance.cues[track.id]?[1] != nil)
            #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -1)-before)<=1)
            let audio=model.playback.core.renderOffline(frames:4096);model.refreshPlayback()
            #expect(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
            #expect(model.playbackSnapshot?.a.phase.active == true && model.playbackSnapshot?.a.synced == true && model.playbackSnapshot?.a.touchActive == false)
        }
    }
}
