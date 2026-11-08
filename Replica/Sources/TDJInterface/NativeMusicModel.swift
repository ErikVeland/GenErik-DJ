import Foundation
import TDJCore

@MainActor final class NativeMusicSessionState {
    var wanted = false
    var closed = false
    var analysisOwner: UUID?
    var analysisCatalogVersion: UInt64?
    var finishedAnalysis: (catalogVersion: UInt64, libraryRevision: Int)?
    var backgrounded = false
    var backgroundRun: (id: UUID, report: (Int, Int) -> Void)?
    var analysisChecked = 0
    var analysisTotal = 0
    var analyses: [UUID: Task<Void, Never>] = [:]
    var loadOwners: [DeckID: UUID] = [:]
    var loads: [UUID: Task<Void, Never>] = [:]
    var rootLoads: [UUID: Task<Void, Never>] = [:]
    let projection = BackgroundFileWork(label: "org.generikdj.native-music-index")
    let files = BackgroundFileWork(label: "org.generikdj.native-music-files")
}

@MainActor private final class NativeMusicLoadAttempt { var failure: Error? }

private enum LibraryAnalysisPass: CaseIterable {
    case matching, structure

    var title: String {
        switch self {
        case .matching: "Analysing beats and key"
        case .structure: "Analysing structure and cues"
        }
    }
}

extension ReplicaModel {
    public func loadLibraryEntry(_ entry: LibraryBrowserEntry, deck: DeckID) {
        if BrowserSettings.onlyLoadToOffAirDecks, controlDisplay[deck].phase.active {
            status = "Deck \(deck.rawValue.uppercased()) is playing. Loading is limited to off-air decks."
            return
        }
        guard entry.canLoad else {
            status = entry.nativeItem?.availability.message ?? MusicLibraryError.missingAudio.localizedDescription
            return
        }
        if let track = entry.track, track.nativeLibraryOnly != true {
            load(trackID: track.id, deck: deck, nativeMetadata: entry.nativeItem.map { .init(item: $0) })
        } else if let item = entry.nativeItem {
            loadNativeMusic(item, deck: deck)
        } else if let track = entry.track {
            load(trackID: track.id, deck: deck)
        }
    }

    public func openNativeMusicLibrary() async {
        guard !nativeMusic.closed else { return }
        nativeMusic.wanted = true
        if analysisProgress == nil {
            analysisProgress = .init(done: 0, total: 0, title: "Checking library…", isLibraryAnalysis: true)
        }
        await refreshMusicLibrary()
        guard !Task.isCancelled else { return }
        if let version = nativeMusic.analysisCatalogVersion, version != musicLibraryCatalogVersion {
            cancelNativeMusicAnalysis()
        }
        startNativeMusicAnalysis()
    }

    var libraryAnalysisNeedsWork: Bool {
        let state = nativeMusic
        return !state.closed && state.wanted
            && (state.finishedAnalysis?.catalogVersion != musicLibraryCatalogVersion
                || state.finishedAnalysis?.libraryRevision != library.revision)
    }

    func setLibraryAnalysisBackgrounded(_ backgrounded: Bool) {
        nativeMusic.backgrounded = backgrounded
        if backgrounded, nativeMusic.backgroundRun == nil { cancelNativeMusicAnalysis() }
    }

    func beginBackgroundLibraryAnalysis(report: @escaping (Int, Int) -> Void) -> UUID? {
        let state = nativeMusic
        guard !state.closed, state.backgroundRun == nil, !arrangementPlaybackActive, libraryAnalysisPlaybackIsIdle
        else { return nil }
        let id = UUID()
        state.backgroundRun = (id, report)
        report(state.analysisChecked, state.analysisTotal)
        return id
    }

    func runBackgroundLibraryAnalysis(_ id: UUID) async -> Bool {
        let state = nativeMusic
        guard state.backgroundRun?.id == id, !Task.isCancelled else { return false }
        if musicLibraryCatalog == nil, musicLibraryError == nil {
            await openNativeMusicLibrary()
        } else {
            state.wanted = true
            startNativeMusicAnalysis()
        }
        while !Task.isCancelled, state.backgroundRun?.id == id, let task = state.analyses.values.first {
            await task.value
        }
        return !Task.isCancelled && !state.closed && state.backgroundRun?.id == id && !libraryAnalysisNeedsWork
    }

    func endBackgroundLibraryAnalysis(_ id: UUID) {
        guard nativeMusic.backgroundRun?.id == id else { return }
        nativeMusic.backgroundRun = nil
        if nativeMusic.backgrounded { cancelNativeMusicAnalysis() }
    }

    func cancelNativeMusicAnalysis() {
        guard let owner = nativeMusic.analysisOwner else { return }
        nativeMusic.analyses[owner]?.cancel()
        nativeMusic.analysisOwner = nil
        musicLibraryProgress = ""
        if let progress = analysisProgress {
            analysisProgress = .init(
                done: progress.done, total: progress.total,
                message: progress.total > 0 ? "Paused at \(progress.done) of \(progress.total)" : nil,
                title: progress.total > 0 ? progress.title : "Analysis paused",
                isLibraryAnalysis: true)
        }
    }

    public func startNativeMusicAnalysis() {
        let state = nativeMusic
        guard state.wanted, !state.closed, !arrangementPlaybackActive, !deckAnalysisIsRunning,
            (!state.backgrounded || (state.backgroundRun != nil && libraryAnalysisPlaybackIsIdle)),
            !importing, !musicLibraryRefreshing, state.analysisOwner == nil, state.analyses.isEmpty,
            state.loadOwners.isEmpty, preparingPlayback.isEmpty,
            musicLibraryCatalog != nil || musicLibraryError != nil
        else { return }
        let version = musicLibraryCatalogVersion
        if let finished = state.finishedAnalysis, finished.catalogVersion == version,
            finished.libraryRevision == library.revision
        {
            if analysisProgress?.total == 0, musicLibraryError == nil { analysisProgress = nil }
            return
        }

        let token = UUID()
        var priorityTracks = Set(loaded.values)
        if let trackID = ProcessInfo.processInfo.environment["GENERIK_DJ_ANALYSIS_PRIORITY_TRACK"] {
            priorityTracks.insert(trackID)
        }
        let queue = NativeMusicAnalysisQueue(
            catalog: musicLibraryCatalog ?? .init(items: [], playlists: []), tracks: library.tracks,
            loaded: priorityTracks, mediaDirectory: store.mediaDirectory, worker: state.projection)
        state.analysisOwner = token
        state.analysisCatalogVersion = version
        state.analysisChecked = 0
        state.analysisTotal = 0
        state.analyses[token] = Task(priority: .background) { [weak self] in
            guard let self else {
                await queue.finish()
                state.analyses[token] = nil
                return
            }
            defer {
                state.analyses[token] = nil
                if state.analysisOwner == token {
                    state.analysisOwner = nil
                    musicLibraryProgress = ""
                }
                if Task.isCancelled, state.analysisOwner == nil { startNativeMusicAnalysis() }
            }
            await removeStaleNativeSources()
            let count = await queue.prepare()
            guard !Task.isCancelled, state.analysisOwner == token else {
                await queue.finish()
                return
            }
            let passes = LibraryAnalysisPass.allCases
            let total = count * passes.count
            state.analysisTotal = total
            state.backgroundRun?.report(0, total)
            if count > 0 { logAnalysis("Analysis queue: \(count) songs") }
            var matched: [String: String] = [:]
            var review: [String: String] = [:]
            for (index, pass) in passes.enumerated() where count > 0 {
                if pass == .structure { await queue.rewind() }
                guard !Task.isCancelled, state.analysisOwner == token else { break }
                let passStart = state.analysisChecked
                let title = "Pass \(index + 1) of \(passes.count) · \(pass.title)"
                analysisProgress = .init(
                    done: 0, total: count, title: title, isLibraryAnalysis: true)
                while let job = await queue.next() {
                    guard !Task.isCancelled, state.analysisOwner == token else { break }
                    if state.backgrounded, !libraryAnalysisPlaybackIsIdle {
                        cancelNativeMusicAnalysis()
                        break
                    }
                    musicLibraryProgress = "\(pass.title) for \(job.title)"
                    let issue: String?
                    do {
                        switch pass {
                        case .matching:
                            let track = try await prepareLibraryMatching(job)
                            matched[job.id] = track.id
                            issue = libraryMatchingIssue(track)
                        case .structure:
                            if let trackID = matched[job.id] {
                                guard let track = library.track(id: trackID) else { throw CoreError.staleContext }
                                let arrangement = try await prepareLibraryStructure(job, track: track)
                                issue = arrangement.automaticCues?.isEmpty != false
                                    ? "No reliable section starts were found for hot cues." : nil
                            } else {
                                issue = nil
                            }
                        }
                    } catch {
                        issue = error.localizedDescription
                    }
                    guard !Task.isCancelled, state.analysisOwner == token else { break }
                    if let issue {
                        if review[job.id] == nil { review[job.id] = issue }
                        logAnalysis("Review \(job.title) (\(pass.title)): \(issue)")
                    }
                    musicLibraryNotices.setFailure(review[job.id], for: job.id)
                    state.analysisChecked += 1
                    let checked = state.analysisChecked - passStart
                    analysisProgress?.done = checked
                    state.backgroundRun?.report(state.analysisChecked, total)
                    if checked == 1 {
                        logAnalysis("\(title) \(checked) of \(count) after checking \(job.title)")
                    }
                }
            }
            await queue.finish()
            guard !Task.isCancelled, state.analysisOwner == token else { return }
            state.finishedAnalysis = (version, library.revision)
            if !review.isEmpty {
                analysisProgress = .init(
                    done: analysisProgress?.done ?? 0, total: count,
                    message: "\(count - review.count) of \(count) tracks ready. \(review.count) need review.",
                    title: "Library analysis", isLibraryAnalysis: true)
            } else if let error = musicLibraryError, musicLibraryCatalog == nil {
                analysisProgress = .init(
                    done: 0, total: 0, message: error, title: "Library analysis",
                    isLibraryAnalysis: true)
            } else {
                analysisProgress = nil
            }
        }
    }

    private var libraryAnalysisPlaybackIsIdle: Bool {
        guard !playback.isRecording, !playback.recordingFinishing, let snapshot = playback.core.snapshot() else {
            return false
        }
        return !DeckID.allCases.contains { snapshot[$0].phase.active || snapshot[$0].touchActive }
    }

    private func libraryMatchingIssue(_ track: Track) -> String? {
        let usesAutomaticGrid = track.mayRefreshAutomaticGrid && track.traktorPreparation?.normalized.grid == nil
        if track.grid == nil || (usesAutomaticGrid && track.analysis.bpm == nil) {
            return "No reliable beat grid was found."
        }
        if usesAutomaticGrid, track.automaticBarGrid == nil { return "Check the downbeat." }
        if track.key == nil || track.keyDecision.needsReview { return "Check the musical key." }
        return nil
    }

    private func prepareLibraryMatching(_ job: NativeMusicAnalysisQueue.Job) async throws -> Track {
        switch job {
        case .managed(let track):
            let current = library.track(id: track.id) ?? track
            guard current.needsCurrentLibraryAnalysis else { return current }
            let snapshot = try await service.reanalyze(trackID: track.id)
            adoptLibrary(snapshot)
            guard let updated = snapshot.track(id: track.id) else { throw CoreError.staleContext }
            return updated
        case .native(let item, let known):
            var track = known.flatMap { library.track(id: $0.id) }
            if track == nil { track = await preparedNativeTrack(item) }
            if let track, !track.needsCurrentLibraryAnalysis { return track }
            let sourceChanged = track?.nativeSourceNeedsAnalysis == true
            return try await withNativeAudio(item) { prepared in
                let snapshot = try await self.service.importAudio(
                    url: prepared.url, musicLibrary: prepared.metadata, copyMedia: false,
                    forceFullAnalysis: sourceChanged)
                self.adoptLibrary(snapshot)
                guard let updated = await self.preparedNativeTrack(item) else { throw MusicLibraryError.missingAudio }
                return updated
            }
        }
    }

    private func prepareLibraryStructure(_ job: NativeMusicAnalysisQueue.Job, track: Track) async throws
        -> ArrangementCache
    {
        switch job {
        case .managed:
            let source = store.mediaDirectory.appendingPathComponent(track.mediaFilename)
            guard let arrangement = try await prepareLibraryArrangement(track: track, source: source) else {
                throw MusicLibraryError.missingAudio
            }
            return arrangement
        case .native(let item, _):
            if let arrangement = try await prepareLibraryArrangement(track: track, source: nil) { return arrangement }
            return try await withNativeAudio(item) { prepared in
                guard let arrangement = try await self.prepareLibraryArrangement(
                    track: track, source: prepared.url)
                else { throw MusicLibraryError.missingAudio }
                return arrangement
            }
        }
    }

    public func flushNativeMusicAnalysis() async {
        while !nativeMusic.analyses.isEmpty { for task in Array(nativeMusic.analyses.values) { await task.value } }
    }

    public func flushNativeMusicLoads() async {
        while !nativeMusic.loads.isEmpty { for task in Array(nativeMusic.loads.values) { await task.value } }
    }

    func preparedNativeTrack(_ item: MusicLibraryItem) async -> Track? {
        let source = libraryReadSource()
        return await nativeMusic.projection.run {
            source.withValue { snapshot in
                snapshot.tracks.first { $0.musicLibrarySources?.contains(item.source) == true }
            }
        }
    }

    public func loadNativeMusic(_ item: MusicLibraryItem, deck: DeckID) {
        beginNativeMusicLoad(deck: deck, selection: item) { item }
    }

    private func beginNativeMusicLoad(
        deck: DeckID, selection: MusicLibraryItem? = nil, resolve: @escaping @MainActor () async -> MusicLibraryItem?
    ) {
        let state = nativeMusic
        guard !state.closed else { return }
        guard playback.core.snapshot()?[deck].phase.active != true else {
            status = TransportError.protectedDeck.localizedDescription
            return
        }
        cancelNativeMusicAnalysis()
        cancelNativeMusicLoad(deck: deck)
        cancelDeckLoadIntent(deck: deck)
        let token = UUID()
        state.loadOwners[deck] = token
        preparingNativeMusic.insert(deck)
        pendingNativeSelection[deck] = selection
        if let selection, let known = preparedTrack(for: selection) {
            pendingNativeWaveforms[deck] = known
            nativePreviewTasks[deck] = Task { [weak self] in
                guard let self else { return }
                defer { if state.loadOwners[deck] == token { nativePreviewTasks[deck] = nil } }
                guard let hydrated = try? await store.hydrateAsync(known), !Task.isCancelled,
                    state.loadOwners[deck] == token
                else { return }
                pendingNativeWaveforms[deck] = hydrated
            }
        }
        browserVisible = false
        selectedTrackID = nil
        status = "Preparing track…"
        state.loads[token] = Task { [weak self] in
            guard let self else {
                state.loads[token] = nil
                return
            }
            defer {
                state.loads[token] = nil
                state.rootLoads[token] = nil
                if state.loadOwners[deck] == token {
                    state.loadOwners[deck] = nil
                    pendingNativeSelection[deck] = nil
                    pendingNativeWaveforms[deck] = nil
                    nativePreviewTasks.removeValue(forKey: deck)?.cancel()
                    preparingNativeMusic.remove(deck)
                    if Task.isCancelled { cancelDeckLoadIntent(deck: deck) }
                    scheduleDeckAnalysis(deck: deck)
                }
                if state.loadOwners.isEmpty { startNativeMusicAnalysis() }
            }
            var selectedID: String?
            do {
                let item = await resolve()
                try Task.checkCancellation()
                guard state.loadOwners[deck] == token else { throw CancellationError() }
                guard let item else { throw MusicLibraryError.missingAudio }
                pendingNativeSelection[deck] = item
                selectedID = item.id
                status = "Preparing \(item.title)…"
                if item.isOnDevice, let source = try await musicLibraryProvider.playbackSource(item) {
                    let scoped = await state.files.run { source.url.startAccessingSecurityScopedResource() }
                    let opening = try await NativePlaybackOpening.open(
                        url: source.url, sourceIdentity: item.source.id,
                        cleanup: {
                            if scoped { source.url.stopAccessingSecurityScopedResource() }
                            if source.temporary { try? FileManager.default.removeItem(at: source.url) }
                        })
                    try Task.checkCancellation()
                    guard state.loadOwners[deck] == token else { throw CancellationError() }
                    if pendingNativeWaveforms[deck]?.analysis.waveform.isEmpty != false {
                        var preview = try Track(
                            title: item.title, artist: item.artist,
                            mediaFilename: opening.analysis.contentSHA256 + ".native", analysis: opening.analysis)
                        preview.nativeLibraryOnly = true
                        preview.musicLibrarySources = [item.source]
                        pendingNativeWaveforms[deck] = preview
                    }
                    adoptLibrary(
                        try await service.registerNativePlayback(
                            analysis: opening.analysis, metadata: source.metadata,
                            audioFingerprint: opening.audioFingerprint))
                    try Task.checkCancellation()
                    guard state.loadOwners[deck] == token, let track = await preparedNativeTrack(item) else {
                        throw CancellationError()
                    }
                    try await loadOwnedNativeTrack(
                        track, deck: deck, sourceURL: source.url, metadata: source.metadata, token: token,
                        opening: opening)
                } else if item.isOnDevice {
                    try await withNativeAudio(item) { prepared in
                        var track = await self.preparedNativeTrack(item)
                        if track == nil {
                            self.adoptLibrary(
                                try await self.service.analyzeNativeMusic(
                                    url: prepared.url, musicLibrary: prepared.metadata,
                                    preservePreparationFor: Set(self.loaded.values), quickLoad: true))
                            track = await self.preparedNativeTrack(item)
                        }
                        try Task.checkCancellation()
                        guard state.loadOwners[deck] == token, let track else { throw CancellationError() }
                        do {
                            try await self.loadOwnedNativeTrack(
                                track, deck: deck, sourceURL: prepared.url, metadata: prepared.metadata, token: token)
                        } catch TransportError.nativeSourceChanged {
                            try Task.checkCancellation()
                            guard state.loadOwners[deck] == token else { throw CancellationError() }
                            self.preparingNativeMusic.insert(deck)
                            self.status = "Preparing \(item.title)…"
                            self.adoptLibrary(
                                try await self.service.analyzeNativeMusic(
                                    url: prepared.url, musicLibrary: prepared.metadata,
                                    preservePreparationFor: Set(self.loaded.values), quickLoad: true))
                            guard let replacement = await self.preparedNativeTrack(item) else {
                                throw TransportError.stale
                            }
                            try await self.loadOwnedNativeTrack(
                                replacement, deck: deck, sourceURL: prepared.url, metadata: prepared.metadata,
                                token: token)
                        }
                    }
                } else if let track = await preparedNativeTrack(item), track.nativeLibraryOnly != true {
                    try Task.checkCancellation()
                    guard state.loadOwners[deck] == token else { throw CancellationError() }
                    try await loadOwnedNativeTrack(
                        track, deck: deck, sourceURL: nil, metadata: .init(item: item), token: token)
                } else {
                    status = item.availability.message
                    return
                }
                musicLibraryNotices.setFailure(nil, for: item.id)
                if status == "Preparing \(item.title)…" { status = "" }
                if NativeAnalysisPlan.isMix(duration: item.duration), let id = loaded[deck] {
                    await applyAnalysisHintIfNeeded(trackID: id)
                }
            } catch is CancellationError {} catch {
                guard state.loadOwners[deck] == token else { return }
                cancelDeckLoadIntent(deck: deck)
                if let selectedID { musicLibraryNotices.setFailure(error.localizedDescription, for: selectedID) }
                status = error.localizedDescription
            }
        }
    }

    private func loadOwnedNativeTrack(
        _ track: Track, deck: DeckID, sourceURL: URL?, metadata: MusicLibraryImportMetadata, token: UUID,
        asset: PCMAsset? = nil, opening: NativePlaybackOpening? = nil
    ) async throws {
        try Task.checkCancellation()
        guard nativeMusic.loadOwners[deck] == token else { throw CancellationError() }
        let attempt = NativeMusicLoadAttempt()
        let root = loadPreparedTrack(
            trackID: track.id, deck: deck, sourceURL: sourceURL, nativeMetadata: metadata, nativeLoadOwner: token,
            preparedAsset: asset, opening: opening, onFailure: { attempt.failure = $0 })
        if let failure = attempt.failure { throw failure }
        guard let root else { throw TransportError.stale }
        nativeMusic.rootLoads[token] = root
        pendingNativeSelection[deck] = nil
        pendingNativeWaveforms[deck] = nil
        nativePreviewTasks.removeValue(forKey: deck)?.cancel()
        preparingNativeMusic.remove(deck)
        await root.value
        try Task.checkCancellation()
        guard nativeMusic.loadOwners[deck] == token else { throw CancellationError() }
        if let failure = attempt.failure { throw failure }
        refreshPlayback()
    }

    func loadNativeTrack(_ track: Track, deck: DeckID) {
        let catalog = musicLibraryCatalog
        let sources = track.musicLibrarySources ?? []
        let projection = nativeMusic.projection
        let selection = sources.first.map {
            MusicLibraryItem(
                source: $0, title: track.title, artist: track.artist, album: track.album ?? "",
                duration: track.analysis.duration, assetURL: nil, availability: .unavailable)
        }
        beginNativeMusicLoad(deck: deck, selection: selection) {
            await projection.run { catalog?.items.first { sources.contains($0.source) && $0.isOnDevice } }
        }
    }

    func cancelNativeMusicLoad(deck: DeckID) {
        guard let old = nativeMusic.loadOwners.removeValue(forKey: deck) else { return }
        pendingNativeSelection[deck] = nil
        pendingNativeWaveforms[deck] = nil
        nativePreviewTasks.removeValue(forKey: deck)?.cancel()
        preparingNativeMusic.remove(deck)
        nativeMusic.loads[old]?.cancel()
        nativeMusic.rootLoads[old]?.cancel()
    }

    func cancelPendingNativeMusicLoads() {
        for task in nativeMusic.loads.values { task.cancel() }
        for task in nativeMusic.rootLoads.values { task.cancel() }
        nativeMusic.loadOwners.removeAll()
        pendingNativeSelection.removeAll()
        pendingNativeWaveforms.removeAll()
        for task in nativePreviewTasks.values { task.cancel() }
        nativePreviewTasks.removeAll()
        preparingNativeMusic.removeAll()
    }

    func closeNativeMusic() async {
        nativeMusic.closed = true
        nativeMusic.wanted = false
        cancelNativeMusicAnalysis()
        cancelPendingNativeMusicLoads()
        await flushNativeMusicLoads()
        await flushNativeMusicAnalysis()
    }

    func withNativeAudio<Value: Sendable>(
        _ item: MusicLibraryItem, perform: @MainActor (PreparedMusicLibraryAudio) async throws -> Value
    ) async throws -> Value {
        let directory = store.root.appendingPathComponent(".native-source-" + UUID().uuidString, isDirectory: true)
        let files = nativeMusic.files
        do {
            let prepared = try await musicLibraryProvider.prepare(item, in: directory)
            let scoped = await files.run { prepared.url.startAccessingSecurityScopedResource() }
            let outcome: Result<Value, Error>
            do {
                try Task.checkCancellation()
                outcome = .success(try await perform(prepared))
            } catch { outcome = .failure(error) }
            await files.run {
                if scoped { prepared.url.stopAccessingSecurityScopedResource() }
                if prepared.temporary { try? FileManager.default.removeItem(at: prepared.url) }
                try? FileManager.default.removeItem(at: directory)
            }
            return try outcome.get()
        } catch {
            await files.run { try? FileManager.default.removeItem(at: directory) }
            throw error
        }
    }
}
