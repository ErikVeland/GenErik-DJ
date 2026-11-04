import Foundation
import XCTest

@testable import TDJCore

final class DenseBeatAlignmentTests: XCTestCase {
    func testCreepRemixKeepsEveryKickAndTheOpeningAttack() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let data = try Data(
            contentsOf: root.appendingPathComponent("docs/testing/checks/R43/2026-11-04-creep-grid/creep-opening.json"))
        let value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let frames = (value["frames"] as! [[Double]]).map { row in
            MusicalPulseFrame(
                rms: row[0], bass: row[1], middle: row[2], high: row[3], attackFrame: row[4], rise: row[5])
        }
        let result = try MusicalRhythmAnalyzer.analyze(
            frames: frames, sampleRate: 44100, framesPerBin: 221, spectralActivity: 0.246, configuration: .init(),
            checkCancellation: {})
        XCTAssertEqual(result.bpm ?? -1, 136.017, accuracy: 0.06)
        XCTAssertEqual(result.anchorSeconds ?? -1, 0.1836, accuracy: 0.025)
        let last = (result.anchorSeconds ?? 0) + 64 * 60 / (result.bpm ?? 1)
        XCTAssertEqual(last, 28.4154, accuracy: 0.035)
    }
    func testCachedStereoGridDetectionRejectsMissingFramesAndCancels() throws {
        let source = AudioAnalysis(
            implementation: "fixture", configurationID: "fixture", contentSHA256: String(repeating: "a", count: 64),
            sampleRate: 1000, frameCount: 16000, channelCount: 2, waveformFramesPerBin: 10, waveform: [], bpm: 68,
            beatAnchorFrame: 633, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pcm")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0, count: 16000 * 8).write(to: url)
        XCTAssertNil(try AudioAnalyzer.detectBeatGrid(pcm: url, matching: source))
        struct Cancelled: Error {}
        do {
            _ = try AudioAnalyzer.detectBeatGrid(pcm: url, matching: source, checkCancellation: { throw Cancelled() })
            XCTFail("Cancellation must stop grid detection.")
        } catch is Cancelled {}
        try Data(repeating: 0, count: 16000 * 8 - 8).write(to: url)
        do {
            _ = try AudioAnalyzer.detectBeatGrid(pcm: url, matching: source)
            XCTFail("A partial cache must not produce a grid.")
        } catch is CoreError {}
    }

    func testCachedStereoPulsesKeepAnOpeningBeatWithOppositeChannels() throws {
        let rate = 8000.0
        let count = Int(16 * rate)
        var samples = [Float](repeating: 0, count: count * 2)
        for beat in 0..<32 {
            let start = Int(Double(beat) * 0.5 * rate)
            for offset in 0..<480 where start + offset < count {
                let time = Double(offset) / rate
                let value = Float(0.4 * exp(-time * 150) * cos(2 * Double.pi * 110 * time))
                samples[(start + offset) * 2] = value
                samples[(start + offset) * 2 + 1] = -value
            }
        }
        let source = AudioAnalysis(
            implementation: "fixture", configurationID: "fixture", contentSHA256: String(repeating: "b", count: 64),
            sampleRate: rate, frameCount: Int64(count), channelCount: 2, waveformFramesPerBin: 80, waveform: [],
            bpm: 60, beatAnchorFrame: 4000, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pcm")
        defer { try? FileManager.default.removeItem(at: url) }
        try samples.withUnsafeBytes { try Data($0).write(to: url) }
        guard let result = try AudioAnalyzer.detectBeatGrid(pcm: url, matching: source) else {
            XCTFail("Opposite channels must retain the audible pulse.")
            return
        }
        XCTAssertEqual(result.grid.bpm, 120, accuracy: 0.04)
        XCTAssertEqual(result.grid.anchorFrame / rate, 0, accuracy: 0.015)
    }

}
