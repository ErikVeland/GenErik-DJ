import CloudKit
import Foundation
import TDJCore

/// Sync retains revisions in the signed-in user's private database.
actor CloudPreparationSync: CKSyncEngineDelegate {
    static let containerID = "iCloud.org.generikdj.analysis"
    private let files = BackgroundFileWork(label: "org.generikdj.cloud-files")
    private var zoneID = CKRecordZone.ID(zoneName: "PreparationRevisions")
    private var engine: CKSyncEngine?
    private var vault: CloudPreparationVault?
    private var account: CKRecord.ID?
    private var stopped = false
    private var failure: String?
    private var confirmed: Set<String> = []
    private var uploadsRemaining: Int?
    private var engineStateFilename = "engine-state"

    struct Result: Sendable {
        let root: URL
        let revisions: [CloudPreparationVault.Revision]
        let message: String
    }

    func stop() async {
        stopped = true
        await engine?.cancelOperations()
    }

    func synchronize(
        store: WorkspaceStore, tracks: [Track], performance: PerformancePreparation, automatic: Bool = false,
        incomingDirectories: [URL] = [], expectedAccount: String? = nil,
        progress: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> Result {
        stopped = false
        uploadsRemaining = automatic ? 32 : nil
        zoneID = .init(zoneName: automatic ? "AutomaticAnalysis" : "PreparationRevisions")
        engineStateFilename = automatic ? "automatic-engine-state" : "engine-state"
        failure = nil
        let container = CKContainer(identifier: Self.containerID)
        guard try await container.accountStatus() == .available else {
            throw CoreError.invalidWorkspace("Sign in to iCloud before syncing. Local preparation is retained.")
        }
        let user = try await container.userRecordID()
        try check()
        account = user
        let accountID = CloudPreparationVault.digest(Data(user.recordName.utf8))
        guard expectedAccount == nil || expectedAccount == accountID else {
            throw CoreError.invalidWorkspace("The iCloud account does not match the library run. Uploads are paused.")
        }
        let root = store.root.appendingPathComponent("CloudPreparation").appendingPathComponent(accountID)
        let storage = try CloudPreparationVault(root: root)
        vault = storage
        try await files.run {
            Swift.Result {
                try Data(accountID.utf8).write(
                    to: root.deletingLastPathComponent().appendingPathComponent("last-account"), options: .atomic)
            }
        }.get()
        confirmed = try await files.run { () -> Swift.Result<Set<String>, Error> in
            Swift.Result {
                Set(
                    try FileManager.default.contentsOfDirectory(atPath: root.path)
                        .filter { $0.hasSuffix(".confirmed") }.map { String($0.dropLast(".confirmed".count)) })
            }
        }.get()
        let stateURL = root.appendingPathComponent(engineStateFilename)
        let state = try await files.run { () -> Swift.Result<CKSyncEngine.State.Serialization?, Error> in
            Swift.Result {
                guard FileManager.default.fileExists(atPath: stateURL.path) else { return nil }
                return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: Data(contentsOf: stateURL))
            }
        }.get()
        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: state, delegate: self)
        configuration.automaticallySync = false
        let syncEngine = CKSyncEngine(configuration)
        engine = syncEngine
        defer { engine = nil }
        syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])

        if automatic, !incomingDirectories.isEmpty {
            try await files.run {
                Swift.Result {
                    var retained = 0
                    for directory in incomingDirectories {
                        guard FileManager.default.fileExists(atPath: directory.path) else { continue }
                        let sources = try FileManager.default.contentsOfDirectory(
                            at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
                        for source in sources {
                            let id = source.deletingPathExtension().lastPathComponent
                            guard id.count == 64, id.allSatisfy(\.isHexDigit),
                                !FileManager.default.fileExists(atPath: storage.root.appendingPathComponent(id + ".json").path)
                            else { continue }
                            let sourceVault = try CloudPreparationVault(root: directory)
                            let archive = try sourceVault.read(id)
                            guard archive.automaticAnalysis == true else {
                                throw CoreError.invalidWorkspace("Only automatic analysis can enter the library upload queue.")
                            }
                            try storage.retain(data: Data(contentsOf: sourceVault.payloadURL(id)), expectedID: id)
                            retained += 1
                            if retained >= 32 { return }
                        }
                    }
                }
            }.get()
        }

        var captured = 0
        let exports = AutomaticAnalysisExports(root: root)
        var skipped = 0
        var firstFailure: String?
        for (index, track) in tracks.enumerated() {
            try check()
            guard CloudPreparationArchive.hasAudioIdentity(track) else {
                skipped += 1
                continue
            }
            let retained = await files.run { () -> Swift.Result<CloudPreparationVault.Revision?, Error> in
                autoreleasepool {
                    Swift.Result {
                        if automatic { return try exports.retain(track: track, store: store, vault: storage) }
                        return try storage.retain(
                            CloudPreparationVault.capture(store: store, track: track, performance: performance))
                    }
                }
            }
            try check()
            switch retained {
            case .success(let revision):
                guard let revision else { continue }
                captured += 1
                if !confirmed.contains(revision.id) {
                    syncEngine.state.add(pendingRecordZoneChanges: [
                        .saveRecord(.init(recordName: revision.id, zoneID: zoneID))
                    ])
                }
            case .failure(let error):
                skipped += 1
                if firstFailure == nil { firstFailure = "\(track.title): \(error.localizedDescription)" }
            }
            if automatic && captured >= 32 { break }
            if index % 25 == 0 { await progress("Saving local cloud revisions: \(index + 1)/\(tracks.count)") }
        }
        // Requeue retained files even if a previous launch ended before engine state was saved.
        let revisions = try await files.run { Swift.Result { try storage.list() } }.get()
        syncEngine.state.add(
            pendingRecordZoneChanges: revisions.filter {
                ($0.automaticAnalysis == true) == automatic && !confirmed.contains($0.id)
            }.map {
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

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async
        -> CKSyncEngine.RecordZoneChangeBatch?
    {
        guard engine === syncEngine, !stopped, failure == nil, uploadsRemaining != 0, let vault else { return nil }
        guard
            let change = syncEngine.state.pendingRecordZoneChanges.first(where: { context.options.scope.contains($0) }),
            case .saveRecord(let id) = change
        else { return nil }
        let result = await files.run { Swift.Result { try vault.read(id.recordName) } }
        guard !stopped else { return nil }
        switch result {
        case .success(let archive):
            let record = CKRecord(recordType: "PreparationRevision", recordID: id)
            record["audioSHA256"] = archive.track.analysis.contentSHA256
            record["payload"] = CKAsset(fileURL: vault.payloadURL(id.recordName))
            if uploadsRemaining != nil { uploadsRemaining! -= 1 }
            return .init(recordsToSave: [record], atomicByZone: false)
        case .failure(let error):
            failure = error.localizedDescription
            return nil
        }
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard engine === syncEngine, let vault else { return }
        let stateFilename = engineStateFilename
        do {
            switch event {
            case .stateUpdate(let update):
                guard failure == nil else { return }
                try await files.run {
                    Swift.Result {
                        try JSONEncoder().encode(update.stateSerialization)
                            .write(to: vault.root.appendingPathComponent(stateFilename), options: .atomic)
                    }
                }.get()
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
                    try await files.run {
                        Swift.Result {
                            for id in ids {
                                let marker = vault.root.appendingPathComponent(id + ".confirmed")
                                if FileManager.default.fileExists(atPath: marker.path) {
                                    try FileManager.default.removeItem(at: marker)
                                }
                            }
                        }
                    }.get()
                }
            case .sentRecordZoneChanges(let sent):
                for record in sent.savedRecords { try await markConfirmed(record.recordID.recordName, vault: vault) }
                for item in sent.failedRecordSaves {
                    if item.error.code == .serverRecordChanged,
                        let server = item.error.serverRecord,
                        server.recordID == item.record.recordID
                    {
                        // A repeated revision is accepted only after its payload is verified.
                        try await retain(server, vault: vault)
                        syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(server.recordID)])
                    } else {
                        failure = item.error.localizedDescription
                    }
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
                    try await files.run {
                        Swift.Result {
                            if FileManager.default.fileExists(atPath: marker.path) {
                                try FileManager.default.removeItem(at: marker)
                            }
                        }
                    }.get()
                }
            case .didFetchRecordZoneChanges(let result):
                if let error = result.error, error.code != .zoneNotFound { failure = error.localizedDescription }
            default: break
            }
        } catch { failure = error.localizedDescription }
    }

    private func retain(_ record: CKRecord, vault: CloudPreparationVault) async throws {
        guard record.recordType == "PreparationRevision", record.recordID.zoneID == zoneID,
            let asset = record["payload"] as? CKAsset, let url = asset.fileURL
        else {
            throw CoreError.invalidWorkspace("A cloud preparation record is incomplete.")
        }
        let id = record.recordID.recordName
        let date = record.creationDate ?? Date()
        try await files.run {
            Swift.Result {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= CloudPreparationArchive.maximumBytes else {
                    throw CoreError.invalidWorkspace("The cloud preparation is too large.")
                }
                _ = try vault.retain(data: Data(contentsOf: url), expectedID: id, savedAt: date)
            }
        }.get()
        try await markConfirmed(id, vault: vault)
    }

    private func markConfirmed(_ id: String, vault: CloudPreparationVault) async throws {
        guard id.count == 64, id.allSatisfy({ $0.isHexDigit }) else {
            throw CoreError.invalidWorkspace("The cloud revision identifier is invalid.")
        }
        try await files.run {
            Swift.Result {
                try Data().write(to: vault.root.appendingPathComponent(id + ".confirmed"), options: .atomic)
            }
        }.get()
        confirmed.insert(id)
    }
}
