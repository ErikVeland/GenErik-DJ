import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func clockModel() async throws -> (ReplicaModel, URL, Track) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    return (model, root, track)
}

@Test func historyPutsTheNewestSessionFirstAndOlderOnesInMonthFolders() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Australia/Brisbane")!
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 22))!
    }
    let sessions = [UUID(), UUID(), UUID()]
    func load(_ session: Int, _ day: Date, _ track: String) -> PerformanceEvent {
        PerformanceEvent(
            id: UUID(), sessionID: sessions[session], kind: .load, timestamp: day, fromTrackID: nil, toTrackID: track,
            durationSeconds: nil)
    }
    let events = [
        load(0, date(2026, 10, 30), "a"), load(0, date(2026, 10, 30).addingTimeInterval(60), "b"),
        load(0, date(2026, 10, 30).addingTimeInterval(90), "a"), load(1, date(2026, 10, 2), "c"),
        load(2, date(2026, 9, 6), "d"),
    ]
    let grouped = HistorySessions.sessions(from: events)
    #expect(grouped.map(\.trackIDs) == [["a", "b"], ["c"], ["d"]])
    let layout = HistorySessions.layout(grouped, calendar: calendar)
    #expect(layout.latest?.id == sessions[0])
    #expect(layout.months.map(\.id) == ["2026-10", "2026-09"])
    #expect(layout.months.first?.sessions.map(\.id) == [sessions[1]])
}

@Test func recordingTracklistLinesBecomeFeaturedTracks() {
    let lines = RecordingTracklist.parse(
        "00:00:00 - Mythos 'n' Dj Cosmo - Hymn\n00:04:31 - Sash! - Encore Une Fois - Radio Edit\nnot a line\n")
    #expect(
        lines == [
            .init(seconds: 0, artist: "Mythos 'n' Dj Cosmo", title: "Hymn"),
            .init(seconds: 271, artist: "Sash!", title: "Encore Une Fois - Radio Edit"),
        ])
}

@Test @MainActor func batteryShowsChargingAndLevelWarnings() throws {
    let full = try #require(BatteryReadout.presentation(for: 1))
    #expect(full.percent == 100 && full.symbol == "battery.100percent")
    #expect(full.tint == PerformancePalette.text)
    #expect(full.chargingSymbol == nil)
    let low = try #require(BatteryReadout.presentation(for: 0.09))
    #expect(low.percent == 9 && low.tint == PerformancePalette.red)
    #expect(BatteryReadout.presentation(for: 0.10)?.tint == .orange)
    #expect(BatteryReadout.presentation(for: 0.19)?.tint == .orange)
    #expect(BatteryReadout.presentation(for: 0.20)?.tint == PerformancePalette.text)
    let charging = try #require(BatteryReadout.presentation(for: 0.09, isCharging: true))
    #expect(charging.symbol == low.symbol && charging.chargingSymbol == "bolt.fill")
    #expect(charging.tint == PerformancePalette.red)
    #expect(BatteryReadout.presentation(for: 0.099)?.tint == PerformancePalette.red)
    #expect(BatteryReadout.presentation(for: 0.50)?.symbol == "battery.50percent")
    #expect(BatteryReadout.presentation(for: -1) == nil)
}

@Test @MainActor func playbackSettingsSetDefaultLoopSizeAndOffAirLoadingIsEnforced() async throws {
    let (model, root, track) = try await clockModel()
    defer {
        try? FileManager.default.removeItem(at: root)
        UserDefaults.standard.removeObject(forKey: BrowserSettings.onlyLoadToOffAirDecksKey)
    }
    model.performance.defaultLoopBeats = 16
    #expect(model.performance.loopBeats(for: .b) == 16)
    model.pressPlay(deck: .a)
    await model.flushWrites()
    #expect(model.controlDisplay[.a].phase.active)
    UserDefaults.standard.set(true, forKey: BrowserSettings.onlyLoadToOffAirDecksKey)
    model.loadLibraryEntry(LibraryBrowserEntry(track: track), deck: .a)
    #expect(model.status.contains("off-air"))
}

@Test @MainActor func gridEditBarHalvesDoublesResetsAndLocks() async throws {
    let (model, root, _) = try await clockModel()
    defer { try? FileManager.default.removeItem(at: root) }
    model.toggleGridEditing(deck: .a)
    let original = try #require(model.grid(.a)?.bpm)
    model.correctTempo(deck: .a, factor: 0.5)
    #expect(abs((model.grid(.a)?.bpm ?? 0) - original / 2) < 0.01)
    model.resetGrid(deck: .a)
    #expect(abs((model.grid(.a)?.bpm ?? 0) - original) < 0.01)
    model.gridLocked.insert(.a)
    model.setDownbeat(atBeat: 2, deck: .a)
    #expect(model.grid(.a)?.downbeatOffset == 0)
    model.gridLocked.remove(.a)
    model.setDownbeat(atBeat: 6, deck: .a)
    #expect(model.grid(.a)?.downbeatOffset == 2)
    let grid = try #require(model.grid(.a))
    #expect((0..<8).map { GridBeatMarkers.number(beat: $0 + 2, grid: grid) } == [1, 2, 3, 4, 1, 2, 3, 4])
}

@Test @MainActor func flagOpensHotcuePadsAndTheRedXDeletes() async throws {
    let (model, root, track) = try await clockModel()
    defer { try? FileManager.default.removeItem(at: root) }
    model.toggleHotcuePads(deck: .a)
    #expect(model.hotcuePadsVisible.contains(.a))
    model.cue(slot: 2, deck: .a)
    #expect(model.performance.cues[track.id]?[2] != nil)
    model.hotcueDeleting.insert(.a)
    model.cue(slot: 2, deck: .a, delete: true)
    #expect(model.performance.cues[track.id]?[2] == nil)
    model.toggleHotcuePads(deck: .a)
    #expect(!model.hotcuePadsVisible.contains(.a) && !model.hotcueDeleting.contains(.a))
}

@Test @MainActor func speakerPanelSetsMasterLevelAndSplitOutput() async throws {
    let (model, root, _) = try await clockModel()
    defer { try? FileManager.default.removeItem(at: root) }
    model.setMixer(.master, value: 0.8)
    #expect(abs((model.playbackSnapshot?.masterGain ?? 0) - 0.8) < 0.001)
    model.setOutputRoute(.masterAndHeadphones)
    #expect(model.outputRoute == .masterAndHeadphones)
    model.setOutputRoute(.stereoMaster)
    #expect(model.outputRoute == .stereoMaster)
}

@Test func referenceComparisonScoresTempoAndKey() {
    #expect(ReferenceBenchmarkReport.tempoVerdict(ours: 128.4, reference: 128) == "exact")
    #expect(ReferenceBenchmarkReport.tempoVerdict(ours: 64.1, reference: 128) == "octave")
    #expect(ReferenceBenchmarkReport.tempoVerdict(ours: 140, reference: 128) == "miss")
    #expect(ReferenceBenchmarkReport.tempoVerdict(ours: nil, reference: 128) == "none")
    let a = MusicalKey(tonic: 9, mode: .minor)
    #expect(ReferenceBenchmarkReport.keyVerdict(ours: a, reference: a) == "exact")
    #expect(ReferenceBenchmarkReport.keyVerdict(ours: MusicalKey(tonic: 0, mode: .major), reference: a) == "compatible")
    #expect(ReferenceBenchmarkReport.keyVerdict(ours: MusicalKey(tonic: 1, mode: .major), reference: a) == "miss")
}
