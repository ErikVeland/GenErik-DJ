import Testing
@testable import TDJCore

@Suite struct AdaptiveRhythmTests {
    @Test(arguments: ["steady", "drift", "ramp", "sections", "swing", "lateSnare", "syncopation"])
    func trajectories(kind: String) throws {
        var times = [Double](), time = 0.0
        for beat in 0..<128 {
            times.append(time)
            switch kind {
            case "drift", "ramp": time += 0.5 + Double(beat) * 0.0005
            case "sections": time += beat < 64 ? 0.5 : 0.6
            default: time += 0.5
            }
        }
        var events = times.map { MusicalOnset(seconds: $0, weight: 1) }
        if kind == "swing" || kind == "lateSnare" || kind == "syncopation" {
            events += times.map { MusicalOnset(seconds: $0 + (kind == "swing" ? 0.33 : 0.28), weight: 0.25) }
            events.sort { $0.seconds < $1.seconds }
        }
        let result = try AdaptiveRhythmAnalyzer.candidate(onsets: events, sampleRate: 48_000,
            frameCount: Int64((time + 1) * 48_000), downbeat: 0)
        let map = try #require(result)
        try map.validate(frameCount: Int64((time + 1) * 48_000))
        #expect(map.anchors.count <= 256)
        let error = abs(map.frame(atBeat: 120) / 48_000 - times[120])
        #expect(error < 0.035)
        if kind == "drift" || kind == "ramp" { #expect(error < abs(60 - times[120]) / 10) }
    }
    @Test func sparseAndUnreliableEvidenceIsRejected() throws {
        #expect(try AdaptiveRhythmAnalyzer.candidate(onsets: [], sampleRate: 48_000, frameCount: 480_000, downbeat: 0) == nil)
        let events = (0..<100).map { MusicalOnset(seconds: Double($0) * Double(($0 % 5) + 1), weight: 1) }.sorted { $0.seconds < $1.seconds }
        #expect(try AdaptiveRhythmAnalyzer.candidate(onsets: events, sampleRate: 48_000, frameCount: 48_000_000, downbeat: 0) == nil)
    }
}

extension AdaptiveRhythmTests {
    @Test(arguments: [64, 127]) func isolatedLateBeatDoesNotBendTheTempoTrajectory(lateBeat: Int) throws {
        let events = (0..<128).map { MusicalOnset(seconds: Double($0) * 0.5 + ($0 == lateBeat ? 0.1 : 0), weight: 1) }
        let map = try #require(try AdaptiveRhythmAnalyzer.candidate(onsets: events, sampleRate: 48_000, frameCount: 3_200_000, downbeat: 0))
        #expect(abs(map.frame(atBeat: Double(lateBeat)) / 48_000 - Double(lateBeat) * 0.5) < 0.01)
        for pair in zip(map.anchors, map.anchors.dropFirst()) {
            let bpm = 60 * 48_000 * (pair.1.beat - pair.0.beat) / (pair.1.frame - pair.0.frame)
            #expect(abs(bpm - 120) < 0.5)
        }
    }
}
