import Foundation
import Testing

@testable import TDJCore

@Test func cloudPreparationRetainsManualEditsAndClearedCues() throws {
    var track = try syntheticTrack("a", bpm: 120)
    track.preparation.gridIsManual = true
    try track.preparation.grid?.halveBPM()
    var performance = PerformancePreparation()
    performance.cues[track.id] = [:]
    performance.traktorCueHistory = [track.id: .init(protectedEmptySlots: [0, 3])]
    let archive = CloudPreparationArchive(track: track, performance: performance, arrangement: nil)
    let restored = try CloudPreparationArchive.decode(archive.encoded())
    #expect(restored.track.bpm == 60)
    #expect(restored.cues == [:])
    #expect(restored.cueHistory?.protectedEmptySlots == [0, 3])
    #expect(restored == archive)
    let json = try #require(JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
    let history = try #require(json["cueHistory"] as? [String: Any])
    #expect(history["protectedEmptySlots"] as? [Int] == [0, 3])
}

@Test func cloudPreparationRetainsWaveformsAndRejectsDamagedPayloads() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var track = try syntheticTrack("a", bpm: 120)
    track.analysis = track.analysis.replacingWaveform(Array(repeating: .init(minimum: -0.2, maximum: 0.3, rms: 0.1), count: 1000))
    var library = LibrarySnapshot()
    library.tracks = [track]
    let compact = try store.save(library)
    let archive = try CloudPreparationVault.capture(store: store, track: compact.tracks[0], performance: .init())
    let decoded = try CloudPreparationArchive.decode(archive.encoded())
    #expect(decoded.waveformData != nil)
    let reference = try #require(compact.tracks[0].analysis.waveformReference)
    try Data("damaged".utf8).write(to: store.waveformDirectory.appendingPathComponent(reference))
    #expect(throws: (any Error).self) {
        try CloudPreparationVault.capture(store: store, track: compact.tracks[0], performance: .init()).encoded()
    }
}

@Test func cloudPreparationRecoveryResumesAnInterruptedJournal() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var library = LibrarySnapshot()
    library.tracks = try [syntheticTrack("a", bpm: 120)]
    try store.save(library)
    var selected = library.tracks[0]
    selected.preparation.correctedKey = .init(tonic: 2, mode: .minor)
    var cues = PerformancePreparation()
    cues.cues[selected.id] = [1: .init(frame: 1000)]
    try CloudPreparationRecovery.schedule(.init(track: selected, performance: cues, arrangement: nil),
        trackID: selected.id, store: store)
    let requestURL = CloudPreparationRecovery.requestURL(store)
    var request = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: requestURL)) as? [String: Any])
    request["started"] = true
    try JSONSerialization.data(withJSONObject: request).write(to: requestURL)
    try cues.save(to: root.appendingPathComponent("performance.json"))
    try CloudPreparationRecovery.applyPending(store: store)
    #expect(try store.load().tracks[0].key?.tonic == 2)
    #expect(!FileManager.default.fileExists(atPath: requestURL.path))
    #expect(try PerformancePreparation.load(from: root.appendingPathComponent("performance.json")).cues[selected.id]?[1]?.frame == 1000)
}

@Test func cloudPreparationRejectsDifferentAudioAndNativeOpeningIdentity() throws {
    let a = try syntheticTrack("a", bpm: 120)
    let b = try syntheticTrack("b", bpm: 120)
    let archive = CloudPreparationArchive(track: a, performance: .init(), arrangement: nil)
    #expect(archive.matches(a))
    #expect(!archive.matches(b))
    var opening = a
    opening.analysis = a.analysis.replacingWaveform([], configurationID: "native-opening-1", frameCount: 441000, decodedFrames: 100)
    #expect(throws: (any Error).self) {
        try CloudPreparationArchive(track: opening, performance: .init(), arrangement: nil).encoded()
    }
}

@Test func cloudPreparationVaultRetainsBothVersionsAndChecksDigest() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let vault = try CloudPreparationVault(root: root)
    var track = try syntheticTrack("a", bpm: 120)
    let first = try vault.retain(.init(track: track, performance: .init(), arrangement: nil))
    track.preparation.correctedKey = .init(tonic: 2, mode: .minor)
    let second = try vault.retain(.init(track: track, performance: .init(), arrangement: nil))
    #expect(first.id != second.id)
    #expect(try vault.list().count == 2)
    let reopened = try CloudPreparationVault(root: root)
    #expect(try reopened.read(first.id).track.preparation.correctedKey == nil)
    #expect(try vault.read(first.id).track.preparation.correctedKey == nil)
    #expect(try vault.read(second.id).track.preparation.correctedKey?.tonic == 2)
    try Data("corrupt".utf8).write(to: vault.payloadURL(first.id))
    #expect(throws: (any Error).self) { try vault.read(first.id) }
    #expect(throws: (any Error).self) { try vault.read("../library") }
}

@Test func cloudPreparationRejectsInvalidCueAndUnsupportedSchema() throws {
    let track = try syntheticTrack("a", bpm: 120)
    var performance = PerformancePreparation()
    performance.cues[track.id] = [0: .init(frame: 999999)]
    let archive = CloudPreparationArchive(track: track, performance: performance, arrangement: nil)
    #expect(throws: (any Error).self) { try archive.encoded() }
    let valid = CloudPreparationArchive(track: track, performance: .init(), arrangement: nil)
    var json = try #require(JSONSerialization.jsonObject(with: valid.encoded()) as? [String: Any])
    json["version"] = 999
    #expect(throws: (any Error).self) { try CloudPreparationArchive.decode(JSONSerialization.data(withJSONObject: json)) }
}

@Test func cloudPreparationRecoveryWaitsForRestartAndKeepsPreviousPreparation() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var track = try syntheticTrack("a", bpm: 120)
    var library = LibrarySnapshot()
    library.tracks = [track]
    try store.save(library)
    track.preparation.correctedKey = .init(tonic: 2, mode: .minor)
    var cloudCues = PerformancePreparation()
    cloudCues.cues[track.id] = [:]
    let archive = CloudPreparationArchive(track: track, performance: cloudCues, arrangement: nil)
    try CloudPreparationRecovery.schedule(archive, trackID: track.id, store: store)
    #expect(try store.load().tracks[0].preparation.correctedKey == nil)
    try CloudPreparationRecovery.applyPending(store: store)
    #expect(try store.load().tracks[0].preparation.correctedKey?.tonic == 2)
    #expect(try PerformancePreparation.load(from: root.appendingPathComponent("performance.json")).cues[track.id] == [:])
    let vault = try CloudPreparationVault(root: root.appendingPathComponent("RecoveryVersions"))
    #expect(try vault.list().count == 2)
    try CloudPreparationRecovery.applyPending(store: store)
    #expect(try store.load().revision == 1)
}

@Test func cloudPreparationRecoveryRefusesEditsMadeAfterScheduling() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var library = LibrarySnapshot()
    library.tracks = try [syntheticTrack("a", bpm: 120)]
    try store.save(library)
    let remote = CloudPreparationArchive(track: library.tracks[0], performance: .init(), arrangement: nil)
    try CloudPreparationRecovery.schedule(remote, trackID: library.tracks[0].id, store: store)
    library.tracks[0].preparation.correctedKey = .init(tonic: 7, mode: .major)
    try store.save(library)
    #expect(throws: (any Error).self) { try CloudPreparationRecovery.applyPending(store: store) }
    #expect(try store.load().tracks[0].preparation.correctedKey?.tonic == 7)
}
