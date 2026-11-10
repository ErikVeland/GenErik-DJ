import Foundation
import TDJCore

extension ReplicaModel {
    func startAutomaticPreparationSharing() {
        guard automaticCloudLoop == nil, !nativeMusic.closed else { return }
        automaticCloudLoop = Task { [weak self] in
            while !Task.isCancelled {
                if let self, !self.nativeMusic.closed, !self.nativeMusic.backgrounded,
                    Date() >= self.automaticCloudRetryAt, self.canSyncCloud
                {
                    self.startCloudSync(automatic: true)
                }
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
    }

    func stopAutomaticPreparationSharing() {
        automaticCloudLoop?.cancel()
        automaticCloudLoop = nil
        cancelCloudSyncForPlayback()
    }

    func adoptAutomaticCloudResults(_ result: CloudPreparationSync.Result) async throws {
        if automaticCloudAccount != result.root {
            automaticCloudAccount = result.root
            automaticCloudRead.removeAll()
        }
        let tracks = library.tracks
        let byHash = await cloudFiles.run { Dictionary(grouping: tracks, by: { $0.analysis.contentSHA256 }) }
        for revision in result.revisions
        where revision.automaticAnalysis == true && !automaticCloudRead.contains(revision.id) {
            try Task.checkCancellation()
            guard cloudPlaybackIsIdle, !nativeMusic.backgrounded, !nativeMusic.closed else { throw CancellationError() }
            let matches = byHash[revision.audioSHA256] ?? []
            guard !matches.isEmpty else { continue }
            let read = await cloudFiles.run {
                Result { try CloudPreparationVault(root: result.root).read(revision.id) }
            }
            guard case .success(var archive) = read else {
                automaticCloudRead.insert(revision.id)
                logAnalysis("A shared analysis failed its integrity check. Its saved file was retained.")
                continue
            }
            // Legacy exports use their cloud revision date until they carry a completion date.
            if archive.track.analysis.deepBeatAnalysis?.completedAt == nil {
                var source = archive.track
                source.analysis.deepBeatAnalysis?.completedAt = revision.savedAt
                archive = .analysisOnly(track: source, arrangement: archive.arrangement)
            }
            var deferred = false
            for match in matches {
                try Task.checkCancellation()
                guard cloudPlaybackIsIdle else { throw CancellationError() }
                guard !sharedAnalysisTrackIsProtected(match.id), nativeMusic.loadOwners.isEmpty,
                    preparingPlayback.isEmpty, let local = library.track(id: match.id), archive.matches(local)
                else {
                    deferred = true
                    continue
                }
                let merged = try archive.automaticallyMergedTrack(matching: local)
                let store = store
                let performance = performance
                if merged != local {
                    try await cloudFiles.run {
                        Result {
                            let history = try CloudPreparationVault(
                                root: store.root.appendingPathComponent("RecoveryVersions"))
                            try history.retain(
                                CloudPreparationVault.capture(store: store, track: local, performance: performance))
                        }
                    }.get()
                    try Task.checkCancellation()
                    guard cloudPlaybackIsIdle, !sharedAnalysisTrackIsProtected(local.id), nativeMusic.loadOwners.isEmpty
                    else {
                        deferred = true
                        continue
                    }
                    if let deep = archive.track.analysis.deepBeatAnalysis {
                        adoptLibrary(
                            try await service.adoptDeepAnalysis(
                                deep, trackID: local.id,
                                protectedTracks: Set(loaded.values)))
                    }
                }
                try Task.checkCancellation()
                guard cloudPlaybackIsIdle, !sharedAnalysisTrackIsProtected(local.id), nativeMusic.loadOwners.isEmpty
                else {
                    deferred = true
                    continue
                }
                try await adoptSharedArrangement(archive, track: library.track(id: local.id) ?? local)
            }
            if !deferred { automaticCloudRead.insert(revision.id) }
        }
    }

    private func sharedAnalysisTrackIsProtected(_ id: String) -> Bool {
        loaded.values.contains(id) || nativeMusic.activeTrackID == id
    }

    private func adoptSharedArrangement(_ archive: CloudPreparationArchive, track: Track) async throws {
        guard archive.automaticAnalysis == true, archive.matches(track), let data = archive.arrangement else { return }
        let decoded = await nativeMusic.files.run { try? JSONDecoder().decode(ArrangementCache.self, from: data) }
        guard let incoming = decoded,
            incoming.isCurrent(for: track.analysis, context: .init(title: track.title, genre: track.genre))
        else { return }
        let url = arrangementURL(track.id)
        let previous = await nativeMusic.files.run {
            (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(ArrangementCache.self, from: $0) }
        }
        if let previous,
            previous.isCurrent(for: track.analysis, context: .init(title: track.title, genre: track.genre)),
            previous.automaticCues != nil
        {
            return
        }
        let saved = await nativeMusic.files.run {
            var candidate = incoming
            if let previous { candidate.arrangement.retainCorrections(from: previous.arrangement) }
            candidate.automaticCues = SectionCueAllocator.allocate(
                sections: candidate.arrangement.sections, existing: [:], alreadyPrepared: false)
            return candidate
        }
        try Task.checkCancellation()
        guard cloudPlaybackIsIdle, !sharedAnalysisTrackIsProtected(track.id), nativeMusic.loadOwners.isEmpty else {
            throw CancellationError()
        }
        let store = store
        let performance = performance
        try await nativeMusic.files.run {
            Result {
                if previous != nil {
                    let history = try CloudPreparationVault(root: store.root.appendingPathComponent("RecoveryVersions"))
                    try history.retain(
                        CloudPreparationVault.capture(store: store, track: track, performance: performance))
                }
                try saved.write(to: url)
            }
        }.get()
    }
}
