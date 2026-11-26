import CloudKit
import Foundation
import TDJCore
import os

enum SharedAnalysisCloud {
    static let recordType = "SharedAnalysisV1"
    static let field = "analysis"

    static func fetch(_ names: [String]) async throws -> [String: Data] {
        try Task.checkCancellation()
        let database = CKContainer(identifier: CloudPreparationSync.containerID).publicCloudDatabase
        let operation = CKFetchRecordsOperation(recordIDs: names.map { CKRecord.ID(recordName: $0) })
        operation.desiredKeys = [field]
        operation.configuration.qualityOfService = .background
        operation.configuration.timeoutIntervalForRequest = 3
        operation.configuration.timeoutIntervalForResource = 5

        let replies = OSAllocatedUnfairLock(initialState: [String: Result<Data?, Error>]())
        operation.perRecordResultBlock = { id, result in
            let reply = result.map { record in
                record.recordType == recordType ? record[field] as? Data : nil
            }
            replies.withLock { $0[id.recordName] = reply }
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operation.fetchRecordsResultBlock = { result in
                    continuation.resume(with: Result {
                        if case .failure(let error) = result, (error as? CKError)?.code != .partialFailure {
                            throw error
                        }
                        let collected = replies.withLock { $0 }
                        var payloads: [String: Data] = [:]
                        for name in names {
                            guard let reply = collected[name] else {
                                try result.get()
                                continue
                            }
                            do {
                                payloads[name] = try reply.get()
                            } catch let error as CKError where error.code == .unknownItem {
                                continue
                            }
                        }
                        return payloads
                    })
                }
                database.add(operation)
            }
        } onCancel: {
            operation.cancel()
        }
    }
}

extension ReplicaModel {
    func checkSharedAnalysisCatalogue() async throws {
        guard storeAccess.developerAccess, let catalog = musicLibraryCatalog,
            Date() >= sharedAnalysisRetryAt, cloudPlaybackIsIdle else { return }

        if Date() >= sharedAnalysisNextRefresh {
            sharedAnalysisChecked.removeAll()
            sharedAnalysisNextRefresh = Date().addingTimeInterval(3600)
        }
        let version = musicLibraryCatalogVersion
        let tracks = library.tracks
        let excluding = Set(loaded.values).union(nativeMusic.activeTrackID.map { [$0] } ?? [])
        let checked = sharedAnalysisChecked
        let targets = await cloudFiles.run {
            SharedAnalysisCatalogue.targets(tracks: tracks, catalog: catalog, excluding: excluding, checked: checked)
        }
        try Task.checkCancellation()
        guard cloudPlaybackIsIdle, version == musicLibraryCatalogVersion else { return }
        guard !targets.isEmpty else {
            sharedAnalysisRetryAt = Date().addingTimeInterval(300)
            return
        }

        let payloads: [String: Data]
        do {
            payloads = try await SharedAnalysisCloud.fetch(Array(targets.keys))
        } catch {
            try Task.checkCancellation()
            let retry = (error as? CKError)?.retryAfterSeconds ?? 0
            sharedAnalysisRetryAt = Date().addingTimeInterval(max(300, retry))
            logAnalysis("Shared catalogue lookup could not finish. \(Self.cloudErrorSummary(error))")
            return
        }
        let matches = await cloudFiles.run {
            var results: [String: DeepBeatAnalysis] = [:]
            for (name, payload) in payloads {
                for track in targets[name] ?? [] {
                    results[track.id] = SharedAnalysisCatalogue.decode(payload, matching: track)
                }
            }
            return results
        }
        try Task.checkCancellation()
        guard cloudPlaybackIsIdle, version == musicLibraryCatalogVersion, nativeMusic.loadOwners.isEmpty,
            preparingPlayback.isEmpty else { return }

        let protected = Set(loaded.values).union(nativeMusic.activeTrackID.map { [$0] } ?? [])
        if !matches.isEmpty {
            let oldRevision = library.revision
            adoptLibrary(try await service.adoptDeepAnalyses(matches, protectedTracks: protected, onlyMissing: true))
            if library.revision != oldRevision { logAnalysis("Shared catalogue saved deep analysis for playlist tracks.") }
        }
        for (name, tracks) in targets where !tracks.contains(where: { protected.contains($0.id) }) {
            sharedAnalysisChecked.insert(name)
        }
    }
}
