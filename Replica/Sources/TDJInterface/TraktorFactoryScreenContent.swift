import Foundation
import TDJCore

enum TraktorFactoryScreenContent {
    static func browser(side: UInt8, rows: [String], selected: Int) -> [UInt8] {
        let rows = Array(rows.prefix(4))
        var payload: [UInt8] = [side, 1, UInt8(clamping: selected)]
        for index in 0..<4 {
            var text = index < rows.count ? Array(rows[index].utf8.prefix(25)) : []
            while String(bytes: text, encoding: .utf8) == nil { text.removeLast() }
            payload += text + [UInt8](repeating: 0, count: 25 - text.count)
        }
        return payload
    }

    static func waveform(side: UInt8, analysis: AudioAnalysis?, progress: Double) -> [UInt8] {
        let value = progress.isFinite ? UInt16((min(1, max(0, progress)) * 65_535).rounded()) : 0
        var payload: [UInt8] = [side, 0, UInt8(truncatingIfNeeded: value), UInt8(value >> 8)]
        let bins = analysis?.waveform ?? []
        let framesPerBin = max(1, analysis?.waveformFramesPerBin ?? 1)
        let total = max(bins.count, Int((analysis?.frameCount ?? 0) / Int64(framesPerBin)))
        for column in 0..<99 {
            var peak: Float = 0
            let lower = Int(Double(total) * Double(column) / 99)
            let upper = Int(Double(total) * Double(column + 1) / 99)
            for point in 0..<4 {
                let index = lower + (upper - lower) * point / 4
                if bins.indices.contains(index) {
                    let bin = bins[index]
                    peak = max(peak, abs(bin.minimum), abs(bin.maximum))
                }
            }
            payload.append(peak.isFinite ? UInt8((min(1, peak) * 255).rounded()) : 0)
        }
        return payload
    }
}
