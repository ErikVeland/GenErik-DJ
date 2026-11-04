import Foundation
import TDJCore

@MainActor final class NativeMusicSessionState {
    var wanted = false
    var closed = false
    var analysisOwner: UUID?
    var analyses: [UUID: Task<Void, Never>] = [:]
    var loadOwners: [DeckID: UUID] = [:]
    var loads: [UUID: Task<Void, Never>] = [:]
    var rootLoads: [UUID: Task<Void, Never>] = [:]
    let projection = BackgroundFileWork(label: "org.generikdj.native-music-index")
    let files = BackgroundFileWork(label: "org.generikdj.native-music-files")
}

@MainActor private final class NativeMusicLoadAttempt { var failure: Error? }

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
        await refreshMusicLibrary()
        cancelNativeMusicAnalysis()
        startNativeMusicAnalysis()
    }

    func cancelNativeMusicAnalysis() {
        if let owner = nativeMusic.analysisOwner { nativeMusic.analyses[owner]?.cancel() }
        nativeMusic.analysisOwner = nil
        musicLibraryProgress = ""
    }

    public func startNativeMusicAnalysis() {
        let state = nativeMusic
        guard state.wanted, !state.closed, !arrangementPlaybackActive, !deckAnalysisIsRunning,
            state.analysisOwner == nil, state.analyses.isEmpty, state.loadOwners.isEmpty, preparingPlayback.isEmpty,
            let catalog = musicLibraryCatalog
        else { return }
        let token = UUID()
        let loadedSources = Set(
            loaded.values.flatMap { id in library.tracks.first { $0.id == id }?.musicLibrarySources ?? [] })
        let analysedMixes = Set(analysisHints.entries.filter { $0.value.isMix }.keys)
        let queue = NativeMusicAnalysisQueue(
            catalog: catalog, tracks: library.tracks, loaded: loadedSources, analysedMixes: analysedMixes,
            worker: state.projection)
        state.analysisOwner = token
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
                    if analysisProgress?.message == nil { analysisProgress = nil }
                }
                if Task.isCancelled, state.analysisOwner == nil { startNativeMusicAnalysis() }
            }
            guard !Task.isCancelled, state.analysisOwner == token, !state.closed else {
                await queue.finish()
                return
            }
            await removeStaleNativeSources()
            let count = await queue.prepare()
            if count > 0 { logAnalysis("Analysis queue: \(count) songs (loaded first, mixes last)") }
            var index = 0
            while let item = await queue.next() {
                guard !Task.isCancelled, state.analysisOwner == token, !state.closed else { break }
                index += 1
                let plan = NativeAnalysisPlan.plan(duration: item.duration)
                if plan == .full {
                    let known = await preparedNativeTrack(item)
                    if known != nil && known?.analysis.musicalAnalysisDeferred != true { continue }
                }
                musicLibraryProgress = "Analysing \(index) of \(count): \(item.title)"
                analysisProgress = .init(done: index - 1, total: count, title: "Analysing")
                do {
                    if plan == .firstMinute {
                        try await analyseMixOpening(item)
                        logAnalysis("Mix opening analysed: \(item.title)")
                    } else {
                        let snapshot = try await withNativeAudio(item) { prepared in
                            try await self.service.analyzeNativeMusic(
                                url: prepared.url, musicLibrary: prepared.metadata,
                                preservePreparationFor: Set(self.loaded.values))
                        }
                        adoptLibrary(snapshot)
                    }
                } catch is CancellationError { break } catch {
                    musicLibraryFailures[item.id] = error.localizedDescription
                    logAnalysis("Skipped \(item.title): \(error.localizedDescription)")
                }
            }
            if count > 0, !Task.isCancelled { analysisProgress = .init(done: count, total: count, title: "Analysing") }
            await queue.finish()
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
                        try await service.registerNativePlayback(analysis: opening.analysis, metadata: source.metadata))
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
                musicLibraryFailures[item.id] = nil
                if status == "Preparing \(item.title)…" { status = "" }
                if NativeAnalysisPlan.isMix(duration: item.duration), let id = loaded[deck] {
                    await applyAnalysisHintIfNeeded(trackID: id)
                }
            } catch is CancellationError {} catch {
                guard state.loadOwners[deck] == token else { return }
                cancelDeckLoadIntent(deck: deck)
                if let selectedID { musicLibraryFailures[selectedID] = error.localizedDescription }
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
