import CloudKit
import Foundation
import TDJCore

/// Explicit sync retains revisions in the signed-in user's private database.
actor CloudPreparationSync: CKSyncEngineDelegate {
    static let containerID = "iCloud.org.generikdj.analysis"
    private let files = BackgroundFileWork(label: "org.generikdj.cloud-files")
    private let zoneID = CKRecordZone.ID(zoneName: "PreparationRevisions")
    private var engine: CKSyncEngine?
    private var vault: CloudPreparationVault?
    private var account: CKRecord.ID?
    private var stopped = false
    private var failure: String?
    private var confirmed: Set<String> = []

    struct Result: Sendable {
        let root: URL
        let revisions: [CloudPreparationVault.Revision]
        let message: String
    }

    func stop() async {
        stopped = true
        await engine?.cancelOperations()
    }

    func synchronize(store: WorkspaceStore, tracks: [Track], performance: PerformancePreparation,
        progress: @escaping @MainActor @Sendable (String) -> Void) async throws -> Result {
        stopped = false
        failure = nil
        let container = CKContainer(identifier: Self.containerID)
        guard try await container.accountStatus() == .available else {
            throw CoreError.invalidWorkspace("Sign in to iCloud before syncing. Local preparation is retained.")
        }
        let user = try await container.userRecordID()
        try check()
        account = user
        let accountID = CloudPreparationVault.digest(Data(user.recordName.utf8))
        let root = store.root.appendingPathComponent("CloudPreparation").appendingPathComponent(accountID)
        let storage = try CloudPreparationVault(root: root)
        vault = storage
        try await files.run { Swift.Result {
            try Data(accountID.utf8).write(to: root.deletingLastPathComponent().appendingPathComponent("last-account"), options: .atomic)
        } }.get()
        confirmed = try await files.run { () -> Swift.Result<Set<String>, Error> in
            Swift.Result { Set(try FileManager.default.contentsOfDirectory(atPath: root.path)
                .filter { $0.hasSuffix(".confirmed") }.map { String($0.dropLast(".confirmed".count)) }) }
        }.get()
        let stateURL = root.appendingPathComponent("engine-state")
        let state = try await files.run { () -> Swift.Result<CKSyncEngine.State.Serialization?, Error> in
            Swift.Result {
                guard FileManager.default.fileExists(atPath: stateURL.path) else { return nil }
                return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: Data(contentsOf: stateURL))
            }
        }.get()
        var configuration = CKSyncEngine.Configuration(database: container.privateCloudDatabase,
            stateSerialization: state, delegate: self)
        configuration.automaticallySync = false
        let syncEngine = CKSyncEngine(configuration)
        engine = syncEngine
        defer { engine = nil }
        syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])

        var skipped = 0
        var firstFailure: String?
        for (index, track) in tracks.enumerated() {
            try check()
            guard CloudPreparationArchive.hasAudioIdentity(track) else { skipped += 1; continue }
            let retained = await files.run { () -> Swift.Result<CloudPreparationVault.Revision, Error> in
                autoreleasepool { Swift.Result {
                    try storage.retain(CloudPreparationVault.capture(store: store, track: track, performance: performance))
                } }
            }
            try check()
            switch retained {
            case .success(let revision):
                if !confirmed.contains(revision.id) {
                    syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(.init(recordName: revision.id, zoneID: zoneID))])
                }
            case .failure(let error):
                skipped += 1
                if firstFailure == nil { firstFailure = "\(track.title): \(error.localizedDescription)" }
            }
            if index % 25 == 0 { await progress("Saving local cloud revisions: \(index + 1)/\(tracks.count)") }
        }
        // Requeue retained files even if a previous launch ended before engine state was saved.
        let revisions = try await files.run { Swift.Result { try storage.list() } }.get()
        syncEngine.state.add(pendingRecordZoneChanges: revisions.filter { !confirmed.contains($0.id) }.map {
            .saveRecord(.init(recordName: $0.id, zoneID: zoneID))
        })
        try check()
        await progress("Uploading saved preparation revisions…")
        let group = CKOperationGroup()
        group.defaultConfiguration.qualityOfService = .background
        try await syncEngine.sendChanges(.init(operationGroup: group))
        try check()
        await progress("Downloading cloud preparation revisions…")
        try await syncEngine.fetchChanges(.init(scope: .zoneIDs([zoneID]), operationGroup: group))
        try check()
        let all = try await files.run { Swift.Result { try storage.list() } }.get()
        let pending = all.filter { !confirmed.contains($0.id) }.count
        var message = "\(confirmed.count) cloud revisions confirmed."
        if pending > 0 { message += " \(pending) local revisions are waiting to upload." }
        if skipped > 0 { message += " \(skipped) tracks were not saved to cloud." }
        if let firstFailure { message += " \(firstFailure)" }
        return Result(root: root, revisions: all, message: message)
    }

    private func check() throws {
        try Task.checkCancellation()
        if stopped { throw CancellationError() }
        if let failure { throw CoreError.invalidWorkspace(failure) }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard !stopped, failure == nil, let vault else { return nil }
        guard let change = syncEngine.state.pendingRecordZoneChanges.first(where: { context.options.scope.contains($0) }),
            case .saveRecord(let id) = change else { return nil }
        let result = await files.run { Swift.Result { try vault.read(id.recordName) } }
        guard !stopped else { return nil }
        switch result {
        case .success(let archive):
            let record = CKRecord(recordType: "PreparationRevision", recordID: id)
            record["audioSHA256"] = archive.track.analysis.contentSHA256
            record["payload"] = CKAsset(fileURL: vault.payloadURL(id.recordName))
            return .init(recordsToSave: [record], atomicByZone: false)
        case .failure(let error): failure = error.localizedDescription; return nil
        }
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard let vault else { return }
        do {
            switch event {
            case .stateUpdate(let update):
                guard failure == nil else { return }
                try await files.run { Swift.Result {
                    try JSONEncoder().encode(update.stateSerialization)
                        .write(to: vault.root.appendingPathComponent("engine-state"), options: .atomic)
                } }.get()
            case .accountChange(let change):
                switch change.changeType {
                case .signIn(let current) where current == account: break
                default:
                    stopped = true
                    failure = "The iCloud account changed. Start sync again. Local preparation is retained."
                }
            case .sentDatabaseChanges(let sent):
                if let error = sent.failedZoneSaves.first?.error { failure = error.localizedDescription }
            case .fetchedDatabaseChanges(let fetched):
                if fetched.deletions.contains(where: { $0.zoneID == zoneID }) {
                    let ids = confirmed
                    confirmed.removeAll()
                    try await files.run { Swift.Result {
                        for id in ids {
                            let marker = vault.root.appendingPathComponent(id + ".confirmed")
                            if FileManager.default.fileExists(atPath: marker.path) { try FileManager.default.removeItem(at: marker) }
                        }
                    } }.get()
                }
            case .sentRecordZoneChanges(let sent):
                for record in sent.savedRecords { try await markConfirmed(record.recordID.recordName, vault: vault) }
                for item in sent.failedRecordSaves {
                    if item.error.code == .serverRecordChanged,
                        let server = item.error.serverRecord,
                        server.recordID == item.record.recordID {
                        // A repeated revision is accepted only after its payload is verified.
                        try await retain(server, vault: vault)
                        syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(server.recordID)])
                    } else { failure = item.error.localizedDescription }
                }
            case .fetchedRecordZoneChanges(let fetched):
                for item in fetched.modifications {
                    guard !stopped else { throw CancellationError() }
                    try await retain(item.record, vault: vault)
                }
                // Remote deletions never remove retained local recovery versions.
                for item in fetched.deletions {
                    let id = item.recordID.recordName
                    guard id.count == 64, id.allSatisfy({ $0.isHexDigit }) else { continue }
                    confirmed.remove(id)
                    let marker = vault.root.appendingPathComponent(id + ".confirmed")
                    try await files.run { Swift.Result {
                        if FileManager.default.fileExists(atPath: marker.path) { try FileManager.default.removeItem(at: marker) }
                    } }.get()
                }
            case .didFetchRecordZoneChanges(let result):
                if let error = result.error, error.code != .zoneNotFound { failure = error.localizedDescription }
            default: break
            }
        } catch { failure = error.localizedDescription }
    }

    private func retain(_ record: CKRecord, vault: CloudPreparationVault) async throws {
        guard record.recordType == "PreparationRevision", record.recordID.zoneID == zoneID,
            let asset = record["payload"] as? CKAsset, let url = asset.fileURL else {
            throw CoreError.invalidWorkspace("A cloud preparation record is incomplete.")
        }
        let id = record.recordID.recordName
        let date = record.creationDate ?? Date()
        try await files.run { Swift.Result {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= CloudPreparationArchive.maximumBytes else { throw CoreError.invalidWorkspace("The cloud preparation is too large.") }
            _ = try vault.retain(data: Data(contentsOf: url), expectedID: id, savedAt: date)
        } }.get()
        try await markConfirmed(id, vault: vault)
    }

    private func markConfirmed(_ id: String, vault: CloudPreparationVault) async throws {
        guard id.count == 64, id.allSatisfy({ $0.isHexDigit }) else {
            throw CoreError.invalidWorkspace("The cloud revision identifier is invalid.")
        }
        try await files.run { Swift.Result { try Data().write(to: vault.root.appendingPathComponent(id + ".confirmed"), options: .atomic) } }.get()
        confirmed.insert(id)
    }
}
