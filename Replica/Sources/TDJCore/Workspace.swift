import Foundation

public struct WorkspaceStore: Sendable {
    public let root: URL
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
    }
    public var mediaDirectory: URL { root.appendingPathComponent("Media", isDirectory: true) }
    public var libraryURL: URL { root.appendingPathComponent("library.json") }

    public func load(includeWaveforms: Bool = true) throws -> LibrarySnapshot {
        guard FileManager.default.fileExists(atPath: libraryURL.path) else { return .init() }
        var snapshot: LibrarySnapshot
        do { snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: libraryURL)) } catch {
            throw CoreError.invalidWorkspace(error.localizedDescription)
        }
        for index in snapshot.tracks.indices {
            let track = snapshot.tracks[index]
            if let map = track.preparation.adaptiveMap,
                map.sampleRate != track.analysis.sampleRate
                    || (try? map.validate(frameCount: track.analysis.frameCount)) == nil
            {
                snapshot.tracks[index].preparation.adaptiveMap = nil
            }
        }
        if !includeWaveforms { return try metadataSnapshot(snapshot) }
        try Self.validate(snapshot)
        var hydrated = snapshot
        for index in hydrated.tracks.indices { hydrated.tracks[index] = try hydrate(hydrated.tracks[index]) }
        return hydrated.preparingTrackLookup()
    }
    @discardableResult public func save(_ snapshot: LibrarySnapshot) throws -> LibrarySnapshot {
        let span = AnalysisMeasurement.begin("persistence")
        defer { span?.finish() }
        var compact = try metadataSnapshot(snapshot)
        compact.schemaVersion = 2
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(compact)
        let backup = root.appendingPathComponent("library.before-waveform-storage.json")
        if snapshot.schemaVersion == 1, FileManager.default.fileExists(atPath: libraryURL.path),
            !FileManager.default.fileExists(atPath: backup.path)
        {
            try FileManager.default.copyItem(at: libraryURL, to: backup)
        }
        try data.write(to: libraryURL, options: .atomic)
        AnalysisMeasurement.current?.count("libraryBytesWritten", Int64(data.count))
        return compact
    }
    func metadataSnapshot(_ snapshot: LibrarySnapshot) throws -> LibrarySnapshot {
        try Self.validate(snapshot)
        return try WaveformStorage.metadata(snapshot, directory: waveformDirectory).preparingTrackLookup()
    }
    static func validate(_ snapshot: LibrarySnapshot) throws {
        if let calibration = snapshot.calibration { try calibration.validate() }
        guard
            snapshot.adaptiveMemory.calibrationID == nil
                || snapshot.adaptiveMemory.calibrationID == snapshot.calibration?.id
        else { throw CoreError.invalidWorkspace("Adaptive state and calibration must be retained together.") }
        guard (1...2).contains(snapshot.schemaVersion), snapshot.revision >= 0,
            Set(snapshot.tracks.map(\.id)).count == snapshot.tracks.count,
            Set(snapshot.events.map(\.id)).count == snapshot.events.count
        else {
            throw CoreError.invalidWorkspace("Unsupported schema or duplicate identities. Original file was retained.")
        }
        var librarySourceIDs: Set<String> = []
        for track in snapshot.tracks {
            try track.keyGovernance?.validate(trackID: track.id)
            for source in track.musicLibrarySources ?? [] {
                guard !source.persistentID.isEmpty, librarySourceIDs.insert(source.id).inserted else {
                    throw CoreError.invalidWorkspace("Invalid or duplicate music-library identity.")
                }
            }
            let a = track.analysis
            try a.deepBeatAnalysis?.validate(matching: a)
            try a.acceptedDeepBeatAnalysis?.validate(matching: a)
            if let reference = track.traktorPreparation {
                guard reference.normalized.collectionSHA256 == reference.collection.sourceSHA256,
                    reference.normalized.entryIndex == reference.record.entryIndex,
                    UInt64(reference.matchedSource.persistentID) == reference.record.persistentID
                else { throw CoreError.invalidWorkspace("Invalid original preparation provenance.") }
                _ = try TraktorPreparationMergePlan(
                    reference: reference.normalized, track: track, existingCues: [:],
                    history: .init(protectedEmptySlots: []))
            }
            if a.musicalAnalysisDeferred == true {
                guard a.bpm == nil, a.key == nil, a.detectedDownbeatOffset == nil, a.musicalEnergy == nil,
                    a.cachedEnergyLevel == nil
                else {
                    throw CoreError.invalidWorkspace(
                        "Imported preparation cannot be labelled as detected musical analysis.")
                }
            }
            if let energy = a.musicalEnergy {
                guard (0...10).contains(energy.level), energy.onsetsPerSecond.isFinite, energy.onsetsPerSecond >= 0,
                    energy.rhythmicity.isFinite, (0...1).contains(energy.rhythmicity), energy.spectralActivity.isFinite,
                    (0...1).contains(energy.spectralActivity), energy.brightness.isFinite,
                    (0...1).contains(energy.brightness), energy.crestFactorDB.isFinite, energy.crestFactorDB >= 0,
                    a.cachedEnergyLevel == nil || a.cachedEnergyLevel == energy.level
                else { throw CoreError.invalidWorkspace("Invalid musical energy analysis.") }
            }
            if let artwork = track.artworkFilename {
                guard artwork == (artwork as NSString).lastPathComponent, !artwork.isEmpty, artwork != ".",
                    artwork != ".."
                else { throw CoreError.invalidWorkspace("Invalid artwork path.") }
            }
            guard a.waveformDecodedFrames.map({ $0 > 0 && $0 <= a.frameCount }) ?? true else {
                throw CoreError.invalidWorkspace("Invalid decoded waveform coverage.")
            }
            guard a.contentSHA256.count == 64, a.contentSHA256.allSatisfy({ $0.isHexDigit }),
                track.nativePlaybackIdentity.map({ $0.count == 64 && $0.allSatisfy({ $0.isHexDigit }) }) ?? true,
                track.id == a.contentSHA256 || track.nativePlaybackIdentity != nil, track.id.count == 64,
                track.id.allSatisfy({ $0.isHexDigit }), a.sampleRate.isFinite, a.sampleRate > 0, a.frameCount > 0,
                a.waveformFramesPerBin > 0, track.mediaFilename == (track.mediaFilename as NSString).lastPathComponent,
                track.mediaFilename != ".", track.mediaFilename != "..", !track.mediaFilename.isEmpty,
                !track.mediaFilename.contains("/"), a.bpm.map({ $0.isFinite && $0 > 0 }) ?? true,
                a.beatAnchorFrame.map(\.isFinite) ?? true, a.timbre.allSatisfy(\.isFinite),
                a.chroma.allSatisfy(\.isFinite), WaveformStorage.validReference(a),
                a.cachedEnergyLevel.map({ (0...10).contains($0) }) ?? true,
                a.detectedDownbeatOffset.map({ (0..<4).contains($0) && a.bpm != nil && a.beatAnchorFrame != nil })
                    ?? true,
                a.downbeatConfidence.map({ $0.isFinite && (0...1).contains($0) && a.detectedDownbeatOffset != nil })
                    ?? true, a.tuningCents.map({ $0.isFinite && (-50...50).contains($0) }) ?? true,
                a.keyStability.map({ $0.isFinite && (0...1).contains($0) }) ?? true,
                a.gridResidualMilliseconds.map({ $0.isFinite && $0 >= 0 }) ?? true,
                a.waveform.allSatisfy({ $0.minimum.isFinite && $0.maximum.isFinite && $0.rms.isFinite })
            else { throw CoreError.invalidWorkspace("Invalid track or media path. Original file was retained.") }
            if let grid = track.grid {
                _ = try BeatGrid(
                    bpm: grid.bpm, anchorFrame: grid.anchorFrame, sampleRate: grid.sampleRate,
                    downbeatOffset: grid.downbeatOffset)
                guard grid.sampleRate == a.sampleRate else { throw CoreError.invalidGrid }
            }
        }
    }
}

private final class LibraryExecutor: SerialExecutor {
    static let shared = LibraryExecutor()
    private let queue = DispatchQueue(label: "org.generikdj.library-storage", qos: .background)
    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        let executor = asUnownedSerialExecutor()
        queue.async(qos: .background, flags: .enforceQoS) { job.runSynchronously(on: executor) }
    }
}

public actor LibraryService {
    public nonisolated var unownedExecutor: UnownedSerialExecutor { LibraryExecutor.shared.asUnownedSerialExecutor() }
    private static let importWorker = AnalysisWorker()
    private static let nativeQuickWorker = AnalysisWorker(label: "org.generikdj.native-quick-preparation")
    private let store: WorkspaceStore
    private var library: LibrarySnapshot
    private var traktorCatalog: TraktorPreparationCatalog?
    private var traktorDiscoveryAttempted = false
    private let discoverSyncedTraktor: Bool
    private let automaticTraktorSources: [URL]
    public private(set) var traktorReferenceWarning: String?

    public func importTraktorCollection(url: URL) async throws -> TraktorCollectionReferenceSummary {
        let catalog = try await TraktorPreparationStorage.importCollection(at: url, store: store)
        traktorCatalog = catalog
        traktorDiscoveryAttempted = true
        traktorReferenceWarning = nil
        return catalog.summary
    }

    public func refreshTraktorReferences(force: Bool = false) async throws -> TraktorCollectionReferenceSummary? {
        if traktorDiscoveryAttempted && !force { return traktorCatalog?.summary }
        do {
            let catalog = try await TraktorPreparationStorage.discover(
                store: store, includeSyncedFolder: discoverSyncedTraktor, automaticSources: automaticTraktorSources)
            traktorCatalog = catalog
            traktorDiscoveryAttempted = true
            traktorReferenceWarning = nil
            return catalog?.summary
        } catch {
            traktorReferenceWarning = error.localizedDescription
            throw error
        }
    }
    /// Digest of the active collection, for detecting a changed linked file without importing it.
    public func activeCollectionDigest() -> String? { traktorCatalog?.summary.sourceSHA256 }
    /// Collection tempo and key for every Music library item the active collection identifies.
    /// The browser shows these straight away; preparation itself still binds at load.
    public func collectionHints(for catalog: MusicLibraryCatalog) -> [String: BrowserPreparationHint] {
        guard let collection = traktorCatalog else { return [:] }
        var hints: [String: BrowserPreparationHint] = [:]
        for item in catalog.items {
            guard let record = collection.match(item.source), record.bpm != nil || record.key != nil else { continue }
            hints[item.id] = .init(
                bpm: record.bpm, key: record.key,
                isMix: NativeAnalysisPlan.isMix(duration: record.durationSeconds ?? item.duration))
        }
        return hints
    }
    /// Stage validated references. Existing musical preparation changes only at an intentional load.
    /// Progress reports (matched tracks done, matched total). Batches are saved as they finish, so an
    /// interrupted pass resumes from saved state; tracks already holding the same reference are skipped.
    public func reuseTraktorPreparationForExistingTracks(
        preservePreparationFor protectedTracks: Set<String> = [], batchSize: Int = 250,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) throws -> LibrarySnapshot {
        guard let catalog = traktorCatalog else { return library }
        var changed = library
        var pending: [(Int, MusicLibrarySource, TraktorPreparationRecord)] = []
        for index in changed.tracks.indices {
            let matches = (changed.tracks[index].musicLibrarySources ?? []).compactMap { source in
                catalog.match(source).map { (source, $0) }
            }
            guard let (source, record) = matches.first, Set(matches.map { $0.1.entryIndex }).count == 1 else {
                continue
            }
            pending.append((index, source, record))
        }
        progress?(0, pending.count)
        var unsaved = 0
        for (done, (index, source, record)) in pending.enumerated() {
            var track = changed.tracks[index]
            do {
                let original = try catalog.bind(record, source: source, analysis: track.analysis)
                if track.traktorPreparation != original {
                    track.traktorPreparation = original
                    changed.tracks[index] = track
                    unsaved += 1
                }
            } catch { traktorReferenceWarning = error.localizedDescription }
            if unsaved >= max(1, batchSize) {
                changed.revision += 1
                library = try store.save(changed)
                changed = library
                unsaved = 0
            }
            progress?(done + 1, pending.count)
        }
        guard unsaved > 0 || changed.tracks != library.tracks else { return library }
        changed.revision += 1
        library = try store.save(changed)
        return library
    }

    public init(
        store: WorkspaceStore, initial: LibrarySnapshot? = nil, discoverSyncedTraktor: Bool = false,
        automaticTraktorSources: [URL] = []
    ) throws {
        self.discoverSyncedTraktor = discoverSyncedTraktor
        self.automaticTraktorSources = automaticTraktorSources
        self.store = store
        if let initial {
            library = try store.metadataSnapshot(initial)
        } else {
            library = try store.load(includeWaveforms: false)
        }
    }
    public func snapshot() -> LibrarySnapshot { library }

    public func registerNativePlayback(
        analysis: AudioAnalysis, metadata: MusicLibraryImportMetadata, audioFingerprint: String? = nil
    ) throws
        -> LibrarySnapshot
    {
        if let index = library.tracks.firstIndex(where: { $0.musicLibrarySources?.contains(metadata.source) == true }) {
            var current = library.tracks[index]
            // Older imports can retain a managed flag after their audio copy is removed.
            let missingCopy =
                current.nativeLibraryOnly != true
                && !FileManager.default.isReadableFile(
                    atPath: store.mediaDirectory.appendingPathComponent(current.mediaFilename).path)
            if missingCopy { current.nativeLibraryOnly = true }
            guard current.analysis.sampleRate == analysis.sampleRate else {
                throw CoreError.invalidAudio("The Music sample rate changed. Saved preparation is retained.")
            }
            let fingerprint = audioFingerprint ?? current.nativeAudioFingerprint
            let audioChanged = current.nativeAudioFingerprint != nil && current.nativeAudioFingerprint != fingerprint
            let revisionChanged = current.nativePlaybackIdentity != analysis.contentSHA256
            if !missingCopy, !revisionChanged, current.nativeAudioFingerprint == fingerprint { return library }
            let refresh = current.nativePlaybackIdentity != nil && (revisionChanged || audioChanged)
            current.nativePlaybackIdentity = analysis.contentSHA256
            current.nativeAudioFingerprint = fingerprint
            let durationChanged =
                abs(Double(current.analysis.frameCount) - Double(analysis.frameCount))
                > analysis.sampleRate / 4
            if audioChanged || durationChanged {
                current.nativeSourceNeedsAnalysis = true
            }
            if refresh {
                current.analysis = current.analysis.replacingWaveform(
                    analysis.waveform, configurationID: "native-refresh-1-" + analysis.contentSHA256,
                    frameCount: current.analysis.frameCount,
                    decodedFrames: min(
                        current.analysis.frameCount, analysis.waveformDecodedFrames ?? analysis.frameCount))
            }
            var changed = library
            changed.tracks[index] = current
            changed.revision += 1
            library = try store.save(changed)
            return library
        }
        var track = try Track(
            title: metadata.title, artist: metadata.artist, genre: metadata.genre,
            mediaFilename: analysis.contentSHA256 + ".native", analysis: analysis)
        track.album = metadata.album
        track.nativeLibraryOnly = true
        track.nativePlaybackIdentity = track.id
        track.nativeAudioFingerprint = audioFingerprint
        track.musicLibrarySources = [metadata.source]
        var changed = library
        for index in changed.tracks.indices {
            changed.tracks[index].musicLibrarySources?.removeAll { $0 == metadata.source }
        }
        if let index = changed.tracks.firstIndex(where: { $0.id == track.id }) {
            track.preparation = changed.tracks[index].preparation
            changed.tracks[index] = track
        } else {
            changed.tracks.append(track)
        }
        changed.revision += 1
        library = try store.save(changed)
        return library
    }

    public func updateNativeWaveform(trackID: String, analysis: AudioAnalysis) throws -> LibrarySnapshot {
        guard let index = library.tracks.firstIndex(where: { $0.id == trackID }),
            library.tracks[index].nativePlaybackIdentity != nil,
            library.tracks[index].analysis.waveformDecodedFrames != nil,
            library.tracks[index].analysis.sampleRate == analysis.sampleRate,
            library.tracks[index].analysis.frameCount == analysis.frameCount
        else { return library }
        var changed = library
        changed.tracks[index].analysis = analysis
        changed.revision += 1
        library = try store.save(changed)
        return library
    }

    public func analyzeNativeMusic(
        url: URL, musicLibrary: MusicLibraryImportMetadata, preservePreparationFor protectedTracks: Set<String> = [],
        quickLoad: Bool = false
    ) async throws -> LibrarySnapshot {
        try await importAudio(
            url: url, musicLibrary: musicLibrary, preservePreparationFor: protectedTracks, copyMedia: false,
            forceFullAnalysis: !quickLoad, quickLoad: quickLoad)
    }
    public func importAudio(
        url: URL, musicLibrary: MusicLibraryImportMetadata? = nil,
        preservePreparationFor protectedTracks: Set<String> = [], copyMedia: Bool = true,
        forceFullAnalysis: Bool = false, quickLoad: Bool = false
    ) async throws -> LibrarySnapshot {
        try await importAudioReportingReuse(
            url: url, musicLibrary: musicLibrary, preservePreparationFor: protectedTracks,
            copyMedia: copyMedia, forceFullAnalysis: forceFullAnalysis, quickLoad: quickLoad
        ).snapshot
    }

    public func prepareNativeLibraryMatching(
        url: URL, musicLibrary: MusicLibraryImportMetadata, sourceChanged: Bool
    ) async throws -> (snapshot: LibrarySnapshot, reusedTraktor: Bool) {
        try await importAudioReportingReuse(
            url: url, musicLibrary: musicLibrary, preservePreparationFor: [], copyMedia: false,
            forceFullAnalysis: sourceChanged, quickLoad: false)
    }

    private func importAudioReportingReuse(
        url: URL, musicLibrary: MusicLibraryImportMetadata?, preservePreparationFor protectedTracks: Set<String>,
        copyMedia: Bool, forceFullAnalysis: Bool, quickLoad: Bool
    ) async throws -> (snapshot: LibrarySnapshot, reusedTraktor: Bool) {
        try Task.checkCancellation()
        let lookup = AnalysisMeasurement.begin("traktorReferenceLookup")
        if !quickLoad {
            do { _ = try await refreshTraktorReferences() } catch {
                traktorDiscoveryAttempted = true
                traktorReferenceWarning = error.localizedDescription
            }
        }
        let catalog = traktorCatalog
        let record = musicLibrary.flatMap { catalog?.match($0.source) }
        lookup?.finish()
        if record != nil { AnalysisMeasurement.current?.cacheHit("traktorReference") }
        let waveformWorker = quickLoad ? Self.nativeQuickWorker : AnalysisWorker.shared
        var analysis =
            quickLoad || (!forceFullAnalysis && record?.canReuseMusicalPreparation == true)
            ? try await waveformWorker.waveformOnly(url: url) : try await AnalysisWorker.shared.analyze(url: url)
        var original: ImportedTraktorPreparation?
        if let catalog, let record, let musicLibrary {
            do {
                original = try AnalysisMeasurement.measure("traktorDurationValidation") {
                    try catalog.bind(record, source: musicLibrary.source, analysis: analysis)
                }
            } catch {
                traktorReferenceWarning = error.localizedDescription
                if analysis.musicalAnalysisDeferred == true && !quickLoad {
                    analysis = try await AnalysisWorker.shared.analyze(url: url)
                }
            }
        }
        try Task.checkCancellation()
        let reusedTraktor =
            analysis.musicalAnalysisDeferred == true && original?.normalized.grid != nil
            && original?.normalized.key != nil
        if let index = musicLibrary.flatMap({ metadata in
            library.tracks.firstIndex(where: {
                $0.nativePlaybackIdentity != nil && $0.musicLibrarySources?.contains(metadata.source) == true
            })
        })
            ?? library.tracks.firstIndex(where: {
                $0.id == analysis.contentSHA256
                    || ($0.nativePlaybackIdentity != nil && $0.analysis.contentSHA256 == analysis.contentSHA256)
            })
        {
            if copyMedia, library.tracks[index].nativeLibraryOnly == true {
                let filename = library.tracks[index].mediaFilename
                let existingID = library.tracks[index].id
                try await Self.copyVerifiedAudio(
                    url: url, destination: store.mediaDirectory.appendingPathComponent(filename),
                    sourceIdentity: analysis.contentSHA256)
                try Task.checkCancellation()
                guard let current = library.tracks.firstIndex(where: { $0.id == existingID }) else {
                    throw CoreError.staleContext
                }
                let snapshot = try commitExisting(
                    analysis: analysis, original: original, metadata: musicLibrary, index: current,
                    preservePreparation: protectedTracks.contains(analysis.contentSHA256),
                    managedMediaFilename: filename)
                return (snapshot, reusedTraktor)
            }
            let snapshot = try commitExisting(
                analysis: analysis, original: original, metadata: musicLibrary, index: index,
                preservePreparation: protectedTracks.contains(analysis.contentSHA256))
            return (snapshot, reusedTraktor)
        }
        let metadata = (try? await EmbeddedMetadata.read(url: url)) ?? EmbeddedMetadata()
        try Task.checkCancellation()
        let ext = url.pathExtension.lowercased().filter { $0.isLetter || $0.isNumber }
        let filename = analysis.contentSHA256 + (ext.isEmpty ? "" : "." + ext)
        let destination = store.mediaDirectory.appendingPathComponent(filename)
        let sourceIdentity = analysis.contentSHA256
        if copyMedia {
            try await Self.copyVerifiedAudio(url: url, destination: destination, sourceIdentity: sourceIdentity)
        }
        try Task.checkCancellation()
        if let index = library.tracks.firstIndex(where: {
            $0.id == analysis.contentSHA256
                || ($0.nativePlaybackIdentity != nil && $0.analysis.contentSHA256 == analysis.contentSHA256)
        }) {
            let snapshot = try commitExisting(
                analysis: analysis, original: original, metadata: musicLibrary, index: index,
                preservePreparation: protectedTracks.contains(analysis.contentSHA256),
                managedMediaFilename: copyMedia ? filename : nil)
            return (snapshot, reusedTraktor)
        }
        var changed = library
        var track = try Track(
            title: musicLibrary.flatMap { $0.title.isEmpty ? nil : $0.title } ?? metadata.title
                ?? url.deletingPathExtension().lastPathComponent,
            artist: musicLibrary.flatMap { $0.artist.isEmpty ? nil : $0.artist } ?? metadata.artist ?? "",
            genre: musicLibrary?.genre ?? metadata.genre, mediaFilename: filename, analysis: analysis)
        track.nativeLibraryOnly = copyMedia ? nil : true
        track.album = musicLibrary.flatMap { $0.album.isEmpty ? nil : $0.album } ?? metadata.album
        if let artwork = musicLibrary?.artwork ?? metadata.artwork {
            let name = analysis.contentSHA256 + ".artwork"
            try artwork.write(to: store.mediaDirectory.appendingPathComponent(name), options: .atomic)
            track.artworkFilename = name
        }
        if let original { apply(original, to: &track, preservePreparation: false) }
        if let musicLibrary {
            track.musicLibrarySources = [musicLibrary.source]
            for index in changed.tracks.indices {
                changed.tracks[index].musicLibrarySources?.removeAll { $0 == musicLibrary.source }
            }
        }
        changed.tracks.append(track)
        changed.revision += 1
        library = try store.save(changed)
        return (library, reusedTraktor)
    }

    private func apply(_ original: ImportedTraktorPreparation, to track: inout Track, preservePreparation: Bool) {
        track.traktorPreparation = original
        guard !preservePreparation else { return }
        if let grid = track.automaticBarGrid {
            track.preparation.grid = grid
            track.preparation.gridIsManual = false
        } else if !track.preparation.gridIsManual && track.preparation.gridWasEditedByUser != true
            && !track.preparation.gridLocked, let grid = original.normalized.grid
        {
            track.preparation.grid = grid
            track.preparation.gridIsManual = true
        }
        track.preparation.importKey(original.normalized.key, authority: .traktor)
    }

    private static func copyVerifiedAudio(url: URL, destination: URL, sourceIdentity: String) async throws {
        try await importWorker.run { check in
            try check()
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: url, to: destination)
            }
            guard try AudioAnalyzer.sha256(url: destination, checkCancellation: check) == sourceIdentity else {
                throw CoreError.invalidAudio(
                    "The imported copy does not match the analysed audio. No library entry was added.")
            }
        }
    }
    private func commitExisting(
        analysis: AudioAnalysis, original: ImportedTraktorPreparation?, metadata: MusicLibraryImportMetadata?,
        index: Int, preservePreparation: Bool, managedMediaFilename: String? = nil
    ) throws -> LibrarySnapshot {
        var changed = library
        var track = changed.tracks[index]
        if let managedMediaFilename {
            guard track.mediaFilename == managedMediaFilename else { throw CoreError.staleContext }
            track.nativeLibraryOnly = nil
        }
        let wouldDiscardAnalysis =
            analysis.musicalAnalysisDeferred == true && track.analysis.musicalAnalysisDeferred != true
        if !preservePreparation, !wouldDiscardAnalysis,
            track.analysis.configurationID != analysis.configurationID || track.nativeSourceNeedsAnalysis == true
        {
            guard track.analysis.sampleRate == analysis.sampleRate,
                track.analysis.frameCount == analysis.frameCount || track.nativePlaybackIdentity != nil
            else { throw CoreError.invalidAudio("Updated analysis does not match the prepared source.") }
            try applyAnalysis(analysis, to: &track)
            if analysis.musicalAnalysisDeferred != true { track.nativeSourceNeedsAnalysis = nil }
        }
        if let original { track.traktorPreparation = original }
        if let metadata {
            for other in changed.tracks.indices where other != index {
                changed.tracks[other].musicLibrarySources?.removeAll { $0 == metadata.source }
            }
            var sources = track.musicLibrarySources ?? []
            if !sources.contains(metadata.source) { sources.append(metadata.source) }
            track.musicLibrarySources = sources
            if !metadata.album.isEmpty { track.album = metadata.album }
        }
        if track == library.tracks[index] && changed.tracks == library.tracks { return library }
        changed.tracks[index] = track
        changed.revision += 1
        library = try store.save(changed)
        return library
    }

    public func reanalyze(trackID: String) async throws -> LibrarySnapshot {
        guard let source = library.tracks.first(where: { $0.id == trackID }) else { throw CoreError.staleContext }
        let analysis = try await AnalysisWorker.shared.analyze(
            url: store.mediaDirectory.appendingPathComponent(source.mediaFilename))
        try Task.checkCancellation()
        guard analysis.contentSHA256 == source.analysis.contentSHA256,
            let index = library.tracks.firstIndex(where: { $0.id == trackID })
        else { throw CoreError.staleContext }
        try replaceAnalysis(analysis, at: index)
        return library
    }

    private func replaceAnalysis(_ analysis: AudioAnalysis, at index: Int) throws {
        let previous = library.tracks[index].analysis
        guard previous.contentSHA256 == analysis.contentSHA256, previous.sampleRate == analysis.sampleRate,
            previous.frameCount == analysis.frameCount
        else {
            throw CoreError.invalidAudio(
                "Updated analysis does not match the prepared source. Existing preparation was retained.")
        }
        var changed = library
        try applyAnalysis(analysis, to: &changed.tracks[index])
        changed.revision += 1
        library = try store.save(changed)
    }

    private func applyAnalysis(_ incoming: AudioAnalysis, to track: inout Track) throws {
        let previous = track.analysis
        let analysis = incoming.retainingDeepEvidence(from: previous)
        track.analysis = analysis
        track.recordKeyAnalysisChange(from: previous)
        if let grid = track.automaticBarGrid {
            track.preparation.grid = grid
            track.preparation.gridIsManual = false
        } else if !track.preparation.gridIsManual && track.preparation.gridWasEditedByUser != true
            && !track.preparation.gridLocked && track.preparation.adaptiveMap == nil
        {
            if let bpm = analysis.bpm {
                track.preparation.grid = try BeatGrid(
                    bpm: bpm, anchorFrame: analysis.beatAnchorFrame ?? 0, sampleRate: analysis.sampleRate,
                    downbeatOffset: analysis.detectedDownbeatOffset ?? 0)
            } else if previous.contentSHA256 != analysis.contentSHA256 || previous.frameCount != analysis.frameCount {
                track.preparation.grid = nil
            }
        }
    }

    public func adoptDeepAnalysis(
        _ result: DeepBeatAnalysis, trackID: String, protectedTracks: Set<String> = []
    ) throws -> LibrarySnapshot {
        try Task.checkCancellation()
        guard !protectedTracks.contains(trackID), let index = library.tracks.firstIndex(where: { $0.id == trackID })
        else { return library }
        let track = try library.tracks[index].adoptingDeepAnalysis(result)
        guard track != library.tracks[index] else { return library }
        var changed = library
        changed.tracks[index] = track
        changed.revision += 1
        try Task.checkCancellation()
        library = try store.save(changed)
        return library
    }

    public func updatePreparation(trackID: String, preparation: Preparation) throws -> LibrarySnapshot {
        guard let index = library.tracks.firstIndex(where: { $0.id == trackID }) else { throw CoreError.staleContext }
        var changed = library
        changed.tracks[index].preparation = preparation
        if library.tracks[index].preparation.correctedKey != preparation.correctedKey
            || library.tracks[index].preparation.correctedKeyAuthority != preparation.correctedKeyAuthority
        {
            var state = changed.tracks[index].keyGovernance ?? .init()
            state.events.append(
                .init(action: "preparationEdit", observationID: nil, decision: changed.tracks[index].keyDecision))
            changed.tracks[index].keyGovernance = state
        }
        changed.revision += 1
        library = try store.save(changed)
        return library
    }

    public func previewKeyImport(data: Data) throws -> KeyImportPlan {
        guard data.count <= 2 * 1024 * 1024 else {
            throw CoreError.invalidAudio("The key import exceeds the 2 MB limit.")
        }
        let manifest = try JSONDecoder().decode(KeyImportManifest.self, from: data)
        return try KeyImportPlan(manifest: manifest, library: library)
    }

    public func applyKeyImport(_ plan: KeyImportPlan, preservePreparationFor protectedTracks: Set<String> = []) throws
        -> LibrarySnapshot
    {
        guard !plan.changes.contains(where: { $0.addsEvidence && protectedTracks.contains($0.trackID) }) else {
            throw CoreError.invalidAudio("Stop the protected tracks before you apply key imports.")
        }
        let changed = try plan.applying(to: library)
        guard changed != library else { return library }
        library = try store.save(changed)
        return library
    }

    public func reviewKey(
        trackID: String, key: MusicalKey, reason: String, expectedRevision: Int,
        preservePreparationFor protectedTracks: Set<String> = []
    ) throws -> LibrarySnapshot {
        guard expectedRevision == library.revision, !protectedTracks.contains(trackID),
            let index = library.tracks.firstIndex(where: { $0.id == trackID })
        else { throw CoreError.staleContext }
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, reason.utf8.count <= 4096 else {
            throw CoreError.invalidAudio("Record a review reason between 1 and 4096 bytes.")
        }
        var changed = library
        changed.tracks[index].preparation.correctedKey = key
        var state = changed.tracks[index].keyGovernance ?? .init()
        state.events.append(
            .init(action: "review", observationID: nil, decision: changed.tracks[index].keyDecision, reason: reason))
        changed.tracks[index].keyGovernance = state
        changed.revision += 1
        library = try store.save(changed)
        return library
    }

    public func record(_ event: PerformanceEvent) throws -> LibrarySnapshot {
        guard !library.events.contains(where: { $0.id == event.id }) else { return library }
        var changed = library
        changed.events.append(event)
        changed.revision += 1
        if let calibration = changed.calibration { try changed.adaptiveMemory.consume(event, calibration: calibration) }
        library = try store.save(changed)
        return library
    }
}

extension LibraryService {
    /// Use a fresh catalog. A failed catalog read cannot prove that Music audio was removed.
    public func reconcileAvailableAudio(catalog: MusicLibraryCatalog, protectedTracks: Set<String> = []) throws
        -> LibrarySnapshot
    {
        let available = Set(catalog.items.lazy.filter(\.isOnDevice).map(\.source))
        var changed = library
        var removed = [Track]()
        changed.tracks = library.tracks.compactMap { track in
            let hasCopy = track.nativeLibraryOnly != true
                && FileManager.default.isReadableFile(atPath: store.mediaDirectory.appendingPathComponent(track.mediaFilename).path)
            if hasCopy { return track }
            if (track.musicLibrarySources ?? []).contains(where: available.contains) || protectedTracks.contains(track.id) {
                var native = track
                native.nativeLibraryOnly = true
                return native
            }
            removed.append(track)
            return nil
        }
        guard changed.tracks != library.tracks else { return library }
        if !removed.isEmpty {
            let archive = store.root.appendingPathComponent("UnavailableTracks", isDirectory: true)
            try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
            try JSONEncoder().encode(removed).write(to: archive.appendingPathComponent(UUID().uuidString + ".json"), options: .atomic)
        }
        changed.revision += 1
        library = try store.save(changed)
        return library
    }
}
