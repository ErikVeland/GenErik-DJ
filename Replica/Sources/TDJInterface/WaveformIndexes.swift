import Foundation
import SwiftUI
import TDJCore

private struct SnapshotWaveformIndexes: EnvironmentKey {
    static let defaultValue: [WaveformIndexKey: WaveformRangeIndex] = [:]
}
extension EnvironmentValues {
    var snapshotWaveformIndexes: [WaveformIndexKey: WaveformRangeIndex] {
        get { self[SnapshotWaveformIndexes.self] }
        set { self[SnapshotWaveformIndexes.self] = newValue }
    }
}

struct WaveformIndexKey: Hashable, Sendable {
    let content: String
    let implementation: String
    let configuration: String
    let binFrames: Int
    let count: Int
    init(_ analysis: AudioAnalysis) {
        content = analysis.contentSHA256
        implementation = analysis.implementation
        configuration = analysis.configurationID
        binFrames = analysis.waveformFramesPerBin
        count = analysis.waveform.count
    }
}

actor WaveformIndexes {
    static let shared = WaveformIndexes()
    private static let worker = DispatchQueue(label: "dj.waveform-index", qos: .background)
    private var cache: [WaveformIndexKey: WaveformRangeIndex] = [:]
    private var order: [WaveformIndexKey] = []
    private var pending: [WaveformIndexKey: Task<WaveformRangeIndex, Never>] = [:]
    private var bytes = 0
    private let budget = 16 * 1024 * 1024
    func load(_ analysis: AudioAnalysis) async -> WaveformRangeIndex {
        let key = WaveformIndexKey(analysis)
        if let result = cache[key] { return result }
        if let task = pending[key] { return await task.value }
        let bins = analysis.waveform
        let task = Task {
            await withCheckedContinuation { continuation in
                Self.worker.async(qos: .background, flags: .enforceQoS) {
                    continuation.resume(returning: WaveformRangeIndex(bins))
                }
            }
        }
        pending[key] = task
        let result = await task.value
        pending[key] = nil
        if result.storageBytes <= budget {
            while bytes + result.storageBytes > budget || order.count >= 8 {
                let oldest = order.removeFirst()
                bytes -= cache.removeValue(forKey: oldest)?.storageBytes ?? 0
            }
            cache[key] = result
            order.append(key)
            bytes += result.storageBytes
        }
        return result
    }
}
