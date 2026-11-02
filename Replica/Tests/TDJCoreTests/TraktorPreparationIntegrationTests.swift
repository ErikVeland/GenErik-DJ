import AVFoundation
import Foundation
import Testing
@testable import TDJCore

private func referenceFixtureSource() -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
}

private func referenceXML(persistentID: String = "3B3D1D51BE612BD2", duration: Double) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <NML VERSION="17"><HEAD PROGRAM="Traktor DJ"/><COLLECTION ENTRIES="1">
    <ENTRY UUID="original-track" TITLE="Reference clock" ARTIST="Synthetic">
    <ITUNES PERSISTENT_ID="\(persistentID)" PLAYTIME="\(duration * 1000)"/>
    <MODIFICATION_INFO AUTHOR_TYPE="application"/><MUSICAL_KEY VALUE="21"/><TEMPO BPM="123"/>
    <CUE_V2 NAME="AutoGrid Traktor DJ" HOTCUE="-1" START="1000" TYPE="4"/>
    <CUE_V2 NAME="Entry" HOTCUE="2" START="2000" TYPE="0"/>
    </ENTRY></COLLECTION></NML>
    """
}

@Test func detectedTraktorPreparationBypassesMusicalAnalysisForExactNativeIdentity() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let directory = root.appendingPathComponent("TraktorReferences")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = try AVAudioFile(forReading: referenceFixtureSource())
    let duration = Double(file.length) / file.processingFormat.sampleRate
    try Data(referenceXML(duration: duration).utf8).write(to: directory.appendingPathComponent("collection.nml"))
    let service = try LibraryService(store: store)
    let item = MusicLibraryItem(source: .init(platform: .iosMusic, persistentID: String(UInt64("3B3D1D51BE612BD2", radix: 16)!)),
        title: "Reference clock", artist: "Synthetic", duration: duration, assetURL: referenceFixtureSource(), availability: .available)
    let snapshot = try await service.importAudio(url: referenceFixtureSource(), musicLibrary: .init(item: item))
    let track = try #require(snapshot.tracks.first)
    #expect(track.preparation.grid?.bpm == 123)
    #expect(track.preparation.correctedKey == MusicalKey(tonic: 9, mode: .minor))
    #expect(track.preparation.grid?.anchorFrame == file.processingFormat.sampleRate)
    #expect(track.preparation.gridIsManual)
    #expect(track.analysis.bpm == nil)
    #expect(track.analysis.key == nil)
    #expect(track.analysis.tempoConfidence == 0)
    #expect(track.analysis.detectedDownbeatOffset == nil)
    #expect(!((try store.hydrate(track)).analysis.waveform.isEmpty))
}

private func referenceItem(duration: Double, persistentID: String = "3B3D1D51BE612BD2") -> MusicLibraryItem {
    .init(source: .init(platform: .iosMusic, persistentID: String(UInt64(persistentID, radix: 16)!)),
        title: "Reference clock", artist: "Synthetic", duration: duration,
        assetURL: referenceFixtureSource(), availability: .available)
}

@Test func traktorCatalogWithholdsUnknownKeysAmbiguousGridsAndDuplicateIdentities() throws {
    let xml = referenceXML(duration: 12).replacingOccurrences(of: "VALUE=\"21\"", with: "VALUE=\"1001\"")
        .replacingOccurrences(of: "</ENTRY>", with: "<CUE_V2 TYPE=\"4\" START=\"2000\" HOTCUE=\"-1\"/></ENTRY>")
    let catalog = try TraktorPreparationCatalog.read(Data(xml.utf8))
    let record = try #require(catalog.records.first)
    #expect(record.key == nil && record.gridMilliseconds == nil && !record.canReuseMusicalPreparation)
    #expect(record.rawEntry.children.contains { $0.attributes["VALUE"] == "1001" })
    let doubled = xml.replacingOccurrences(of: "ENTRIES=\"1\"", with: "ENTRIES=\"2\"")
        .replacingOccurrences(of: "</COLLECTION>", with: String(xml[xml.range(of: "<ENTRY ")!.lowerBound..<xml.range(of: "</ENTRY>")!.upperBound]) + "</COLLECTION>")
    let duplicate = try TraktorPreparationCatalog.read(Data(doubled.utf8))
    #expect(duplicate.match(referenceItem(duration: 12).source) == nil)
    #expect(catalog.match(referenceItem(duration: 12, persistentID: "3B3D1D51BE612BD3").source) == nil)
}

@Test func traktorCollectionImportArchivesOriginalAndRejectsAnInvalidReplacementAtomically() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let source = root.appendingPathComponent("original.nml")
    let data = Data(referenceXML(duration: 12).utf8)
    try data.write(to: source)
    let service = try LibraryService(store: store)
    let summary = try await service.importTraktorCollection(url: source)
    let directory = root.appendingPathComponent("TraktorReferences")
    let pointer = directory.appendingPathComponent("current.json")
    let before = try Data(contentsOf: pointer)
    #expect(try Data(contentsOf: directory.appendingPathComponent(summary.sourceSHA256 + ".collection")) == data)
    #expect(try Data(contentsOf: source) == data)
    let invalid = root.appendingPathComponent("bad.nml")
    try Data("<NML>incomplete".utf8).write(to: invalid)
    do { _ = try await service.importTraktorCollection(url: invalid); Issue.record("Accepted invalid collection") }
    catch {}
    #expect(try Data(contentsOf: pointer) == before)
    #expect(try await service.refreshTraktorReferences(force: true)?.sourceSHA256 == summary.sourceSHA256)
}

@Test(arguments: ["identity", "duration"])
func traktorPreparationFallsBackToDetectionWhenTheSourceCannotBeVerified(_ mismatch: String) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let file = try AVAudioFile(forReading: referenceFixtureSource())
    let duration = Double(file.length) / file.processingFormat.sampleRate
    let source = root.appendingPathComponent("original.nml")
    try Data(referenceXML(duration: mismatch == "duration" ? duration + 20 : duration).utf8).write(to: source)
    let service = try LibraryService(store: store)
    _ = try await service.importTraktorCollection(url: source)
    let item = referenceItem(duration: duration, persistentID: mismatch == "identity" ? "3B3D1D51BE612BD3" : "3B3D1D51BE612BD2")
    let snapshot = try await service.importAudio(url: referenceFixtureSource(), musicLibrary: .init(item: item))
    let track = try #require(snapshot.tracks.first)
    #expect(track.traktorPreparation == nil)
    #expect(track.analysis.musicalAnalysisDeferred != true)
    #expect(abs((track.analysis.bpm ?? 0) - 120) < 0.1)
    if mismatch == "duration" { #expect(await service.traktorReferenceWarning != nil) }
}

@Test func traktorPreparationPreservesEditsReanalysisAndDeletedCuesAcrossRestart() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let file = try AVAudioFile(forReading: referenceFixtureSource())
    let duration = Double(file.length) / file.processingFormat.sampleRate
    let source = root.appendingPathComponent("original.nml")
    try Data(referenceXML(duration: duration).utf8).write(to: source)
    let service = try LibraryService(store: store)
    _ = try await service.importTraktorCollection(url: source)
    let item = referenceItem(duration: duration)
    var snapshot = try await service.importAudio(url: referenceFixtureSource(), musicLibrary: .init(item: item))
    var track = try #require(snapshot.tracks.first)
    #expect(PerformerSuggestions.energyLevel(track.analysis) == nil)
    let imported = track.traktorPreparation
    let performanceURL = root.appendingPathComponent("performance.json")
    var performance = PerformancePreparation()
    let installed = try performance.installTraktorCues(for: track)
    #expect(installed)
    #expect(performance.cues[track.id]?.keys.sorted() == [2])
    performance.cues[track.id]?[2] = nil
    try performance.save(to: performanceURL)
    performance = try PerformancePreparation.load(from: performanceURL)
    _ = try performance.installTraktorCues(for: track)
    #expect(performance.cues[track.id]?.isEmpty == true)
    let addedGridCue = performance.synchronizeGridCue(trackID: track.id, frame: 0)
    #expect(!addedGridCue)
    var edited = track.preparation
    edited.grid = try BeatGrid(bpm: 128, anchorFrame: 42, sampleRate: track.analysis.sampleRate, downbeatOffset: 2)
    edited.correctedKey = .init(tonic: 1, mode: .major)
    _ = try await service.updatePreparation(trackID: track.id, preparation: edited)
    snapshot = try await service.reanalyze(trackID: track.id)
    track = try #require(snapshot.tracks.first)
    #expect(track.preparation == edited && track.traktorPreparation == imported)
    #expect(track.analysis.musicalAnalysisDeferred != true)
    let restarted = try LibraryService(store: store)
    snapshot = try await restarted.importAudio(url: referenceFixtureSource(), musicLibrary: .init(item: item), preservePreparationFor: [track.id])
    let protected = try #require(snapshot.tracks.first)
    #expect(protected.preparation == edited && protected.analysis == track.analysis)
    #expect(protected.traktorPreparation == imported)
    var oldBank = PerformancePreparation()
    oldBank.cues[track.id] = [0: .init(frame: 10)]
    _ = try oldBank.installTraktorCues(for: track)
    #expect(oldBank.cues[track.id] == [0: .init(frame: 10)])
}

@Test func traktorPreparationAttachesToExistingNativeItemsWithoutReanalysisAndProtectsLoadedTracks() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let file = try AVAudioFile(forReading: referenceFixtureSource())
    let duration = Double(file.length) / file.processingFormat.sampleRate
    let service = try LibraryService(store: store)
    var snapshot = try await service.importAudio(url: referenceFixtureSource(), musicLibrary: .init(item: referenceItem(duration: duration)))
    let before = try #require(snapshot.tracks.first)
    let source = root.appendingPathComponent("original.nml")
    try Data(referenceXML(duration: duration).utf8).write(to: source)
    _ = try await service.importTraktorCollection(url: source)
    snapshot = try await service.reuseTraktorPreparationForExistingTracks(preservePreparationFor: [before.id])
    let staged=try #require(snapshot.tracks.first)
    #expect(staged.preparation == before.preparation && staged.analysis == before.analysis)
    #expect(staged.traktorPreparation != nil && staged.grid?.bpm == 123)
    snapshot = try await service.reuseTraktorPreparationForExistingTracks()
    let after = try #require(snapshot.tracks.first)
    #expect(after.bpm == 123 && after.traktorPreparation != nil)
    #expect(after.analysis == before.analysis)
    let revision = snapshot.revision
    snapshot = try await service.reuseTraktorPreparationForExistingTracks()
    #expect(snapshot.revision == revision)
    #expect(try store.load(includeWaveforms: false).tracks.first == after)
}
