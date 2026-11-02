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
    /// Beat-grid line positions in points, with downbeat flags.
    public let beats: [(x: Double, downbeat: Bool)]
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.columns == rhs.columns && lhs.beats.map(\.x) == rhs.beats.map(\.x) && lhs.beats.map(\.downbeat) == rhs.beats.map(\.downbeat)
    }

    /// Fraction of half the height a full-scale peak uses, leaving headroom like a DJ display.
    public static let headroom=0.86
    /// Visible span for about four and a half beats at the given tempo.
    public static func defaultSeconds(bpm: Double?) -> Double {
        guard let bpm, bpm.isFinite, bpm > 0 else { return 2.2 }
        return 4.5*60/bpm
    }

    public init(index: WaveformRangeIndex, framesPerBin: Int, left: Double, span: Double, width: Int, height: Double,
                grid: BeatGrid? = nil, adaptiveMap: BeatGridMap? = nil) {
        let width=max(1,width), perPixel=max(1e-9,span/Double(width)), bin=Double(max(1,framesPerBin))
        let half=max(0,height)/2*Self.headroom
        var columns: [Column]=[]
        columns.reserveCapacity(width)
        for x in 0..<width {
            let low=max(0,Int(floor((left+Double(x)*perPixel)/bin)))
            let high=min(index.count,Int(ceil((left+Double(x+1)*perPixel)/bin)))
            guard low<high else { continue }
            var extent=index.extent(from:low,to:high)
            // Narrower than one bin: interpolate between bin centres so edges are continuous.
            if perPixel<bin {
                let position=(left+(Double(x)+0.5)*perPixel)/bin-0.5
                let lower=max(0,min(index.count-1,Int(floor(position)))),upper=min(index.count-1,lower+1)
                let t=Float(max(0,min(1,position-Double(lower))))
                let a=index.extent(from:lower,to:lower+1),b=index.extent(from:upper,to:upper+1)
                extent = .init(minimum:a.minimum+(b.minimum-a.minimum)*t,maximum:a.maximum+(b.maximum-a.maximum)*t,rms:a.rms+(b.rms-a.rms)*t)
            }
            let peak=Double(min(1,max(extent.maximum,-extent.minimum)))*half
            let body=min(peak,Double(min(1,extent.rms))*1.6*half)
            columns.append(.init(x:x,peak:peak,body:body,core:body*0.45))
        }
        self.columns=columns
        var beats: [(Double,Bool)]=[]
        if let fixed=grid,
           case let grid=BeatTiming(fixed:fixed,adaptive:adaptiveMap),
           let first=Int(exactly:floor(grid.beat(atFrame:left))),
           let last=Int(exactly:ceil(grid.beat(atFrame:left+span))),
           first<=last,last-first<300 {
            for beat in first...last {
                let x=(grid.frame(atBeat:Double(beat))-left)/perPixel
                if x>=0 && x<=Double(width) { beats.append((x,grid.isDownbeat(beat))) }
            }
        }
        self.beats=beats
    }
}
