import Foundation
import XCTest
@testable import TDJCore

final class GenreVersionStructureTests: XCTestCase {
    private func analysis() -> AudioAnalysis {
        .init(implementation: "fixture", configurationID: "fixture", contentSHA256: "fixture", sampleRate: 1000,
              frameCount: 128_000, channelCount: 2, waveformFramesPerBin: 1000, waveform: [],
              bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    }
    private func features(vocals: Bool = true) -> [MusicalStructureFrame] {
        (0..<128).map { i in
            .init(start: Double(i*1000), end: Double((i+1)*1000), rms: 0.4, bass: 0.6, rhythm: 0.9,
                  bands: [0.3,0.2,0.2,0.1,0.1,0.1], chroma: [1,0,0,0,0,0,0,0,0,0,0,0],
                  vocal: vocals && (32..<96).contains(i) ? 0.9 : 0.02)
        }
    }
    func testDanceGenreRecognisesFullLevelMixingSections() {
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(),
                                           context: .init(title: "Track", genre: "House"))
        XCTAssertEqual(result.section(at: 16_000)?.role, .intro)
        XCTAssertEqual(result.section(at: 112_000)?.role, .outro)
        XCTAssertEqual(result.sections.first?.end, 32_000)
        XCTAssertEqual(result.sections.last?.start, 96_000)
        XCTAssertEqual(result.sections.first?.name, "Rhythmic intro")
    }
    func testExtendedVersionCanOverrideBroadPopTagWithAudioEvidence() {
        let frames=features()
        let extended=TrackArrangement.prepare(analysis: analysis(), features: frames,
                                             context: .init(title: "Track (Extended Mix)", genre: "Pop"))
        let radio=TrackArrangement.prepare(analysis: analysis(), features: frames,
                                          context: .init(title: "Track (Radio Edit)", genre: "Pop"))
        XCTAssertEqual(extended.section(at: 16_000)?.role, .intro)
        XCTAssertEqual(extended.section(at: 112_000)?.role, .outro)
        XCTAssertEqual(radio.sections.map(\.role), TrackArrangement.prepare(analysis: analysis(), features: frames).sections.map(\.role))
        XCTAssertFalse(radio.sections.contains { $0.name == "Rhythmic intro" || $0.name == "Rhythmic outro" })
    }
    func testInstrumentalLoopIsNotAnEntireTrackIntroOrOutro() {
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(vocals: false),
                                           context: .init(title: "Groove (12\" Mix)", genre: "Disco"))
        XCTAssertFalse(result.sections.contains { $0.role == .intro || $0.role == .outro })
    }
    func testTwelveInchVersionUsesEvidenceWithoutAGenreTag() {
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(), context: .init(title: "Track (12'' Mix)"))
        XCTAssertEqual(result.section(at: 16_000)?.role, .intro)
        XCTAssertEqual(result.section(at: 112_000)?.role, .outro)
    }
    func testVersionTitleCannotInventInstrumentalEdgesOverVocals() {
        var frames=features()
        for i in frames.indices { frames[i].vocal=0.9 }
        let result=TrackArrangement.prepare(analysis: analysis(), features: frames, context: .init(title: "Track (Extended Mix)", genre: "House"))
        XCTAssertFalse(result.sections.contains { $0.role == .intro || $0.role == .outro })
    }
    func testAcappellaAndMissingVocalEvidenceDoNotBecomeMixingSections() {
        var frames=features()
        let acappella=TrackArrangement.prepare(analysis: analysis(), features: frames,
                                              context: .init(title: "Song (Extended A Cappella)", genre: "Dance"))
        XCTAssertFalse(acappella.sections.contains { $0.name.hasPrefix("Rhythmic") })
        for i in frames.indices { frames[i].vocal=nil }
        let missing=TrackArrangement.prepare(analysis: analysis(), features: frames,
                                            context: .init(title: "Song (Extended Mix)", genre: "House"))
        XCTAssertFalse(missing.sections.contains { $0.name.hasPrefix("Rhythmic") })
    }
    func testSustainedRhythmBreakRemainsOutsideTheIntro() {
        var frames=features()
        for i in 32..<48 { frames[i].vocal=0.02; frames[i].rhythm=0.05; frames[i].bass=0.02 }
        let result=TrackArrangement.prepare(analysis: analysis(), features: frames,
                                           context: .init(title: "Track (Extended Mix)", genre: "House"))
        XCTAssertEqual(result.section(at: 16_000)?.role, .intro)
        XCTAssertFalse(result.section(at: 40_000)?.role == .intro)
        XCTAssertTrue(result.sections.contains { $0.start == 32_000 })
    }
    private struct RecordedFrame: Decodable {
        let start, end, rms, bass, rhythm: Double
        let bands, chroma: [Double]
        let vocal: Double?
        var value: MusicalStructureFrame {
            .init(start: start, end: end, rms: rms, bass: bass, rhythm: rhythm, bands: bands, chroma: chroma, vocal: vocal)
        }
    }
    private struct Fixture: Decodable {
        let title, genre: String
        let analysis: AudioAnalysis
        let frames: [RecordedFrame]
    }
    private func fixture(_ name: String) throws -> Fixture {
        let url=URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/"+name+".json")
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }
    func testHarrisonExtendedMixConsolidatesMeasuredInstrumentalEdges() throws {
        let f=try fixture("harrison-extended-structure")
        let result=TrackArrangement.prepare(analysis: f.analysis, features: f.frames.map(\.value), context: .init(title: f.title, genre: f.genre))
        XCTAssertEqual(result.section(at: 20*f.analysis.sampleRate)?.role, .intro)
        XCTAssertEqual(result.sections.first!.end/f.analysis.sampleRate, 30, accuracy: 2)
        XCTAssertEqual(result.section(at: 210*f.analysis.sampleRate)?.role, .outro)
        XCTAssertTrue(result.sections.count < 15)
        XCTAssertTrue(result.isValid(fileEnd: Double(f.analysis.frameCount)))
    }
    func testTiestoExtendedMixKeepsTheOpeningRhythmBreak() throws {
        let f=try fixture("tiesto-extended-structure")
        let result=TrackArrangement.prepare(analysis: f.analysis, features: f.frames.map(\.value), context: .init(title: f.title, genre: f.genre))
        XCTAssertEqual(result.section(at: 20*f.analysis.sampleRate)?.role, .intro)
        XCTAssertEqual(result.sections.first!.end/f.analysis.sampleRate, 32, accuracy: 2)
        XCTAssertFalse(result.section(at: 40*f.analysis.sampleRate)?.role == .intro)
        XCTAssertEqual(result.section(at: 205*f.analysis.sampleRate)?.role, .outro)
        XCTAssertTrue(result.sections.count < 14)
    }
    func testMergedAutomaticCuesKeepTheirFramesAndManualCues() {
        let sections=[ArrangementSection(start: 0, end: 32_000, role: .intro, name: "Rhythmic intro")]
        let old=PerformanceCue(frame: 16_000, sectionName: "INSTRUMENTAL", sectionColour: 0x8592A5)
        let manual=PerformanceCue(frame: 20_000, loopEnd: 24_000)
        let result=SectionCueAllocator.allocate(sections: sections, existing: [0:old,1:manual], alreadyPrepared: true)
        XCTAssertEqual(result[0]?.sectionName, "Rhythmic intro")
        XCTAssertEqual(result[0]?.frame, 16_000)
        XCTAssertEqual(result[1], manual)
        XCTAssertNil(result[2])
    }
}
