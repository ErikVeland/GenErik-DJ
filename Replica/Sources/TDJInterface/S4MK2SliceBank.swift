import Foundation
import TDJCore

struct S4MK2SliceBank {
    let timing: BeatTiming
    let origin: Double
    let beats: Double
    let frames: Double
    let looping: Bool
    let count: Int

    init?(timing: BeatTiming, origin: Double, beats: Double, frames: Double, looping: Bool, count: Int = 8) {
        guard origin.isFinite, beats.isFinite, beats > 0, frames.isFinite, count > 0, frames > Double(count) else {
            return nil
        }
        let first = timing.beat(atFrame: 0)
        let last = timing.beat(atFrame: frames)
        guard first.isFinite, last.isFinite, last > first else { return nil }
        self.timing = timing
        self.beats = min(beats, last - first)
        self.origin = max(first, min(origin, last - self.beats))
        self.frames = frames
        self.looping = looping
        self.count = count
    }

    func range(slot: Int) -> Range<Double>? {
        guard (0..<count).contains(slot) else { return nil }
        let start = max(0, timing.frame(atBeat: origin + beats * Double(slot) / Double(count)))
        let end = min(frames, timing.frame(atBeat: origin + beats * Double(slot + 1) / Double(count)))
        return end - start >= 1 ? start..<end : nil
    }

    func moved(groups: Int) -> Self? {
        .init(
            timing: timing, origin: origin + Double(groups) * beats, beats: beats, frames: frames, looping: looping,
            count: count)
    }

    func resized(by detents: Int) -> Self? {
        let size = min(32, max(0.25, beats * pow(2, Double(detents))))
        return .init(timing: timing, origin: origin, beats: size, frames: frames, looping: looping, count: count)
    }
}
