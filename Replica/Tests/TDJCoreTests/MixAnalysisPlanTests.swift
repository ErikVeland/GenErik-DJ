import Foundation
import Testing
@testable import TDJCore

@Test func nineteenMinutesSeparatesFullAnalysisFromFirstMinuteAnalysis() {
    #expect(NativeAnalysisPlan.plan(duration: 18 * 60 + 59) == .full)
    #expect(NativeAnalysisPlan.plan(duration: 19 * 60) == .full)
    #expect(NativeAnalysisPlan.plan(duration: 19 * 60 + 1) == .firstMinute)
    #expect(NativeAnalysisPlan.plan(duration: nil) == .full)
    #expect(NativeAnalysisPlan.excerptSeconds == 60)
}

private func item(_ id: String, _ seconds: Double) -> MusicLibraryItem {
    .init(source: .init(platform: .iosMusic, persistentID: id), title: id, artist: "", duration: seconds,
          assetURL: URL(fileURLWithPath: "/dev/null"), availability: .available)
}

@Test func analysisRunsLoadedSongsFirstThenShortestAndMixesLast() {
    let catalog = MusicLibraryCatalog(items: [item("mix", 3600), item("long", 400), item("short", 120),
                                              item("loaded", 300), item("done-mix", 2400)], playlists: [])
    let order = MusicLibraryReconciliation(catalog: catalog, tracks: [])
        .analysisOrder(loaded: [.init(platform: .iosMusic, persistentID: "loaded")],
                       analysedMixes: ["ios:done-mix", MusicLibrarySource(platform: .iosMusic, persistentID: "done-mix").id])
    #expect(order.map(\.title) == ["loaded", "short", "long", "mix"])
}

@Test func mixFlagShowsOnEntriesOverNineteenMinutesAndFromStoredResults() throws {
    let mix = LibraryBrowserEntry(nativeItem: item("a", 19 * 60 + 1))
    let song = LibraryBrowserEntry(nativeItem: item("b", 18 * 60 + 59))
    #expect(mix.isMix && !song.isMix)
    let flagged = LibraryBrowserEntry(nativeItem: item("c", 0), hint: .init(bpm: 124, key: nil, isMix: true))
    #expect(flagged.isMix && flagged.bpm == 124)
    // Stored results survive a save and load, so the analyser does not repeat the work.
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: url) }
    let hints = NativeAnalysisHints(entries: ["x": .init(bpm: 126, beatAnchorSeconds: 0.2, downbeatOffset: 1,
        key: .init(tonic: 9, mode: .minor), isMix: true, analysedSeconds: 60, configurationID: "c")])
    try hints.save(to: url)
    #expect(try NativeAnalysisHints.load(from: url) == hints)
}

@Test func recommendationsKeepNearbyTemposAndMarkCompatibleKeys() {
    func entry(_ id: String, _ bpm: Double, _ key: MusicalKey) -> LibraryBrowserEntry {
        LibraryBrowserEntry(nativeItem: item(id, 200), hint: .init(bpm: bpm, key: key, isMix: false))
    }
    let selected = entry("sel", 128, .init(tonic: 9, mode: .minor))
    let entries = [selected, entry("near", 126, .init(tonic: 4, mode: .minor)), entry("double", 64, .init(tonic: 9, mode: .minor)),
                   entry("far", 100, .init(tonic: 9, mode: .minor)), entry("clash", 129, .init(tonic: 1, mode: .major))]
    let matches = BrowserRecommendations.matches(for: selected, in: entries)
    #expect(Set(matches.map(\.entry.title)) == ["near", "double", "clash"])
    #expect(matches.first { $0.entry.title == "near" }?.keyCompatible == true)
    #expect(matches.first { $0.entry.title == "clash" }?.keyCompatible == false)
}

@Test func layeredWaveformHasBeatLinesAndNestedColourBands() throws {
    let bins = (0..<4000).map { index -> WaveformBin in
        let level = Float(0.3 + 0.6 * abs(sin(Double(index) * 0.05)))
        return WaveformBin(minimum: -level, maximum: level, rms: level * 0.5)
    }
    let index = WaveformRangeIndex(bins)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    // Four and a half beats at 120 BPM, 256 frames per bin.
    let span = WaveformLayers.defaultSeconds(bpm: 120) * 48000
    #expect(abs(span - 108000) < 1)
    let layers = WaveformLayers(index: index, framesPerBin: 256, left: 48000, span: span, width: 900, height: 200, grid: grid)
    #expect(layers.columns.count == 900)
    #expect(layers.columns.allSatisfy { $0.peak >= $0.body && $0.body >= $0.core && $0.core > 0 })
    #expect(layers.columns.allSatisfy { $0.peak <= 100 * WaveformLayers.headroom + 1e-9 })
    #expect(layers.columns.contains { $0.peak - $0.body > 10 })
    // Beats every 24,000 frames = 200 points; 5 lines from 48,000 to 156,000.
    #expect(layers.beats.count == 5)
    #expect(zip(layers.beats, layers.beats.dropFirst()).allSatisfy { abs(($1.x - $0.x) - 200) < 0.01 })
}
