import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withControllerCuePlayback(
    _ name: String = "DJ2GO2 Touch", manual: Bool = false, ports: [String] = [],
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
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
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
    try await withControllerCuePlayback("Denon DJ MCX8000", manual: true) { model, input in
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

@Test @MainActor func controllerCatalogueSlateFourNativeManualCuePreservesSavedSync() async throws {
    try await withControllerCuePlayback("SLATE4-4 decks", manual: true) { model, input in
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
