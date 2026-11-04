import Foundation
import Testing

@testable import TDJCore

@Suite struct BeatGridMapTests {
    let map = BeatGridMap(
        anchors: [.init(beat: 0, frame: 0), .init(beat: 4, frame: 96_000), .init(beat: 8, frame: 192_960)],
        sampleRate: 48_000, downbeatOffset: 0)
    @Test func lookup() throws {
        try map.validate(frameCount: 240_000)
        #expect(map.frame(atBeat: 2) == 48_000)
        #expect(map.frame(atBeat: 6) == 144_480)
        #expect(map.frame(atBeat: -1) == -24_000)
        #expect(map.frame(atBeat: 9) == 217_200)
        for beat in stride(from: -4.0, through: 12, by: 0.125) {
            #expect(abs(map.beat(atFrame: map.frame(atBeat: beat)) - beat) < 1e-10)
        }
    }
    @Test func rejectsInvalidMaps() {
        let bad: [BeatGridMap] = [
            .init(anchors: map.anchors, sampleRate: 0, downbeatOffset: 0),
            .init(anchors: map.anchors, sampleRate: .infinity, downbeatOffset: 0),
            .init(anchors: [], sampleRate: 48_000, downbeatOffset: 0),
            .init(anchors: [.init(beat: 0, frame: 0)], sampleRate: 48_000, downbeatOffset: 0),
            .init(
                anchors: [.init(beat: 0, frame: 0), .init(beat: 0, frame: 100)], sampleRate: 48_000, downbeatOffset: 0),
            .init(
                anchors: [.init(beat: 0, frame: 1), .init(beat: 1, frame: 0)], sampleRate: 48_000, downbeatOffset: 0),
            .init(
                anchors: [.init(beat: .nan, frame: 0), .init(beat: 1, frame: 24_000)], sampleRate: 48_000,
                downbeatOffset: 0),
            .init(
                anchors: [.init(beat: 0, frame: -1), .init(beat: 1, frame: 24_000)], sampleRate: 48_000,
                downbeatOffset: 0), .init(anchors: map.anchors, sampleRate: 48_000, downbeatOffset: 4),
            .init(
                anchors: [.init(beat: 0, frame: 0), .init(beat: 1, frame: 1)], sampleRate: 48_000, downbeatOffset: 0),
            .init(
                anchors: (0...256).map { .init(beat: Double($0), frame: Double($0) * 24_000) }, sampleRate: 48_000,
                downbeatOffset: 0),
        ]
        for value in bad { #expect(throws: (any Error).self) { try value.validate(frameCount: 10_000_000) } }
        #expect(throws: (any Error).self) { try map.validate(frameCount: 100) }
    }
    @Test func legacyPreparation() throws {
        let grid = try BeatGrid(bpm: 127.7, anchorFrame: 321, sampleRate: 48_000, downbeatOffset: 2)
        let old = Preparation(grid: grid, correctedKey: .init(tonic: 2, mode: .minor), gridIsManual: true)
        let data = try JSONEncoder().encode(old)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "adaptiveMap")
        json.removeValue(forKey: "gridLocked")
        json.removeValue(forKey: "gridMode")
        let decoded = try JSONDecoder().decode(Preparation.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.grid == grid)
        #expect(decoded.gridIsManual)
        #expect(decoded.adaptiveMap == nil)
        #expect(!decoded.gridLocked)
        #expect(try JSONDecoder().decode(Preparation.self, from: JSONEncoder().encode(decoded)) == decoded)
    }
}
