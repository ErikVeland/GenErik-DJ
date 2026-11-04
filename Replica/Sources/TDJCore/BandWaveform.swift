import Foundation

/// Display waveform with low, mid and high peaks per 64-frame bin and summaries at 4x, 16x and 64x.
/// Built from decoded audio when a deck loads, held in memory only, so the stored library stays small.
public struct BandWaveform: Sendable {
    public struct Bin: Sendable, Equatable {
        public var low: Float, mid: Float, high: Float
        public init(low: Float = 0, mid: Float = 0, high: Float = 0) {
            self.low = low
            self.mid = mid
            self.high = high
        }
        mutating func include(_ other: Bin) {
            low = max(low, other.low)
            mid = max(mid, other.mid)
            high = max(high, other.high)
        }
    }
    public static let baseFramesPerBin = 64
    public let sampleRate: Double
    public let frameCount: Int
    /// Level k has baseFramesPerBin * 4^k frames per bin.
    public let levels: [[Bin]]
    /// Largest value per band across the track, for display scaling.
    public let maximum: Bin

    /// Interleaved stereo float samples. Low below about 150 Hz, high above about 2.5 kHz, mid between.
    public init(
        interleavedStereo samples: UnsafeBufferPointer<Float>, sampleRate: Double,
        checkCancellation: () throws -> Void = {}
    ) rethrows {
        let frames = samples.count / 2
        let size = Self.baseFramesPerBin
        let lowCoefficient = Float(1 - exp(-2 * Double.pi * 150 / sampleRate))
        let highCoefficient = Float(1 - exp(-2 * Double.pi * 2500 / sampleRate))
        var lowState: Float = 0
        var highState: Float = 0
        var base = [Bin](repeating: .init(), count: (frames + size - 1) / size)
        var top = Bin()
        for start in stride(from: 0, to: frames, by: size) {
            if start % (size * 4096) == 0 { try checkCancellation() }
            var bin = Bin()
            for frame in start..<min(frames, start + size) {
                let x = 0.5 * (samples[2 * frame] + samples[2 * frame + 1])
                lowState += lowCoefficient * (x - lowState)
                highState += highCoefficient * (x - highState)
                bin.low = max(bin.low, abs(lowState))
                bin.mid = max(bin.mid, abs(highState - lowState))
                bin.high = max(bin.high, abs(x - highState))
            }
            base[start / size] = bin
            top.include(bin)
        }
        var levels = [base]
        while levels.count < 4, let last = levels.last, last.count > 1 {
            levels.append(
                stride(from: 0, to: last.count, by: 4).map { index in
                    var merged = Bin()
                    for other in last[index..<min(last.count, index + 4)] { merged.include(other) }
                    return merged
                })
        }
        self.sampleRate = sampleRate
        self.frameCount = frames
        self.levels = levels
        self.maximum = top
    }

    /// Reads a playback cache file (interleaved stereo 32-bit float).
    public static func load(pcm url: URL, sampleRate: Double, checkCancellation: () throws -> Void = {}) throws
        -> BandWaveform
    {
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        return try data.withUnsafeBytes { raw in
            try BandWaveform(
                interleavedStereo: raw.bindMemory(to: Float.self), sampleRate: sampleRate,
                checkCancellation: checkCancellation)
        }
    }

    /// Band values at a pixel spanning `width` frames from `frame`. Uses the finest level whose bins
    /// are no wider than the pixel, takes the maximum across it, and interpolates linearly between
    /// bin centres when a pixel is narrower than one bin, so edges are continuous rather than stepped.
    public func value(from frame: Double, width: Double) -> Bin {
        guard frameCount > 0, width > 0, frame + width > 0, frame < Double(frameCount) else { return .init() }
        var level = 0
        while level + 1 < levels.count && Double(Self.baseFramesPerBin << (2 * (level + 1))) <= width { level += 1 }
        let bins = levels[level]
        let binFrames = Double(Self.baseFramesPerBin << (2 * level))
        if width >= binFrames {
            let first = max(0, Int(floor(frame / binFrames)))
            let last = min(bins.count - 1, Int(ceil((frame + width) / binFrames)) - 1)
            guard first <= last else { return .init() }
            var result = Bin()
            for index in first...last { result.include(bins[index]) }
            return result
        }
        let position = (frame + width / 2) / binFrames - 0.5
        let lower = max(0, min(bins.count - 1, Int(floor(position))))
        let upper = min(bins.count - 1, lower + 1)
        let t = Float(max(0, min(1, position - Double(lower))))
        let a = bins[lower]
        let b = bins[upper]
        return .init(
            low: a.low + (b.low - a.low) * t, mid: a.mid + (b.mid - a.mid) * t, high: a.high + (b.high - a.high) * t)
    }
}

/// Per-device-pixel half heights for the three mirrored layers, outermost (low body) first.
public struct BandWaveformColumns: Sendable {
    public let pixelWidth: Int
    public let low: [Double], mid: [Double], high: [Double]
    public init(_ waveform: BandWaveform, left: Double, span: Double, pixelWidth: Int, height: Double) {
        let count = max(1, pixelWidth)
        let perPixel = max(1e-9, span / Double(count))
        let half = max(0, height) / 2 * WaveformLayers.headroom
        // Scale each band against the track's own loudest moment; lows draw widest, highs as a narrow core.
        let scale = (
            low: 1 / max(1e-6, Double(waveform.maximum.low)), mid: 0.8 / max(1e-6, Double(waveform.maximum.mid)),
            high: 0.55 / max(1e-6, Double(waveform.maximum.high))
        )
        var low = [Double](repeating: 0, count: count)
        var mid = low
        var high = low
        for x in 0..<count {
            let value = waveform.value(from: left + Double(x) * perPixel, width: perPixel)
            low[x] = min(1, Double(value.low) * scale.low) * half
            mid[x] = min(1, Double(value.mid) * scale.mid) * half
            high[x] = min(1, Double(value.high) * scale.high) * half
        }
        self.pixelWidth = count
        self.low = low
        self.mid = mid
        self.high = high
    }
}
