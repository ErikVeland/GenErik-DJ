import Foundation
import TDJCore

@MainActor final class NativeMusicSessionState {
    var wanted = false
    var deferredDeepTracks = Set<String>()
    var activeTrackID: String?
    var closed = false
    var analysisCatalogVersion: UInt64?
    var finishedAnalysis: (catalogVersion: UInt64, libraryRevision: Int)?
    var backgrounded = false
    var conditions = LibraryAnalysisConditions.initial
    var activePass: NativeMusicAnalysisQueue.Pass?
    var waitingForStructure: (catalogVersion: UInt64, libraryRevision: Int)?
    var backgroundRun: (id: UUID, report: (Int, Int) -> Void)?
    var analysisChecked = 0
    var analysisTotal = 0
    var analyses: [UUID: Task<Void, Never>] = [:]
    var loadOwners: [DeckID: UUID] = [:]
    var loads: [UUID: Task<Void, Never>] = [:]
    var rootLoads: [UUID: Task<Void, Never>] = [:]
    var measurements: [AnalysisMeasurement.Record] = []
    var droppedMeasurements = 0
    var measurementLogUnavailable = false
    let projection = BackgroundFileWork(label: "org.generikdj.native-music-index")
    let files = BackgroundFileWork(label: "org.generikdj.native-music-files")
}

@MainActor private final class NativeMusicLoadAttempt { var failure: Error? }

private enum LibraryMatchingSource: String {
    case traktorBoth = "traktor"
    case traktorGrid, traktorKey, saved, fresh, failed

    init(reusing track: Track) {
        let originalGrid = track.traktorPreparation?.normalized.grid
        let usesTraktorGrid = originalGrid != nil && originalGrid == track.grid
        let usesTraktorKey = track.keyDecision.authority == .traktor
        self =
            switch (usesTraktorGrid, usesTraktorKey) {
            case (true, true): .traktorBoth
            case (true, false): .traktorGrid
            case (false, true): .traktorKey
            case (false, false): .saved
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
        if let item = entry.nativeItem, item.isOnDevice {
            loadNativeMusic(item, deck: deck)
        } else if let track = entry.track, track.nativeLibraryOnly != true {
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
        if !backgrounded && AnalysisExecution.supportsAcceleration { nativeMusic.finishedAnalysis = nil }
        // Restart with CPU-only analysis when the app enters the background.
        if backgrounded { cancelNativeMusicAnalysis() }
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
        guard let owner = libraryAnalysisOwner else { return }
        nativeMusic.analyses[owner]?.cancel()
        libraryAnalysisOwner = nil
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
        guard state.wanted, !state.closed, !arrangementPlaybackActive, libraryAnalysisPlaybackIsIdle,
            !deckAnalysisIsRunning, !cloudBusy || cloudSyncIsAutomatic,
            !state.backgrounded || (state.backgroundRun != nil && libraryAnalysisPlaybackIsIdle),
            !importing, !musicLibraryRefreshing, libraryAnalysisOwner == nil, state.analyses.isEmpty,
            state.loadOwners.isEmpty, preparingPlayback.isEmpty,
            musicLibraryCatalog != nil || musicLibraryError != nil
        else { return }
        let version = musicLibraryCatalogVersion
        if let finished = state.finishedAnalysis, finished.catalogVersion == version,
            finished.libraryRevision == library.revision,
            state.deferredDeepTracks.subtracting(Set(loaded.values)).isEmpty
        {
            if analysisProgress?.total == 0, musicLibraryError == nil { analysisProgress = nil }
            return
        }

        if let waiting = state.waitingForStructure, waiting.catalogVersion == version,
            waiting.libraryRevision == library.revision, let message = state.conditions.pauseMessage
        {
            analysisProgress?.message = message
            return
        }
        state.waitingForStructure = nil
        let token = UUID()
        var priorityTracks = Set(loaded.values)
        if let trackID = ProcessInfo.processInfo.environment["GENERIK_DJ_ANALYSIS_PRIORITY_TRACK"] {
            priorityTracks.insert(trackID)
        }
        let queue = NativeMusicAnalysisQueue(
            catalog: musicLibraryCatalog ?? .init(items: [], playlists: []), tracks: library.tracks,
            loaded: priorityTracks, mediaDirectory: store.mediaDirectory, worker: state.projection,
            includeDeep: AnalysisExecution.supportsAcceleration && !state.backgrounded)
        libraryAnalysisOwner = token
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
                state.activePass = nil
                state.activeTrackID = nil
                if libraryAnalysisOwner == token {
                    libraryAnalysisOwner = nil
                    musicLibraryProgress = ""
                }
                let conditionsRecovered = state.waitingForStructure != nil && state.conditions.pauseMessage == nil
                if Task.isCancelled || conditionsRecovered, libraryAnalysisOwner == nil {
                    startNativeMusicAnalysis()
                }
            }
            await removeStaleNativeSources()
            let batches = await queue.prepare()
            guard !Task.isCancelled, libraryAnalysisOwner == token else {
                await queue.finish()
                return
            }
            let count = batches.filter { $0.pass == .matching }.reduce(0) { $0 + $1.range.count }
            let total = batches.reduce(0) { $0 + $1.range.count }
            state.analysisTotal = total
            state.backgroundRun?.report(0, total)
            if count > 0 { logAnalysis("Analysis queue: \(count) songs") }
            if let mixes = batches.first(where: { $0.isMix }) {
                logAnalysis(
                    "Checking \(mixes.range.count) mixes over 19 minutes after shorter tracks, before structure analysis."
                )
            }
            var matched: [String: String] = [:]
            var review: [String: String] = [:]
            var waitingForConditions = false
            batches: for batch in batches {
                await queue.begin(batch)
                guard !Task.isCancelled, libraryAnalysisOwner == token else { break }
                let pass = batch.pass
                state.activePass = pass
                let batchCount = batch.range.count
                let passStart = state.analysisChecked
                let title = batch.title
                var matchingCounts: [LibraryMatchingSource: Int] = [:]
                @MainActor func logMatchingSummary() {
                    logAnalysis(
                        "\(batch.isMix ? "Mixes over 19 min · " : "")Pass 1 summary \(state.analysisChecked - passStart) of \(batchCount) · "
                            + "Traktor both \(matchingCounts[.traktorBoth, default: 0]), "
                            + "grid only \(matchingCounts[.traktorGrid, default: 0]), "
                            + "key only \(matchingCounts[.traktorKey, default: 0]), "
                            + "saved GenErik \(matchingCounts[.saved, default: 0]), "
                            + "fresh analysis \(matchingCounts[.fresh, default: 0]), "
                            + "failed \(matchingCounts[.failed, default: 0])")
                }
                defer { if pass == .matching { logMatchingSummary() } }
                analysisProgress = .init(
                    done: 0, total: batchCount, title: title, isLibraryAnalysis: true)
                while let job = await queue.next() {
                    state.activeTrackID = matched[job.id] ?? job.trackID
                    defer { state.activeTrackID = nil }
                    guard !Task.isCancelled, libraryAnalysisOwner == token else { break }
                    if !libraryAnalysisPlaybackIsIdle {
                        cancelNativeMusicAnalysis()
                        break
                    }
                    if pass != .matching, let trackID = matched[job.id], let track = library.track(id: trackID),
                        let message = state.conditions.pauseMessage
                    {
                        let cached =
                            pass == .deep
                            ? !DeepAnalysisProfile.current.needsAnalysis(after: track.analysis.deepBeatAnalysis)
                                || loaded.values.contains(trackID)
                            : await hasCurrentLibraryArrangement(track)
                        if !cached {
                            state.waitingForStructure = (version, library.revision)
                            analysisProgress?.message = message
                            waitingForConditions = true
                            break batches
                        }
                    }
                    analysisProgress?.message = nil
                    musicLibraryProgress = "\(pass.title) for \(job.title)"
                    let measurement = AnalysisMeasurement(
                        runID: token.uuidString, jobID: job.id,
                        pass: pass == .matching ? "matching" : pass == .deep ? "deep" : "structure",
                        duration: job.duration)
                    var matchingSource = LibraryMatchingSource.failed
                    var outcome = "success"
                    let issue = await withTaskCancellationHandler {
                        await AnalysisExecution.$foregroundLibrary.withValue(!state.backgrounded) {
                            await AnalysisMeasurement.$current.withValue(measurement) {
                                do {
                                    switch pass {
                                    case .matching:
                                        let (track, source) = try await prepareLibraryMatching(job)
                                        matchingSource = source
                                        measurement.capture(track.analysis)
                                        measurement.update { $0.source = source.rawValue }
                                        matched[job.id] = track.id
                                        return libraryMatchingIssue(track)
                                    case .deep:
                                        if let trackID = matched[job.id], let track = library.track(id: trackID) {
                                            guard !loaded.values.contains(trackID) else {
                                                state.deferredDeepTracks.insert(trackID)
                                                return nil
                                            }
                                            state.deferredDeepTracks.remove(trackID)
                                            let result = try await prepareLibraryDeepAnalysis(job, track: track)
                                            try Task.checkCancellation()
                                            adoptLibrary(
                                                try await service.adoptDeepAnalysis(
                                                    result, trackID: trackID, protectedTracks: Set(loaded.values)))
                                            return result.needsReview(for: track)
                                                ? "Deep beat evidence needs review." : nil
                                        }
                                        outcome = "skipped"
                                        return nil
                                    case .structure:
                                        if let trackID = matched[job.id] {
                                            guard let track = library.track(id: trackID) else {
                                                throw CoreError.staleContext
                                            }
                                            measurement.capture(track.analysis)
                                            let arrangement = try await prepareLibraryStructure(job, track: track)
                                            return arrangement.automaticCues?.isEmpty != false
                                                ? "No reliable section starts were found for hot cues." : nil
                                        }
                                        outcome = "skipped"
                                        return nil
                                    }
                                } catch {
                                    outcome = error is CancellationError ? "cancelled" : "failed"
                                    return error.localizedDescription
                                }
                            }
                        }
                    } onCancel: {
                        measurement.requestCancellation()
                    }
                    if Task.isCancelled { outcome = "cancelled" }
                    if state.measurements.count < 128 {
                        state.measurements.append(measurement.finish(outcome: outcome))
                    } else {
                        state.droppedMeasurements += 1
                    }
                    guard !Task.isCancelled, libraryAnalysisOwner == token else { break }
                    await flushLibraryMeasurements()
                    guard !Task.isCancelled, libraryAnalysisOwner == token else { break }
                    if pass == .deep, outcome == "success", let trackID = matched[job.id],
                        let current = library.track(id: trackID)
                    {
                        review[job.id] = libraryMatchingIssue(current)
                    }
                    if let issue {
                        if review[job.id] == nil { review[job.id] = issue }
                        logAnalysis("Review \(job.title) (\(pass.title)): \(issue)")
                    }
                    let warning = review[job.id].map { LibraryAnalysisWarning(title: job.title, message: $0) }
                    if libraryAnalysisWarnings[job.id] != warning { libraryAnalysisWarnings[job.id] = warning }
                    state.analysisChecked += 1
                    let checked = state.analysisChecked - passStart
                    if pass == .matching {
                        matchingCounts[matchingSource, default: 0] += 1
                        if checked.isMultiple(of: 100), checked < batchCount { logMatchingSummary() }
                    }
                    analysisProgress?.done = checked
                    state.backgroundRun?.report(state.analysisChecked, total)
                    if checked == 1 {
                        logAnalysis("\(title) \(checked) of \(batchCount) after checking \(job.title)")
                    }
                }
            }
            await queue.finish()
            await flushLibraryMeasurements(force: true)
            guard !Task.isCancelled, libraryAnalysisOwner == token, !waitingForConditions else { return }
            state.waitingForStructure = nil
            state.finishedAnalysis = (version, library.revision)
            state.deferredDeepTracks.formIntersection(Set(library.tracks.map(\.id)))
            if !state.deferredDeepTracks.isEmpty {
                analysisProgress = .init(
                    done: max(0, count - state.deferredDeepTracks.count), total: count,
                    message: "Deep analysis will continue when the remaining loaded tracks are unloaded.",
                    title: "Deep analysis", isLibraryAnalysis: true)
            } else if !review.isEmpty {
                analysisProgress = .init(
                    done: count, total: count,
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
        if playback.core.playingPads != 0 { return false }
        #if os(iOS)
            if playback.s2MicrophoneActive || playback.s3ExtEnabled || playback.s4InputChannels > 0
                || playback.core.loopRecorderState.isActive
                || playback.core.previewGeneration != 0 || s2SampleLoad != nil {
                return false
            }
        #endif
        guard !playback.isRecording, !playback.recordingFinishing, let snapshot = playback.core.snapshot() else {
            return false
        }
        return !DeckID.allCases.contains { snapshot[$0].phase.active || snapshot[$0].touchActive }
    }

    func flushLibraryMeasurements(force: Bool = false) async {
        let state = nativeMusic
        while !state.measurements.isEmpty, force || state.measurements.count >= 16 {
            guard !Task.isCancelled, libraryAnalysisPlaybackIsIdle, state.loadOwners.isEmpty,
                preparingPlayback.isEmpty, !deckAnalysisIsRunning, !importing, !state.measurementLogUnavailable
            else { return }
            let records = Array(state.measurements.prefix(16))
            let url = store.root.appendingPathComponent("analysis-measurements.jsonl")
            let result = await state.files.run { Result { try AnalysisMeasurementLog.append(records, to: url) } }
            guard case .success(true) = result else {
                state.measurementLogUnavailable = true
                logAnalysis(
                    "Analysis measurement log is full or unavailable. Export the saved log before another baseline.")
                return
            }
            state.measurements.removeFirst(records.count)
        }
        if state.droppedMeasurements > 0, !Task.isCancelled, libraryAnalysisPlaybackIsIdle {
            logAnalysis("Analysis measurement buffer omitted \(state.droppedMeasurements) attempts.")
            state.droppedMeasurements = 0
        }
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

    private func prepareLibraryMatching(_ job: NativeMusicAnalysisQueue.Job) async throws
        -> (Track, LibraryMatchingSource)
    {
        let lookup = AnalysisMeasurement.begin("identityLookup")
        switch job {
        case .managed(let track):
            let current = library.track(id: track.id) ?? track
            lookup?.finish()
            guard current.needsCurrentLibraryAnalysis else {
                AnalysisMeasurement.current?.cacheHit("savedMatching")
                return (current, .init(reusing: current))
            }
            let snapshot = try await service.reanalyze(trackID: track.id)
            adoptLibrary(snapshot)
            guard let updated = snapshot.track(id: track.id) else { throw CoreError.staleContext }
            return (updated, .fresh)
        case .native(let item, let known):
            var track = known.flatMap { library.track(id: $0.id) }
            if track == nil { track = await preparedNativeTrack(item) }
            lookup?.finish()
            if let track, !track.needsCurrentLibraryAnalysis {
                AnalysisMeasurement.current?.cacheHit("savedMatching")
                return (track, .init(reusing: track))
            }
            let sourceChanged = track?.nativeSourceNeedsAnalysis == true
            return try await withNativeAudio(item) { prepared in
                let (snapshot, reusedTraktor) = try await self.service.prepareNativeLibraryMatching(
                    url: prepared.url, musicLibrary: prepared.metadata, sourceChanged: sourceChanged)
                self.adoptLibrary(snapshot)
                guard let updated = await self.preparedNativeTrack(item) else { throw MusicLibraryError.missingAudio }
                return (updated, reusedTraktor ? .init(reusing: updated) : .fresh)
            }
        }
    }

    private func prepareLibraryDeepAnalysis(_ job: NativeMusicAnalysisQueue.Job, track: Track) async throws
        -> DeepBeatAnalysis
    {
        if let saved = track.analysis.deepBeatAnalysis, !DeepAnalysisProfile.current.needsAnalysis(after: saved) {
            return saved
        }
        let root = store.root
        let token = libraryAnalysisOwner
        let progress: @Sendable (Int, Int) -> Void = { [weak self] done, total in
            Task { @MainActor in
                guard let self, self.libraryAnalysisOwner == token else { return }
                self.analysisProgress?.message = "\(track.title) · saved window \(done) of \(total)"
            }
        }
        switch job {
        case .managed:
            return try await AnalysisWorker.shared.deepBeatAnalysis(
                url: store.mediaDirectory.appendingPathComponent(track.mediaFilename), matching: track.analysis,
                root: root, progress: progress)
        case .native(let item, _):
            return try await withNativeAudio(item) { prepared in
                try await AnalysisWorker.shared.deepBeatAnalysis(
                    url: prepared.url, matching: track.analysis, root: root, progress: progress)
            }
        }
    }

    private func prepareLibraryStructure(_ job: NativeMusicAnalysisQueue.Job, track: Track) async throws
        -> ArrangementCache
    {
        let span = AnalysisMeasurement.begin("pass2Total")
        defer { span?.finish() }
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
                guard
                    let arrangement = try await self.prepareLibraryArrangement(
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
        cancelCloudSyncForPlayback()
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
            var selectedTitle = selection?.title ?? "Music track"
            do {
                let item = await resolve()
                try Task.checkCancellation()
                guard state.loadOwners[deck] == token else { throw CancellationError() }
                guard let item else { throw MusicLibraryError.missingAudio }
                pendingNativeSelection[deck] = item
                selectedID = item.id
                selectedTitle = item.title
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
                            audioFingerprint: opening.audioFingerprint, saveWithLoadHistory: true))
                    try Task.checkCancellation()
                    guard state.loadOwners[deck] == token else { throw CancellationError() }
                    guard let track = await preparedNativeTrack(item) else { throw TransportError.stale }
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
                    throw MusicLibraryError.missingAudio
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
                reportTrackLoadFailure(deck: deck, title: selectedTitle, error: error)
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
            let prepared: PreparedMusicLibraryAudio
            do {
                let span = AnalysisMeasurement.begin("sourcePreparation")
                defer { span?.finish() }
                prepared = try await musicLibraryProvider.prepare(item, in: directory)
            }
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
