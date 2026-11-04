import Foundation

/// Column geometry for the layered deck waveform. Each column is mirrored about the centre line:
/// the peak outline is the low-frequency body, RMS is the mid band and a narrower core marks the highs.
public struct WaveformLayers: Sendable, Equatable {
    public struct Column: Sendable, Equatable {
        public let x: Int
        /// Half heights in points, outermost first.
        public let peak: Double, body: Double, core: Double
    }
    public let columns: [Column]

    /// Fraction of half the height a full-scale peak uses, leaving headroom like a DJ display.
    public static let headroom = 0.86
    /// Visible span for one bar and one beat at the given tempo.
    public static func defaultSeconds(bpm: Double?) -> Double {
        guard let bpm, bpm.isFinite, bpm > 0 else { return 2.5 }
        return 5 * 60 / bpm
    }

    public init(index: WaveformRangeIndex, framesPerBin: Int, left: Double, span: Double, width: Int, height: Double) {
        let width = max(1, width)
        let perPixel = max(1e-9, span / Double(width))
        let bin = Double(max(1, framesPerBin))
        let half = max(0, height) / 2 * Self.headroom
        var columns: [Column] = []
        columns.reserveCapacity(width)
        for x in 0..<width {
            let low = max(0, Int(floor((left + Double(x) * perPixel) / bin)))
            let high = min(index.count, Int(ceil((left + Double(x + 1) * perPixel) / bin)))
            guard low < high else { continue }
            let extent: WaveformRangeIndex.Extent
            // Narrower than one bin: interpolate between bin centres so edges are continuous.
            if perPixel < bin {
                let position = (left + (Double(x) + 0.5) * perPixel) / bin - 0.5
                let lower = max(0, min(index.count - 1, Int(floor(position))))
                let upper = min(index.count - 1, lower + 1)
                let t = Float(max(0, min(1, position - Double(lower))))
                let a = index.extent(from: lower, to: lower + 1)
                let b = index.extent(from: upper, to: upper + 1)
                extent = .init(
                    minimum: a.minimum + (b.minimum - a.minimum) * t, maximum: a.maximum + (b.maximum - a.maximum) * t,
                    rms: a.rms + (b.rms - a.rms) * t)
            } else {
                extent = index.extent(from: low, to: high)
            }
            let peak = Double(min(1, max(extent.maximum, -extent.minimum))) * half
            let body = min(peak, Double(min(1, extent.rms)) * 1.6 * half)
            columns.append(.init(x: x, peak: peak, body: body, core: body * 0.45))
        }
        self.columns = columns
    }

    /// Beat positions depend on the grid and viewport, without reading waveform samples.
    public static func beatLines(
        grid fixed: BeatGrid, adaptiveMap: BeatGridMap? = nil, left: Double, span: Double, width: Int
    ) -> [(x: Double, downbeat: Bool)] {
        let width = max(1, width)
        let perPixel = max(1e-9, span / Double(width))
        let grid = BeatTiming(fixed: fixed, adaptive: adaptiveMap)
        var beats: [(Double, Bool)] = []
        if let first = Int(exactly: floor(grid.beat(atFrame: left))),
            let last = Int(exactly: ceil(grid.beat(atFrame: left + span))), first <= last, last - first < 300
        {
            for beat in first...last {
                let x = (grid.frame(atBeat: Double(beat)) - left) / perPixel
                if x >= 0 && x <= Double(width) { beats.append((x, grid.isDownbeat(beat))) }
            }
        }
        return beats
    }
}
