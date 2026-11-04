import Foundation
import XCTest
@testable import TDJCore

final class VocalFormTests: XCTestCase {
    private func analysis() -> AudioAnalysis {
        .init(implementation: "fixture", configurationID: "fixture", contentSHA256: "fixture", sampleRate: 1000,
              frameCount: 160_000, channelCount: 2, waveformFramesPerBin: 1000, waveform: [],
              bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1, key: nil, keyConfidence: 0, chroma: [], timbre: [])
    }
    private func features(sung: Bool = false, voice: Double = 0.9) -> [MusicalStructureFrame] {
        (0..<160).map { i in
            .init(start: Double(i*1000), end: Double((i+1)*1000), rms: 0.4, bass: 0.5, rhythm: 0.8,
                  bands: [0.3,0.2,0.2,0.1,0.1,0.1], chroma: [1,0,0,0,0,0,0,0,0,0,0,0],
                  vocal: voice, rapping: sung ? 0.02:0.8, singing: sung ? 0.8:0.02)
        }
    }
    private func phrases() -> [VocalPhrase] {
        var values=[VocalPhrase]()
        for start in [8,72] {
            for line in 0..<8 {
                values.append(.init(start: Double((start+line*4)*1000), end: Double((start+line*4+4)*1000),
                    words: (0..<10).map { UInt64(1000+start*100+line*10+$0) }, confidence: 0.9))
            }
        }
        for start in [40,104] {
            values.append(.init(start: Double(start*1000), end: Double((start+6)*1000), words: Array(1...12), confidence: 0.9))
            values.append(.init(start: Double((start+6)*1000), end: Double((start+12)*1000), words: Array(13...24), confidence: 0.9))
        }
        return values.sorted { $0.start < $1.start }
    }
    func testRapRefrainsBecomeHooksAndUniquePassagesBecomeVerses() {
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(), context: .init(genre: "Hip-Hop"), vocalPhrases: phrases())
        XCTAssertEqual(result.section(at: 20_000)?.role, .verse)
        XCTAssertEqual(result.section(at: 44_000)?.role, .hook)
        XCTAssertEqual(result.section(at: 90_000)?.role, .verse)
        XCTAssertEqual(result.sections.filter { $0.role == .hook }.count, 2)
        XCTAssertTrue(result.isValid(fileEnd: 160_000))
    }
    func testSungRefrainsBecomeChorusesWithNoArbitraryCountLimit() {
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(sung: true), context: .init(genre: "Pop"), vocalPhrases: phrases())
        XCTAssertEqual(result.section(at: 44_000)?.role, .chorus)
        XCTAssertEqual(result.section(at: 108_000)?.role, .chorus)
        XCTAssertEqual(result.section(at: 20_000)?.role, .verse)
    }
    func testBackingAndLowConfidenceWordsCannotInventVocalRoles() {
        let silent=TrackArrangement.prepare(analysis: analysis(), features: features(voice: 0.01), vocalPhrases: phrases())
        XCTAssertFalse(silent.sections.contains { $0.role == .verse || $0.role == .hook || $0.role == .chorus })
        var uncertain=phrases()
        for i in uncertain.indices { uncertain[i].confidence=0.1 }
        let baseline=TrackArrangement.prepare(analysis: analysis(), features: features())
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(), vocalPhrases: uncertain)
        XCTAssertEqual(result.sections.map(\.role), baseline.sections.map(\.role))
        XCTAssertEqual(result.sections.map(\.start), baseline.sections.map(\.start))
        XCTAssertEqual(result.sections.map(\.end), baseline.sections.map(\.end))
    }
    func testShortRepeatedSampleIsAHookAndDoesNotCreateVerses() {
        let samples=[16,48,80,112].map { start in
            VocalPhrase(start: Double(start*1000), end: Double((start+4)*1000), words: Array(1...6), confidence: 0.9)
        }
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(sung: true),
            context: .init(title: "Track (12\" Dub Mix)", genre: "House"), vocalPhrases: samples)
        XCTAssertFalse(result.sections.contains { $0.role == .chorus || $0.role == .verse })
        XCTAssertEqual(result.sections.filter { $0.role == .hook }.count, 4)
    }
    func testAnAdlibDoesNotSplitOneRefrainIntoSeveralSections() {
        var words=phrases()
        for start in [46,110] {
            words.append(.init(start: Double(start*1000), end: Double((start+1)*1000), words: [900,901], confidence: 0.9))
        }
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(), vocalPhrases: words)
        XCTAssertEqual(result.sections.filter { $0.role == .hook }.count, 2)
        XCTAssertEqual(result.sections.first { $0.role == .hook }?.end, 52_000)
    }
    func testWordNormalisationKeepsStableHashesWithoutSavingText() throws {
        let a=VocalPhrase(start: 0, end: 1000, text: "We’re HERE, in the night!", confidence: 0.9)
        let b=VocalPhrase(start: 0, end: 1000, text: "we're here in the NIGHT", confidence: 0.9)
        XCTAssertEqual(a.words, b.words)
        let encoded=String(decoding: try JSONEncoder().encode(a), as: UTF8.self)
        XCTAssertFalse(encoded.lowercased().contains("night"))
    }
    func testMissedWordsDoNotSplitAContinuousRapVerse() {
        let words=phrases().filter { !((72_000..<84_000).contains($0.start)) }
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(), vocalPhrases: words)
        XCTAssertEqual(result.section(at: 76_000)?.role, .verse)
        XCTAssertEqual(result.sections.first { $0.role == .verse && $0.start > 40_000 }?.start, 52_000)
    }
    func testVocalContinuityCannotExtendAVerseAcrossAnInstrumentalGap() {
        let words=phrases().filter { !((72_000..<84_000).contains($0.start)) }
        var frames=features()
        for i in 52..<84 { frames[i].vocal=0.01 }
        let result=TrackArrangement.prepare(analysis: analysis(), features: frames, vocalPhrases: words)
        XCTAssertFalse(result.section(at: 76_000)?.role == .verse)
        XCTAssertEqual(result.section(at: 90_000)?.role, .verse)
    }
    func testNineRealRefrainsAreNotLimitedToThree() {
        var words=[VocalPhrase]()
        for start in stride(from: 0, through: 144, by: 18) {
            words.append(.init(start: Double(start*1000), end: Double((start+4)*1000), words: Array(1...12), confidence: 0.9))
            words.append(.init(start: Double((start+4)*1000), end: Double((start+8)*1000), words: Array(13...24), confidence: 0.9))
        }
        let result=TrackArrangement.prepare(analysis: analysis(), features: features(sung: true), vocalPhrases: words)
        XCTAssertEqual(result.sections.filter { $0.role == .chorus }.count, 9)
    }
    func testExtendedInstrumentalEdgesDoNotDiluteASungChorus() {
        var frames=features(sung: true, voice: 0.01)
        for i in frames.indices {
            let singing=(40..<52).contains(i) || (104..<116).contains(i)
            frames[i].vocal=singing ? 0.9:0.01
            frames[i].singing=singing ? 0.8:0.01
        }
        let result=TrackArrangement.prepare(analysis: analysis(), features: frames,
            context: .init(title: "Song (Extended Mix)", genre: "Dance"), vocalPhrases: phrases())
        XCTAssertEqual(result.section(at: 44_000)?.role, .chorus)
        XCTAssertEqual(result.section(at: 108_000)?.role, .chorus)
    }
    func testLyricRolesReplaceOldAcousticVerseSubdivisions() {
        var result=TrackArrangement(sections: stride(from: 0, to: 160, by: 8).map {
            .init(start: Double($0*1000), end: Double(($0+8)*1000), role: .verse)
        }, landmarks: [], musicalEnd: 160_000, rhythmicEnd: nil)
        result.prepareVocalForm(phrases: phrases(), features: features(), analysis: analysis(), context: .init())
        XCTAssertEqual(result.sections.filter { $0.role == .verse }.count, 2)
        XCTAssertEqual(result.sections.filter { $0.role == .hook }.count, 2)
    }
    func testRepeatedSungRefrainsShareTheirRoleAcrossDifferentMixLevels() {
        var frames=features(sung: true)
        for i in 40..<52 { frames[i].singing=0.2 }
        let result=TrackArrangement.prepare(analysis: analysis(), features: frames, vocalPhrases: phrases())
        XCTAssertEqual(result.section(at: 44_000)?.role, .chorus)
        XCTAssertEqual(result.section(at: 108_000)?.role, .chorus)
    }
    func test99ProblemsHasThreeVersesAndThreeMainHooks() throws {
        struct Frame: Decodable {
            let start, end, rms, bass, rhythm: Double
            let bands, chroma: [Double]
            let vocal, rapping, singing: Double?
            var value: MusicalStructureFrame {
                .init(start: start, end: end, rms: rms, bass: bass, rhythm: rhythm, bands: bands, chroma: chroma,
                      vocal: vocal, rapping: rapping, singing: singing)
            }
        }
        struct Fixture: Decodable { let analysis: AudioAnalysis; let frames: [Frame]; let phrases: [VocalPhrase] }
        let url=URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/99-problems-vocal-form.json")
        let f=try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let result=TrackArrangement.prepare(analysis: f.analysis, features: f.frames.map(\.value), context: .init(title: "99 Problems", genre: "Mashup"), vocalPhrases: f.phrases)
        let rate=f.analysis.sampleRate
        XCTAssertEqual(result.sections.filter { $0.role == .verse }.count, 3)
        XCTAssertEqual(result.sections.filter { $0.role == .hook && $0.name != "Opening hook" }.count, 3)
        XCTAssertEqual(result.sections.first?.name, "Opening hook")
        XCTAssertFalse(result.sections.contains { $0.role == .chorus })
        for second in [20,75,165] { XCTAssertEqual(result.section(at: Double(second)*rate)?.role, .verse) }
        for second in [48,125,205] { XCTAssertEqual(result.section(at: Double(second)*rate)?.role, .hook) }
        XCTAssertEqual(result.section(at: 230*rate)?.role, .outro)
        XCTAssertTrue(result.isValid(fileEnd: Double(f.analysis.frameCount)))
        let frames=[0.0,20*rate,48*rate,75*rate,125*rate,165*rate,205*rate,230*rate]
        var existing=[Int:PerformanceCue]()
        for (slot,frame) in frames.enumerated() { existing[slot] = .init(frame: frame, sectionName: "OLD", sectionColour: 0) }
        let cues=SectionCueAllocator.allocate(sections: result.sections, existing: existing, alreadyPrepared: true)
        XCTAssertEqual(cues[3]?.sectionName, "VERSE")
        XCTAssertEqual(cues[4]?.sectionName, "HOOK")
        for (slot,frame) in frames.enumerated() { XCTAssertEqual(cues[slot]?.frame, frame) }
        let decoded=try JSONDecoder().decode(TrackArrangement.self, from: JSONEncoder().encode(result))
        XCTAssertEqual(decoded.sections.map(\.role), result.sections.map(\.role))
    }
}
