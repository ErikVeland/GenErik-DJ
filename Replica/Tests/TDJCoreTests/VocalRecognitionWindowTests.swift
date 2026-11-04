import Foundation
import XCTest

@testable import TDJCore

final class VocalRecognitionWindowTests: XCTestCase {
    private func frames(rate: Double = 1000, voice: (Int) -> Double?) -> [MusicalStructureFrame] {
        (0..<240).map { second in
            .init(
                start: Double(second) * rate, end: Double(second + 1) * rate, rms: 0.4, bass: 0.6, rhythm: 0.8,
                bands: [], chroma: [], vocal: voice(second))
        }
    }
    func testExtendedIntroDoesNotFillTheRecognitionWindow() {
        let result = VocalRecognitionWindow.plan(
            features: frames { (64..<128).contains($0) ? 0.8 : 0.02 }, sampleRate: 1000, frameCount: 240_000)
        XCTAssertEqual(result.first?.coreStart, 64_000)
        XCTAssertEqual(result.first?.start, 64_000)
        XCTAssertEqual(result.first?.end, 94_000)
        XCTAssertTrue(result.allSatisfy { $0.end - $0.start <= 30_000 })
    }
    func testLongInstrumentalBreakDoesNotTriggerMoreRecognition() {
        let result = VocalRecognitionWindow.plan(
            features: frames { (32..<56).contains($0) || (160..<184).contains($0) ? 0.8 : 0.02 }, sampleRate: 1000,
            frameCount: 240_000)
        XCTAssertFalse(result.contains { $0.coreStart >= 80_000 && $0.coreEnd <= 150_000 })
        XCTAssertTrue(result.contains { $0.coreStart >= 148_000 })
        XCTAssertTrue(zip(result, result.dropFirst()).allSatisfy { $0.coreEnd <= $1.coreStart })
    }
    func testMissingVoiceAndInstrumentalEvidenceDoNotForceWords() {
        XCTAssertTrue(
            VocalRecognitionWindow.plan(features: frames { _ in nil }, sampleRate: 1000, frameCount: 240_000).isEmpty)
        XCTAssertTrue(
            VocalRecognitionWindow.plan(features: frames { _ in 0.07 }, sampleRate: 1000, frameCount: 240_000).isEmpty)
        XCTAssertTrue(
            VocalRecognitionWindow.plan(
                features: frames { $0.isMultiple(of: 50) ? 0.9 : 0.02 }, sampleRate: 1000, frameCount: 240_000
            ).isEmpty)
    }
    func testContextAndOwnershipStayOnTheOriginalTimeline() {
        let result = VocalRecognitionWindow.plan(features: frames { _ in 0.8 }, sampleRate: 1000, frameCount: 240_000)
        XCTAssertEqual(result.first?.start, 0)
        XCTAssertEqual(result.first?.coreStart, 0)
        XCTAssertEqual(result.last?.coreEnd, 240_000)
        XCTAssertEqual(result.last?.end, 240_000)
        XCTAssertTrue(
            result.allSatisfy { $0.start <= $0.coreStart && $0.end >= $0.coreEnd && $0.start >= 0 && $0.end <= 240_000 }
        )
    }
    func testSampleRateDoesNotChangeWindowTimes() {
        let low = VocalRecognitionWindow.plan(
            features: frames { (64..<128).contains($0) ? 0.8 : 0.02 }, sampleRate: 1000, frameCount: 240_000)
        for rate in [44_100.0, 48_000] {
            let high = VocalRecognitionWindow.plan(
                features: frames(rate: rate) { (64..<128).contains($0) ? 0.8 : 0.02 }, sampleRate: rate,
                frameCount: Int64(240 * rate))
            XCTAssertEqual(high.map { $0.start / rate }, low.map { $0.start / 1000 })
            XCTAssertEqual(high.map { $0.coreEnd / rate }, low.map { $0.coreEnd / 1000 })
        }
    }
    func testSparseClassifierHitsDoNotCreateMostlyInstrumentalWindows() {
        let result = VocalRecognitionWindow.plan(
            features: frames { [32, 36, 40].contains($0) ? 0.8 : 0.02 }, sampleRate: 1000, frameCount: 240_000)
        XCTAssertTrue(result.isEmpty)
    }
    func testDanCrollIncludesTheMeasuredStrongestVocalWindow() throws {
        struct Frame: Decodable { let start, end, vocal: Double }
        struct Fixture: Decodable {
            let sampleRate: Double
            let frameCount: Int64
            let frames: [Frame]
        }
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(
            "Fixtures/dan-croll-vocal-windows.json")
        let f = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let values = f.frames.map {
            MusicalStructureFrame(
                start: $0.start, end: $0.end, rms: 0.4, bass: 0.5, rhythm: 0.8, bands: [], chroma: [], vocal: $0.vocal)
        }
        let result = VocalRecognitionWindow.plan(features: values, sampleRate: f.sampleRate, frameCount: f.frameCount)
        XCTAssertTrue(result.contains { abs($0.start / f.sampleRate - 120) < 0.001 })
    }
}
