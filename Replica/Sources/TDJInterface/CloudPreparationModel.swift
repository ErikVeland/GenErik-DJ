import Foundation
import TDJCore

struct CloudRecoveryChoice: Identifiable, Sendable {
    let revision: CloudPreparationVault.Revision
    let root: URL
    var id: String { root.lastPathComponent + revision.id }
}

extension ReplicaModel {
    public var canSyncCloud: Bool { !cloudBusy && cloudPlaybackIsIdle }

    private var cloudPlaybackIsIdle: Bool {
        guard !playback.isRecording, !playback.recordingFinishing, !importing,
            !musicLibraryRefreshing, !musicLibraryPreparing, !deckAnalysisIsRunning,
            preparingTrack.isEmpty, preparingSourceActions.isEmpty,
            applyingGrids.isEmpty, detectingGrids.isEmpty else { return false }
        guard let snapshot = playback.core.snapshot() else { return true }
        return !DeckID.allCases.contains { snapshot[$0].phase.active || snapshot[$0].touchActive }
    }

    public func startCloudSync() {
        guard canSyncCloud else { return }
        cloudBusy = true
        cloudStatus = "Preparing local revisions…"
        cancelNativeMusicAnalysis()
        cloudTask = Task {
            defer { cloudBusy = false; cloudTask = nil }
            do {
                await flushNativeMusicAnalysis()
                await flushWrites()
                await flushPerformanceWrites()
                try Task.checkCancellation()
                guard cloudPlaybackIsIdle else { throw CancellationError() }
                let result = try await cloudSync.synchronize(store: store, tracks: library.tracks,
                    performance: performance) { [self] message in self.cloudStatus = message }
                try Task.checkCancellation()
                cloudStatus = result.message
                await loadCloudVersions()
            } catch is CancellationError {
                cloudStatus = "Sync stopped. Saved local revisions are retained. Select Sync now when the decks are idle."
            } catch {
                cloudStatus = "Sync did not finish. Local preparation is retained. \(error.localizedDescription)"
                await loadCloudVersions()
            }
        }
    }

    func cancelCloudSyncForPlayback() {
        guard let cloudTask, !cloudTask.isCancelled else { return }
        cloudTask.cancel()
        Task { await cloudSync.stop() }
    }

    func loadCloudVersions() async {
        let root = store.root
        let result = await cloudFiles.run { Result { () -> [CloudRecoveryChoice] in
            var roots = [root.appendingPathComponent("RecoveryVersions")]
            let accountFile = root.appendingPathComponent("CloudPreparation/last-account")
            if let account = try? String(contentsOf: accountFile, encoding: .utf8),
                account.count == 64, account.allSatisfy({ $0.isHexDigit }) {
                roots.append(root.appendingPathComponent("CloudPreparation").appendingPathComponent(account))
            }
            return try roots.filter { FileManager.default.fileExists(atPath: $0.path) }.flatMap { path in
                try CloudPreparationVault(root: path).list().map { CloudRecoveryChoice(revision: $0, root: path) }
            }.sorted { $0.revision.savedAt > $1.revision.savedAt }
        } }
        if case .success(let versions) = result { cloudVersions = versions }
    }

    func scheduleCloudRecovery(_ choice: CloudRecoveryChoice) {
        guard canSyncCloud else { return }
        let matches = library.tracks.filter {
            CloudPreparationArchive.hasAudioIdentity($0) && $0.analysis.contentSHA256 == choice.revision.audioSHA256
        }
        guard let track = matches.first(where: { $0.id == choice.revision.sourceTrackID })
            ?? (matches.count == 1 ? matches.first : nil) else {
            cloudStatus = "Import and fully analyze the matching audio file before restoring this revision."
            return
        }
        cloudBusy = true
        cancelNativeMusicAnalysis()
        cloudTask = Task {
            defer { cloudBusy = false; cloudTask = nil }
            do {
                await flushNativeMusicAnalysis()
                await flushWrites()
                await flushPerformanceWrites()
                try Task.checkCancellation()
                guard cloudPlaybackIsIdle else { throw CancellationError() }
                let store = store
                try await cloudFiles.run { Result {
                    let archive = try CloudPreparationVault(root: choice.root).read(choice.revision.id)
                    try CloudPreparationRecovery.schedule(archive, trackID: track.id, store: store)
                } }.get()
                cloudStatus = "Recovery is scheduled for the next launch. Close and reopen the app. Your current preparation has a saved recovery version."
            } catch is CancellationError {
                cloudStatus = "Recovery preparation stopped. Your local preparation is retained."
            } catch { cloudStatus = error.localizedDescription }
        }
    }
}
