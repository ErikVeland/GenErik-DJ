import Foundation

@main enum CompareWaveformRendering {
    static func main() throws {
        let bins = (0..<120000).map { i in
            let peak = Float((i * 17) % 97) / 97
            return WaveformBin(minimum: -peak, maximum: peak * 0.9, rms: peak * 0.4)
        }
        let fixed = try BeatGrid(bpm: 120, anchorFrame: 1234, sampleRate: 48000, downbeatOffset: 1)
        let adaptive = BeatGridMap(anchors: [.init(beat: 0, frame: 1234), .init(beat: 4, frame: 97234),
                                           .init(beat: 8, frame: 177234)], sampleRate: 48000, downbeatOffset: 2)
        var cases = 0
        for count in [0, 1, 128, bins.count] {
            let index = WaveformRangeIndex(Array(bins.prefix(count)))
            for width in [0, 1, 900, 1800, 2700] {
                for span in [64.0, 16000, 108000, 480000, 9600000] {
                    for left in [-108000.0, 0, 48000, 30000000] {
                        for map in [nil, adaptive] {
                            let before = BaselineWaveformLayers(index: index, framesPerBin: 256, left: left,
                                span: span, width: width, height: 216, grid: fixed, adaptiveMap: map)
                            let after = WaveformLayers(index: index, framesPerBin: 256, left: left,
                                span: span, width: width, height: 216)
                            let beats = WaveformLayers.beatLines(grid: fixed, adaptiveMap: map, left: left, span: span, width: width)
                            precondition(before.columns.count == after.columns.count)
                            for (a, b) in zip(before.columns, after.columns) {
                                precondition(a.x == b.x && a.peak == b.peak && a.body == b.body && a.core == b.core)
                            }
                            precondition(before.beats.map(\.x) == beats.map(\.x))
                            precondition(before.beats.map(\.downbeat) == beats.map(\.downbeat))
                            cases += 1
                        }
                    }
                }
            }
        }
        print("Exact waveform and beat parity: \(cases) cases passed")
        let index = WaveformRangeIndex(bins)
        for bandReady in [false, true] {
            var before: [Double] = [], after: [Double] = []
            for _ in 0..<5 {
                for original in [true, false] {
                    let start = ProcessInfo.processInfo.systemUptime
                    let checksum = render(original: original, bandReady: bandReady, index: index, grid: fixed)
                    let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000
                    if original { before.append(elapsed) } else { after.append(elapsed) }
                    precondition(checksum.isFinite && checksum > 0)
                }
            }
            let old = before.sorted()[2], new = after.sorted()[2]
            print(String(format: "%@: 1000 geometry passes, median %.3f ms -> %.3f ms (%.1f%% less time)",
                         bandReady ? "Beat overlay with bands ready" : "Stored-bin geometry and beat overlay", old, new, (1-new/old)*100))
        }
    }

    @inline(never) static func render(original: Bool, bandReady: Bool, index: WaveformRangeIndex, grid: BeatGrid) -> Double {
        var checksum = 0.0
        for frame in 0..<1000 {
            let left = 48000 + Double(frame) * 31
            if original {
                if !bandReady {
                    let layers = BaselineWaveformLayers(index: index, framesPerBin: 256, left: left, span: 108000, width: 1800, height: 216)
                    checksum += layers.columns.last?.peak ?? 0
                }
                let overlay = BaselineWaveformLayers(index: index, framesPerBin: 256, left: left, span: 108000, width: 1800, height: 0, grid: grid)
                checksum += overlay.beats.last?.x ?? 0
            } else {
                if !bandReady {
                    let layers = WaveformLayers(index: index, framesPerBin: 256, left: left, span: 108000, width: 1800, height: 216)
                    checksum += layers.columns.last?.peak ?? 0
                }
                checksum += WaveformLayers.beatLines(grid: grid, left: left, span: 108000, width: 1800).last?.x ?? 0
            }
        }
        return checksum
    }
}
