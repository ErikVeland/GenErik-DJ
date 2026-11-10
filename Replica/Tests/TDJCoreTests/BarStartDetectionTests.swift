import Foundation
import XCTest

@testable import TDJCore

final class BarStartDetectionTests: XCTestCase {
    private func pattern(pickup: Int = 0, uniform: Bool = false, triple: Bool = false) -> [MusicalPulseFrame] {
        let rate = 1000.0
        let bin = 5
        let period = 0.5
        let count = Int(42 * rate / Double(bin))
        var frames = (0..<count).map { i in
            MusicalPulseFrame(rms: 0, bass: 0, middle: 0, high: 0, attackFrame: Double(i * bin), rise: 0)
        }
        for beat in 0..<80 {
            let start = Int(((0.25 + Double(beat) * period) * rate / Double(bin)).rounded())
            let position = ((beat - pickup) % (triple ? 3 : 4) + (triple ? 3 : 4)) % (triple ? 3 : 4)
            let quiet = beat < pickup ? 0.08 : 1.0
            let bass = (triple && position == 0 ? 1.8 : 0.6) * quiet
            let middle = (!uniform && !triple && position == 1 ? 1.8 : 0.1) * quiet
            for delta in 0..<10 {
                let decay = exp(-Double(delta) * 0.4)
                let level = sqrt(bass * bass + middle * middle + 0.01) * decay
                frames[start + delta] = .init(
                    rms: level, bass: bass * decay, middle: middle * decay, high: 0.1 * quiet * decay,
                    attackFrame: Double((start + delta) * bin), rise: delta == 0 ? level : 0)
            }
        }
        return frames
    }
    private func detect(_ frames: [MusicalPulseFrame]) throws -> MusicalRhythmResult {
        try MusicalRhythmAnalyzer.analyze(
            frames: frames, sampleRate: 1000, framesPerBin: 5, spectralActivity: 0.2, configuration: .init(),
            checkCancellation: {})
    }
    func testLoudSnareOnBeatTwoCannotBecomeBeatOne() throws {
        let result = try detect(pattern())
        XCTAssertEqual(result.bpm ?? -1, 120, accuracy: 0.03)
        XCTAssertEqual(result.downbeat, 0)
    }
    func testQuietPickupDoesNotBecomeTheBarStart() throws {
        let result = try detect(pattern(pickup: 1))
        XCTAssertEqual(result.bpm ?? -1, 120, accuracy: 0.03)
        let bar = (result.anchorSeconds ?? -99) + Double(result.downbeat ?? -99) * 60 / (result.bpm ?? 1)
        XCTAssertEqual(bar, 0.75, accuracy: 0.025)
    }
    func testUnaccentedPulseDoesNotInventABar() throws { XCTAssertNil(try detect(pattern(uniform: true)).downbeat) }
    func testTriplePatternDoesNotInventFourBeatBars() throws {
        XCTAssertNil(try detect(pattern(triple: true)).downbeat)
    }
    func testCreepOpeningKeepsAlignmentUntilFullContextIsAvailable() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let data = try Data(
            contentsOf: root.appendingPathComponent("docs/testing/checks/R43/2026-11-04-creep-grid/creep-opening.json"))
        let value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let frames = (value["frames"] as! [[Double]]).map { r in
            MusicalPulseFrame(rms: r[0], bass: r[1], middle: r[2], high: r[3], attackFrame: r[4], rise: r[5])
        }
        let tonal =
            try JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: root.appendingPathComponent(
                        "docs/testing/checks/R43/2026-11-04-auto-bars/creep-harmony.json"))) as! [[String: Any]]
        let harmony = tonal.map {
            MusicalHarmonicFrame(seconds: $0["seconds"] as! Double, chroma: $0["chroma"] as! [Double])
        }
        let result = try MusicalRhythmAnalyzer.analyze(
            frames: frames, sampleRate: 44100, framesPerBin: 221, spectralActivity: 0.246, configuration: .init(),
            harmonicFrames: harmony, checkCancellation: {})
        XCTAssertNil(result.downbeat)
        XCTAssertEqual(result.anchorSeconds ?? -1, 0.1836, accuracy: 0.025)
    }
    func testHarmonicChangesIdentifyABarAfterAnUnaccentedPickup() throws {
        var harmony = [MusicalHarmonicFrame]()
        for beat in 0..<80 {
            let roots = [0, 5, 7, 9]
            let bar = (beat + 399) / 4
            let root = roots[bar % roots.count]
            var chroma = [Double](repeating: 0, count: 12)
            chroma[root] = 0.5
            chroma[(root + 4) % 12] = 0.25
            chroma[(root + 7) % 12] = 0.25
            harmony.append(.init(seconds: 0.33 + Double(beat) * 0.5, chroma: chroma))
        }
        let result = try MusicalRhythmAnalyzer.analyze(
            frames: pattern(uniform: true), sampleRate: 1000, framesPerBin: 5, spectralActivity: 0.2,
            configuration: .init(), harmonicFrames: harmony, checkCancellation: {})
        XCTAssertEqual(result.downbeat, 1)
    }
    func testOnlyUneditedUnlockedInheritedGridsMayRefresh() throws {
        let original = try BeatGrid(bpm: 68, anchorFrame: 633, sampleRate: 1000)
        let edited = try BeatGrid(bpm: 136, anchorFrame: 180, sampleRate: 1000)
        let cases: [(Bool, Bool, Bool, Bool, BeatGrid?, BeatGrid?, Bool, Bool)] = [
            (true, false, false, false, original, original, true, true),
            (true, true, false, false, original, original, true, false),
            (true, false, true, false, original, original, true, false),
            (true, false, false, true, original, original, true, false),
            (true, false, false, false, edited, original, true, false),
            (true, false, false, false, original, original, false, false),
            (true, false, false, false, original, nil, false, false),
            (false, false, false, false, original, nil, false, true),
        ]
        for (manual, user, locked, adaptive, current, imported, unlocked, expected) in cases {
            XCTAssertEqual(
                AutomaticGridPolicy.mayRefresh(
                    isManual: manual, wasEditedByUser: user, isLocked: locked, hasAdaptiveMap: adaptive,
                    current: current, imported: imported, importIsUnlocked: unlocked), expected)
        }
    }

    func testUserGridEditsSurviveSavingAndLegacyPreparationStillDecodes() throws {
        var prep = try JSONDecoder().decode(Preparation.self, from: Data("{\"gridIsManual\":true}".utf8))
        XCTAssertNil(prep.gridWasEditedByUser)
        prep.gridWasEditedByUser = true
        let restored = try JSONDecoder().decode(Preparation.self, from: JSONEncoder().encode(prep))
        XCTAssertEqual(restored.gridWasEditedByUser, true)
    }
    func testBarAnalysisVersionSurvivesWaveformReplacement() throws {
        var value = AudioAnalysis(
            implementation: "fixture", configurationID: "fixture", contentSHA256: String(repeating: "a", count: 64),
            sampleRate: 1000, frameCount: 10000, channelCount: 2, waveformFramesPerBin: 10, waveform: [], bpm: 120,
            beatAnchorFrame: 250, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
        value.barAnalysisVersion = 1
        XCTAssertEqual(value.replacingWaveform([]).barAnalysisVersion, 1)
        let decoded = try JSONDecoder().decode(AudioAnalysis.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(decoded.barAnalysisVersion, 1)
    }

    func testCreepFullTimelineFindsTheOpeningBar() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let file = root.appendingPathComponent("docs/testing/checks/R43/2026-11-04-auto-bars/creep-bar-frames.json")
        let beats = try JSONDecoder().decode([MusicalBarFrame].self, from: Data(contentsOf: file))
        let result = try MusicalRhythmAnalyzer.barStart(beats: beats)
        XCTAssertEqual(result.offset, 0)
        XCTAssertGreaterThanOrEqual(result.confidence ?? 0, 0.55)
    }
    func testCreepDetectedBarReplacesOnlyTheUntouchedImport() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let data = try Data(
            contentsOf: root.appendingPathComponent(
                "docs/testing/checks/R43/2026-11-04-auto-bars/creep-preparation.json"))
        let value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let decoder = JSONDecoder()
        var prep = try decoder.decode(
            Preparation.self, from: JSONSerialization.data(withJSONObject: value["preparation"]!))
        var analysis = try decoder.decode(
            AudioAnalysis.self, from: JSONSerialization.data(withJSONObject: value["analysis"]!))
        let original = try decoder.decode(
            BeatGrid.self, from: JSONSerialization.data(withJSONObject: value["importedGrid"]!))
        XCTAssertNil(prep.detectedBarGrid(analysis: analysis, imported: original, importIsUnlocked: true))
        analysis.barAnalysisVersion = BarStartAnalysis.version
        let adopted = prep.detectedBarGrid(analysis: analysis, imported: original, importIsUnlocked: true)
        XCTAssertEqual(adopted?.bpm ?? -1, 136.017769, accuracy: 0.0001)
        XCTAssertEqual((adopted?.anchorFrame ?? -44100) / 44100, 0.180408, accuracy: 0.01)
        XCTAssertEqual(adopted?.downbeatOffset, 0)
        XCTAssertEqual(prep.grid, original)
        prep.gridWasEditedByUser = true
        XCTAssertNil(prep.detectedBarGrid(analysis: analysis, imported: original, importIsUnlocked: true))
        prep.gridWasEditedByUser = nil
        prep.gridLocked = true
        XCTAssertNil(prep.detectedBarGrid(analysis: analysis, imported: original, importIsUnlocked: true))
        prep.gridLocked = false
        analysis.barAnalysisVersion = nil
        XCTAssertNil(prep.detectedBarGrid(analysis: analysis, imported: original, importIsUnlocked: true))
        analysis.barAnalysisVersion = BarStartAnalysis.version
        analysis.downbeatConfidence = 0.6
        XCTAssertNil(prep.detectedBarGrid(analysis: analysis, imported: original, importIsUnlocked: true))
        analysis.downbeatConfidence = 0.783
        let unrelated = try BeatGrid(bpm: 90, anchorFrame: 633, sampleRate: 44100)
        prep.grid = unrelated
        XCTAssertNil(prep.detectedBarGrid(analysis: analysis, imported: unrelated, importIsUnlocked: true))
    }

}
