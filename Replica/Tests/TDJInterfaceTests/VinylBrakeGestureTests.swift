import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func vinylBrakeGestureStartsImmediatelyAndCancellationCommits() {
    let gesture = VinylBrakeGestureSession()
    var starts = 0
    var strengths: [Double] = []
    func send(_ phase: SurfaceEvent.Phase, _ y: Double) {
        gesture.handle(
            .init(phase: phase, points: [.init(id: 7, x: 0.5, y: y)], ending: phase == .ended ? [7] : []), height: 50,
            begin: { starts += 1 }, shape: { strengths.append($0) })
    }
    send(.began, 0.5)
    #expect(starts == 1)
    send(.moved, 1.5)
    #expect(strengths.last == 2)
    send(.moved, -0.5)
    #expect(strengths.last == 0.5)
    send(.cancelled, -0.5)
    let count = strengths.count
    send(.moved, 0.5)
    #expect(starts == 1 && strengths.count == count)
    send(.began, 0.5)
    send(.ended, 0.5)
    #expect(starts == 2)
}

@Test func vinylBrakeSettingsAreOptionalAndDurationIsBounded() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    #expect(!defaults.bool(forKey: DeckToolSettings.vinylStop))
    #expect(VinylBrakeSettings.duration(in: defaults) == 1)
    defaults.set(100, forKey: DeckToolSettings.vinylStopDuration)
    #expect(VinylBrakeSettings.duration(in: defaults) == 5)
    defaults.set(-3, forKey: DeckToolSettings.vinylStopDuration)
    #expect(VinylBrakeSettings.duration(in: defaults) == 0.2)
}

@Test @MainActor func vinylBrakeModelPreservesNormalPauseAndExplicitResume() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    _ = model.playback.core.renderOffline(frames: 4000)
    model.refreshPlayback()
    model.beginBrake(deck: .a, duration: 1)
    #expect(model.playbackSnapshot?.a.braking == true)
    _ = model.playback.core.renderOffline(frames: 12000)
    model.refreshPlayback()
    let at = try #require(model.playbackSnapshot?.a.sourceFrame)
    model.resumeBrake(deck: .a)
    #expect(model.playbackSnapshot?.a.braking == false)
    #expect(model.playbackSnapshot?.a.phase == .playing)
    #expect(model.playbackSnapshot?.a.synced == true)
    #expect(abs(try #require(model.playbackSnapshot?.syncPhaseError(.a))) < 0.000001)
    #expect(abs(try #require(model.playbackSnapshot?.a.sourceFrame) - at) <= 11025)
    model.beginBrake(deck: .a, duration: 1)
    model.pressPlay(deck: .a)
    #expect(model.playbackSnapshot?.a.phase == .paused)
    #expect(model.playbackSnapshot?.a.braking == false)
    await model.finishForShutdown()
}

#if os(macOS)
    import SwiftUI
    import AppKit

    @Test @MainActor func vinylBrakeLayoutsRenderInFullAndCompactDecks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "brake-preview-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: DeckToolSettings.vinylStop)
        var base = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { base.deleteLastPathComponent() }
        let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
        await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
        let track = try #require(model.library.tracks.first)
        model.load(trackID: track.id, deck: .a)
        await model.flushWrites()
        model.pressPlay(deck: .a)
        _ = model.playback.core.renderOffline(frames: 4000)
        model.refreshPlayback()
        model.beginBrake(deck: .a, duration: 1)
        for compact in [false, true] {
            model.browserVisible = compact
            let content = try await ReplicaView(model: model).preparedForSnapshot()
            model.refreshPlayback()
            if model.playbackSnapshot?.a.phase != .playing { model.pressPlay(deck: .a) }
            model.beginBrake(deck: .a, duration: 1)
            #expect(model.playbackSnapshot?.a.braking == true)
            let renderer = ImageRenderer(content: content.defaultAppStorage(defaults).frame(width: 1024, height: 768))
            renderer.scale = 1
            let image = try #require(renderer.nsImage)
            #expect(image.size == NSSize(width: 1024, height: 768))
            if let directory = ProcessInfo.processInfo.environment["TDJ_BRAKE_PREVIEW_DIR"],
                let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                let png = bitmap.representation(using: .png, properties: [:])
            {
                try png.write(
                    to: URL(fileURLWithPath: directory).appendingPathComponent(
                        compact ? "brake-compact.png" : "brake-full.png"))
            }
        }
        await model.finishForShutdown()
    }
#endif
