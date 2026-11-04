import Foundation

public enum RecoveryMode: String, Codable, CaseIterable, Sendable {
    case off, replayLastDrop, autoMix
    public var title: String {
        switch self {
        case .off: "Off"
        case .replayLastDrop: "Replay best section"
        case .autoMix: "Auto-mix next track"
        }
    }
}

public struct RecoverySettings: Codable, Equatable, Sendable {
    public var mode: RecoveryMode = .replayLastDrop
    public var leadBars: Int = 16
    public var dropFrames: [String: Double] = [:]
    public init() {}
    public func validate() throws {
        guard [8, 16].contains(leadBars), dropFrames.values.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw TransportError.invalid
        }
    }
}

/// End is an exclusive beat boundary. Replay prefers a manual marker, then a drop, then an audible section.
public struct RecoveryPlan: Equatable, Sendable {
    public let dropFrame: Double?
    public let endFrame: Double
    public let endBeat: Double
    private let timing: BeatTiming
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.dropFrame == rhs.dropFrame && lhs.endFrame == rhs.endFrame
    }
    public init?(
        waveform: [WaveformBin], framesPerBin: Int, frameCount: Int64, timing: BeatTiming, dropOverride: Double? = nil
    ) {
        guard frameCount > 0, framesPerBin > 0, !waveform.isEmpty,
            waveform.allSatisfy({ $0.rms.isFinite && $0.rms >= 0 }), let peak = waveform.map(\.rms).max(), peak > 0,
            let last = waveform.lastIndex(where: { $0.rms > peak * 0.005 })
        else { return nil }
        let audibleEnd = min(Double(frameCount), Double(last + 1) * Double(framesPerBin))
        let endBeat = ceil(timing.beat(atFrame: audibleEnd) - 1e-9)
        let end = min(Double(frameCount), timing.frame(atBeat: endBeat))
        guard end.isFinite, end > 0 else { return nil }
        func energy(from start: Double, to end: Double) -> Double {
            let a = max(0, min(waveform.count, Int(start / Double(framesPerBin))))
            let b = max(a, min(waveform.count, Int(ceil(end / Double(framesPerBin)))))
            guard b > a else { return 0 }
            return waveform[a..<b].reduce(0) { $0 + Double($1.rms) } / Double(b - a)
        }
        let drop: Double?
        if let override = dropOverride, override.isFinite, override >= 0, override < end {
            let beat = floor(timing.beat(atFrame: override))
            drop = max(0, timing.frame(atBeat: beat))
        } else {
            let first =
                ceil((timing.beat(atFrame: 0) - Double(timing.downbeatOffset)) / 4) * 4 + Double(timing.downbeatOffset)
            var candidate: Double?
            if first.isFinite, endBeat - first >= 32, endBeat - first < 100_000 {
                for beat in stride(from: first + 4, through: endBeat - 32, by: 4) {
                    let frame = timing.frame(atBeat: beat)
                    let before = energy(from: timing.frame(atBeat: beat - 4), to: frame)
                    let after = energy(from: frame, to: timing.frame(atBeat: beat + 16))
                    if after > Double(peak) * 0.35 && after > before * 1.8 { candidate = frame }
                }
            }
            if candidate == nil, first.isFinite, first < endBeat {
                let offset = Double(timing.downbeatOffset)
                let preferred = max(first, floor((endBeat - 64 - offset) / 4) * 4 + offset)
                // Prefer the last 16 bars. Move earlier if that section starts quietly.
                for beat in stride(from: preferred, through: max(first, preferred - 64), by: -4) {
                    let frame = timing.frame(atBeat: beat)
                    let openingEnd = min(end, timing.frame(atBeat: beat + 4))
                    if frame >= 0, frame < end, energy(from: frame, to: openingEnd) >= Double(peak) * 0.1 {
                        candidate = frame
                        break
                    }
                }
            }
            if candidate == nil {
                // Sparse or very short tracks can lack an audible full-bar opening.
                let strongest = waveform.indices.filter { Double($0) * Double(framesPerBin) < end }.max {
                    waveform[$0].rms < waveform[$1].rms
                }
                if let strongest {
                    let frame = Double(strongest) * Double(framesPerBin)
                    let beat =
                        floor((timing.beat(atFrame: frame) - Double(timing.downbeatOffset)) / 4) * 4
                        + Double(timing.downbeatOffset)
                    candidate = max(0, timing.frame(atBeat: beat))
                }
            }
            drop = candidate
        }
        if let drop, !drop.isFinite || drop < 0 || drop >= end { return nil }
        self.dropFrame = drop
        self.endFrame = end
        self.endBeat = timing.beat(atFrame: end)
        self.timing = timing
    }
    public func incomingFrame(timing incoming: BeatTiming, leadBars: Int) -> Double? {
        guard let start = mixStartFrame(leadBars: leadBars) else { return nil }
        let sourceBeat = timing.beat(atFrame: start) - Double(timing.downbeatOffset)
        let phase = (sourceBeat.truncatingRemainder(dividingBy: 4) + 4).truncatingRemainder(dividingBy: 4)
        let first =
            ceil((incoming.beat(atFrame: 0) - Double(incoming.downbeatOffset)) / 4) * 4
            + Double(incoming.downbeatOffset)
        return incoming.frame(atBeat: first + phase)
    }
    public func mixStartFrame(leadBars: Int) -> Double? {
        guard [8, 16].contains(leadBars) else { return nil }
        let value = timing.frame(atBeat: endBeat - Double(leadBars * 4))
        return value >= 0 && value < endFrame ? value : nil
    }
}
