import Foundation

public struct BeatGrid: Codable, Equatable, Sendable {
    public private(set) var bpm: Double
    public private(set) var anchorFrame: Double
    public let sampleRate: Double
    public private(set) var downbeatOffset: Int
    public var framesPerBeat: Double { sampleRate * 60 / bpm }
    public init(bpm: Double, anchorFrame: Double, sampleRate: Double, downbeatOffset: Int = 0) throws {
        guard bpm.isFinite, bpm > 0, anchorFrame.isFinite, sampleRate.isFinite, sampleRate > 0,
              (sampleRate * 60 / bpm).isFinite, sampleRate * 60 / bpm > 0,
              (0..<4).contains(downbeatOffset) else { throw CoreError.invalidGrid }
        self.bpm = bpm
        self.anchorFrame = anchorFrame
        self.sampleRate = sampleRate
        self.downbeatOffset = downbeatOffset
    }
    private enum CodingKeys: String, CodingKey { case bpm, anchorFrame, sampleRate, downbeatOffset }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(bpm: values.decode(Double.self, forKey: .bpm),
                      anchorFrame: values.decode(Double.self, forKey: .anchorFrame),
                      sampleRate: values.decode(Double.self, forKey: .sampleRate),
                      downbeatOffset: values.decode(Int.self, forKey: .downbeatOffset))
    }
    public func frame(atBeat beat: Double) -> Double { anchorFrame + beat * framesPerBeat }
    public func beat(atFrame frame: Double) -> Double { (frame - anchorFrame) / framesPerBeat }
    public func isDownbeat(_ beat: Int) -> Bool { ((beat - downbeatOffset) % 4 + 4) % 4 == 0 }
    public mutating func setBPM(_ value: Double) throws {
        guard value.isFinite, value > 0, (sampleRate * 60 / value).isFinite else { throw CoreError.invalidGrid }
        bpm = value
    }
    public mutating func halveBPM() throws { try setBPM(bpm / 2) }
    public mutating func doubleBPM() throws { try setBPM(bpm * 2) }
    public mutating func shiftWaveform(bySourceFrames delta: Double) throws {
        guard delta.isFinite, (anchorFrame - delta).isFinite else { throw CoreError.invalidGrid }
        anchorFrame -= delta
    }
    public mutating func selectDownbeat(_ beatWithinBar: Int) throws {
        guard (0..<4).contains(beatWithinBar) else { throw CoreError.invalidGrid }
        downbeatOffset = beatWithinBar
    }
    public func fourBeatInspection(from frame: Double, direction: Int, endFrame: Double) -> Double {
        min(max(frame + Double(direction.signum()) * 4 * framesPerBeat, 0), max(0, endFrame))
    }
}

public struct TapTempo: Sendable {
    private var times: [Double] = []
    public init() {}
    public mutating func tap(atMonotonicSeconds time: Double) throws -> Double? {
        guard time.isFinite, times.last.map({ time > $0 }) ?? true else { throw CoreError.insufficientTaps }
        times.append(time)
        if times.count > 8 { times.removeFirst() }
        guard times.count >= 3 else { return nil }
        let intervals = zip(times.dropFirst(), times).map { $0 - $1 }.sorted()
        let mid = intervals.count / 2
        let interval = intervals.count.isMultiple(of: 2)
            ? (intervals[mid - 1] + intervals[mid]) / 2 : intervals[mid]
        return 60 / interval
    }
}

public struct GridDrag: Sendable {
    public let originalGrid: BeatGrid
    public let originalViewportFrame: Double
    public let framesPerPoint: Double
    public init(grid: BeatGrid, viewportFrame: Double, framesPerPoint: Double) {
        originalGrid = grid
        originalViewportFrame = viewportFrame
        self.framesPerPoint = framesPerPoint
    }
    public func preview(translationPoints: Double) throws -> (grid: BeatGrid, viewportFrame: Double) {
        let delta = translationPoints * framesPerPoint
        var grid = originalGrid
        try grid.shiftWaveform(bySourceFrames: delta)
        return (grid, originalViewportFrame - delta)
    }
}

public enum BarStartAnalysis {
    public static let version=1
}

public enum AutomaticGridPolicy {
    public static func mayRefresh(isManual:Bool,wasEditedByUser:Bool,isLocked:Bool,hasAdaptiveMap:Bool,
        current:BeatGrid?,imported:BeatGrid?,importIsUnlocked:Bool) -> Bool {
        guard !wasEditedByUser,!isLocked,!hasAdaptiveMap else { return false }
        if imported != nil && !importIsUnlocked { return false }
        if isManual { return imported != nil && current == imported }
        return true
    }
}
