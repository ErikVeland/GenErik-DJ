import Foundation

/// Background-only tracking of strong pulse evidence. Weak offbeats cannot steer the trajectory.
enum AdaptiveRhythmAnalyzer {
    static func candidate(onsets: [MusicalOnset], sampleRate: Double, frameCount: Int64,
                          downbeat: Int, referenceBPM: Double? = nil, checkCancellation: @Sendable () throws -> Void = {}) throws -> BeatGridMap? {
        guard onsets.count >= 24, sampleRate.isFinite, sampleRate > 0 else { return nil }
        let strongest = onsets.map(\.weight).sorted()[onsets.count / 2]
        let events = onsets.filter { $0.weight >= strongest * 0.65 }
        guard events.count >= 24 else { return nil }
        let intervals = zip(events.dropFirst(), events).map { $0.seconds - $1.seconds }
        let initial = intervals.prefix(16).filter { (0.15...3).contains($0) }.sorted()
        guard initial.count >= 12 else { return nil }
        var period = referenceBPM.map { 60 / $0 } ?? initial[initial.count / 2]
        var points = [BeatGridAnchor(beat: 0, frame: events[0].seconds * sampleRate)]
        var recent = [period], beat = 0.0, rejected = 0
        var previous = events[0]
        for (index, event) in events.dropFirst().enumerated() {
            if index.isMultiple(of: 256) { try checkCancellation() }
            let delta = event.seconds - previous.seconds
            let count = (delta / period).rounded()
            guard count >= 1, count <= 4, abs(delta / count - period) < period * 0.26 else {
                rejected += 1; continue
            }
            beat += count
            points.append(.init(beat: beat, frame: event.seconds * sampleRate))
            recent.append(delta / count)
            if recent.count > 8 { recent.removeFirst() }
            let sorted = recent.sorted()
            period = sorted[sorted.count / 2]
            previous = event
        }
        guard points.count >= 24, Double(rejected) / Double(events.count) < 0.15 else { return nil }
        // Four-beat windows retain section boundaries without following single drum offsets.
        let strideSize = max(4, Int(ceil(Double(points.count - 1) / Double(BeatGridMap.maximumAnchorCount - 1))))
        var indices = Array(stride(from: 0, to: points.count, by: strideSize))
        if indices.last != points.count - 1 { indices.append(points.count - 1) }
        let anchors = indices.map { index -> BeatGridAnchor in
            let lower = max(0, index - 2), upper = min(points.count - 1, index + 2)
            let window = Array(points[lower...upper])
            let periods = zip(window, window.dropFirst()).map { ($1.frame - $0.frame) / ($1.beat - $0.beat) }.sorted()
            let localPeriod = periods[periods.count / 2]
            let phases = window.map { $0.frame - ($0.beat - points[index].beat) * localPeriod }.sorted()
            return .init(beat: points[index].beat, frame: max(0,min(Double(frameCount-1),phases[phases.count / 2])))
        }
        let map = BeatGridMap(anchors: anchors, sampleRate: sampleRate, downbeatOffset: downbeat)
        guard (try? map.validate(frameCount: frameCount)) != nil else { return nil }
        // Reject isolated evidence that disagrees with the window trajectory by more than 35 ms.
        let errors = points.map { abs(map.frame(atBeat: $0.beat) - $0.frame) / sampleRate }.sorted()
        guard errors[Int(Double(errors.count - 1) * 0.9)] <= 0.035 else { return nil }
        return map
    }
}
