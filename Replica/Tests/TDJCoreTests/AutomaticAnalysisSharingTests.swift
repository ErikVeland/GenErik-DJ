import Foundation
import Testing

@testable import TDJCore

@Test func automaticAnalysisExportIsDurableDeduplicatedAndAccountScoped() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var track = try syntheticTrack("a", bpm: 120)
    track.preparation.gridIsManual = true
    track.preparation.correctedKey = .init(tonic: 5, mode: .minor)
    track.analysis.deepBeatAnalysis = .init(
        audio: .init(track.analysis), profile: .current,
        coveredFrames: track.analysis.frameCount,
        windowCount: BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(track.analysis)).count,
        candidate: nil)
    let vault = try CloudPreparationVault(root: root.appendingPathComponent("account-a"))
    let export = AutomaticAnalysisExports(root: vault.root)
    let first = try #require(try export.retain(track: track, store: store, vault: vault))
    #expect(first.automaticAnalysis == true)
    #expect(try export.retain(track: track, store: store, vault: vault) == nil)
    let reopened = try CloudPreparationVault(root: vault.root)
    let payload = try reopened.read(first.id)
    #expect(payload.automaticAnalysis == true)
    #expect(payload.track.preparation.grid == nil)
    #expect(payload.track.preparation.correctedKey == nil)
    #expect(payload.cues == nil && payload.cueHistory == nil)
    #expect(throws: (any Error).self) { try payload.restoredTrack(matching: track) }
    let secondAccount = try CloudPreparationVault(root: root.appendingPathComponent("account-b"))
    #expect(
        try AutomaticAnalysisExports(root: secondAccount.root).retain(track: track, store: store, vault: secondAccount)
            != nil)
    var receiver = try syntheticTrack("a", bpm: 120)
    receiver.preparation.gridLocked = true
    receiver.preparation.correctedKey = .init(tonic: 2, mode: .major)
    let merged = try payload.automaticallyMergedTrack(matching: receiver)
    #expect(merged.preparation == receiver.preparation)
    #expect(merged.analysis.deepBeatAnalysis == payload.track.analysis.deepBeatAnalysis)
    #expect(try payload.automaticallyMergedTrack(matching: merged) == merged)
    #expect(
        try payload.automaticallyMergedTrack(matching: syntheticTrack("b", bpm: 120)).analysis.deepBeatAnalysis == nil)
}

@Test func automaticAnalysisDoesNotApplyFullRecoveryArchives() throws {
    let track = try syntheticTrack("a", bpm: 120)
    var remote = track
    remote.preparation.correctedKey = .init(tonic: 2, mode: .minor)
    let full = CloudPreparationArchive(track: remote, performance: .init(), arrangement: nil)
    #expect(try full.automaticallyMergedTrack(matching: track) == track)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["GENERIK_DEEP_TEST_AUDIO"] != nil))
func deepActualModelCompletesAndReopensSavedResult() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["GENERIK_DEEP_TEST_AUDIO"])
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = URL(fileURLWithPath: path)
    let analysis = try await AnalysisWorker.shared.waveformOnly(url: url)
    let result = try await AnalysisWorker.shared.deepBeatAnalysis(url: url, matching: analysis, root: root)
    try result.validate(matching: analysis)
    #expect(result.coveredFrames == analysis.frameCount)
    #expect(result.profile == .current)
    print("Deep model result: \(String(data: try JSONEncoder().encode(result), encoding: .utf8)!)")
    let reopened = try await AnalysisWorker.shared.deepBeatAnalysis(url: url, matching: analysis, root: root)
    #expect(reopened == result)
}
