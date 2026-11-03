import Foundation
import XCTest
@testable import TDJCore

final class ChorusEvidenceTests: XCTestCase {
    private func analysis(seconds: Int) -> AudioAnalysis {
        .init(implementation: "fixture", configurationID: "fixture", contentSHA256: "fixture", sampleRate: 1000,
              frameCount: Int64(seconds * 1000), channelCount: 2, waveformFramesPerBin: 1000, waveform: [],
              bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    }

    private func passage(_ start: Int, _ end: Int, pitch: Int, rms: Double = 0.5,
                         vocal: Double = 0.9, rhythm: Double = 0.7) -> [MusicalStructureFrame] {
        (start..<end).map { second in
            var chroma = [Double](repeating: 0, count: 12)
            chroma[pitch] = 1
            return .init(start: Double(second * 1000), end: Double((second + 1) * 1000), rms: rms,
                         bass: 0.5, rhythm: rhythm, bands: [0.3, 0.1, 0.2, 0.2, 0.1, 0.1], chroma: chroma, vocal: vocal)
        }
    }

    func testLoopedBackingDoesNotEstablishAChorus() {
        let frames = (0..<8).flatMap { part in
            passage(part * 16, (part + 1) * 16, pitch: 0,
                    vocal: part.isMultiple(of: 2) ? 0.5 : 0.95, rhythm: part.isMultiple(of: 2) ? 0.1 : 0.8)
        }
        let result = TrackArrangement.prepare(analysis: analysis(seconds: 128), features: frames)
        XCTAssertTrue(result.sections.count > 2)
        XCTAssertFalse(result.sections.contains { $0.role == .chorus })
        XCTAssertFalse(result.landmarks.contains { $0.kind == .mainReturn })
        XCTAssertTrue(result.sections.contains { $0.name == "Vocal section" && $0.role == .unknown })
    }

    func testEqualAveragesWithDifferentOrderDoNotEstablishARepeatedHook() {
        var frames = passage(0, 16, pitch: 4, rms: 0.1, vocal: 0)
        frames += passage(16, 40, pitch: 2, rms: 0.25)
        frames += passage(40, 64, pitch: 0)
        frames += passage(64, 88, pitch: 2, rms: 0.25)
        frames += passage(88, 112, pitch: 0)
        frames += passage(112, 128, pitch: 4, rms: 0.1, vocal: 0)
        for i in 40..<64 {
            frames[i].chroma[0] = i < 52 ? 0.65 : 0.35
            frames[i].chroma[7] = i < 52 ? 0.35 : 0.65
        }
        for i in 88..<112 {
            frames[i].chroma[0] = i < 100 ? 0.35 : 0.65
            frames[i].chroma[7] = i < 100 ? 0.65 : 0.35
        }
        let result = TrackArrangement.prepare(analysis: analysis(seconds: 128), features: frames)
        XCTAssertFalse(result.sections.contains { $0.role == .chorus })
    }

    func testDistinctRecurringRefrainsHaveNoArbitraryCountLimit() {
        let frames = (0..<18).flatMap { part in
            passage(part * 16, (part + 1) * 16, pitch: part.isMultiple(of: 2) ? 2 : 7,
                    rms: part.isMultiple(of: 2) ? 0.25 : 0.5)
        }
        let result = TrackArrangement.prepare(analysis: analysis(seconds: 288), features: frames)
        XCTAssertEqual(result.sections.filter { $0.role == .chorus }.count, 9)
        XCTAssertEqual(result.section(at: 8_000)?.role, .verse)
    }

    func test99ProblemsDoesNotLabelNearlyTheEntireRecordingAsChorus() throws {
        struct Frame: Decodable {
            let start, end, rms, bass, rhythm: Double
            let bands, chroma: [Double]
            let vocal: Double?
            var value: MusicalStructureFrame {
                .init(start: start, end: end, rms: rms, bass: bass, rhythm: rhythm, bands: bands, chroma: chroma, vocal: vocal)
            }
        }
        struct Fixture: Decodable {
            let analysis: AudioAnalysis
            let frames: [Frame]
        }
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/99-problems-structure.json")
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let result = TrackArrangement.prepare(analysis: fixture.analysis, features: fixture.frames.map(\.value))
        let chorusDuration = result.sections.filter { $0.role == .chorus }.reduce(0) { $0 + $1.end - $1.start }
        XCTAssertTrue(chorusDuration < Double(fixture.analysis.frameCount) * 0.5)
        XCTAssertTrue(result.sections.contains { $0.name == "Vocal section" })
        XCTAssertTrue(result.isValid(fileEnd: Double(fixture.analysis.frameCount)))
    }

    func testUncertainVocalLabelsReplaceGeneratedChorusCues() {
        let sections = [ArrangementSection(start: 0, end: 1000, role: .unknown, name: "Vocal section", labelConfidence: 0.5)]
        let manual = PerformanceCue(frame: 123, loopEnd: 456)
        let old = PerformanceCue(frame: 0, sectionName: "CHORUS ?", sectionColour: 0xF6AF69)
        let result = SectionCueAllocator.allocate(sections: sections, existing: [0: old, 1: manual], alreadyPrepared: true)
        XCTAssertEqual(result[0]?.sectionName, "Vocal section ?")
        XCTAssertEqual(result[1], manual)
        XCTAssertNil(result[2])
    }
}
