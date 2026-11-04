import Foundation

/// A preview binds all proposed changes to one library state. Applying it never writes external files.
public struct KeyImportPlan: Sendable {
    public struct Change: Codable, Equatable, Sendable {
        public let trackID: String
        public let before: KeyDecision
        public let after: KeyDecision
        public let addsEvidence: Bool
    }
    public let policyVersion = KeyGovernancePolicy.version
    public let manifestSHA256: String
    public let expectedRevision: Int
    public let changes: [Change]
    private let expectedTracks: [Track]
    private let proposedTracks: [Track]

    public init(manifest: KeyImportManifest, library: LibrarySnapshot) throws {
        try manifest.validate()
        expectedRevision = library.revision
        manifestSHA256 = try KeyImportManifest.digest(manifest)
        var expected: [Track] = []
        var proposed: [Track] = []
        var changes: [Change] = []
        for entry in manifest.entries {
            guard var track = library.track(id: entry.contentSHA256) else {
                throw CoreError.invalidAudio("Every imported key needs an exact existing track identity.")
            }
            expected.append(track)
            let before = track.keyDecision
            var state = track.keyGovernance ?? .init()
            try state.validate(trackID: track.id)
            let observation = try KeyObservation(manifest: manifest, entry: entry, digest: manifestSHA256)
            let addsEvidence = !state.observations.contains { $0.id == observation.id }
            if addsEvidence {
                state.observations.append(observation)
                if observation.source == .mixedInKey && state.acceptedMixedInKeyID == nil {
                    state.acceptedMixedInKeyID = observation.id
                }
                track.keyGovernance = state
                state.events.append(.init(action: "import", observationID: observation.id, decision: track.keyDecision))
                track.keyGovernance = state
                try state.validate(trackID: track.id)
            }
            proposed.append(track)
            changes.append(
                .init(trackID: track.id, before: before, after: track.keyDecision, addsEvidence: addsEvidence))
        }
        expectedTracks = expected
        proposedTracks = proposed
        self.changes = changes
    }

    public func applying(to library: LibrarySnapshot) throws -> LibrarySnapshot {
        guard library.revision == expectedRevision, expectedTracks.allSatisfy({ library.track(id: $0.id) == $0 }) else {
            throw CoreError.staleContext
        }
        guard changes.contains(where: \.addsEvidence) else { return library }
        var changed = library
        let replacements = Dictionary(uniqueKeysWithValues: proposedTracks.map { ($0.id, $0) })
        for index in changed.tracks.indices {
            if let replacement = replacements[changed.tracks[index].id] { changed.tracks[index] = replacement }
        }
        changed.revision += 1
        return changed
    }
}
