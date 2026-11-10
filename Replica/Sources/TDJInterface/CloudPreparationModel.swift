import Foundation
import TDJCore

struct CloudRecoveryChoice: Identifiable, Sendable {
    let revision: CloudPreparationVault.Revision
    let root: URL
    var id: String { root.lastPathComponent + revision.id }
}

extension ReplicaModel {
    public var canSyncCloud: Bool { !cloudBusy && !macSourceTransferActive && cloudPlaybackIsIdle }

    var cloudPlaybackIsIdle: Bool {
        guard !playback.isRecording, !playback.recordingFinishing, !importing,
            !musicLibraryRefreshing, !musicLibraryPreparing, !deckAnalysisIsRunning,
            preparingTrack.isEmpty, preparingSourceActions.isEmpty,
            applyingGrids.isEmpty, detectingGrids.isEmpty
        else { return false }
        guard let snapshot = playback.core.snapshot() else { return true }
        return !DeckID.allCases.contains { snapshot[$0].phase.active || snapshot[$0].touchActive }
    }

    public func startCloudSync() { startCloudSync(automatic: false) }

    func startCloudSync(automatic: Bool) {
        guard canSyncCloud else { return }
        cloudBusy = true
        cloudSyncIsAutomatic = automatic
        cloudStatus = "Preparing local revisions…"
        logAnalysis("Cloud sync started. Automatic: \(automatic).")
        if !automatic { cancelNativeMusicAnalysis() }
        cloudTask = Task {
            let timeout = Task { [weak self, cloudSync] in
                do {
                    try await Task.sleep(for: .seconds(automatic ? 45 : 120))
                    try Task.checkCancellation()
                    self?.cloudTask?.cancel()
                    await cloudSync.stop()
                } catch {}
            }
            defer {
                timeout.cancel()
                cloudBusy = false
                cloudSyncIsAutomatic = false
                cloudTask = nil
                startNativeMusicAnalysis()
            }
            do {
                if !automatic { await flushNativeMusicAnalysis() }
                await flushWrites()
                await flushPerformanceWrites()
                try Task.checkCancellation()
                guard cloudPlaybackIsIdle else { throw CancellationError() }
                var result = try await cloudSync.synchronize(
                    store: store, tracks: library.tracks,
                    performance: performance, automatic: automatic,
                    retainedResults: { [self] in try await adoptAutomaticCloudResults($0) }
                ) { [self] message in
                    self.cloudStatus = message
                    self.logAnalysis("Cloud sync: \(message)")
                }
                if !automatic {
                    let shared = try await cloudSync.synchronize(
                        store: store, tracks: library.tracks,
                        performance: performance, automatic: true,
                        retainedResults: { [self] in try await adoptAutomaticCloudResults($0) }
                    ) { [self] message in self.cloudStatus = message }
                    result = .init(
                        root: shared.root, revisions: shared.revisions,
                        message: result.message + " " + shared.message)
                }
                try Task.checkCancellation()
                try await adoptAutomaticCloudResults(result)
                cloudStatus = result.message
                logAnalysis("Cloud sync finished: \(result.message)")
                automaticCloudRetryAt = Date().addingTimeInterval(60)
                if !automatic { await loadCloudVersions() }
            } catch is CancellationError {
                automaticCloudRetryAt = Date().addingTimeInterval(30)
                cloudStatus = "Sync paused. Saved analysis will retry while the decks are idle."
                logAnalysis("Cloud sync cancelled at: \(cloudStatus)")
            } catch {
                cloudStatus = "Sync did not finish. Local preparation is retained. \(error.localizedDescription)"
                logAnalysis("Cloud sync failed: \((error as NSError).domain) \((error as NSError).code); \(error.localizedDescription)")
                automaticCloudRetryAt = Date().addingTimeInterval(300)
                if !automatic { await loadCloudVersions() }
            }
        }
    }

    func cancelCloudSyncForPlayback() {
        macSourceTransferWork?.cancel()
        guard let cloudTask, !cloudTask.isCancelled else { return }
        cloudTask.cancel()
        Task { await cloudSync.stop() }
    }

    func loadCloudVersions() async {
        let root = store.root
        let result = await cloudFiles.run {
            Result { () -> [CloudRecoveryChoice] in
                var roots = [root.appendingPathComponent("RecoveryVersions")]
                let accountFile = root.appendingPathComponent("CloudPreparation/last-account")
                if let account = try? String(contentsOf: accountFile, encoding: .utf8),
                    account.count == 64, account.allSatisfy({ $0.isHexDigit })
                {
                    roots.append(root.appendingPathComponent("CloudPreparation").appendingPathComponent(account))
                }
                return try roots.filter { FileManager.default.fileExists(atPath: $0.path) }.flatMap { path in
                    try CloudPreparationVault(root: path).list().filter { $0.automaticAnalysis != true }.map {
                        CloudRecoveryChoice(revision: $0, root: path)
                    }
                }.sorted { $0.revision.savedAt > $1.revision.savedAt }
            }
        }
        if case .success(let versions) = result { cloudVersions = versions }
    }

    func scheduleCloudRecovery(_ choice: CloudRecoveryChoice) {
        guard canSyncCloud else { return }
        let matches = library.tracks.filter {
            CloudPreparationArchive.hasAudioIdentity($0) && $0.analysis.contentSHA256 == choice.revision.audioSHA256
        }
        guard
            let track = matches.first(where: { $0.id == choice.revision.sourceTrackID })
                ?? (matches.count == 1 ? matches.first : nil)
        else {
            cloudStatus = "Import and fully analyze the matching audio file before restoring this revision."
            return
        }
        cloudBusy = true
        cancelNativeMusicAnalysis()
        cloudTask = Task {
            defer {
                cloudBusy = false
                cloudTask = nil
            }
            do {
                await flushNativeMusicAnalysis()
                await flushWrites()
                await flushPerformanceWrites()
                try Task.checkCancellation()
                guard cloudPlaybackIsIdle else { throw CancellationError() }
                let store = store
                try await cloudFiles.run {
                    Result {
                        let archive = try CloudPreparationVault(root: choice.root).read(choice.revision.id)
                        try CloudPreparationRecovery.schedule(archive, trackID: track.id, store: store)
                    }
                }.get()
                cloudStatus =
                    "Recovery is scheduled for the next launch. Close and reopen the app. Your current preparation has a saved recovery version."
            } catch is CancellationError {
                cloudStatus = "Recovery preparation stopped. Your local preparation is retained."
            } catch { cloudStatus = error.localizedDescription }
        }
    }
}
