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
