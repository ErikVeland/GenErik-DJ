import Foundation
import Observation
import TDJCore

@MainActor @Observable
public final class ReplicaModel {
    let effectDisplay=EffectControlDisplay()
    var effects: [DeckID:[Int:EffectControl]] = [:] {
        didSet { effectDisplay.publish(effects) }
    }
    var selectedEffectSlots: [DeckID:Int] = [:]
    let performancePersistence=CoalescingFileWriter<PerformancePreparation>()
    let effectsPersistence=CoalescingFileWriter<[DeckID:[Int:EffectControl]]>()
    public var performance = PerformancePreparation()
    public var frozen: Set<DeckID> = []
    public var filterLocked: Set<DeckID> = []
    public var superSlicerFamilies: [DeckID: SuperSlicerFamily] = [:]
    @ObservationIgnored private var storedLibrary: LibrarySnapshot
    @ObservationIgnored private let libraryObservation = ObservationRegistrar()
    @ObservationIgnored public var library: LibrarySnapshot {
        _read {
            libraryObservation.access(self, keyPath: \.library)
            yield storedLibrary
        }
        set {
            let notify = storedLibrary != newValue
            let retiring = BackgroundOwnedValue(storedLibrary)
            withExtendedLifetime(retiring) {
                if notify {
                    libraryObservation.withMutation(of: self, keyPath: \.library) {
                        storedLibrary = newValue
                        loadedTrackCache.removeAll(keepingCapacity: true)
                    }
                } else {
                    storedLibrary = newValue
                    loadedTrackCache.removeAll(keepingCapacity: true)
                }
            }
        }
        _modify {
            libraryObservation.access(self, keyPath: \.library)
            libraryObservation.willSet(self, keyPath: \.library)
            defer {
                loadedTrackCache.removeAll(keepingCapacity: true)
                libraryObservation.didSet(self, keyPath: \.library)
            }
            yield &storedLibrary
        }
    }
    func libraryReadSource() -> BackgroundOwnedValue<LibrarySnapshot> {
        libraryObservation.access(self, keyPath: \.library)
        return BackgroundOwnedValue(storedLibrary)
    }
    func catalogReadSource() -> BackgroundOwnedValue<MusicLibraryCatalog>? {
        _ = musicLibraryCatalogVersion
        return storedMusicLibraryCatalog.map { BackgroundOwnedValue($0) }
    }
    private var loadedWaveforms: [String: AudioAnalysis] = [:] {
        didSet { loadedTrackCache.removeAll(keepingCapacity:true) }
    }
    public private(set) var preparingWaveforms: Set<String> = []
    public private(set) var preparingSourceActions: Set<DeckID> = []
    @ObservationIgnored private var waveformWork: [String:Task<Void,Never>] = [:]
    @ObservationIgnored private var waveformRequests: [String:UUID] = [:]
    @ObservationIgnored private var waveformShutdown = false
    @ObservationIgnored private var loadedTrackCache: [DeckID: (String, Track?)] = [:]
    public var loaded: [DeckID: String] = [:] {
        didSet { for deck in DeckID.allCases where loaded[deck] != nil && loaded[deck] != oldValue[deck] { lastLoadedDeck = deck } }
    }
    /// Most recent deck to receive a track. Seeds recommendations when no deck is playing.
    public internal(set) var lastLoadedDeck: DeckID?
    /// Prep list (Queue): browser entry IDs in play order, saved in the workspace.
    public internal(set) var queuedIDs: [String] = []
    /// Decks showing the hotcue pad row (the flag button), and decks whose pads delete instead of set.
    public var hotcuePadsVisible: Set<DeckID> = []
    public var hotcueDeleting: Set<DeckID> = []
    /// Grid edit lock and tap mode, per deck.
    public var gridLocked: Set<DeckID> = []
    public var gridTapMode: Set<DeckID> = []
    /// CUE button points, per deck, in source frames.
    public internal(set) var cuePoints: [DeckID: Double] = [:]
    public var viewport: [DeckID: Double] = [:]
    public private(set) var applyingGrids: Set<DeckID> = []
    var adaptiveUndo: [String: [Preparation]] = [:]
    public var gridDraft: [DeckID: BeatGrid] = [:]
    public var editing: Set<DeckID> = []
    public var browserVisible = true
    public var helpVisible = false
    public var suggestionDestination: DeckID?
    public var selectedTrackID: String?
    public var suggestions: [Suggestion] = []
    public var suggestionMessage: String?
    private var suggestionWork: Task<Void,Never>?
    private var suggestionRequest=UUID()
    public func flushSuggestions() async { await suggestionWork?.value }
    public var status = ""
    public var importing = false
    public var traktorPreparationRecords = 0
    /// Automatic preparation import shown as a quiet header pill. Nil when idle.
    public private(set) var preparationImport: PreparationImportProgress?
    @ObservationIgnored private var preparationImportGeneration = 0
    @ObservationIgnored private var preparationImportRunning = false
    /// Background analysis status, shown beside the import pill. Nil when idle.
    public internal(set) var analysisProgress: PreparationImportProgress?
    public internal(set) var browserHintsVersion: UInt64 = 0
    @ObservationIgnored var collectionHints: [String: BrowserPreparationHint] = [:]
    @ObservationIgnored var analysisHints = NativeAnalysisHints()
    @ObservationIgnored var staleSourcesCleaned = false
    var analysisHintsURL: URL { store.root.appendingPathComponent("native-analysis.json") }
    var analysisLogURL: URL { store.root.appendingPathComponent("analysis.log") }
    public var isRecording = false
    public var recordingFinishing = false
    public var recordings: [URL] = []
    public private(set) var recordingTracklists: [URL: URL] = [:]
    @ObservationIgnored private let recordingListReader = BackgroundFileWork(label: "org.generikdj.recording-list")
    public private(set) var recordingsRefreshing = false
    @ObservationIgnored private var recordingListWork: Task<Void, Never>?
    @ObservationIgnored private var recordingListPending = false
    public let recordingsDirectory: URL
    public var recordingLocation = ""
    public func loadRecording(_ url: URL, deck: DeckID) async {
        guard !importing, recordings.contains(url), playbackSnapshot?[deck].phase.active != true else { return }
        importing=true
        defer { importing=false }
        do {
            adoptLibrary(try await service.importAudio(url:url))
            let identity=try await Task.detached(priority:.utility) { try AudioAnalyzer.sha256(url:url) }.value
            load(trackID:identity,deck:deck)
            await flushWrites()
            refreshSuggestions()
        } catch { status=error.localizedDescription }
    }
    public func refreshRecordings() {
        recordingListPending = true
        guard recordingListWork == nil else { return }
        recordingsRefreshing = true
        let directory = recordingsDirectory
        recordingListWork = Task {
            while recordingListPending {
                recordingListPending = false
                let saved = await recordingListReader.run { SetRecorder.savedRecordingSnapshot(in: directory) }
                recordings = saved.recordings
                recordingTracklists = saved.tracklists
            }
            recordingsRefreshing = false
            recordingListWork = nil
        }
    }
    public func flushRecordingList() async { await recordingListWork?.value }
    public func recordingTracklist(for recording: URL) -> URL? {
        recordingTracklists[recording]
    }
    public func toggleRecording() async {
        if playback.isRecording { refreshPlayback(); await playback.finishRecording() }
        else {
            do {
                try await playback.startRecording(directory: recordingsDirectory, location: recordingLocation)
            }
            catch { status = error.localizedDescription }
        }
        refreshPlayback()
        refreshRecordings()
        await flushRecordingList()
    }
    @ObservationIgnored private var storedMusicLibraryCatalog: MusicLibraryCatalog?
    public private(set) var musicLibraryCatalogVersion: UInt64 = 0
    public var musicLibraryCatalog: MusicLibraryCatalog? {
        get { _ = musicLibraryCatalogVersion; return storedMusicLibraryCatalog }
        set {
            let retiring = storedMusicLibraryCatalog.map { BackgroundOwnedValue($0) }
            withExtendedLifetime(retiring) {
                storedMusicLibraryCatalog = newValue
                musicLibraryCatalogVersion &+= 1
            }
        }
    }
    public var musicLibraryRefreshing = false
    @ObservationIgnored private var musicLibraryRefreshTask: Task<Void, Never>?
    public private(set) var musicLibraryPreparing = false
    @ObservationIgnored private var musicLibraryImportTask: Task<Void, Never>?
    public func startMusicLibraryImport(_ ids: Set<String>) {
        guard !importing, !musicLibraryRefreshing, musicLibraryImportTask == nil, !ids.isEmpty else { return }
        musicLibraryPreparing = true
        musicLibraryImportTask = Task {
            await importMusicLibraryItems(ids)
            musicLibraryPreparing = false
            musicLibraryImportTask = nil
        }
    }
    public func cancelMusicLibraryImport() { musicLibraryImportTask?.cancel() }
    public func flushMusicLibraryImport() async { await musicLibraryImportTask?.value }
    public var musicLibraryError: String?
    /// Songs the browser can list: every Music library item plus prepared tracks outside it.
    public var browsableSongCount: Int {
        guard let catalog = musicLibraryCatalog else { return library.tracks.count }
        let known = Set(catalog.items.map(\.source))
        return catalog.items.count + library.tracks.filter { !($0.musicLibrarySources ?? []).contains(where: known.contains) }.count
    }
    public var libraryFooterText: String {
        if !status.isEmpty { return status }
        if let musicLibraryError { return "Music library unavailable: \(musicLibraryError)" }
        let count = browsableSongCount
        return count == 1 ? "1 song" : "\(count) songs"
    }
    public var musicLibraryFailures: [String: String] = [:]
    public var musicLibraryProgress = ""
    let musicLibraryProvider: any LocalMusicLibraryProviding
    @ObservationIgnored let nativeMusic = NativeMusicSessionState()
    let importAccess = SecurityScopedFileAccess()
    private let musicImportFileWork=BackgroundFileWork(label:"org.generikdj.music-import-cleanup")
    public var preparingPlayback: Set<DeckID> = []
    public var previewing: Set<DeckID> = []
    let controlDisplay = PlaybackControlDisplay()
    @ObservationIgnored let mixerFaderInputs=MixerFaderInputValues()
    public var playbackSnapshot: PlaybackSnapshot? {
        didSet { controlDisplay.update(playbackSnapshot) }
    }
    private var mixerPreferences = MixerPreferences()
    private let mixerPersistence=CoalescingFileWriter<MixerPreferences>()
    private let collectionPersistence=CoalescingFileWriter<CollectionPlaylists>()
    private var mixerPreferencesURL: URL { store.root.appendingPathComponent("mixer-preferences.json") }
    public func persistMixerPreferences() {
        let url=mixerPreferencesURL
        mixerPersistence.enqueue(mixerPreferences,write:{ try $0.save(to:url) },reportError:{ [weak self] in self?.status=$0 })
    }
    public func persistCollectionPlaylists(_ value: CollectionPlaylists) {
        let url=store.root.appendingPathComponent("collection-playlists.json")
        collectionPersistence.enqueue(value,write:{ try $0.save(to:url) },reportError:{ [weak self] in self?.status=$0 })
    }
    public func flushPreferenceWrites() async {
        await mixerPersistence.flush(); await collectionPersistence.flush(); await flushPerformanceWrites()
    }
    public func finishForShutdown() async {
        waveformShutdown=true
        musicLibraryRefreshTask?.cancel()
        waveformRequests.removeAll()
        for task in waveformWork.values { task.cancel() }
        waveformWork.removeAll(); preparingWaveforms.removeAll()
        stopAudio()
        cancelMusicLibraryImport()
        await closeNativeMusic()
        await flushMusicLibraryImport()
        await playback.finishRecording()
        await flushPreferenceWrites(); await flushHistoryWrites(); await flushWrites(); await flushRecordingList()
        await drainQueuedBackgroundRetirements()
    }
    public func pauseVisualUpdates() {
        playbackMonitor?.cancel(); playbackMonitor=nil
    }
    public func prepareForBackground() async {
        persistMixerPreferences()
        await flushPreferenceWrites(); await flushHistoryWrites()
    }
    public var outputRoute: AudioOutputRoute = .stereoMaster
    public var z1Enabled = false
    public var z1Status = "Z1 disabled"
    private var z1Mapper = Z1ControlMapper()
    private var z1Mode = false
#if os(macOS)
    private var z1Connection: Z1HIDConnection?
#endif
    public func toggleZ1() {
#if os(macOS)
        if z1Enabled {
            z1Connection?.stop(); z1Connection=nil; z1Enabled=false; z1Mapper.reset(); return
        }
        let connection=Z1HIDConnection()
        connection.onState = { [weak self] text,calibration in
            self?.z1Status=text; self?.z1Mapper=Z1ControlMapper(calibration:calibration)
        }
        connection.onReport = { [weak self] report in self?.receiveZ1(report) }
        do { try connection.start(); z1Connection=connection; z1Enabled=true }
        catch { status=error.localizedDescription }
#else
        status="Z1 iPad accessory transport remains unimplemented."
#endif
    }
    public func receiveZ1(_ report: Z1InputReport) {
        z1Mode=report.mode
        for action in z1Mapper.consume(report) {
            switch action {
            case .mixer(let parameter,let value,let deck): setMixer(parameter,value:value,deck:deck)
            case .play(let deck): pressPlay(deck:deck)
            case .cue(let deck): setMixer(.cue,value:playbackSnapshot?[deck].mixer.cue == true ? 0 : 1,deck:deck)
            case .filter(let deck): setMixer(.filterEnabled,value:playbackSnapshot?[deck].mixer.filterEnabled == true ? 0 : 1,deck:deck)
            case .fxMode(let deck): status="Deck \(deck.rawValue.uppercased()): \(z1Mapper.fxDecks.contains(deck) ? "FX" : "Filter") controls"
            case .effectParameter(let x,let deck): setHardwareEffectX(x,deck:deck)
            case .effectToggle(let deck): toggleHardwareEffect(deck:deck)
            }
        }
    }
    public func setOutputRoute(_ route: AudioOutputRoute) {
        do { try playback.setOutputRoute(route); outputRoute = playback.outputRoute; refreshPlayback() }
        catch { status = error.localizedDescription }
    }
    public let playback: PlaybackController
    public let calibration: SuggestionCalibration?
    public let store: WorkspaceStore
    let service: LibraryService
    private let sessionID = UUID()
    private var tapTempos: [DeckID: TapTempo] = [:]
    // Audio readiness has its own ordered tail; full-library persistence never gates a load.
    var playbackLoads: Task<Void, Never>?
    var preparationWrites: Task<Void, Never>?
    @ObservationIgnored private var pendingPreparations: [String: (token: UUID, value: Preparation)] = [:]
    var historyWrites: Task<Void, Never>?
    private var recordedGenerationPairs = Set<String>()
    public func flushHistoryWrites() async { await historyWrites?.value }
    private func retainPerformedPair(_ snapshot: PlaybackSnapshot) {
        guard snapshot.pairedFrames > 0,
              let a=committedTrackIDs[.a],let b=committedTrackIDs[.b],a != b,
              playback.generations[.a] == snapshot.a.generation,playback.generations[.b] == snapshot.b.generation else { return }
        let pair="\(snapshot.a.generation):\(snapshot.b.generation)"
        guard recordedGenerationPairs.insert(pair).inserted else { return }
        let event=PerformanceEvent(sessionID:sessionID,kind:.transition,timestamp:Date(),fromTrackID:a,toTrackID:b,
            durationSeconds:Double(snapshot.pairedFrames)/snapshot.sampleRate)
        enqueueHistory(event,failedPair:pair)
    }
    private func enqueueHistory(_ event: PerformanceEvent, failedPair: String? = nil) {
        let previous = historyWrites
        historyWrites = Task {
            await previous?.value
            do { adoptLibrary(try await service.record(event)); refreshSuggestions() }
            catch {
                if let failedPair { recordedGenerationPairs.remove(failedPair) }
                status = error.localizedDescription
            }
        }
    }
    func adoptLibrary(_ snapshot: LibrarySnapshot) {
        guard snapshot.revision >= storedLibrary.revision else { return }
        pendingLoadKeys = pendingLoadKeys.filter { $0.value.value != nil }
        let pendingKeys = pendingLoadKeys.values.compactMap { $0.value }
        let retained=Set(loadPreparations.values.map { $0.track.id } + committedPreparations.values.map { $0.track.id }
            + pendingKeys.map { $0.trackID })
        for id in retained {
            guard let latest=snapshot.track(id:id) else { continue }
            let key=latest.preparation.correctedKey
            for intent in pendingKeys where intent.trackID == id && intent.stored != key {
                intent.stored = key
                intent.effective = key
            }
            if storedPreparationKeys[id]?.value != key {
                for deck in DeckID.allCases {
                    if loadPreparations[deck]?.track.id == id {
                        loadPreparations[deck]?.track.preparation.correctedKey=key
                    }
                    if committedPreparations[deck]?.track.id == id {
                        committedPreparations[deck]?.track.preparation.correctedKey=key
                    }
                }
            }
            storedPreparationKeys[id] = .init(value:key)
        }
        storedPreparationKeys=storedPreparationKeys.filter { retained.contains($0.key) }
        library = snapshot
    }
    private final class PendingLoadKey {
        let trackID: String
        var stored: MusicalKey?
        var effective: MusicalKey?
        var grid: BeatGrid?
        init(trackID: String, stored: MusicalKey?, effective: MusicalKey?) {
            self.trackID = trackID; self.stored = stored; self.effective = effective
        }
    }
    private struct WeakPendingLoadKey { weak var value: PendingLoadKey? }
    @ObservationIgnored private var pendingLoadKeys: [UUID:WeakPendingLoadKey] = [:]
    private struct StoredPreparationKey { let value: MusicalKey? }
    @ObservationIgnored private var storedPreparationKeys: [String:StoredPreparationKey] = [:]
    private struct LoadPreparation {
        let token: UUID
        var track: Track
        var generation: UInt64?
    }
    private var loadPreparations: [DeckID:LoadPreparation] = [:] {
        didSet { loadedTrackCache.removeAll(keepingCapacity:true) }
    }
    @ObservationIgnored private var committedPreparations: [DeckID:LoadPreparation] = [:]
    private var playbackMonitor: Task<Void, Never>?
    private var loadTokens: [DeckID: UUID] = [:]
    private var committedTrackIDs: [DeckID: String] = [:]

    public init(root: URL, playback: PlaybackController? = nil, recordingsDirectory: URL? = nil,
                musicLibraryProvider: (any LocalMusicLibraryProviding)? = nil, discoverSyncedTraktor: Bool = false,
                automaticTraktorSources: [URL] = []) throws {
        self.recordingsDirectory = recordingsDirectory ?? root.appendingPathComponent("Recordings", isDirectory: true)
        self.musicLibraryProvider = musicLibraryProvider ?? LocalMusicLibrary(diagnosticsURL: root.appendingPathComponent("music-library-access.log"))
        store = try WorkspaceStore(root: root)
        let initialLibrary = try store.load(includeWaveforms:false)
        storedLibrary = initialLibrary
        calibration = initialLibrary.calibration
        service = try LibraryService(store: store, initial: initialLibrary, discoverSyncedTraktor: discoverSyncedTraktor,
                                     automaticTraktorSources: automaticTraktorSources)
        self.playback = try playback ?? PlaybackController()
        mixerPreferences=try MixerPreferences.load(from:root.appendingPathComponent("mixer-preferences.json"))
        try self.playback.setMixer(.filterY,value:mixerPreferences.filterResonanceA,deck:.a)
        try self.playback.setMixer(.filterY,value:mixerPreferences.filterResonanceB,deck:.b)
        playbackSnapshot = self.playback.core.snapshot()
        controlDisplay.update(playbackSnapshot)
        try loadEffects()
        performance=try PerformancePreparation.load(from:root.appendingPathComponent("performance.json"))
        analysisHints=(try? NativeAnalysisHints.load(from:root.appendingPathComponent("native-analysis.json"))) ?? .init()
        queuedIDs=(try? JSONDecoder().decode([String].self,from:Data(contentsOf:root.appendingPathComponent("queue.json")))) ?? []
        // Startup happens before playback; runtime refreshes use the background reader.
        recordings = SetRecorder.savedRecordings(in: self.recordingsDirectory)
    }
    public func track(_ deck: DeckID) -> Track? {
        libraryObservation.access(self, keyPath: \.library)
        guard let id = loaded[deck] else { return nil }
        let pin = loadPreparations[deck]
        let waveform = loadedWaveforms[id]
        if let cached = loadedTrackCache[deck], cached.0 == id { return cached.1 }
        var track = pin?.track.id == id ? pin?.track : storedLibrary.track(id:id)
        if let waveform, let analysis = track?.analysis, analysis.waveform.isEmpty,
           analysis.configurationID == waveform.configurationID,
           analysis.waveformReference == waveform.waveformReference {
            track?.analysis = analysis.replacingWaveform(waveform.waveform)
        }
        loadedTrackCache[deck] = (id, track)
        return track
    }
    func prepareLoadedWaveforms() async throws {
        for deck in DeckID.allCases {
            guard let track = track(deck) else { continue }
            let hydrated = try await store.hydrateAsync(track)
            if loaded[deck] == track.id { loadedWaveforms[track.id] = hydrated.analysis }
        }
        let retained = Set(loaded.values)
        loadedWaveforms = loadedWaveforms.filter { retained.contains($0.key) }
    }
    public func grid(_ deck: DeckID) -> BeatGrid? { gridDraft[deck] ?? track(deck)?.grid }
    func loadIdentity(_ deck: DeckID) -> UUID? { loadPreparations[deck]?.token }

    /// Runs at every launch and activation. Reads the collection, never writes to its source, and
    /// reports progress without blocking or asking for input. Overlapping requests join the running pass.
    public func refreshTraktorPreparation(force: Bool = false) async {
        guard !preparationImportRunning else { return }
        preparationImportRunning = true
        preparationImportGeneration += 1
        let generation = preparationImportGeneration
        defer { preparationImportRunning = false }
        do {
            await refreshLinkedCollection()
            traktorPreparationRecords = try await service.refreshTraktorReferences(force: force)?.document.entryCount ?? 0
            let report: @Sendable (Int, Int) -> Void = { [weak self] done, total in
                Task { @MainActor in self?.showPreparationImport(done: done, total: total, generation: generation) }
            }
            adoptLibrary(try await service.reuseTraktorPreparationForExistingTracks(preservePreparationFor: Set(loaded.values),
                                                                                    progress: report))
            await refreshCollectionHints()
            refreshSuggestions()
            finishPreparationImport(message: nil, generation: generation)
        }
        catch { finishPreparationImport(message: error.localizedDescription, generation: generation) }
    }
    private func showPreparationImport(done: Int, total: Int, generation: Int) {
        guard generation == preparationImportGeneration, preparationImportRunning, total > 0 else { return }
        let value = PreparationImportProgress(done: done, total: total)
        if preparationImport != value { preparationImport = value }
    }
    private func finishPreparationImport(message: String?, generation: Int) {
        guard generation == preparationImportGeneration else { return }
        if let message { preparationImport = .init(done: 0, total: 0, message: message) }
        else if let current = preparationImport { preparationImport = .init(done: current.total, total: current.total) }
        guard preparationImport != nil else { return }
        let delay: Duration = message == nil ? .seconds(1.5) : .seconds(6)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, generation == self.preparationImportGeneration, !self.preparationImportRunning else { return }
            self.preparationImport = nil
        }
    }

    public func importTraktorPreparation(_ url: URL) async {
        guard !importing, !musicLibraryPreparing else { return }
        importing = true
        defer { importing = false }
        do {
            let summary = try await importAccess.withAccess(to: url) {
                try await self.service.importTraktorCollection(url: url)
            }
            traktorPreparationRecords = summary.document.entryCount
            saveCollectionLink(url)
            adoptLibrary(try await service.reuseTraktorPreparationForExistingTracks(preservePreparationFor: Set(loaded.values)))
            await refreshCollectionHints()
            refreshSuggestions()
            status = "Imported \(summary.document.entryCount) preparation records. Matching songs will reuse their preparation."
        } catch { status = error.localizedDescription }
    }

    public func importFiles(_ urls: [URL]) async {
        guard !importing, !musicLibraryPreparing else { return }
        importing = true
        defer { importing = false }
        for (index, url) in urls.enumerated() {
            status = "Analysing \(index + 1) of \(urls.count): \(url.lastPathComponent)"
            do {
                let imported = try await importAccess.withAccess(to: url) {
                    try await self.service.importAudio(url: url)
                }
                adoptLibrary(imported)
            }
            catch { status = error.localizedDescription; return }
        }
        status = "\(library.tracks.count) tracks analysed"
        refreshSuggestions()
    }
    public func refreshMusicLibrary() async {
        if let pending = musicLibraryRefreshTask { await pending.value; return }
        guard !importing, !waveformShutdown else { return }
        musicLibraryRefreshing = true
        musicLibraryError = nil
        let provider = musicLibraryProvider
        let work = Task { [weak self] in
            defer {
                self?.musicLibraryRefreshing = false
                self?.musicLibraryRefreshTask = nil
            }
            do {
                let catalog = try await provider.catalog()
                try Task.checkCancellation()
                self?.musicLibraryCatalog = catalog
                self?.musicLibraryFailures = [:]
                await self?.refreshCollectionHints()
            } catch is CancellationError { }
            catch {
                self?.musicLibraryCatalog = nil
                self?.musicLibraryError = error.localizedDescription
            }
        }
        musicLibraryRefreshTask = work
        await work.value
    }
    public func preparedTrack(for item: MusicLibraryItem) -> Track? {
        library.tracks.first { $0.musicLibrarySources?.contains(item.source) == true }
    }
    public func importMusicLibraryItems(_ ids: Set<String>) async {
        guard !importing, !musicLibraryRefreshing, let catalog = musicLibraryCatalog else { return }
        let items = catalog.items.filter { ids.contains($0.id) }
        guard !items.isEmpty else { return }
        importing = true
        musicLibraryFailures = [:]
        let temporaryRoot = store.root.appendingPathComponent(".music-import-" + UUID().uuidString, isDirectory: true)
        var added = 0
        var existing = 0
        var stopped = false
        defer {
            importing = false
            refreshSuggestions()
        }
        for (index, item) in items.enumerated() {
            if Task.isCancelled {
                musicLibraryProgress = "Stopped. Prepared songs were retained."
                stopped = true; break
            }
            if preparedTrack(for: item) != nil { existing += 1; continue }
            guard item.availability == .available else {
                musicLibraryFailures[item.id] = item.availability.message; continue
            }
            musicLibraryProgress = "Preparing \(index + 1) of \(items.count): \(item.title)"
            status = musicLibraryProgress
            do {
                let prepared = try await musicLibraryProvider.prepare(item, in: temporaryRoot)
                adoptLibrary(try await importPreparedMusic(prepared, temporaryRoot:temporaryRoot))
                added += 1
                refreshSuggestions()
            } catch is CancellationError {
                musicLibraryProgress = "Stopped. Prepared songs were retained."
                stopped = true; break
            } catch { musicLibraryFailures[item.id] = error.localizedDescription }
        }
        // Cleanup is awaited even after cancellation, so import/shutdown retains ownership.
        await removeMusicImportItem(at:temporaryRoot)
        guard !stopped else { return }
        musicLibraryProgress = "\(added) added · \(existing) already prepared · \(musicLibraryFailures.count) unavailable"
        status = musicLibraryProgress
    }

    private func importPreparedMusic(_ prepared: PreparedMusicLibraryAudio,
        temporaryRoot: URL) async throws -> LibrarySnapshot {
        let outcome: Result<LibrarySnapshot, any Error>
        do {
            outcome = .success(try await importAccess.withAccess(to: prepared.url) {
                try await self.service.importAudio(url: prepared.url, musicLibrary: prepared.metadata,
                    preservePreparationFor: Set(self.loaded.values))
            })
        } catch { outcome = .failure(error) }
        if prepared.temporary, prepared.url.deletingLastPathComponent().standardizedFileURL == temporaryRoot.standardizedFileURL {
            await removeMusicImportItem(at:prepared.url)
        }
        return try outcome.get()
    }

    private func removeMusicImportItem(at url: URL) async {
        await musicImportFileWork.run { () -> Void in
            try? FileManager.default.removeItem(at:url)
        }
    }

    public func load(trackID: String, deck: DeckID, sourceURL: URL? = nil,
                     nativeMetadata: MusicLibraryImportMetadata? = nil) {
        _ = loadPreparedTrack(trackID: trackID, deck: deck, sourceURL: sourceURL,
                          nativeMetadata: nativeMetadata, nativeLoadOwner: nil)
    }

    @discardableResult
    func loadPreparedTrack(trackID: String, deck: DeckID, sourceURL: URL?,
                           nativeMetadata: MusicLibraryImportMetadata?, nativeLoadOwner: UUID?,
                           onFailure: (@MainActor (Error) -> Void)? = nil) -> Task<Void, Never>? {
        refreshPlayback()
        guard var track = storedLibrary.track(id:trackID) else { onFailure?(TransportError.stale); return nil }
        if track.nativeLibraryOnly == true && sourceURL == nil { loadNativeTrack(track, deck: deck); return nil }
        if let nativeMetadata {
            if !nativeMetadata.title.isEmpty { track.title = nativeMetadata.title }
            if !nativeMetadata.artist.isEmpty { track.artist = nativeMetadata.artist }
            if !nativeMetadata.album.isEmpty { track.album = nativeMetadata.album }
        }
        let storedKey=track.preparation.correctedKey
        if let pending = pendingPreparations[trackID] { track.preparation = pending.value }
        track=track.resolvingTraktorPreparation()
        if playbackSnapshot?[deck].phase.active == true {
            status = TransportError.protectedDeck.localizedDescription
            onFailure?(TransportError.protectedDeck); return nil
        }
        if let nativeLoadOwner {
            guard nativeMusic.loadOwners[deck] == nativeLoadOwner else { onFailure?(CancellationError()); return nil }
        } else { cancelNativeMusicLoad(deck: deck) }
        do {
            if try performance.installTraktorCues(for: track) { savePerformance() }
        } catch { status = error.localizedDescription; onFailure?(error); return nil }
        let token = UUID()
        let keyIntent = PendingLoadKey(trackID:trackID,stored:storedKey,effective:track.preparation.correctedKey)
        pendingLoadKeys = pendingLoadKeys.filter { $0.value.value != nil }
        pendingLoadKeys[token] = .init(value:keyIntent)
        loadTokens[deck] = token
        storedPreparationKeys[trackID] = .init(value:storedKey)
        loadPreparations[deck] = .init(token:token,track:track)
        loaded[deck] = trackID
        viewport[deck] = track.grid?.anchorFrame ?? 0
        gridDraft[deck] = pendingPreparations[trackID]?.value.grid
        editing.remove(deck)
        frozen.remove(deck)
        previewing.remove(deck)
        preparingPlayback.insert(deck)
        browserVisible = false
        selectedTrackID = nil
        let event = PerformanceEvent(sessionID: sessionID, kind: .load, timestamp: Date(),
            fromTrackID: loaded[deck == .a ? .b : .a], toTrackID: trackID)
        let previous = playbackLoads
        let loadTask = Task {
            await previous?.value
            guard loadTokens[deck] == token else { return }
            do {
                guard let requested=loadPreparations[deck], requested.token==token else { return }
                let sourceTrack=requested.track
                try await playback.load(track:sourceTrack,store:store,deck:deck,sourceURL:sourceURL,committed:{ [weak self = self] generation in
                    guard let self else { return }
                    var acceptedTrack = sourceTrack
                    acceptedTrack.preparation.correctedKey = keyIntent.effective
                    let actual=LoadPreparation(token:token,track:acceptedTrack,generation:generation)
                    self.committedPreparations[deck]=actual
                    self.committedTrackIDs[deck]=trackID
                    self.playback.registerRecordingTrack(deck: deck, generation: generation,
                        artist: sourceTrack.artist, title: sourceTrack.title)
                    let needsLateReconciliation = !self.preparingPlayback.contains(deck) || self.loadTokens[deck] != token
                    if !self.preparingPlayback.contains(deck) {
                        self.loaded[deck]=trackID
                        self.loadTokens[deck]=token
                        self.loadPreparations[deck]=actual
                        self.gridDraft[deck]=keyIntent.grid == nil ? self.pendingPreparations[trackID]?.value.grid : nil
                        self.prepareWaveform(sourceTrack)
                        self.warmCuePositions(deck:deck)
                    }
                    if needsLateReconciliation { self.reconcileAcceptedGrid(keyIntent,token:token,deck:deck,generation:generation) }
                })
                guard loadTokens[deck] == token, let current=loadPreparations[deck] else { return }
                let currentGrid=current.track.grid
                if let grid=currentGrid, grid != sourceTrack.grid { try playback.updateGrid(grid,deck:deck) }
                var committed=current
                committed.generation=playback.generations[deck]
                loadPreparations[deck]=committed
                committedPreparations[deck]=committed
                let retained = Set(loaded.values)
                loadedWaveforms = loadedWaveforms.filter { retained.contains($0.key) }
                for (id,work) in waveformWork where !retained.contains(id) {
                    waveformRequests[id]=nil; work.cancel(); waveformWork[id]=nil; preparingWaveforms.remove(id)
                }
                committedTrackIDs[deck] = trackID
                if track.traktorPreparation == nil, let grid=currentGrid ?? track.grid { synchronizeGridCue(trackID:trackID,grid:grid) }
                if performance.freezeOnLoad { frozen.insert(deck); previewing.insert(deck) }
                preparingPlayback.remove(deck)
                warmCuePositions(deck: deck)
                prepareWaveform(track)
                enqueueHistory(event)
            } catch {
                onFailure?(error)
                if loadTokens[deck] == token {
                    let obsoleteNativeLoad = nativeLoadOwner.map { nativeMusic.loadOwners[deck] != $0 } ?? false
                    let handledNativeFailure = nativeLoadOwner != nil
                        && (error is CancellationError || (error as? TransportError) == .nativeSourceChanged)
                    if !obsoleteNativeLoad && !handledNativeFailure { status = error.localizedDescription }
                    loaded[deck] = committedTrackIDs[deck]
                    loadPreparations[deck]=committedPreparations[deck]
                    gridDraft[deck] = committedTrackIDs[deck].flatMap { pendingPreparations[$0]?.value.grid }
                }
                if let actual = committedPreparations[deck], actual.token == token, let generation = actual.generation {
                    if loadPreparations[deck]?.token == token, keyIntent.grid != nil { gridDraft[deck] = nil }
                    reconcileAcceptedGrid(keyIntent,token:token,deck:deck,generation:generation)
                }
            }
            if loadTokens[deck] == token, preparingPlayback.contains(deck) { preparingPlayback.remove(deck) }
            refreshPlayback()
        }
        playbackLoads = loadTask
        return loadTask
    }
    private func reconcileAcceptedGrid(_ intent: PendingLoadKey, token: UUID, deck: DeckID, generation: UInt64) {
        guard let grid = intent.grid, let actual = committedPreparations[deck],
              actual.token == token, actual.generation == generation, actual.track.grid != grid else { return }
        do {
            try playback.reconcileGrid(grid,deck:deck,generation:generation) { [weak self] in
                guard let self, intent.grid == grid, var accepted = self.committedPreparations[deck],
                      accepted.token == token, accepted.generation == generation else { return }
                accepted.track.preparation.grid = grid
                accepted.track.preparation.gridIsManual = true
                self.committedPreparations[deck] = accepted
                if self.loadPreparations[deck]?.token == token, self.loadPreparations[deck]?.generation == generation {
                    self.loadPreparations[deck]?.track.preparation.grid = grid
                    self.loadPreparations[deck]?.track.preparation.gridIsManual = true
                }
            }
        } catch { status = error.localizedDescription }
    }
    public func flushWrites() async {
        await flushNativeMusicLoads()
        await playbackLoads?.value
        await preparationWrites?.value
        await flushHistoryWrites()
    }
    public func flushWaveforms() async { for work in Array(waveformWork.values) { await work.value } }
    private func prepareWaveform(_ track: Track) {
        guard !waveformShutdown, waveformWork[track.id] == nil else { return }
        if let cached=loadedWaveforms[track.id], cached.configurationID == track.analysis.configurationID,
           cached.waveformReference == track.analysis.waveformReference { return }
        let request=UUID(), id=track.id, storage=store
        waveformRequests[id]=request; preparingWaveforms.insert(id)
        waveformWork[id]=Task { [weak self] in
            defer {
                if let self,self.waveformRequests[id] == request {
                    self.waveformRequests[id]=nil; self.waveformWork[id]=nil; self.preparingWaveforms.remove(id)
                }
            }
            do {
                let hydrated=try await storage.hydrateAsync(track)
                guard !Task.isCancelled,let self,self.waveformRequests[id] == request,
                      self.loaded.values.contains(id) else { return }
                self.loadedWaveforms[id]=hydrated.analysis
            } catch is CancellationError { }
            catch {
                if let self,self.waveformRequests[id] == request,self.loaded.values.contains(id) {
                    self.status="Waveform unavailable: \(error.localizedDescription)"
                }
            }
        }
    }
    /// Play requests now submit synchronously. Retained for existing callers.
    public func flushTransportRequests() async {}
    public func showLibrary() {
        suggestionWork?.cancel(); suggestionRequest=UUID()
        suggestionDestination = nil; suggestions = []; suggestionMessage = nil; browserVisible = true
    }
    public func showSuggestions(destination: DeckID) {
        suggestionDestination = destination
        browserVisible = true
        selectedTrackID = nil
        refreshSuggestions()
    }
    public func refreshSuggestions() {
        suggestionWork?.cancel()
        let request=UUID(); suggestionRequest=request
        guard let destination = suggestionDestination else { return }
        let other: DeckID = destination == .a ? .b : .a
        guard let reference = loaded[other] else {
            suggestions = []; suggestionMessage = "Load a reference track on deck \(other.rawValue.uppercased())."; return
        }
        let context = SuggestionContext(referenceTrackID: reference, destination: destination,
                performanceBPM: playbackSnapshot?.masterBPM,
                usePerformanceBPM: playbackSnapshot?[other].phase.active == true && playbackSnapshot?[other].synced == true, loadedTrackIDs: Set(loaded.values),
                libraryRevision: storedLibrary.revision, historyRevision: storedLibrary.adaptiveMemory.revision)
        let librarySource=libraryReadSource()
        let referenceTrack=track(other)
        let referenceToken=loadPreparations[other]?.token
        suggestions=[]; suggestionMessage=nil
        suggestionWork=Task {
            do {
                let ranked=try await PerformerSuggestions.rankAsync(librarySource:librarySource,context:context,referenceOverride:referenceTrack)
                guard !Task.isCancelled, suggestionRequest == request,
                      loaded[other] == reference, Set(loaded.values) == context.loadedTrackIDs,
                      loadPreparations[other]?.token == referenceToken,
                      track(other)?.preparation == referenceTrack?.preparation else { return }
                if storedLibrary.revision != context.libraryRevision { refreshSuggestions(); return }
                suggestions=ranked
            } catch is CancellationError { }
            catch { if suggestionRequest == request { suggestions=[]; suggestionMessage=error.localizedDescription } }
        }
    }
    public func saveGrid(_ grid: BeatGrid, deck: DeckID) {
        guard let track = track(deck) else { return }
        guard playbackSnapshot?[deck].phase != .queued else {
            gridDraft[deck] = nil; status = TransportError.unresolved.localizedDescription; return
        }
        guard !applyingGrids.contains(deck) else { return }
        var preparation = pendingPreparations[track.id]?.value
            ?? storedLibrary.track(id:track.id)?.preparation ?? track.preparation
        guard !preparation.gridLocked else { status = "Unlock preparation before editing the grid."; return }
        if let map=preparation.adaptiveMap, preparation.gridMode != .fixed, let fixed=preparation.grid {
            do {
                preparation.adaptiveMap = try map.transforming(tempoFactor:grid.bpm/fixed.bpm,
                    frameOffset:grid.anchorFrame-fixed.anchorFrame,frameCount:track.analysis.frameCount)
                preparation.gridIsManual=true
                gridDraft[deck]=nil
                saveAdaptivePreparation(preparation,deck:deck)
            } catch { gridDraft[deck]=nil;status=error.localizedDescription }
            return
        }
        preparation.adaptiveMap = nil; preparation.gridMode = .fixed
        preparation.grid = grid; preparation.gridIsManual = true
        do { if !preparingPlayback.contains(deck) { try playback.updateGrid(grid,deck:deck) } }
        catch { status=error.localizedDescription; return }
        adaptiveUndo[track.id]=nil
        for destination in DeckID.allCases where loaded[destination]==track.id &&
            (destination==deck || preparingPlayback.contains(destination)) {
            if let identity = loadPreparations[destination]?.token { pendingLoadKeys[identity]?.value?.grid = grid }
            loadPreparations[destination]?.track.preparation.grid=grid
            loadPreparations[destination]?.track.preparation.gridIsManual=true
            if !preparingPlayback.contains(destination), let pin=loadPreparations[destination] {
                committedPreparations[destination]=pin
            }
        }
        gridDraft[deck] = grid
        refreshSuggestions()
        synchronizeGridCue(trackID:track.id,grid:grid)
        let token = UUID()
        pendingPreparations[track.id] = (token, preparation)
        let previous = preparationWrites
        preparationWrites = Task {
            await previous?.value
            do {
                adoptLibrary(try await service.updatePreparation(trackID: track.id, preparation: preparation))
                if pendingPreparations[track.id]?.token == token {
                    pendingPreparations[track.id] = nil
                    for destination in DeckID.allCases where loaded[destination] == track.id && gridDraft[destination] == grid {
                        gridDraft[destination] = nil
                    }
                }
                refreshSuggestions()
                refreshPlayback()
            } catch { status = error.localizedDescription }
        }
    }
    public func startPlaybackMonitor() {
        guard playbackMonitor == nil else { return }
        playbackMonitor = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshPlayback()
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
            }
        }
    }
    public func stopPlaybackMonitor() {
        suggestionWork?.cancel()
        persistMixerPreferences()
        playbackMonitor?.cancel(); playbackMonitor = nil
#if os(macOS)
        z1Connection?.stop(); z1Connection=nil; z1Enabled=false
#endif
        playback.stopAudio(); refreshPlayback()
    }
    public func refreshPlayback() {
        let wasRecording = isRecording || recordingFinishing
        isRecording = playback.isRecording
        recordingFinishing = playback.recordingFinishing
        if wasRecording && !isRecording && !recordingFinishing {
            refreshRecordings()
            if let error = playback.recordingError { status = error }
        }
        let (snapshot, messages) = playback.snapshotAndMessages()
        preparingSourceActions = playback.preparingSourceDecks
        if let snapshot {
            playbackSnapshot = snapshot
            retainPerformedPair(snapshot)
#if os(macOS)
            z1Connection?.send(Z1OutputReport.bytes(snapshot:snapshot,mode:z1Mode,fxDecks:z1Mapper.fxDecks,
                enabledEffects:Set(DeckID.allCases.filter { effects[$0]?[selectedEffectSlots[$0,default:0]]?.enabled == true })))
#endif
            for deck in DeckID.allCases where !editing.contains(deck) && !previewing.contains(deck) && !frozen.contains(deck) {
                if snapshot[deck].phase == .playing || snapshot[deck].phase == .queued
                    || snapshot[deck].phase == .paused || snapshot[deck].phase == .ended {
                    viewport[deck] = snapshot[deck].sourceFrame
                }
            }
        }
        if let error = messages.compactMap(\.error).last { status = error.localizedDescription }
    }
    public func pressPlay(deck: DeckID) {
        guard !preparingPlayback.contains(deck) else { return }
        do {
            try playback.play(deck)
            previewing.remove(deck)
            refreshPlayback()
        } catch { status = error.localizedDescription }
    }
    public func setMixer(_ parameter: MixerParameter, value: Double, deck: DeckID = .a) {
        if submitMixer(parameter,value:value,deck:deck) { refreshPlayback() }
    }
    @discardableResult
    func submitMixer(_ parameter: MixerParameter, value: Double, deck: DeckID) -> Bool {
        do {
            try playback.setMixer(parameter, value: value, deck: deck)
            mixerFaderInputs.accept(parameter,value:value,deck:deck)
            if parameter == .filterY, value.isFinite, (0...1).contains(value) {
                if deck == .a { mixerPreferences.filterResonanceA=value } else { mixerPreferences.filterResonanceB=value }
            }
            return true
        }
        catch { status = error.localizedDescription; return false }
    }
    public func resetEQ(deck: DeckID) {
        for band in [MixerParameter.low, .mid, .high] { setMixer(band, value: 1, deck: deck) }
    }
    public func setMasterBPM(_ value: Double) {
        do { try playback.setMasterBPM(value); refreshPlayback(); refreshSuggestions() }
        catch { status = error.localizedDescription }
    }
    public func toggleSync(deck: DeckID) {
        guard let snapshot=playbackSnapshot else { return }
        let state=snapshot[deck]
        do {
            if state.phase == .playing && (!state.synced || snapshot.syncNeedsAlignment(deck)) {
                try playback.restoreSync(deck:deck)
            } else { try playback.setSync(!state.synced,deck:deck) }
            refreshPlayback()
        }
        catch { status = error.localizedDescription }
    }
    func disengageSyncForManualControl(deck: DeckID) {
        guard playbackSnapshot?[deck].synced == true else { return }
        do { try playback.setSync(false,deck:deck); refreshPlayback() }
        catch { status=error.localizedDescription }
    }
    public func toggleKeylock(deck: DeckID) {
        guard playbackSnapshot?[deck].phase != .empty else { return }
        do { try playback.setKeylock(!playback.requestedKeylock(deck), deck: deck); refreshPlayback() }
        catch { status = error.localizedDescription }
    }
    public func stopAudio() {
        cancelPendingNativeMusicLoads()
        persistMixerPreferences()
        refreshPlayback()
        let wasDeviceOutput = playback.outputActive && !playback.offline
        playback.stopAudio(); refreshPlayback()
        if wasDeviceOutput, let snapshot = playbackSnapshot {
            let url = store.root.appendingPathComponent("last-playback-stop.json")
            Task.detached(priority: .utility) {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try? encoder.encode(snapshot).write(to: url, options: .atomic)
            }
        }
    }
    public func correctTempo(deck: DeckID, factor: Double) {
        guard var grid = grid(deck) else { return }
        do { try grid.setBPM(grid.bpm * factor); saveGrid(grid, deck: deck) }
        catch { status = error.localizedDescription }
    }
    public func tapTempo(deck: DeckID) {
        do {
            var tap = tapTempos[deck] ?? TapTempo()
            let bpm = try tap.tap(atMonotonicSeconds: ProcessInfo.processInfo.systemUptime)
            tapTempos[deck] = tap
            guard let bpm, let track = track(deck) else { return }
            var changed = try grid(deck) ?? BeatGrid(bpm: bpm, anchorFrame: viewport[deck] ?? 0, sampleRate: track.analysis.sampleRate)
            if let map=gridPreparation(deck)?.adaptiveMap,gridPreparation(deck)?.gridMode != .fixed,
               let fixed=grid(deck) {
                try changed.setBPM(fixed.bpm*bpm/map.bpm(atFrame:viewport[deck] ?? 0))
            } else { try changed.setBPM(bpm) }
            saveGrid(changed, deck: deck)
        } catch { status = error.localizedDescription }
    }
    public func selectDownbeat(deck: DeckID, beat: Int) {
        guard var changed = grid(deck) else { return }
        if var preparation=gridPreparation(deck),let map=preparation.adaptiveMap,preparation.gridMode != .fixed {
            guard !preparation.gridLocked,(0..<4).contains(beat) else { return }
            preparation.adaptiveMap=BeatGridMap(anchors:map.anchors,sampleRate:map.sampleRate,downbeatOffset:beat)
            preparation.gridIsManual=true
            saveAdaptivePreparation(preparation,deck:deck)
            return
        }
        do { try changed.selectDownbeat(beat); saveGrid(changed, deck: deck) }
        catch { status = error.localizedDescription }
    }
}

extension ReplicaModel {
    public func timing(_ deck: DeckID) -> BeatTiming? {
        grid(deck).map { BeatTiming(fixed: $0, adaptive: playbackSnapshot?[deck].adaptiveMap) }
    }
    public func candidateConfidence(_ deck: DeckID) -> Double? {
        guard let id=loaded[deck] else { return nil }
        return storedLibrary.track(id:id)?.analysis.adaptiveConfidence
    }
    public func gridPreparation(_ deck: DeckID) -> Preparation? {
        guard let track = track(deck) else { return nil }
        return pendingPreparations[track.id]?.value ?? track.preparation
    }
    public func selectGridMode(_ mode: GridMode, deck: DeckID) {
        guard let track = track(deck), var preparation = gridPreparation(deck), !preparation.gridLocked else { return }
        if mode != .fixed, preparation.adaptiveMap == nil {
            guard let candidate = storedLibrary.track(id:track.id)?.analysis.adaptiveCandidate ?? track.analysis.adaptiveCandidate else { status = "No adaptive candidate is available."; return }
            do { try preparation.acceptAdaptive(candidate, frameCount: track.analysis.frameCount) }
            catch { status = error.localizedDescription; return }
        }
        preparation.gridMode = mode
        saveAdaptivePreparation(preparation, deck: deck)
    }
    public func correctLocalAnchor(deck: DeckID) {
        guard let track = track(deck), var preparation = gridPreparation(deck),
              let map = preparation.adaptiveMap else { return }
        let frame = boundedFrame(viewport[deck] ?? 0, deck: deck)
        let beat = map.beat(atFrame: frame).rounded()
        do {
            try preparation.correctAnchor(beat: beat, frame: frame, frameCount: track.analysis.frameCount)
            saveAdaptivePreparation(preparation, deck: deck)
        } catch { status = error.localizedDescription }
    }
    public func setGridLocked(_ locked: Bool, deck: DeckID) {
        guard var preparation = gridPreparation(deck) else { return }
        preparation.gridLocked = locked
        saveAdaptivePreparation(preparation, deck: deck, publish: false)
    }
    public func undoGridCorrection(deck: DeckID) {
        guard let track = track(deck), gridPreparation(deck)?.gridLocked != true,
              let previous = adaptiveUndo[track.id]?.last else { return }
        saveAdaptivePreparation(previous, deck: deck, remember: false)
    }
    private func saveAdaptivePreparation(_ preparation: Preparation, deck: DeckID, publish: Bool = true, remember: Bool = true) {
        guard !applyingGrids.contains(deck), let track = track(deck), let previousPreparation = gridPreparation(deck),
              let generation=playbackSnapshot?[deck].generation else { return }
        if publish {
            guard !preparingPlayback.contains(deck), let state = playbackSnapshot?[deck],
                  !state.phase.active, !state.loopEnabled, !state.touchActive, !state.jumpPending else {
                status = "Pause the deck and finish loops or gestures before applying a grid."; return
            }
        }
        applyingGrids.insert(deck)
        let previous = preparationWrites
        preparationWrites = Task {
            await previous?.value
            defer { applyingGrids.remove(deck) }
            do {
                guard loaded[deck]==track.id,playbackSnapshot?[deck].generation==generation else { throw TransportError.stale }
                if publish {
                    try await playback.updateAdaptiveMap(preparation.gridMode == .fixed ? nil : preparation.adaptiveMap, deck: deck)
                }
                guard loaded[deck]==track.id,playback.generations[deck]==generation else { throw TransportError.stale }
                if loadPreparations[deck]?.track.id == track.id { loadPreparations[deck]?.track.preparation=preparation }
                if committedPreparations[deck]?.track.id == track.id { committedPreparations[deck]?.track.preparation=preparation }
                if preparation.gridLocked { gridLocked.insert(deck) } else { gridLocked.remove(deck) }
                if remember { adaptiveUndo[track.id, default: []].append(previousPreparation) }
                else { adaptiveUndo[track.id]?.removeLast() }
                if adaptiveUndo[track.id, default: []].count > 16 { adaptiveUndo[track.id]?.removeFirst() }
                let token=UUID()
                pendingPreparations[track.id]=(token,preparation)
                adoptLibrary(try await service.updatePreparation(trackID: track.id, preparation: preparation))
                if pendingPreparations[track.id]?.token==token { pendingPreparations[track.id]=nil }
                refreshPlayback()
            } catch { status = error.localizedDescription;refreshPlayback() }
        }
    }
}
