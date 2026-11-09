import Foundation

extension CloudPreparationArchive {
    /// The automatic receiver never imports the sender's performance preparation.
    public static func analysisOnly(track: Track, arrangement: Data?) -> Self {
        var source = track
        source.analysis = source.analysis.replacingWaveform([])
        source.analysis.waveformReference = nil
        source.analysis.waveformDecodedFrames = nil
        source.preparation = .init()
        source.keyGovernance = nil
        source.traktorPreparation = nil
        source.musicLibrarySources = nil
        var archive = Self(track: source, performance: .init(), arrangement: arrangement)
        archive.version = 2
        archive.automaticAnalysis = true
        return archive
    }

    public func automaticallyMergedTrack(matching local: Track) throws -> Track {
        guard automaticAnalysis == true, matches(local) else { return local }
        guard let deep = track.analysis.deepBeatAnalysis else { return local }
        return try local.adoptingDeepAnalysis(deep)
    }
}

/// Export markers belong to one iCloud account. Retained payloads are the durable upload queue.
public struct AutomaticAnalysisExports: Sendable {
    let root: URL
    public init(root: URL) { self.root = root }

    public func retain(track: Track, store: WorkspaceStore, vault: CloudPreparationVault) throws
        -> CloudPreparationVault.Revision?
    {
        guard CloudPreparationArchive.hasAudioIdentity(track) else { return nil }
        let arrangementURL = CloudPreparationVault.arrangementURL(root: store.root, trackID: track.id)
        let arrangement = try? Data(contentsOf: arrangementURL)
        guard track.analysis.deepBeatAnalysis != nil || arrangement != nil else { return nil }
        let archive = CloudPreparationArchive.analysisOnly(track: track, arrangement: arrangement)
        let encoded = try archive.encoded()
        let digest = CloudPreparationVault.digest(encoded)
        let marker = root.appendingPathComponent("automatic-exports").appendingPathComponent(track.id)
        if (try? String(contentsOf: marker, encoding: .utf8)) == digest,
            FileManager.default.fileExists(atPath: vault.payloadURL(digest).path)
        {
            return nil
        }
        let revision = try vault.retain(data: encoded)
        try FileManager.default.createDirectory(
            at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(digest.utf8).write(to: marker, options: .atomic)
        return revision
    }
}
