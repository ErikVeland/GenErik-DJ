import Foundation

/// Recovery runs before the library opens. Its journal survives an interrupted write.
public enum CloudPreparationRecovery {
    private struct Request: Codable {
        let trackID: String
        let previous: String
        let selected: String
        var started = false
    }
    public static func requestURL(_ store: WorkspaceStore) -> URL {
        store.root.appendingPathComponent("cloud-recovery.json")
    }
    public static func schedule(_ archive: CloudPreparationArchive, trackID: String, store: WorkspaceStore) throws {
        guard !FileManager.default.fileExists(atPath: requestURL(store).path) else {
            throw CoreError.invalidWorkspace("A recovery is already scheduled. Restart the app to finish it.")
        }
        let library = try store.load(includeWaveforms: false)
        guard let local = library.track(id: trackID), archive.matches(local) else {
            throw CoreError.invalidWorkspace("The cloud preparation does not match this audio file.")
        }
        let performance = try PerformancePreparation.load(from: store.root.appendingPathComponent("performance.json"))
        let vault = try CloudPreparationVault(root: store.root.appendingPathComponent("RecoveryVersions"))
        let previous = try vault.retain(CloudPreparationVault.capture(store: store, track: local, performance: performance))
        let selected = try vault.retain(archive)
        try JSONEncoder().encode(Request(trackID: trackID, previous: previous.id, selected: selected.id))
            .write(to: requestURL(store), options: .atomic)
    }

    public static func applyPending(store: WorkspaceStore) throws {
        let url = requestURL(store)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: url))
        let vault = try CloudPreparationVault(root: store.root.appendingPathComponent("RecoveryVersions"))
        let archive = try vault.read(request.selected)
        let previous = try vault.read(request.previous)
        var library = try store.load(includeWaveforms: false)
        var performance = try PerformancePreparation.load(from: store.root.appendingPathComponent("performance.json"))
        guard let index = library.tracks.firstIndex(where: { $0.id == request.trackID }), archive.matches(library.tracks[index]) else {
            throw CoreError.invalidWorkspace("The recovery audio is unavailable. The saved revisions are retained.")
        }
        if !request.started {
            let current = try CloudPreparationVault.capture(store: store, track: library.tracks[index], performance: performance)
            guard current == previous else {
                try FileManager.default.moveItem(at: url, to: store.root.appendingPathComponent("cloud-recovery-rejected-\(UUID().uuidString).json"))
                throw CoreError.invalidWorkspace("Local preparation changed after recovery was scheduled. Schedule recovery again to replace it.")
            }
            request.started = true
            try JSONEncoder().encode(request).write(to: url, options: .atomic)
        }
        library.tracks[index] = try archive.restoredTrack(matching: library.tracks[index])
        archive.restoreCues(to: &performance, trackID: request.trackID)
        if let waveform = archive.waveformData, let name = archive.track.analysis.waveformReference {
            try FileManager.default.createDirectory(at: store.waveformDirectory, withIntermediateDirectories: true)
            try waveform.write(to: store.waveformDirectory.appendingPathComponent(name), options: .atomic)
        }
        let arrangementURL = CloudPreparationVault.arrangementURL(root: store.root, trackID: request.trackID)
        if let arrangement = archive.arrangement {
            try FileManager.default.createDirectory(at: arrangementURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try arrangement.write(to: arrangementURL, options: .atomic)
        } else if FileManager.default.fileExists(atPath: arrangementURL.path) {
            // The previous section data remains in the retained preparation revision.
            try FileManager.default.removeItem(at: arrangementURL)
        }
        try performance.save(to: store.root.appendingPathComponent("performance.json"))
        library.revision += 1
        try store.save(library)
        try FileManager.default.removeItem(at: url)
    }
}
