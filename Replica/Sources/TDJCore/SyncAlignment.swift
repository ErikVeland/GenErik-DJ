import Foundation

extension BeatGrid {
    /// The closest beat-phase match inside the source interval. Exact ties move forward.
    public func nearestPhaseAlignedFrame(to frame: Double, masterBeat: Double, within interval: Range<Double>)
        -> Double?
    {
        guard frame.isFinite, masterBeat.isFinite, interval.lowerBound.isFinite, interval.upperBound.isFinite,
            interval.lowerBound < interval.upperBound
        else { return nil }
        let origin = anchorFrame + (Double(downbeatOffset) + masterBeat - floor(masterBeat)) * framesPerBeat
        let first = ceil((interval.lowerBound - origin) / framesPerBeat)
        let last = ceil((interval.upperBound - origin) / framesPerBeat) - 1
        let nearest = floor((frame - origin) / framesPerBeat + 0.5)
        guard origin.isFinite, first.isFinite, last.isFinite, nearest.isFinite, first <= last else { return nil }
        var index = max(first, min(last, nearest))
        var position = origin + index * framesPerBeat
        if position < interval.lowerBound, index < last {
            index += 1
            position = origin + index * framesPerBeat
        }
        if position >= interval.upperBound, index > first {
            index -= 1
            position = origin + index * framesPerBeat
        }
        return position.isFinite && interval.contains(position) ? position : nil
    }
}

extension PlaybackSnapshot {
    // Retain the existing display threshold. It remains a reference-comparison item.
    public static let syncPhaseToleranceBeats = 0.01
    public func syncPhaseError(_ deck: DeckID) -> Double? {
        guard clockRunning, let grid = self[deck].timing else { return nil }
        let sourceBeat = grid.beat(atFrame: self[deck].sourceFrame) - Double(grid.downbeatOffset)
        var error = (sourceBeat - masterBeat).truncatingRemainder(dividingBy: 1)
        if error > 0.5 { error -= 1 }
        if error < -0.5 { error += 1 }
        return error.isFinite ? error : nil
    }
    public func syncNeedsAlignment(_ deck: DeckID) -> Bool {
        let state = self[deck]
        guard state.synced, state.phase != .empty else { return false }
        guard state.timing != nil else { return true }
        return state.phase == .playing
            && syncPhaseError(deck).map { abs($0) > Self.syncPhaseToleranceBeats } == true
    }
}
