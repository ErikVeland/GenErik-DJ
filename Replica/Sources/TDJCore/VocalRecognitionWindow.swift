import Foundation

/// Context may overlap. Each decoded phrase belongs to one source-frame interval.
public struct VocalRecognitionWindow: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var coreStart: Double
    public var coreEnd: Double
    public var vocalScore: Double

    public static func plan(features: [MusicalStructureFrame], sampleRate: Double, frameCount: Int64) -> [Self] {
        guard sampleRate.isFinite, sampleRate > 0, frameCount > 0 else { return [] }
        let fileEnd=Double(frameCount)
        let frames=features.filter {
            $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end > $0.start && $0.end <= fileEnd &&
            ($0.vocal ?? 0).isFinite
        }.sorted { $0.start < $1.start }
        var candidates=[Self]()
        for index in frames.indices where (frames[index].vocal ?? 0) >= 0.3 {
            let start=frames[index].start, end=min(fileEnd,start+30*sampleRate)
            guard end-start >= min(fileEnd,18*sampleRate) else { continue }
            var support=0.0, total=0.0
            for frame in frames[index...].prefix(while: { $0.start < end }) {
                let duration=max(0,min(end,frame.end)-max(start,frame.start))
                let vocal=min(1,max(0,frame.vocal ?? 0))
                total += vocal*duration
                if vocal >= 0.3 { support += duration }
            }
            let score=total/max(1,end-start)
            guard support >= 3*sampleRate, score >= 0.25 else { continue }
            candidates.append(.init(start:start,end:end,coreStart:start,coreEnd:end,vocalScore:score))
        }
        candidates.sort {
            let left=($0.vocalScore*1e9).rounded(), right=($1.vocalScore*1e9).rounded()
            if left != right { return left > right }
            return $0.start < $1.start
        }
        var result=[Self]()
        for candidate in candidates where !result.contains(where: { abs($0.start-candidate.start) < 24*sampleRate }) {
            result.append(candidate)
        }
        result.sort { $0.start < $1.start }
        for index in result.indices {
            if index > 0 { result[index].coreStart=max(result[index].start,(result[index-1].end+result[index].start)/2) }
            if index+1 < result.count { result[index].coreEnd=min(result[index].end,(result[index].end+result[index+1].start)/2) }
        }
        return result
    }
}
