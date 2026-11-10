import Foundation

public struct BeatGridAnchor: Codable, Equatable, Sendable {
    public let beat: Double
    public let frame: Double
    public init(beat: Double, frame: Double) {
        self.beat = beat
        self.frame = frame
    }
}

/// A bounded musical timeline. End segments supply constant-tempo extrapolation.
public struct BeatGridMap: Codable, Equatable, Sendable {
    public static let maximumAnchorCount = 256
    public let anchors: [BeatGridAnchor]
    public let sampleRate: Double
    public let downbeatOffset: Int
    public init(anchors: [BeatGridAnchor], sampleRate: Double, downbeatOffset: Int = 0) {
        self.anchors = anchors
        self.sampleRate = sampleRate
        self.downbeatOffset = downbeatOffset
    }
    /// Adaptive segments support 20–400 BPM. Invalid maps retain the fixed-grid fallback.
    public func validate(frameCount: Int64) throws {
        guard sampleRate.isFinite, sampleRate > 0, frameCount > 0, (0..<4).contains(downbeatOffset),
            (2...Self.maximumAnchorCount).contains(anchors.count)
        else { throw CoreError.invalidGrid }
        for (index, anchor) in anchors.enumerated() {
            guard anchor.beat.isFinite, anchor.frame.isFinite, anchor.frame >= 0, anchor.frame < Double(frameCount)
            else { throw CoreError.invalidGrid }
            if index > 0 {
                let previous = anchors[index - 1]
                let beats = anchor.beat - previous.beat
                let frames = anchor.frame - previous.frame
                let bpm = 60 * sampleRate * beats / frames
                guard beats.isFinite, frames.isFinite, beats > 0, frames > 0, bpm.isFinite, (20...400).contains(bpm)
                else { throw CoreError.invalidGrid }
            }
        }
    }
    private func lookup(_ value: Double, inverse: Bool) -> Double {
        guard value.isFinite, anchors.count >= 2, anchors.count <= Self.maximumAnchorCount else { return .nan }
        func x(_ a: BeatGridAnchor) -> Double { inverse ? a.frame : a.beat }
        func y(_ a: BeatGridAnchor) -> Double { inverse ? a.beat : a.frame }
        var low = 0
        var high = anchors.count - 1
        while low + 1 < high {
            let middle = (low + high) / 2
            if x(anchors[middle]) <= value { low = middle } else { high = middle }
        }
        let a = anchors[low]
        let b = anchors[low + 1]
        return y(a) + (value - x(a)) * (y(b) - y(a)) / (x(b) - x(a))
    }
    public func bpm(atFrame frame: Double) -> Double {
        guard anchors.count >= 2 else { return .nan }
        let beat = beat(atFrame: frame)
        var low = 0
        var high = anchors.count - 1
        while low + 1 < high {
            let mid = (low + high) / 2
            if anchors[mid].beat <= beat { low = mid } else { high = mid }
        }
        return 60 * sampleRate * (anchors[low + 1].beat - anchors[low].beat)
            / (anchors[low + 1].frame - anchors[low].frame)
    }
    public func frame(atBeat beat: Double) -> Double { lookup(beat, inverse: false) }
    public func beat(atFrame frame: Double) -> Double { lookup(frame, inverse: true) }
}

public enum GridMode: String, Codable, Sendable { case automatic, fixed, adaptive }

/// Controls and display share this contract. Ordinary playback does not consume it.
public struct BeatTiming: Sendable {
    public let fixed: BeatGrid
    public let adaptive: BeatGridMap?
    public init(fixed: BeatGrid, adaptive: BeatGridMap? = nil) {
        self.fixed = fixed
        self.adaptive = adaptive
    }
    public var downbeatOffset: Int { adaptive?.downbeatOffset ?? fixed.downbeatOffset }
    public func frame(atBeat beat: Double) -> Double { adaptive?.frame(atBeat: beat) ?? fixed.frame(atBeat: beat) }
    public func beat(atFrame frame: Double) -> Double { adaptive?.beat(atFrame: frame) ?? fixed.beat(atFrame: frame) }
    public func span(beats: Double, from frame: Double) -> Double {
        self.frame(atBeat: beat(atFrame: frame) + beats) - frame
    }
    public func isDownbeat(_ beat: Int) -> Bool { ((beat - downbeatOffset) % 4 + 4) % 4 == 0 }
}

extension BeatTiming {
    public func nearestPhaseAlignedFrame(to frame: Double, masterBeat: Double, within interval: Range<Double>)
        -> Double?
    {
        guard adaptive != nil else {
            return fixed.nearestPhaseAlignedFrame(to: frame, masterBeat: masterBeat, within: interval)
        }
        let phase = Double(downbeatOffset) + masterBeat - floor(masterBeat)
        let first = ceil(beat(atFrame: interval.lowerBound) - phase)
        let last = ceil(beat(atFrame: interval.upperBound) - phase) - 1
        guard first <= last else { return nil }
        let nearest = floor(beat(atFrame: frame) - phase + 0.5)
        let position = self.frame(atBeat: phase + max(first, min(last, nearest)))
        return interval.contains(position) ? position : nil
    }
}

extension Preparation {
    public mutating func acceptAdaptive(_ map: BeatGridMap, frameCount: Int64) throws {
        guard !gridLocked, grid.map({ $0.sampleRate == map.sampleRate }) ?? true else {
            throw CoreError.invalidGrid
        }
        try map.validate(frameCount: frameCount)
        if grid == nil {
            grid = try BeatGrid(
                bpm: map.bpm(atFrame: map.anchors[0].frame), anchorFrame: map.frame(atBeat: 0),
                sampleRate: map.sampleRate, downbeatOffset: map.downbeatOffset)
        }
        adaptiveMap = map
        gridMode = .adaptive
    }
    public mutating func correctAnchor(beat: Double, frame: Double, frameCount: Int64) throws {
        guard !gridLocked, let map = adaptiveMap, beat.isFinite, frame.isFinite else { throw CoreError.invalidGrid }
        var anchors = map.anchors.filter { $0.beat != beat }
        anchors.append(.init(beat: beat, frame: frame))
        anchors.sort { $0.beat < $1.beat }
        let changed = BeatGridMap(anchors: anchors, sampleRate: map.sampleRate, downbeatOffset: map.downbeatOffset)
        try changed.validate(frameCount: frameCount)
        adaptiveMap = changed
        gridMode = .adaptive
        gridIsManual = true
        gridWasEditedByUser = true
    }
}

extension BeatGridMap {
    /// Preserve local sections when existing phase and half/double controls change the timeline.
    public func transforming(tempoFactor: Double, frameOffset: Double, frameCount: Int64) throws -> BeatGridMap {
        guard anchors.count >= 2, frameCount > 1, tempoFactor.isFinite, tempoFactor > 0, frameOffset.isFinite else {
            throw CoreError.invalidGrid
        }
        let shifted = BeatGridMap(
            anchors: anchors.map { .init(beat: $0.beat * tempoFactor, frame: $0.frame + frameOffset) },
            sampleRate: sampleRate, downbeatOffset: downbeatOffset)
        let end = Double(frameCount - 1)
        var bounded = shifted.anchors.filter { $0.frame >= 0 && $0.frame <= end }
        if shifted.anchors.first!.frame < 0 { bounded.insert(.init(beat: shifted.beat(atFrame: 0), frame: 0), at: 0) }
        if shifted.anchors.last!.frame > end { bounded.append(.init(beat: shifted.beat(atFrame: end), frame: end)) }
        let map = BeatGridMap(anchors: bounded, sampleRate: sampleRate, downbeatOffset: downbeatOffset)
        try map.validate(frameCount: frameCount)
        return map
    }
}
