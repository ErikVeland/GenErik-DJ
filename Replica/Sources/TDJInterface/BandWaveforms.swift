import Foundation
import SwiftUI
import TDJCore

private struct SnapshotBandWaveforms: EnvironmentKey { static let defaultValue: [String: BandWaveform] = [:] }
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
    private struct Pending {
        let token: UUID
        let task: Task<BandWaveform?, Never>
        var readers: Set<UUID>
    }
    private var pending: [String: Pending] = [:]

    static func cacheURL(track: Track, store: WorkspaceStore) -> URL {
        store.root.appendingPathComponent("PlaybackCache", isDirectory: true).appendingPathComponent(
            track.id + "-stereo-f32-v1.pcm")
    }

    /// Waits up to `patience` idle seconds for the playback cache, then builds.
    func load(track: Track, store: WorkspaceStore, core: SampleTransport, patience: Double = 30) async -> BandWaveform? {
        if let cached = cache[track.id] { return cached }
        let reader = UUID()
        if var work = pending[track.id] {
            work.readers.insert(reader)
            pending[track.id] = work
            return await result(work, trackID: track.id, reader: reader)
        }
        let url = Self.cacheURL(track: track, store: store)
        let rate = track.analysis.sampleRate
        let expected = Int64(track.analysis.frameCount) * 8
        let task = Task.detached(priority: .background) { () -> BandWaveform? in
            var waited = 0.0
            while !Task.isCancelled {
                do {
                    try await WaveformWork.waitUntilIdle(core)
                    if track.nativeLibraryOnly != true,
                        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ Int64($0) }) != expected
                    {
                        _ = try await PCMCache.prepareAsync(
                            track: track, store: store, checkWorkAllowed: { try WaveformWork.check(core) })
                    }
                    while (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ Int64($0) }) != expected {
                        try await WaveformWork.waitUntilIdle(core)
                        guard waited < patience else { return nil }
                        try await Task.sleep(for: .milliseconds(250))
                        if !WaveformWork.isPaused(core) { waited += 0.25 }
                    }
                    try await WaveformWork.waitUntilIdle(core)
                    return try BandWaveform.load(pcm: url, sampleRate: rate) { try WaveformWork.check(core) }
                } catch is WaveformWorkPaused {
                    continue
                } catch { return nil }
            }
            return nil
        }
        let work = Pending(token: UUID(), task: task, readers: [reader])
        pending[track.id] = work
        return await result(work, trackID: track.id, reader: reader)
    }
    private func result(_ work: Pending, trackID: String, reader: UUID) async -> BandWaveform? {
        await withTaskCancellationHandler {
            let result = await work.task.value
            if pending[trackID]?.token == work.token {
                pending[trackID] = nil
                if let result {
                    cache[trackID] = result
                    order.append(trackID)
                    if order.count > 4 { cache[order.removeFirst()] = nil }
                }
            }
            return Task.isCancelled ? nil : result
        } onCancel: {
            Task { await self.cancel(trackID: trackID, token: work.token, reader: reader) }
        }
    }
    private func cancel(trackID: String, token: UUID, reader: UUID) {
        guard var work = pending[trackID], work.token == token else { return }
        work.readers.remove(reader)
        if work.readers.isEmpty {
            work.task.cancel()
            pending[trackID] = nil
        } else {
            pending[trackID] = work
        }
    }
}
