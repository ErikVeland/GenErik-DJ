import Foundation
import SwiftUI
import TDJCore

private struct SnapshotBandWaveforms: EnvironmentKey {
    static let defaultValue: [String: BandWaveform] = [:]
}
extension EnvironmentValues {
    /// ImageRenderer does not run view tasks; snapshots supply band waveforms directly.
    var snapshotBandWaveforms: [String: BandWaveform] {
        get { self[SnapshotBandWaveforms.self] }
        set { self[SnapshotBandWaveforms.self] = newValue }
    }
}

/// Builds detailed band waveforms from the playback cache in the background. Keeps the last four.
actor BandWaveforms {
    static let shared = BandWaveforms()
    private var cache: [String: BandWaveform] = [:]
    private var order: [String] = []
    private var pending: [String: Task<BandWaveform?, Never>] = [:]

    static func cacheURL(track: Track, store: WorkspaceStore) -> URL {
        store.root.appendingPathComponent("PlaybackCache", isDirectory: true).appendingPathComponent(track.id + "-stereo-f32-v1.pcm")
    }

    /// Waits up to `patience` seconds for the playback cache a deck load writes, then builds.
    func load(track: Track, store: WorkspaceStore, patience: Double = 30) async -> BandWaveform? {
        if let cached = cache[track.id] { return cached }
        if let task = pending[track.id] { return await task.value }
        let url = Self.cacheURL(track: track, store: store), rate = track.analysis.sampleRate
        let expected = Int64(track.analysis.frameCount) * 8
        let task = Task.detached(priority: .utility) { () -> BandWaveform? in
            if track.nativeLibraryOnly != true,
               (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ Int64($0) }) != expected {
                _ = try? await PCMCache.prepareAsync(track: track, store: store)
            }
            let deadline = Date().addingTimeInterval(patience)
            while (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ Int64($0) }) != expected {
                guard Date() < deadline, !Task.isCancelled else { return nil }
                try? await Task.sleep(for: .milliseconds(250))
            }
            return try? BandWaveform.load(pcm: url, sampleRate: rate) { try Task.checkCancellation() }
        }
        pending[track.id] = task
        let result = await task.value
        pending[track.id] = nil
        if let result {
            cache[track.id] = result; order.append(track.id)
            if order.count > 4 { cache[order.removeFirst()] = nil }
        }
        return result
    }
}
