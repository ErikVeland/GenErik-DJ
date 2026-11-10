import Foundation

/// A review candidate. Model consistency and compression error do not establish musical accuracy.
public struct DeepAdaptiveBeatCandidate: Codable, Equatable, Sendable {
    public let map: BeatGridMap
    public let observedBeatCount: Int
    public let barConsistency: Double
    public let compressionErrorMilliseconds: Double

    func validate(frameCount: Int64, sampleRate: Double) throws {
        try map.validate(frameCount: frameCount)
        guard map.sampleRate == sampleRate, (16...600_000).contains(observedBeatCount),
            map.anchors.first?.beat == 0, map.anchors.last?.beat == Double(observedBeatCount - 1),
            barConsistency.isFinite, (0.9...1).contains(barConsistency),
            compressionErrorMilliseconds.isFinite, (0...8.001).contains(compressionErrorMilliseconds)
        else { throw CoreError.invalidAudio("The deep adaptive candidate is invalid.") }
    }

    static func fit(
        beats: [Double], bars: [Double], sampleRate: Double, frameCount: Int64,
        checkCancellation: @Sendable () throws -> Void
    ) throws -> Self? {
        try checkCancellation()
        guard (16...600_000).contains(beats.count), bars.count >= 4,
            sampleRate.isFinite, sampleRate > 0, frameCount > 0,
            beats.allSatisfy({ $0.isFinite && $0 >= 0 && $0 * sampleRate < Double(frameCount) }),
            bars.allSatisfy({ $0.isFinite && $0 >= 0 }),
            zip(beats, beats.dropFirst()).allSatisfy({ $0 < $1 }),
            zip(bars, bars.dropFirst()).allSatisfy({ $0 < $1 })
        else { return nil }
        let intervals = zip(beats.dropFirst(), beats).map(-).sorted()
        let median = intervals[intervals.count / 2]
        guard (60...200).contains(60 / median),
            intervals.first! >= median * 0.88, intervals.last! <= median * 1.12
        else { return nil }

        var barBeats: [Int] = []
        var beatIndex = 0
        for bar in bars {
            try checkCancellation()
            while beatIndex + 1 < beats.count, abs(beats[beatIndex + 1] - bar) < abs(beats[beatIndex] - bar) {
                beatIndex += 1
            }
            guard abs(beats[beatIndex] - bar) <= 0.06 else { return nil }
            if barBeats.last != beatIndex { barBeats.append(beatIndex) }
        }
        guard barBeats.count >= 4 else { return nil }
        let consecutiveBars = zip(barBeats.dropFirst(), barBeats).filter { $0 - $1 == 4 }.count
        let spacingSupport = Double(consecutiveBars) / Double(barBeats.count - 1)
        var phases = [Int](repeating: 0, count: 4)
        for beat in barBeats { phases[beat % 4] += 1 }
        let phase = phases.indices.max { phases[$0] < phases[$1] }!
        let support = min(spacingSupport, Double(phases[phase]) / Double(barBeats.count))
        guard support >= 0.9 else { return nil }

        var retained: Set<Int> = [0, beats.count - 1]
        var pending = [(0, beats.count - 1)]
        var maximumError = 0.0
        while let (first, last) = pending.popLast() {
            try checkCancellation()
            guard last > first + 1 else { continue }
            let step = (beats[last] - beats[first]) / Double(last - first)
            var worst = first
            var error = 0.0
            for index in (first + 1)..<last {
                if index % 1024 == 0 { try checkCancellation() }
                let distance = abs(beats[index] - beats[first] - Double(index - first) * step)
                if distance > error { error = distance; worst = index }
            }
            if error > 0.008 {
                retained.insert(worst)
                guard retained.count <= BeatGridMap.maximumAnchorCount else { return nil }
                pending.append((first, worst))
                pending.append((worst, last))
            } else { maximumError = max(maximumError, error) }
        }
        let map = BeatGridMap(
            anchors: retained.sorted().map { .init(beat: Double($0), frame: beats[$0] * sampleRate) },
            sampleRate: sampleRate, downbeatOffset: phase)
        let result = Self(map: map, observedBeatCount: beats.count, barConsistency: support,
                          compressionErrorMilliseconds: maximumError * 1000)
        try result.validate(frameCount: frameCount, sampleRate: sampleRate)
        return result
    }
}
