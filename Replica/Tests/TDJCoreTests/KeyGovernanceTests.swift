import Foundation
import Testing

@testable import TDJCore

private func governedTrack() throws -> Track {
    let analysis = AudioAnalysis(
        implementation: "test", configurationID: "test", contentSHA256: String(repeating: "a", count: 64),
        sampleRate: 48000, frameCount: 480000, channelCount: 2, waveformFramesPerBin: 512, waveform: [], bpm: 120,
        beatAnchorFrame: 0, tempoConfidence: 1, key: .init(tonic: 0, mode: .major), keyConfidence: 1, chroma: [],
        timbre: [])
    return try Track(title: "Governance fixture", mediaFilename: "fixture.wav", analysis: analysis)
}

private func keyManifest(
    _ track: Track, key: String = "8A", source: KeyImportSource = .mixedInKey,
    attribution: KeyImportAttribution = .userConfirmed
) -> KeyImportManifest {
    .init(
        source: source, attribution: attribution, sourceDescription: "Reviewed test export", producerVersion: "11",
        entries: [.init(contentSHA256: track.id, rawKey: key, notation: .camelot)])
}

private func importedKeyTrack(
    _ track: Track, key: String = "8A", source: KeyImportSource = .mixedInKey,
    attribution: KeyImportAttribution = .userConfirmed
) throws -> Track {
    var library = LibrarySnapshot()
    library.tracks = [track]
    return try KeyImportPlan(
        manifest: keyManifest(track, key: key, source: source, attribution: attribution), library: library
    ).applying(to: library).tracks[0]
}

@Test func keyGovernancePrefersMixedInKeyOverMaximumIndependentConfidence() throws {
    let track = try importedKeyTrack(governedTrack())
    #expect(track.key == MusicalKey(tonic: 9, mode: .minor))
    #expect(track.keyDecision.authority == .mixedInKey)
    #expect(track.keyDecision.needsReview)
    #expect(track.analysis.key == MusicalKey(tonic: 0, mode: .major))
    #expect(track.analysis.keyConfidence == 1)
}

@Test func keyGovernancePreservesManualCorrectionsAndLegacyCorrections() throws {
    var track = try governedTrack()
    track.preparation.correctedKey = .init(tonic: 2, mode: .minor)
    track = try importedKeyTrack(track)
    #expect(track.keyDecision.authority == .manual)
    #expect(track.key == MusicalKey(tonic: 2, mode: .minor))
    let restored = try JSONDecoder().decode(Track.self, from: JSONEncoder().encode(track))
    #expect(restored.keyDecision == track.keyDecision)
}

@Test func keyGovernanceDoesNotPromoteImportedPreparationToManualAuthority() throws {
    var track = try governedTrack()
    track.preparation.importKey(.init(tonic: 7, mode: .major), authority: .traktor)
    #expect(track.keyDecision.authority == .traktor)
    track = try importedKeyTrack(track)
    #expect(track.keyDecision.authority == .mixedInKey)
    track.preparation.correctedKey = .init(tonic: 7, mode: .major)
    #expect(track.keyDecision.authority == .manual)
}

@Test func keyGovernanceWithholdsUnknownTagsFromAuthority() throws {
    let track = try importedKeyTrack(governedTrack(), source: .unknownTag, attribution: .unknown)
    #expect(track.keyDecision.authority == .independent)
    #expect(track.key == track.analysis.key)
    #expect(track.keyDecision.needsReview)
    #expect(track.keyGovernance?.observations.count == 1)
}

@Test func keyGovernanceRequiresAttributionBeforeTrustingMixedInKey() throws {
    let track = try governedTrack()
    var library = LibrarySnapshot()
    library.tracks = [track]
    #expect(throws: CoreError.self) {
        try KeyImportPlan(manifest: keyManifest(track, attribution: .unknown), library: library)
    }
}

@Test func keyGovernanceNormalizesNotationWithoutTreatingAliasesAsConflicts() throws {
    #expect(try KeyNotation.camelot.parse("8A") == KeyNotation.openKey.parse("1m"))
    #expect(try KeyNotation.musical.parse("G#m") == KeyNotation.musical.parse("Ab minor"))
    #expect(try KeyNotation.camelot.parse("8B") == KeyNotation.musical.parse("C major"))
    for invalid in ["0A", "13B", "8", "8Am"] {
        #expect(throws: CoreError.self) { try KeyNotation.camelot.parse(invalid) }
    }
    let track = try importedKeyTrack(governedTrack(), key: "8B")
    #expect(!track.keyDecision.needsReview)
}

@Test func keyGovernanceKeepsAcceptedMixedInKeyWhenANewerImportDisagrees() throws {
    let first = try importedKeyTrack(governedTrack())
    let changed = try importedKeyTrack(first, key: "9A")
    #expect(changed.key == first.key)
    #expect(changed.keyDecision.needsReview)
    #expect(changed.keyGovernance?.observations.count == 2)
}

@Test func keyGovernanceRepeatedImportsAreIdempotent() throws {
    var library = LibrarySnapshot()
    library.tracks = try [governedTrack()]
    let manifest = keyManifest(library.tracks[0])
    let first = try KeyImportPlan(manifest: manifest, library: library).applying(to: library)
    let repeated = try KeyImportPlan(manifest: manifest, library: first).applying(to: first)
    #expect(first == repeated)
    #expect(first.tracks[0].keyGovernance?.events.count == 1)
}

@Test func keyGovernanceRejectsStalePreviewAndWholeInvalidBatches() throws {
    var library = LibrarySnapshot()
    library.tracks = try [governedTrack()]
    let manifest = keyManifest(library.tracks[0])
    let plan = try KeyImportPlan(manifest: manifest, library: library)
    library.tracks[0].preparation.correctedKey = .init(tonic: 3, mode: .minor)
    #expect(throws: CoreError.self) { try plan.applying(to: library) }
    var invalid = manifest
    invalid.entries.append(.init(contentSHA256: String(repeating: "b", count: 64), rawKey: "9A", notation: .camelot))
    #expect(throws: CoreError.self) { try KeyImportPlan(manifest: invalid, library: library) }
    #expect(library.tracks[0].keyGovernance == nil)
    invalid = manifest
    invalid.schemaVersion = 99
    #expect(throws: CoreError.self) { try KeyImportPlan(manifest: invalid, library: library) }
}

@Test func keyGovernanceServicePreviewApplyAndRestartRetainEvidence() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var library = LibrarySnapshot()
    library.tracks = try [governedTrack()]
    try store.save(library)
    let before = try Data(contentsOf: store.libraryURL)
    let service = try LibraryService(store: store)
    let data = try JSONEncoder().encode(keyManifest(library.tracks[0]))
    let plan = try await service.previewKeyImport(data: data)
    #expect(try Data(contentsOf: store.libraryURL) == before)
    _ = try await service.applyKeyImport(plan)
    let restored = try store.load(includeWaveforms: false).tracks[0]
    #expect(restored.keyDecision.authority == .mixedInKey)
    #expect(restored.keyGovernance?.observations.first?.producerVersion == "11")
    #expect(restored.keyGovernance?.events.first?.policyVersion == KeyGovernancePolicy.version)
}

@Test func keyGovernanceManualReviewRequiresReasonAndRejectsStaleDecisions() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var library = LibrarySnapshot()
    library.tracks = try [importedKeyTrack(governedTrack())]
    let service = try LibraryService(store: store, initial: library)
    do {
        _ = try await service.reviewKey(
            trackID: library.tracks[0].id, key: .init(tonic: 4, mode: .minor), reason: " ", expectedRevision: 0)
        Issue.record("Accepted a review without a reason")
    } catch {}
    let reviewed = try await service.reviewKey(
        trackID: library.tracks[0].id, key: .init(tonic: 4, mode: .minor), reason: "Checked the tonal sections by ear",
        expectedRevision: 0)
    #expect(reviewed.tracks[0].keyDecision.authority == .manual)
    #expect(!reviewed.tracks[0].keyDecision.needsReview)
    #expect(reviewed.tracks[0].keyGovernance?.events.last?.reason == "Checked the tonal sections by ear")
    do {
        _ = try await service.reviewKey(
            trackID: library.tracks[0].id, key: .init(tonic: 1, mode: .major), reason: "Old review", expectedRevision: 0
        )
        Issue.record("Accepted a stale manual review")
    } catch {}
    #expect(try store.load(includeWaveforms: false).tracks[0].key == MusicalKey(tonic: 4, mode: .minor))
}

@Test func keyGovernanceKeepsIndependentAnalysisHistoryWithoutDisplacingMixedInKey() throws {
    var track = try importedKeyTrack(governedTrack())
    let previous = track.analysis
    track.analysis = AudioAnalysis(
        implementation: "new-test", configurationID: "new-test", contentSHA256: track.id, sampleRate: 48000,
        frameCount: 480000, channelCount: 2, waveformFramesPerBin: 512, waveform: [], bpm: 120, beatAnchorFrame: 0,
        tempoConfidence: 1, key: .init(tonic: 4, mode: .minor), keyConfidence: 1, chroma: [], timbre: [])
    track.recordKeyAnalysisChange(from: previous)
    #expect(track.keyDecision.authority == .mixedInKey)
    #expect(track.key == MusicalKey(tonic: 9, mode: .minor))
    #expect(
        track.keyGovernance?.events.suffix(2).map(\.analysisKey) == [
            MusicalKey(tonic: 0, mode: .major), MusicalKey(tonic: 4, mode: .minor),
        ])
    #expect(track.keyGovernance?.events.last?.analysisConfigurationID == "new-test")
}

@Test func keyGovernanceProtectsActiveTracksDuringImportApply() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    var library = LibrarySnapshot()
    library.tracks = try [governedTrack()]
    let service = try LibraryService(store: store, initial: library)
    let plan = try await service.previewKeyImport(data: JSONEncoder().encode(keyManifest(library.tracks[0])))
    do {
        _ = try await service.applyKeyImport(plan, preservePreparationFor: [library.tracks[0].id])
        Issue.record("Changed the key of a protected track")
    } catch {}
    let unchanged = await service.snapshot()
    #expect(unchanged.tracks[0].keyGovernance == nil)
}

@Test func keyGovernanceReopensWorkspaceWithEarlierPolicyHistory() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try WorkspaceStore(root: root)
    let track = try importedKeyTrack(importedKeyTrack(governedTrack()), key: "9A")
    var library = LibrarySnapshot()
    library.tracks = [track]
    try store.save(library)

    let data = try Data(contentsOf: store.libraryURL)
    var document = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var tracks = try #require(document["tracks"] as? [[String: Any]])
    var state = try #require(tracks[0]["keyGovernance"] as? [String: Any])
    var events = try #require(state["events"] as? [[String: Any]])
    events[0]["policyVersion"] = "key-authority-1"
    state["events"] = events
    tracks[0]["keyGovernance"] = state
    document["tracks"] = tracks
    let mixedHistory = try JSONSerialization.data(withJSONObject: document)
    try mixedHistory.write(to: store.libraryURL, options: .atomic)

    let reopened = try store.load(includeWaveforms: false)
    #expect(reopened.tracks[0].key == track.key)
    #expect(reopened.tracks[0].keyGovernance?.events.map(\.policyVersion) == ["key-authority-1", "key-authority-2"])
    #expect(try Data(contentsOf: store.libraryURL) == mixedHistory)
    try store.save(reopened)
    #expect(try store.load(includeWaveforms: false).tracks[0].keyGovernance == reopened.tracks[0].keyGovernance)

    events[0]["policyVersion"] = "key-authority-999"
    state["events"] = events
    tracks[0]["keyGovernance"] = state
    document["tracks"] = tracks
    try JSONSerialization.data(withJSONObject: document).write(to: store.libraryURL, options: .atomic)
    #expect(throws: CoreError.self) { try store.load(includeWaveforms: false) }
}
