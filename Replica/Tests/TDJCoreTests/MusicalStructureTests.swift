import Foundation
import XCTest

@testable import TDJCore

final class MusicalStructureTests: XCTestCase {
    private func analysis(seconds: Int) -> AudioAnalysis {
        .init(
            implementation: "fixture", configurationID: "fixture", contentSHA256: "fixture", sampleRate: 1000,
            frameCount: Int64(seconds * 1000), channelCount: 2, waveformFramesPerBin: 1000,
            waveform: (0..<seconds).map { _ in .init(minimum: -0.5, maximum: 0.5, rms: 0.3) }, bpm: 120,
            beatAnchorFrame: 0, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    }
    private func passage(
        _ start: Int, _ end: Int, energy: Double, bass: Double, pitch: Int, vocal: Double? = nil, rhythm: Double = 0.7
    ) -> [MusicalStructureFrame] {
        (start..<end).map { second in
            var chroma = [Double](repeating: 0, count: 12)
            chroma[pitch] = 1
            return .init(
                start: Double(second * 1000), end: Double((second + 1) * 1000), rms: energy, bass: bass, rhythm: rhythm,
                bands: [bass, 0.1, 0.2, 0.2, 0.2, 0.2], chroma: chroma, vocal: vocal)
        }
    }
    func testRepeatedVocalRefrainsHaveChorusNamesAndColours() {
        let frames =
            passage(0, 16, energy: 0.12, bass: 0.25, pitch: 0)
            + passage(16, 40, energy: 0.25, bass: 0.3, pitch: 2, vocal: 0.85)
            + passage(40, 64, energy: 0.5, bass: 0.65, pitch: 7, vocal: 0.9)
            + passage(64, 88, energy: 0.25, bass: 0.3, pitch: 2, vocal: 0.85)
            + passage(88, 112, energy: 0.5, bass: 0.65, pitch: 7, vocal: 0.9)
            + passage(112, 128, energy: 0.12, bass: 0.25, pitch: 0)
        let result = TrackArrangement.prepare(analysis: analysis(seconds: 128), features: frames)
        XCTAssertEqual(result.section(at: 48_000)?.role, .chorus)
        XCTAssertEqual(result.section(at: 96_000)?.role, .chorus)
        XCTAssertEqual(result.section(at: 24_000)?.role, .verse)
        XCTAssertEqual(result.section(at: 48_000)?.colourHex, 0xF6AF69)
        XCTAssertEqual(result.section(at: 24_000)?.colourHex, 0x71ADFF)
        XCTAssertTrue(result.section(at: 48_000)?.label.contains("CHORUS") == true)
        XCTAssertTrue(result.landmarks.contains { $0.kind == .vocal })
        XCTAssertTrue(result.landmarks.contains { $0.kind == .mainReturn })
        XCTAssertTrue(result.isValid(fileEnd: 128_000))
    }
    func testInstrumentalBreakBuildAndDropDoNotInventVocals() {
        var frames = passage(0, 16, energy: 0.25, bass: 0.5, pitch: 0)
        frames += passage(16, 32, energy: 0.08, bass: 0.02, pitch: 5, rhythm: 0.05)
        for second in 32..<48 {
            frames += passage(
                second, second + 1, energy: 0.1 + Double(second - 32) * 0.02, bass: 0.1, pitch: 5,
                rhythm: 0.2 + Double(second - 32) * 0.04)
        }
        frames += passage(48, 72, energy: 0.5, bass: 0.65, pitch: 0)
        let result = TrackArrangement.prepare(analysis: analysis(seconds: 72), features: frames)
        XCTAssertEqual(result.section(at: 24_000)?.behaviour, .breakingDown)
        XCTAssertTrue(result.sections.contains { $0.behaviour == .building })
        XCTAssertEqual(result.section(at: 56_000)?.behaviour, .dropping)
        XCTAssertFalse(result.landmarks.contains { $0.kind == .vocal })
        XCTAssertFalse(result.sections.contains { $0.role == .verse || $0.role == .chorus })
    }
    func testMixRegionsAvoidDetectedVocalsAndEndingPrecedesTail() {
        let frames =
            passage(0, 16, energy: 0.2, bass: 0.5, pitch: 0, vocal: 0)
            + passage(16, 64, energy: 0.4, bass: 0.5, pitch: 2, vocal: 0.9)
            + passage(64, 88, energy: 0.2, bass: 0.5, pitch: 0, vocal: 0)
            + passage(88, 96, energy: 0.015, bass: 0.001, pitch: 0, vocal: 0, rhythm: 0)
        let result = TrackArrangement.prepare(analysis: analysis(seconds: 96), features: frames)
        XCTAssertEqual(result.rhythmicEnd ?? -1, 88_000, accuracy: 2000)
        let mixIn = result.landmarks.first { $0.kind == .mixIn }
        let mixOut = result.landmarks.first { $0.kind == .mixOut }
        XCTAssertNotNil(mixIn?.end)
        XCTAssertLessThanOrEqual(mixIn?.end ?? .infinity, 16_000)
        XCTAssertGreaterThanOrEqual(mixOut?.frame ?? -1, 64_000)
        XCTAssertLessThanOrEqual(mixOut?.end ?? .infinity, 88_000)
    }
    func testSilenceAndSteadyTonesDoNotAcquireSongForm() {
        let silence = passage(0, 64, energy: 0, bass: 0, pitch: 0, rhythm: 0)
        let result = TrackArrangement.prepare(analysis: analysis(seconds: 64), features: silence)
        XCTAssertFalse(
            result.sections.contains { $0.role == .verse || $0.role == .chorus || $0.behaviour == .dropping })
        XCTAssertFalse(result.landmarks.contains { $0.kind == .mixIn || $0.kind == .vocal })
        XCTAssertNil(result.rhythmicEnd)
    }
    func testManualPreparationSurvivesNewAutomaticEvidence() {
        var result = TrackArrangement.prepare(
            analysis: analysis(seconds: 64), features: passage(0, 64, energy: 0.3, bass: 0.5, pitch: 0))
        let saved = TrackArrangement(
            sections: [.init(start: 0, end: 64_000, role: .bridge, name: "Erik", locked: true)],
            landmarks: [.init(frame: 1234, name: "Pickup", kind: .vocal, state: .accepted, locked: true)],
            musicalEnd: 64_000, rhythmicEnd: nil)
        result.retainCorrections(from: saved)
        XCTAssertEqual(result.sections.first?.name, "Erik")
        XCTAssertTrue(result.landmarks.contains { $0.frame == 1234 && $0.locked })
    }
    func testActualCachedPCMProducesFiniteFeaturesWithoutInventingVocals() throws {
        let rate = 16000.0
        let seconds = 12
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pcm")
        defer { try? FileManager.default.removeItem(at: url) }
        var samples = [Float]()
        for frame in 0..<Int(rate * Double(seconds)) {
            let time = Double(frame) / rate
            let envelope = exp(-time.truncatingRemainder(dividingBy: 0.5) * 25)
            let x = Float(0.4 * envelope * sin(2 * Double.pi * 90 * time) + 0.05 * sin(2 * Double.pi * 440 * time))
            samples.append(x)
            samples.append(x)
        }
        try samples.withUnsafeBytes { try Data($0).write(to: url) }
        let a = AudioAnalysis(
            implementation: "PCM fixture", configurationID: "fixture", contentSHA256: "fixture", sampleRate: rate,
            frameCount: Int64(rate * Double(seconds)), channelCount: 2, waveformFramesPerBin: Int(rate),
            waveform: (0..<seconds).map { _ in .init(minimum: -0.5, maximum: 0.5, rms: 0.1) }, bpm: 120,
            beatAnchorFrame: 0, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
        let features = try MusicalStructureAnalyzer.analyze(pcm: url, analysis: a)
        XCTAssertEqual(features.count, seconds)
        XCTAssertTrue(
            features.allSatisfy { $0.rms.isFinite && $0.rms > 0 && $0.bands.count == 6 && $0.chroma.count == 12 })
        XCTAssertTrue(features.contains { $0.rhythm > 0.2 })
        XCTAssertTrue(features.allSatisfy { $0.vocal != nil })
        let arrangement = TrackArrangement.prepare(analysis: a, features: features)
        XCTAssertFalse(arrangement.landmarks.contains { $0.kind == .vocal })
        XCTAssertTrue(arrangement.isValid(fileEnd: Double(a.frameCount)))
        struct Cancelled: Error {}
        do {
            _ = try MusicalStructureAnalyzer.analyze(pcm: url, analysis: a, checkCancellation: { throw Cancelled() })
            XCTFail("Cancellation must stop preparation.")
        } catch is Cancelled {}
    }

}
