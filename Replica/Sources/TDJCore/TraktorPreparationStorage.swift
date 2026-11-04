import Foundation

public enum TraktorPreparationStorage {
    private enum CollectionOrigin: String, Codable { case automatic, manual }
    private struct ActiveCollection: Codable {
        let digest: String
        let origin: CollectionOrigin?
    }

    public static func importCollection(at source: URL, store: WorkspaceStore) async throws -> TraktorPreparationCatalog
    {
        try await AnalysisWorker.shared.run(checkAfterWork: false) { check in
            let data = try readBounded(source)
            let catalog = try withoutActuallyEscaping(check) { cancellation in
                try TraktorPreparationCatalog.read(data, checkCancellation: cancellation)
            }
            try check()
            try retain(data, catalog: catalog, store: store, origin: .manual, check: check)
            return catalog
        }
    }

    public static func discover(store: WorkspaceStore, includeSyncedFolder: Bool = false, automaticSources: [URL] = [])
        async throws -> TraktorPreparationCatalog?
    {
        try await AnalysisWorker.shared.run(checkAfterWork: false) { check in
            let directory = store.root.appendingPathComponent("TraktorReferences", isDirectory: true)
            let pointer = directory.appendingPathComponent("current.json")
            var retained: TraktorPreparationCatalog?
            var retainedData: Data?
            if FileManager.default.fileExists(atPath: pointer.path) {
                let state = try JSONDecoder().decode(ActiveCollection.self, from: readBounded(pointer))
                guard state.digest.count == 64, state.digest.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
                    throw CoreError.invalidWorkspace("Invalid collection reference identity.")
                }
                let data = try readBounded(directory.appendingPathComponent(state.digest + ".collection"))
                let catalog = try withoutActuallyEscaping(check) { cancellation in
                    try TraktorPreparationCatalog.read(data, checkCancellation: cancellation)
                }
                guard catalog.summary.sourceSHA256 == state.digest else {
                    throw CoreError.invalidWorkspace("Collection reference integrity check failed.")
                }
                // A legacy pointer represents the user's existing selection.
                if state.origin != .automatic { return catalog }
                retained = catalog
                retainedData = data
            }
            var candidates =
                automaticSources + [
                    directory.appendingPathComponent("collection.nml.gz"),
                    directory.appendingPathComponent("collection.nml"),
                ]
            #if os(macOS)
                if includeSyncedFolder {
                    candidates.append(
                        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
                            "Library/Mobile Documents/iCloud~com~native-instruments~tdj/Documents/collection.nml.gz"))
                }
            #endif
            for candidate in candidates {
                try check()
                guard FileManager.default.isReadableFile(atPath: candidate.path) else { continue }
                let data = try readBounded(candidate)
                if data == retainedData { return retained }
                let catalog = try withoutActuallyEscaping(check) { cancellation in
                    try TraktorPreparationCatalog.read(data, checkCancellation: cancellation)
                }
                try check()
                try retain(data, catalog: catalog, store: store, origin: .automatic, check: check)
                return catalog
            }
            try check()
            return retained
        }
    }

    public static func readCollection(at url: URL) async throws -> TraktorPreparationCatalog {
        try await AnalysisWorker.shared.run { check in
            try withoutActuallyEscaping(check) { cancellation in
                try TraktorPreparationCatalog.read(readBounded(url), checkCancellation: cancellation)
            }
        }
    }

    private static func retain(
        _ data: Data, catalog: TraktorPreparationCatalog, store: WorkspaceStore, origin: CollectionOrigin,
        check: () throws -> Void
    ) throws {
        let directory = store.root.appendingPathComponent("TraktorReferences", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let archive = directory.appendingPathComponent(catalog.summary.sourceSHA256 + ".collection")
        if FileManager.default.fileExists(atPath: archive.path) {
            guard try readBounded(archive) == data else {
                throw CoreError.invalidWorkspace("The archived collection reference has changed.")
            }
        } else {
            try data.write(to: archive, options: .atomic)
        }
        try check()
        let pointer = try JSONEncoder().encode(ActiveCollection(digest: catalog.summary.sourceSHA256, origin: origin))
        try pointer.write(to: directory.appendingPathComponent("current.json"), options: .atomic)
    }

    private static func readBounded(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size >= 0, size <= 16 * 1024 * 1024 else { throw TraktorNMLReadError.limitExceeded }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 16 * 1024 * 1024 + 1) ?? Data()
        guard data.count <= 16 * 1024 * 1024 else { throw TraktorNMLReadError.limitExceeded }
        return data
    }
}
