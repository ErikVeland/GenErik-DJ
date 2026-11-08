import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func z1ControlsSelectedEffectXWithoutReplacingTouchYOrOtherSlots() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    var effect = EffectControl()
    effect.kind = 4
    effect.x = 0.2
    effect.y = 0.85
    model.setEffect(effect, slot: 2, deck: .a)
    model.selectedEffectSlots[.a] = 2
    func report(_ buttons: UInt8, _ x: UInt16 = 2047) throws -> Z1InputReport {
        var bytes = [UInt8](repeating: 0, count: 30)
        bytes[0] = 1
        for offset in stride(from: 1, to: 29, by: 2) {
            bytes[offset] = 0xff
            bytes[offset + 1] = 7
        }
        bytes[9] = UInt8(x & 255)
        bytes[10] = UInt8(x >> 8)
        bytes[29] = buttons
        return try Z1InputReport(bytes: bytes)
    }
    model.receiveZ1(try report(0))
    model.receiveZ1(try report(6))
    model.receiveZ1(try report(0, 4095))
    #expect(model.effects[.a]?[2]?.x == 1)
    #expect(model.effects[.a]?[2]?.y == 0.85)
    #expect(model.effects[.a]?[2]?.enabled == false)
    model.receiveZ1(try report(4, 4095))
    #expect(model.effects[.a]?[2]?.enabled == true)
    #expect(model.effects[.a]?[0] == nil && model.effects[.b] == nil)
    await model.flushPerformanceWrites()
    let restarted = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(restarted.effects[.a]?[2]?.x == 1)
    #expect(restarted.effects[.a]?[2]?.y == 0.85)
}

@Test @MainActor func verticalTouchPreservesHardwareXForFilterAndFX() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    var axes = TouchAxisSession()
    let began = SurfaceEvent(phase: .began, points: [.init(id: 1, x: 0.2, y: 0.3)], ending: [])
    let moved = SurfaceEvent(phase: .moved, points: [.init(id: 1, x: 0.2, y: 0.6)], ending: [])
    let beganChangesX = axes.updatesX(began)
    model.effectTouch(began, slot: 1, deck: .a, updateX: beganChangesX)
    model.setHardwareEffectX(0.9, deck: .a)
    let movedChangesX = axes.updatesX(moved)
    #expect(!movedChangesX)
    model.effectTouch(moved, slot: 1, deck: .a, updateX: movedChangesX)
    #expect(model.effects[.a]?[1]?.x == 0.9)
    #expect(model.effects[.a]?[1]?.y == 0.4)
    model.filterTouch(x: 0.2, y: 0.3, deck: .b)
    model.setMixer(.filterX, value: 0.8, deck: .b)
    model.filterTouch(x: 0.2, y: 0.6, deck: .b, updateX: movedChangesX)
    #expect(model.playbackSnapshot?.b.mixer.filterX == 0.8)
    #expect(model.playbackSnapshot?.b.mixer.filterY == 0.4)
}

@Test @MainActor func z1FeedbackUsesThePlayingAudioLengthWithoutLibraryMetadata() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true, sampleRate: 8000))
    let core = model.playback.core
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 60 * 8000 * 2), sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let generation = try core.load(asset, deck: .a, grid: grid, sourceFrame: 50 * 8000, synced: false)
    try core.setMixer(.filterEnabled, value: 1, deck: .a)
    try core.setMixer(.filterX, value: 0.7, deck: .a)
    try core.play(deck: .a, generation: generation)
    core.processControlsWhileIdle()
    let playing = try #require(core.snapshot())
    #expect(model.track(.a) == nil)
    let report = model.z1Feedback(playing)
    #expect(report[17] == 127 && report[18] == 24)
    #expect(core.snapshot() == playing)
    #expect(playing.a.mixer.filterEnabled && playing.a.mixer.filterX == 0.7)
    try core.play(deck: .a, generation: generation)
    core.processControlsWhileIdle()
    let paused = model.z1Feedback(try #require(core.snapshot()))
    #expect(paused[17] == 0 && paused[18] == 127)
    await model.finishForShutdown()
}
