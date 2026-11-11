import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@Test @MainActor func bassAssistanceSettingAppliesAndRestoresSavedMode() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(model.bassAssistanceMode == .off)
    model.bassAssistanceMode = .handover
    await model.flushPreferenceWrites()
    let saved = try MixerPreferences.load(from: root.appendingPathComponent("mixer-preferences.json"))
    #expect(saved.bassAssistance == .handover)
    await model.finishForShutdown()
    let restored = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    #expect(restored.bassAssistanceMode == .handover)
    let signal = (0..<24000).flatMap { frame -> [Float] in
        let value = Float(0.3 * sin(2 * .pi * 50 * Double(frame) / 48000))
        return [value, -value]
    }
    let core = restored.playback.core
    for deck in [DeckID.a, .b] {
        let asset = try PCMAsset(interleavedStereo: deck == .a ? signal : signal.map { -$0 }, sampleRate: 48000)
        let generation = try core.load(asset, deck: deck, grid: nil, synced: false)
        try core.play(deck: deck, generation: generation)
    }
    _ = core.renderOffline(frames: 16000)
    restored.refreshPlayback()
    #expect(restored.bassAssistanceMeter.available)
    #expect(restored.bassAssistanceMeter.reductionBDB > 11.9)
    restored.bassAssistanceMode = .off
    restored.refreshPlayback()
    #expect(restored.bassAssistanceMeter == BassAssistanceMeter())
    await restored.finishForShutdown()
}
