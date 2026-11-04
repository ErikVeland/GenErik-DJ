import Foundation
import Testing

@testable import TDJCore

// Frozen pre-optimization behavior is the compatibility oracle.
private enum LegacyCollectionBrowser {
    static func tracks(_ tracks: [Track], search: String, sort: CollectionSort?) -> [Track] {
        let words = search.split(whereSeparator: \.isWhitespace).map(String.init)
        let filtered = tracks.enumerated().filter { _, track in
            let fields = [track.title, track.artist, track.album ?? "", track.genre ?? ""]
            return words.allSatisfy { word in fields.contains { $0.localizedStandardContains(word) } }
        }
        guard let sort else { return filtered.map(\.element) }
        return filtered.sorted { a, b in
            switch sort {
            case .title, .artist, .album:
                let left =
                    sort == .title ? a.element.title : sort == .artist ? a.element.artist : (a.element.album ?? "")
                let right =
                    sort == .title ? b.element.title : sort == .artist ? b.element.artist : (b.element.album ?? "")
                let order = left.localizedStandardCompare(right)
                if order != .orderedSame { return order == .orderedAscending }
            case .key:
                let left = a.element.key?.name
                let right = b.element.key?.name
                if left != right {
                    guard let left else { return false }
                    guard let right else { return true }
                    return left.localizedStandardCompare(right) == .orderedAscending
                }
            case .bpm:
                let left = a.element.bpm ?? .infinity
                let right = b.element.bpm ?? .infinity
                if left != right { return left < right }
            }
            return a.offset < b.offset
        }.map(\.element)
    }
}

private func browserTrack(_ index: Int) throws -> Track {
    let bpm: Double? = index % 4 == 0 ? nil : [120.0, 128.0, 120.0][index % 3]
    let key: MusicalKey? = index % 3 == 0 ? nil : .init(tonic: index % 12, mode: index % 2 == 0 ? .major : .minor)
    let analysis = AudioAnalysis(
        implementation: "test", configurationID: "test", contentSHA256: String(format: "%064x", index % 13),
        sampleRate: 48000, frameCount: 480000, channelCount: 2, waveformFramesPerBin: 4800, waveform: [], bpm: bpm,
        beatAnchorFrame: 0, tempoConfidence: 1, key: key, keyConfidence: 1, chroma: [], timbre: [])
    var track = try Track(
        title: ["Track10", "Track2", "Écho", "echo", "Ångström", "Zebra", "Same", "same"][index % 8],
        artist: ["One", "two", "Artist10", "artist2"][index % 4], genre: index % 2 == 0 ? "House" : nil,
        mediaFilename: "record-\(index).wav", analysis: analysis)
    track.album = [nil, "Album10", "Album2", "Same"][index % 4]
    if index % 5 == 0 { track.preparation.correctedKey = .init(tonic: 0, mode: .major) }
    if index % 7 == 0 {
        track.preparation.grid = try BeatGrid(bpm: 100 + Double(index), anchorFrame: 0, sampleRate: 48000)
    }
    return track
}

@Test func indexSortingMatchesLegacyFieldsFiltersAndMetadata() throws {
    let tracks = try (0..<64).map(browserTrack)
    let modes: [CollectionSort?] = [nil] + CollectionSort.allCases.map { Optional($0) }
    for mode in modes {
        for search in ["", " ", "Echo", "Artist2", "track house", "One Album2", "does-not-match", "Écho \t House"] {
            let expected = LegacyCollectionBrowser.tracks(tracks, search: search, sort: mode)
            let actual = CollectionBrowser.tracks(tracks, search: search, sort: mode)
            #expect(actual == expected)
        }
    }
}

@Test func indexSortingPreservesTiesAndUnsortedSuggestionOrder() throws {
    var tracks = try (0..<4).map(browserTrack)
    for index in tracks.indices {
        tracks[index].title = "Same"
        tracks[index].artist = "Same"
        tracks[index].album = "Same"
        tracks[index].preparation.correctedKey = .init(tonic: 0, mode: .major)
        tracks[index].preparation.grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    }
    let input = [tracks[3], tracks[1], tracks[0], tracks[2]]
    for mode in CollectionSort.allCases {
        #expect(CollectionBrowser.tracks(input, search: "", sort: mode) == input)
        #expect(CollectionBrowser.tracks(input, search: "Same House", sort: mode) == [tracks[0], tracks[2]])
    }
    #expect(CollectionBrowser.tracks(input, search: "", sort: nil) == input)
    #expect(CollectionBrowser.tracks(input, search: "House", sort: nil) == [tracks[0], tracks[2]])
}
