import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withControllerCuePlayback(
    _ name: String = "DJ2GO2 Touch", _ body: (ReplicaModel, ControllerMIDIConnection) async throws -> Void
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
            identity: .init(id: 10, device: 1, names: [name]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: name,
            identity: .init(id: 20, device: 1, names: [name]))
    ]
    input.onTargetAction = model.controllerInput.onTargetAction
    input.onJogAction = model.controllerInput.onJogAction
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
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
