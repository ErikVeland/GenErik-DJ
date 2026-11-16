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
