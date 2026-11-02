import XCTest
@testable import TDJCore

final class TrackArrangementTests: XCTestCase {
    let rate = 1000.0
    func testWarningThresholdsAndLoopRelease() throws {
        let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: rate)
        let timing = BeatTiming(fixed: grid)
        let arrangement = TrackArrangement(sections: [], landmarks: [], musicalEnd: 100_000, rhythmicEnd: nil)
        func display(_ frame: Double, loop: Bool = false, slip: Bool = false, underlying: Double? = nil) -> ArrangementStatus {
            arrangement.status(frame: frame, continuingFrame: underlying, fileEnd: 105_000, sampleRate: rate,
                timing: timing, reliableGrid: true, playing: true, rate: 1, loop: loop, slip: slip)
        }
        XCTAssertEqual(display(36_000).warning, .prepare)
        XCTAssertEqual(display(68_000).warning, .amber)
        XCTAssertEqual(display(84_000).warning, .red)
        XCTAssertEqual(display(92_000).warning, .urgent)
        XCTAssertEqual(display(100_000).endingText, "TAIL")
        XCTAssertEqual(display(90_000, loop: true).endingText, "LOOP ACTIVE · AFTER RELEASE 5 BARS")
        XCTAssertEqual(display(20_000, loop: true, slip: true, underlying: 92_000).warning, .urgent)
        XCTAssertEqual(display(20_000, loop: true, slip: true, underlying: 92_000).barsRemaining, 4)
    }
    func testPulseUsesTransportAndStopsForMotionOrReverse() throws {
        let timing = BeatTiming(fixed: try BeatGrid(bpm: 240, anchorFrame: 0, sampleRate: rate))
        let arrangement = TrackArrangement(sections: [], landmarks: [], musicalEnd: 20_000, rhythmicEnd: nil)
        let status = arrangement.status(frame: 15_125, fileEnd: 22_000, sampleRate: rate,
            timing: timing, reliableGrid: true, playing: true, rate: 1)
        XCTAssertGreaterThan(status.pulse, 0)
        XCTAssertEqual(status.pulseValue(reduceMotion: true, audible: true), 0)
        XCTAssertEqual(status.pulseValue(reduceMotion: false, audible: false), 0)
        let reverse = arrangement.status(frame: 15_125, fileEnd: 22_000, sampleRate: rate,
            timing: timing, reliableGrid: true, playing: true, rate: -1)
        XCTAssertEqual(reverse.pulse, 0)
        XCTAssertEqual(reverse.endingText, "REVERSE")
        let unreliable = arrangement.status(frame: 18_000, fileEnd: 22_000, sampleRate: rate,
            timing: timing, reliableGrid: false, playing: true, rate: 1)
        XCTAssertNil(unreliable.barsRemaining)
        XCTAssertEqual(unreliable.pulse, 0)
        XCTAssertTrue(unreliable.endingText.contains("2 SEC"))
    }
    func testEditsSurviveReanalysisAndCodableRoundTrip() throws {
        let section = ArrangementSection(start: 0, end: 10_000, role: .verse, name: "VERSE 2", locked: true)
        let cue = ArrangementLandmark(frame: 321, name: "Vocal pickup", kind: .vocal, state: .accepted, locked: true)
        let corrected = TrackArrangement(sections: [section], landmarks: [cue], musicalEnd: 9_000, rhythmicEnd: nil)
        var fresh = TrackArrangement(sections: [], landmarks: [], musicalEnd: 10_000, rhythmicEnd: nil)
        fresh.retainCorrections(from: corrected)
        XCTAssertEqual(fresh.sections.first?.name, "VERSE 2")
        XCTAssertEqual(fresh.landmarks.first?.frame, 321)
        XCTAssertEqual(try JSONDecoder().decode(TrackArrangement.self, from: JSONEncoder().encode(fresh)), fresh)
    }
    func testRoleColourWinsAndBehaviourIsFallback() {
        XCTAssertEqual(ArrangementSection(start: 0, end: 100, role: .verse, behaviour: .dropping).colourHex, 0x71ADFF)
        XCTAssertEqual(ArrangementSection(start: 0, end: 100, role: .unknown, behaviour: .dropping).colourHex, 0xF6AF69)
    }
    func testNoSilentBreakdownIsMistakenForTrackEnding() {
        let bins = (0..<100).map { i in WaveformBin(minimum: -0.5, maximum: 0.5, rms: i > 30 && i < 60 ? 0 : 0.3) }
        let analysis = AudioAnalysis(implementation: "test", configurationID: "test", contentSHA256: "test", sampleRate: rate,
            frameCount: 100_000, channelCount: 1, waveformFramesPerBin: 1000, waveform: bins, bpm: 120,
            beatAnchorFrame: 0, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
        let arrangement = TrackArrangement.prepare(analysis: analysis)
        XCTAssertEqual(arrangement.musicalEnd, 100_000)
        XCTAssertFalse(arrangement.sections.contains { $0.role == .chorus || $0.role == .verse })
        XCTAssertFalse(arrangement.landmarks.contains { $0.kind == .vocal })
    }
}
