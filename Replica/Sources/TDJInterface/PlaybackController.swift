import AVFoundation
import CTDJAudioSource
import Foundation
import TDJCore

public enum AudioOutputRoute: String, CaseIterable, Sendable { case stereoMaster, masterAndHeadphones }

@MainActor public final class PlaybackController {
    public let core: SampleTransport
    var recoveryRevisions: [DeckID: UInt64] = [:]
    var recoveryAwaitedCommands: Set<UInt64> = []
    var recoveryAcknowledgements: [UInt64: TransportAcknowledgement] = [:]
    public private(set) var generations: [DeckID: UInt64] = [:]
    // Development startup policy. Original default and persistence remain unmeasured.
    private var keylockPreference: [DeckID: Bool] = [.a: true, .b: true]
    private var ejectCommits: [UInt64: (DeckID, () -> Void)] = [:]
    private var pendingKeylock: [UInt64: (DeckID, Bool)] = [:]
    private var latestKeylock: [DeckID: UInt64] = [:]
    private enum ControlValue {
        case mixer(MixerParameter, Double, DeckID)
        case effect(Int, Int, Double, Double, Bool, DeckID, Bool)
        case gridMetronome(Double?, DeckID, UInt64)

        enum Lane: Equatable {
            case mixer(MixerParameter, DeckID?)
            case effect(Int, DeckID)
            case gridMetronome(DeckID)
        }

        var lane: Lane {
            switch self {
            case .mixer(let parameter, _, let deck):
                switch parameter {
                case .crossfader, .master, .monitor, .cueBlend: return .mixer(parameter, nil)
                default: return .mixer(parameter, deck)
                }
            case .effect(_, let slot, _, _, _, let deck, _): return .effect(slot, deck)
            case .gridMetronome(_, let deck, _): return .gridMetronome(deck)
            }
        }

        func submit(to core: SampleTransport) throws {
            switch self {
            case .mixer(let parameter, let value, let deck):
                try core.setMixer(parameter, value: value, deck: deck)
            case .effect(let kind, let slot, let x, let y, let enabled, let deck, let synced):
                try core.setEffect(kind, slot: slot, x: x, y: y, enabled: enabled, deck: deck, synced: synced)
            case .gridMetronome(let offset, let deck, let generation):
                guard core.snapshot()?[deck].generation == generation else { return }
                try core.setGridMetronome(offset: offset, deck: deck, generation: generation)
            }
        }
    }
    private var pendingControlValues: [ControlValue] = []
    private var pendingTransport: [SourceLane: TrackedSource] = [:]
    private var touchAfterRelease: [DeckID: SourceControl] = [:]
    public private(set) var outputActive = false
    #if os(macOS)
        private var timingActivity: PlaybackTimingActivity?
    #endif
    public var playbackTimingActivityActive: Bool? {
        #if os(macOS)
            timingActivity != nil
        #else
            nil
        #endif
    }
    public let offline: Bool
    private let validationMode: Bool
    private let callbackMetrics: AudioCallbackMetrics?
    public var callbackSummary: AudioCallbackSummary? { callbackMetrics?.summary() }
    public var sourceThreadCPUTracing: Bool { callbackMetrics?.tracesThreadCPU == true }
    public private(set) var outputRoute: AudioOutputRoute = .stereoMaster
    public private(set) var automaticOutputDevice: String?
    private var requestedOutputRoute: AudioOutputRoute = .stereoMaster
    func updateOutputDevice(_ outputs: [AudioOutputDevice]) {
        automaticOutputDevice = outputs.count == 1 ? outputs[0].automaticSplitOutputName : nil
        outputRoute = automaticOutputDevice != nil ? .masterAndHeadphones : requestedOutputRoute
    }
    public func setOutputRoute(_ route: AudioOutputRoute) throws {
        guard automaticOutputDevice == nil else { return }
        guard route != outputRoute else { return }
        guard recorder == nil, recordingStartTask == nil else {
            throw TransportError.cache("Stop recording before changing audio routing.")
        }
        let state = core.snapshot()
        guard !outputActive, outputStartTask == nil, state?.anyDeckActive != true else {
            throw TransportError.cache("Stop playback before changing audio routing.")
        }
        stopAudio()
        discardOutputGraph()
        requestedOutputRoute = route
        outputRoute = route
    }
    private var recorder: SetRecorder?
    private var recordingRegisteredGenerations: Set<String> = []
    private struct RecordingTrackMetadata {
        let deck: DeckID
        let generation: UInt64
        let artist: String
        let title: String
        var key: String { "\(deck.rawValue):\(generation)" }
    }
    private var latestRecordingTracks: [DeckID: RecordingTrackMetadata] = [:]
    private var startingRecordingTracks: [String: RecordingTrackMetadata] = [:]
    private var recordingStartTask: Task<Void, Error>?
    private var recordingStartShouldStop = false
    var recordingPreparedCheckpoint: (() async -> Void)?
    private var recordingFinishTask: Task<Void, Never>?
    public private(set) var recordingFinishing = false
    public private(set) var recordingError: String?
    public var isRecording: Bool { recorder != nil && !recordingFinishing }

    public func startRecording(directory: URL, location: String = "") async throws {
        if let recordingStartTask {
            try await recordingStartTask.value
            return
        }
        guard recorder == nil, !recordingFinishing else { return }
        recordingError = nil
        recordingRegisteredGenerations.removeAll()
        startingRecordingTracks = Dictionary(uniqueKeysWithValues: latestRecordingTracks.values.map { ($0.key, $0) })
        recordingStartShouldStop = false
        let ring = core.recording
        let sampleRate = core.sampleRate
        let task = Task {
            let prepared = try await Task.detached(priority: .utility) {
                try SetRecorder(directory: directory, sampleRate: sampleRate, buffer: ring, location: location)
            }.value
            await recordingPreparedCheckpoint?()
            self.recorder = prepared
            for metadata in startingRecordingTracks.values { enqueueRecordingTrack(metadata, recorder: prepared) }
            startingRecordingTracks.removeAll()
            do { if !offline && !recordingStartShouldStop { try startOutput() } } catch {
                _ = try? await prepared.finish()
                self.recorder = nil
                throw error
            }
        }
        recordingStartTask = task
        defer {
            recordingStartTask = nil
            startingRecordingTracks.removeAll()
        }
        try await task.value
    }
    public func registerRecordingTrack(deck: DeckID, generation: UInt64, artist: String, title: String) {
        let metadata = RecordingTrackMetadata(deck: deck, generation: generation, artist: artist, title: title)
        latestRecordingTracks[deck] = metadata
        if recordingStartTask != nil, recorder == nil { startingRecordingTracks[metadata.key] = metadata }
        guard let recorder, !recordingFinishing else { return }
        enqueueRecordingTrack(metadata, recorder: recorder)
    }
    private func enqueueRecordingTrack(_ metadata: RecordingTrackMetadata, recorder: SetRecorder) {
        guard recordingRegisteredGenerations.insert(metadata.key).inserted else { return }
        recorder.registerTrack(
            deck: UInt32(metadata.deck.transportIndex), generation: metadata.generation, artist: metadata.artist,
            title: metadata.title)
    }
    public func finishRecording() async {
        if let recordingStartTask {
            recordingStartShouldStop = true
            _ = try? await recordingStartTask.value
        }
        if let recordingFinishTask {
            await recordingFinishTask.value
            return
        }
        guard let recorder else { return }
        recorder.stopCapture()
        recordingFinishing = true
        let task = Task {
            do { _ = try await recorder.finish() } catch { recordingError = error.localizedDescription }
            self.recorder = nil
            recordingFinishing = false
            recordingFinishTask = nil
        }
        recordingFinishTask = task
        await task.value
    }
    private var outputStartTask: Task<Void, Never>?
    private var outputStartIdentity: UInt64 = 0
    private var outputRetryAt: ContinuousClock.Instant?
    private var outputRetries = 0
    private var outputWatchdog = OutputProgressWatchdog()
    private var reportedBusyRenderer = false
    private var engine: AVAudioEngine?
    private var source: AVAudioSourceNode?
    private var nativeSource: TDJNativeAudioSource?
    private var engineObserver: NSObjectProtocol?
    private var sessionObservers: [NSObjectProtocol] = []
    private var outputGraphIdentity: UInt64 = 0
    private var interrupted = false
    private var mediaServicesUnavailable = false
    private var resumeRequiresPlay = false
    private(set) var outputRecoveryPending = false
    #if os(iOS)
        private var outputPortIDs: Set<String> = []
    #endif
    private enum LoadResult {
        case waiting, accepted
        case rejected(TransportError)
    }
    private let streamingPlayback: Bool
    private var adaptiveResults: [UInt64: LoadResult] = [:]
    private var loadResults: [UInt64: LoadResult] = [:]
    private var loadCommits: [UInt64: (deck: DeckID, accepted: (UInt64) -> Void)] = [:]
    private struct GridCommit {
        let deck: DeckID
        let generation: UInt64
        let grid: BeatGrid
        let accepted: () -> Void
    }
    private var gridCommits: [UInt64: GridCommit] = [:]
    private var preparedGridCommits: [UInt64: GridCommit] = [:]
    private var messages: [TransportAcknowledgement] = []
    static let maximumPendingMessages = 256
    private var controlMaintenanceTimer: ControlMaintenanceTimer?
    private var nextSourceIdentity: UInt64 = 0
    private var latestSources: [SourceLane: UInt64] = [:]
    private var sentSources: [UInt64: TrackedSource] = [:]
    private var preparationTasks: [SourceLane: Task<Void, Never>] = [:]
    private var preparationIdentities: [SourceLane: UInt64] = [:]
    public private(set) var sourcePreparationFailures = 0
    public private(set) var sourcePreparationRequests = 0
    public private(set) var rejectedCommandCount: UInt64 = 0

    public init(
        offline: Bool = false, sampleRate: Double = 48000, validationMode: Bool = false, streamingPlayback: Bool? = nil
    ) throws {
        let metrics =
            validationMode
            ? try AudioCallbackMetrics(
                sampleRate: sampleRate,
                traceThreadCPU: ProcessInfo.processInfo.environment["TDJ_DIAGNOSE_AUDIO_CPU"] == "1") : nil
        callbackMetrics = metrics
        core = try SampleTransport(sampleRate: sampleRate, keylockDiagnostics: metrics)
        self.offline = offline
        self.streamingPlayback = streamingPlayback ?? !offline
        self.validationMode = validationMode
        #if os(iOS)
            if !offline {
                updateOutputDevice(Self.currentAudioOutputs)
                observeAudioSession()
            }
        #endif
    }
    deinit {
        outputStartTask?.cancel()
        for task in preparationTasks.values { task.cancel() }
    }
    enum LoadCheckpoint {
        case decoded
        case submitted(UInt64)
        case accepted(UInt64)
    }
    var loadCheckpoint: ((LoadCheckpoint) async throws -> Void)?

    public func load(
        track: Track, store: WorkspaceStore, deck: DeckID, sourceURL: URL? = nil, preparedAsset: PCMAsset? = nil,
        opening: NativePlaybackOpening? = nil, synced: Bool = true, committed: @escaping (UInt64) -> Void = { _ in }
    ) async throws {
        guard core.snapshot()?[deck].phase.active != true else { throw TransportError.protectedDeck }
        invalidateRecovery(deck: deck)
        cancelSourcePreparations(deck: deck)
        let asset: PCMAsset
        if let preparedAsset {
            asset = preparedAsset
        } else if let opening {
            let rate = core.sampleRate
            let maximum = core.configuredMaximumOutputFrames == 0 ? 4096 : core.configuredMaximumOutputFrames
            asset = try await Task.detached(priority: .userInitiated) {
                try opening.asset(outputSampleRate: rate, maximumOutputFrames: maximum, compactPool: deck.transportIndex >= 2)
            }.value
        } else {
            asset = try await PCMCache.prepareAsync(
                track: track, store: store, streamed: streamingPlayback, outputSampleRate: core.sampleRate,
                maximumOutputFrames: core.configuredMaximumOutputFrames == 0
                    ? 4096 : core.configuredMaximumOutputFrames, sourceURL: sourceURL, compactPool: deck.transportIndex >= 2)
        }
        try Task.checkCancellation()
        if deck.transportIndex >= 2 {
            let core = core
            try await Task.detached(priority: .utility) { try core.prepareExtraDecks() }.value
            try Task.checkCancellation()
        }
        if let loadCheckpoint { try await loadCheckpoint(.decoded) }
        // The output route can change while the decoder is working. A cold LOAD
        // updates the asset's bound; prepare it again before retrying ownership.
        for attempt in 0..<3 {
            do {
                try await submitLoad(asset: asset, track: track, deck: deck, synced: synced, committed: committed)
                return
            } catch TransportError.sourceCold where attempt < 2 { try Task.checkCancellation() }
        }
    }
    private func submitLoad(
        asset: PCMAsset, track: Track, deck: DeckID, synced: Bool, committed: @escaping (UInt64) -> Void
    ) async throws {
        guard core.snapshot()?[deck].phase.active != true else { throw TransportError.protectedDeck }
        let keylock = requestedKeylock(deck)
        let grid = track.grid
        let map = track.adaptiveMap
        let generation = try core.reserveLoad(
            asset, deck: deck, grid: grid, synced: synced, keylock: keylock, adaptiveMap: map,
            resetMasterTempoWhenIdle: true)
        var submitted = false
        var ownedTicket: UInt64 = 0
        defer {
            if ownedTicket != 0 { asset.releaseSourcePreparation(ownedTicket) }
            if !submitted { core.cancelReservedLoad(generation: generation) }
        }
        var preloadSpeed = 1.0
        if synced, let grid {
            let master = max(core.snapshot()?.masterBPM ?? grid.bpm, grid.bpm)
            preloadSpeed = master / grid.bpm
            if let map {
                for (start, end) in zip(map.anchors, map.anchors.dropFirst()) {
                    let bpm = 60 * map.sampleRate * (end.beat - start.beat) / (end.frame - start.frame)
                    preloadSpeed = max(preloadSpeed, master / bpm)
                }
            }
            if keylock { preloadSpeed = min(8, preloadSpeed) }
        }
        ownedTicket = try await asset.prepareSource(
            .init(position: 0, speed: preloadSpeed, keylock: keylock), generation: generation)
        try Task.checkCancellation()
        let ticket = ownedTicket
        ownedTicket = 0
        cancelSourcePreparations(deck: deck)
        loadCommits[generation] = (deck, committed)
        do { try core.submitPreparedLoad(generation: generation, preparationTicket: ticket) } catch {
            loadCommits[generation] = nil
            throw error
        }
        submitted = true
        loadResults[generation] = .waiting
        defer { loadResults[generation] = nil }
        if let loadCheckpoint { try await loadCheckpoint(.submitted(generation)) }
        if !outputActive { core.processControlsWhileIdle() }
        for _ in 0..<200 {
            collectMessages()
            switch loadResults[generation] {
            case .accepted:
                generations[deck] = generation
                if let loadCheckpoint { try await loadCheckpoint(.accepted(generation)) }
                return
            case .rejected(let error): throw error
            default: break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw TransportError.cache("The audio renderer did not acknowledge the load.")
    }
    public func brake(_ action: VinylBrakeAction, value: Double = 1, deck: DeckID) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        if action == .begin { cancelPerformancePreparations(deck: deck) }
        try submitSource(.brake(action, value, deck, generation))
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func play(_ deck: DeckID) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        if try resumeOutputIfNeeded(deck: deck) { return }
        let lane = SourceLane.play(deck)
        if pendingTransport[lane] != nil {
            invalidateSource(lane)
            return
        }
        let pending = latestSources[lane] != nil || latestSources[.recall(deck)] != nil
        let warming = preparationTasks[lane] != nil || preparationTasks[.recall(deck)] != nil
        cancelPerformancePreparations(deck: deck)
        if pending {
            invalidateSource(lane)
            if warming { return }
        }
        if !offline { try startOutput(userInitiated: true) }
        try submitSource(.play(deck, generation), canPrepare: !pending)
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func recallCue(_ cue: PerformanceCue, deck: DeckID, quantum: Double) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        if !offline { try startOutput() }
        try submitSource(.cueRecall(deck, generation, frame: cue.frame, loopEnd: cue.loopEnd, quantum: quantum))
        if !outputActive { core.processControlsWhileIdle() }
    }
    func eject(deck: DeckID, accepted: @escaping () -> Void) throws {
        guard let generation = generations[deck], core.snapshot()?[deck].generation == generation else {
            throw TransportError.stale
        }
        let identifier = try core.eject(deck: deck, generation: generation)
        ejectCommits[identifier] = (deck, accepted)
        if !outputActive { core.processControlsWhileIdle() }
    }
    func setGridMetronome(offset: Double?, deck: DeckID, generation: UInt64) throws {
        try submitControlValue(.gridMetronome(offset, deck, generation))
    }
    public func perform(
        _ action: PerformanceAction, deck: DeckID, value: Double = 0, end: Double = 0, enabled: Bool = true,
        quantum: Double = 0, touchRate: Double? = nil, followsPosition: Bool = false
    ) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        if action == .loopRoll {
            if latestSources[.rollRelease(deck)] != nil { return }
            if !enabled { invalidateSource(.performance(deck, action.rawValue)) }
        }
        if action == .touch && enabled && !offline { try startOutput() }
        let control = SourceControl.performance(
            action, deck, generation, value: value, end: end, enabled: enabled, quantum: quantum,
            touchRate: touchRate, followsPosition: followsPosition)
        if action == .touch, !enabled {
            touchAfterRelease[deck] = nil
            invalidateSource(.performance(deck, PerformanceAction.touch.rawValue))
            invalidateSource(.performance(deck, PerformanceAction.rate.rawValue))
            if latestSources[.touchRelease(deck)] != nil { return }
        } else if action == .touch || action == .rate, latestSources[.touchRelease(deck)] != nil {
            touchAfterRelease[deck] = control
            return
        }
        try submitSource(control)
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func setEffect(
        _ kind: Int, slot: Int, x: Double, y: Double, enabled: Bool, deck: DeckID, synced: Bool = true
    ) throws {
        guard (0..<3).contains(slot), (0..<PerformanceEffect.supportedCount).contains(kind),
            (0...1).contains(x), (0...1).contains(y)
        else { throw TransportError.invalid }
        try submitControlValue(.effect(kind, slot, x, y, enabled, deck, synced))
    }
    public func setMixer(_ parameter: MixerParameter, value: Double, deck: DeckID = .a) throws {
        let valid = switch parameter {
        case .gain: (0...4).contains(value)
        case .low, .mid, .high: (0...2).contains(value)
        case .filterX: (-1...1).contains(value)
        case .cue, .filterEnabled: value == 0 || value == 1
        default: (0...1).contains(value)
        }
        guard valid else { throw TransportError.invalid }
        if parameter == .crossfader || parameter == .volume { invalidateRecovery(submitCancellation: false) }
        try submitControlValue(.mixer(parameter, value, deck))
    }
    private func submitControlValue(_ value: ControlValue) throws {
        if pendingControlValues.isEmpty && pendingTransport.isEmpty {
            do {
                try value.submit(to: core)
                if !outputActive { core.processControlsWhileIdle() }
                return
            } catch TransportError.queueFull {}
        }
        pendingControlValues.removeAll { $0.lane == value.lane }
        pendingControlValues.append(value)
        startControlMaintenance()
    }
    private func flushPendingControls() {
        guard !pendingTransport.isEmpty || !pendingControlValues.isEmpty else { return }
        let ordered = pendingTransport.values.sorted {
            if $0.lane.isRelease != $1.lane.isRelease { return $0.lane.isRelease }
            return $0.identity < $1.identity
        }
        for action in ordered {
            do {
                try submitTrackedSource(action)
                pendingTransport[action.lane] = nil
            } catch TransportError.queueFull {
                return
            } catch {
                invalidateSource(action.lane)
                appendMessage(.init(commandID: 0, generation: action.control.generation ?? 0,
                                    error: (error as? TransportError) ?? .invalid))
            }
        }
        while let value = pendingControlValues.first {
            do {
                try value.submit(to: core)
            } catch TransportError.queueFull {
                break
            } catch {
                appendMessage(.init(commandID: 0, generation: 0, error: (error as? TransportError) ?? .invalid))
            }
            pendingControlValues.removeFirst()
        }
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func setFreeRate(_ rate: Double, deck: DeckID) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        try submitSource(.freeRate(rate, deck, generation))
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func setMasterBPM(_ bpm: Double) throws {
        try submitSource(.tempo(bpm))
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func setSync(_ enabled: Bool, deck: DeckID) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        try submitSource(.sync(enabled, deck, generation))
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func restoreSync(deck: DeckID) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        try submitSource(.restoreSync(deck, generation))
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func setKeylock(_ enabled: Bool, deck: DeckID) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        guard core.snapshot()?[deck].phase != .queued else { throw TransportError.unresolved }
        try submitSource(.keylock(enabled, deck, generation))
        keylockPreference[deck] = enabled
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func requestedKeylock(_ deck: DeckID) -> Bool { keylockPreference[deck] ?? (deck.transportIndex < 2) }
    public func warmCuePositions(_ cues: [PerformanceCue], deck: DeckID) {
        guard let generation = generations[deck], let asset = core.asset(generation: generation), asset.isStreamed
        else { return }
        let targets = cues.prefix(8).flatMap { cue -> [PCMSourceTarget] in
            guard cue.frame.isFinite, cue.frame >= 0, cue.frame < Double(asset.frames) else { return [] }
            let start = cue.loopEnd == nil ? 0 : cue.frame
            let end = cue.loopEnd ?? 0
            return [
                .init(position: cue.frame, speed: 8, loopStart: start, loopEnd: end, keylock: true),
                .init(position: cue.frame, speed: 8, performanceRate: -1, loopStart: start, loopEnd: end),
            ]
        }
        if targets.isEmpty {
            core.setOptionalWarming(generation: generation, preparation: nil)
            return
        }
        guard let ticket = try? asset.requestOptionalWarming(targets, generation: generation), ticket != 0 else {
            return
        }
        core.setOptionalWarming(
            generation: generation, preparation: .init(asset: asset, deck: deck, generation: generation, ticket: ticket)
        )
    }
    public func updateAdaptiveMap(_ map: BeatGridMap?, deck: DeckID) async throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        if let map, let asset = core.asset(generation: generation) {
            try map.validate(frameCount: Int64(asset.frames))
            guard map.sampleRate == asset.sampleRate else { throw TransportError.invalid }
        }
        let identifier = try submitSource(.adaptiveMap(map, deck, generation), canPrepare: false)
        adaptiveResults[identifier] = .waiting
        defer { adaptiveResults[identifier] = nil }
        for _ in 0..<200 {
            if !outputActive { core.processControlsWhileIdle() }
            collectMessages()
            switch adaptiveResults[identifier] {
            case .accepted:
                guard generations[deck] == generation, let state = core.snapshot()?[deck],
                    state.generation == generation, state.adaptiveMap == map
                else { throw TransportError.stale }
                return
            case .rejected(let error): throw error
            default: break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw TransportError.cache("The audio renderer did not acknowledge the grid.")
    }
    public func updateGrid(_ grid: BeatGrid, deck: DeckID) throws {
        guard let generation = generations[deck] else { return }
        try submitSource(.grid(grid, deck, generation))
        if !outputActive { core.processControlsWhileIdle() }
    }
    func reconcileGrid(_ grid: BeatGrid, deck: DeckID, generation: UInt64, accepted: @escaping () -> Void) throws {
        guard generations[deck] == generation, core.snapshot()?[deck].generation == generation else {
            throw TransportError.stale
        }
        let identifier = try submitSource(.grid(grid, deck, generation))
        gridCommits[identifier] = .init(deck: deck, generation: generation, grid: grid, accepted: accepted)
        if !outputActive {
            core.processControlsWhileIdle()
            collectMessages()
        }
    }
    public func stopAudio() {
        invalidateRecovery()
        #if os(iOS)
            enabledCaptureDevice = nil
            core.setMicrophoneEnabled(false)
        #endif
        controlMaintenanceTimer = nil
        outputWatchdog.resetRecoveryBudget()
        outputRecoveryPending = false
        resumeRequiresPlay = false
        cancelSourcePreparations()
        if recordingStartTask != nil { recordingStartShouldStop = true }
        suspendOutput()
        if recorder != nil || recordingStartTask != nil { Task { await finishRecording() } }
        // Make room for Stop even after a burst fills the command/message rings.
        // Device output is paused before the control thread becomes the consumer.
        collectMessages()
        core.processControlsWhileIdle()
        collectMessages()
        try? core.stopAll()
        core.processControlsWhileIdle()
        flushPendingControls()
    }
    public func snapshotAndMessages() -> (PlaybackSnapshot?, [TransportAcknowledgement]) {
        maintainControlState()
        let result = messages
        messages.removeAll(keepingCapacity: true)
        return (core.snapshot(), result)
    }
    /// Ownership acknowledgements and recorder failures must progress without visual polling.
    func maintainControlState() {
        if recorder?.hasFailed == true, !recordingFinishing {
            recordingFinishing = true
            Task { await finishRecording() }
        }
        if !outputActive { core.processControlsWhileIdle() }
        collectMessages()
        flushPendingControls()
        if !offline {
            checkOutputProgress()
            retryOutputIfDue {
                discardOutputGraph()
                try startOutput()
            }
        }
    }
    private func checkOutputProgress() {
        guard outputActive, !interrupted, !mediaServicesUnavailable,
            outputWatchdog.isStalled(frame: core.renderedOutputFrame)
        else { return }
        let activeDeck = core.snapshot().map(\.anyDeckActive) ?? true
        let pendingStart = sentSources.values.contains { action in
            switch action.lane {
            case .play, .recall: return true
            case .performance(_, let kind): return kind == PerformanceAction.touch.rawValue
            default: return false
            }
        }
        guard activeDeck || pendingStart || isRecording, let nativeSource else { return }
        guard nativeSource.suspendIfIdle() else {
            if !reportedBusyRenderer {
                reportedBusyRenderer = true
                appendMessage(.init(commandID: 0, generation: 0,
                                    error: .cache("Audio rendering stalled. Waiting for the callback to finish.")))
            }
            return
        }
        let allowRestart = outputWatchdog.takeRestart()
        receiveOutputEvent(.renderStalled(allowRestart: allowRestart))
    }

    func startControlMaintenance() {
        guard controlMaintenanceTimer == nil else { return }
        controlMaintenanceTimer = ControlMaintenanceTimer { [weak self] in
            MainActor.assumeIsolated { self?.maintainControlState() }
        }
    }
    private func appendMessage(_ message: TransportAcknowledgement) {
        if messages.count >= Self.maximumPendingMessages {
            // UI feedback is bounded even when hardware controls run with the screen off.
            if message.error == nil { return }
            if let success = messages.firstIndex(where: { $0.error == nil }) {
                messages.remove(at: success)
            } else {
                messages.removeFirst()
            }
        }
        messages.append(message)
    }
    private func collectMessages() {
        for message in core.acknowledgements() {
            if recoveryAwaitedCommands.contains(message.commandID) {
                recoveryAcknowledgements[message.commandID] = message
            }
            if adaptiveResults[message.commandID] != nil {
                adaptiveResults[message.commandID] = message.error.map { .rejected($0) } ?? .accepted
            }
            if handleSourceAcknowledgement(message) { continue }
            if message.error != nil { rejectedCommandCount += 1 }
            if let (deck, accepted) = ejectCommits.removeValue(forKey: message.commandID), message.error == nil,
                generations[deck] == message.generation {
                cancelSourcePreparations(deck: deck)
                generations[deck] = nil
                accepted()
            }
            if let (deck, enabled) = pendingKeylock.removeValue(forKey: message.commandID),
                latestKeylock[deck] == message.commandID
            {
                keylockPreference[deck] = message.error == nil ? enabled : core.snapshot()?[deck].keylock ?? enabled
                latestKeylock[deck] = nil
            }
            if let load = loadCommits.removeValue(forKey: message.generation), message.error == nil {
                generations[load.deck] = message.generation
                load.accepted(message.generation)
            }
            if loadResults[message.generation] != nil {
                loadResults[message.generation] = message.error.map { .rejected($0) } ?? .accepted
            }
            appendMessage(message)
        }
    }
    enum OutputEvent: Sendable {
        case configurationChanged
        case renderStalled(allowRestart: Bool)
        case routeChanged(disconnected: Bool)
        case interruptionBegan
        case interruptionEnded(shouldResume: Bool)
        case mediaServicesLost
        case mediaServicesReset
    }

    private func suspendOutput() {
        outputWatchdog.disarm()
        reportedBusyRenderer = false
        outputRetryAt = nil
        outputStartIdentity &+= 1
        outputStartTask?.cancel()
        outputStartTask = nil
        nativeSource?.suspendAndWait()
        engine?.pause()
        outputActive = false
        #if os(macOS)
            timingActivity = nil
        #endif
    }

    private func discardOutputGraph() {
        outputGraphIdentity &+= 1
        if let engineObserver { NotificationCenter.default.removeObserver(engineObserver) }
        engineObserver = nil
        engine?.stop()
        engine = nil
        source = nil
        nativeSource = nil
        #if os(iOS)
            requestedCaptureDevice = nil
            attachedCaptureDevice = nil
            enabledCaptureDevice = nil
            core.setMicrophoneEnabled(false)
        #endif
    }

    func handleOutputEvent(
        _ event: OutputEvent, outputs: [AudioOutputDevice]? = nil, restart: () throws -> Void
    ) {
        let hadOutput = outputActive || outputStartTask != nil || outputRecoveryPending
            || (offline && core.snapshot().map(\.anyDeckActive) == true)
        let previousRoute = outputRoute
        let previousAutomaticDevice = automaticOutputDevice
        switch event {
        case .configurationChanged, .renderStalled, .routeChanged, .mediaServicesReset:
            if let outputs { updateOutputDevice(outputs) }
        default:
            break
        }
        // Hold playback when an automatic split output disappears.
        if previousAutomaticDevice != nil && automaticOutputDevice == nil && hadOutput { resumeRequiresPlay = true }
        switch event {
        case .interruptionBegan:
            interrupted = true
        case .interruptionEnded(let shouldResume):
            interrupted = false
            if !shouldResume && outputRecoveryPending { resumeRequiresPlay = true }
        case .mediaServicesLost:
            mediaServicesUnavailable = true
        case .mediaServicesReset:
            mediaServicesUnavailable = false
            interrupted = false
            if hadOutput { resumeRequiresPlay = true }
        case .routeChanged(let disconnected):
            if disconnected && hadOutput && outputRoute == .stereoMaster { resumeRequiresPlay = true }
        case .renderStalled(let allowRestart):
            if !allowRestart { resumeRequiresPlay = true }
            #if os(iOS)
                let ports = Set(AVAudioSession.sharedInstance().currentRoute.outputs.map(\.uid))
                if !outputPortIDs.isEmpty, ports != outputPortIDs { resumeRequiresPlay = true }
            #endif
        case .configurationChanged:
            break
        }

        switch event {
        case .interruptionEnded:
            break
        case .routeChanged(disconnected: false)
            where previousRoute == outputRoute && previousAutomaticDevice == automaticOutputDevice
                && outputActive && engine?.isRunning == true:
            return
        default:
            if hadOutput {
                outputRecoveryPending = true
                suspendOutput()
                collectMessages()
                core.processControlsWhileIdle()
                collectMessages()
            }
            if hadOutput || engine != nil { discardOutputGraph() }
        }

        guard outputRecoveryPending else { return }
        #if os(iOS)
            if outputRoute == .stereoMaster, !outputPortIDs.isEmpty,
                outputPortIDs.isDisjoint(with: AVAudioSession.sharedInstance().currentRoute.outputs.map(\.uid))
            {
                resumeRequiresPlay = true
            }
        #endif
        guard !interrupted, !mediaServicesUnavailable else { return }
        guard !resumeRequiresPlay else {
            appendMessage(.init(commandID: 0, generation: 0, error: .cache("Press Play to restore audio output.")))
            return
        }
        outputRetries = 0
        do { try restart() } catch { recordOutputFailure(error) }
    }

    private func recordOutputFailure(_ error: Error, now: ContinuousClock.Instant = .now) {
        if outputRecoveryPending, !interrupted, !mediaServicesUnavailable, !resumeRequiresPlay,
            outputRetries < 3
        {
            outputRetryAt = now + .milliseconds(150 * (1 << outputRetries))
            startControlMaintenance()
            return
        }
        outputRetryAt = nil
        let failure = (error as? TransportError) ?? .cache(error.localizedDescription)
        let message: TransportError = outputRecoveryPending
            ? .cache("\(failure.localizedDescription) Press Play to retry audio output.") : failure
        appendMessage(.init(commandID: 0, generation: 0, error: message))
    }

    func retryOutputIfDue(now: ContinuousClock.Instant = .now, restart: () throws -> Void) {
        guard let retryAt = outputRetryAt, now >= retryAt, outputStartTask == nil else { return }
        outputRetryAt = nil
        guard outputRecoveryPending, !outputActive, !interrupted, !mediaServicesUnavailable, !resumeRequiresPlay else {
            return
        }
        outputRetries += 1
        do { try restart() } catch { recordOutputFailure(error, now: now) }
    }

    func resumeOutputIfNeeded(deck: DeckID) throws -> Bool {
        guard !offline else { return false }
        outputWatchdog.resetRecoveryBudget()
        resumeRequiresPlay = false
        guard outputRecoveryPending, core.snapshot()?[deck].phase.active == true else { return false }
        outputRetryAt = nil
        outputRetries = 0
        do { try startOutput(userInitiated: true) } catch {
            recordOutputFailure(error)
            throw error
        }
        return true
    }

    private func receiveOutputEvent(_ event: OutputEvent) {
        #if os(iOS)
            if let device = enabledCaptureDevice,
                !AVAudioSession.sharedInstance().currentRoute.inputs.contains(where: {
                    Self.matchesInput($0, device: device)
                })
            {
                core.setMicrophoneEnabled(false)
                enabledCaptureDevice = nil
            }
            if Self.currentAudioOutputs.first?.automaticSplitOutputName != "S3" {
                core.setPreviewGeneration(0)
            }
            handleOutputEvent(event, outputs: Self.currentAudioOutputs) { try startOutput() }
        #else
            handleOutputEvent(event) { try startOutput() }
        #endif
    }

    #if os(iOS)
        private static var currentAudioOutputs: [AudioOutputDevice] {
            AVAudioSession.sharedInstance().currentRoute.outputs.map {
                .init(name: $0.portName, wired: $0.portType == .usbAudio || $0.portType == .lineOut)
            }
        }

        private func observeAudioSession() {
            guard sessionObservers.isEmpty else { return }
            func observe(_ name: Notification.Name, decode: @escaping @Sendable (Notification) -> OutputEvent?) {
                sessionObservers.append(NotificationCenter.default.addObserver(
                    forName: name, object: nil, queue: nil
                ) { [weak self] notification in
                    guard let event = decode(notification) else { return }
                    Task { @MainActor [weak self] in self?.receiveOutputEvent(event) }
                })
            }
            observe(AVAudioSession.interruptionNotification) { notification in
                guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                    let type = AVAudioSession.InterruptionType(rawValue: value) else { return nil }
                switch type {
                case .began: return .interruptionBegan
                case .ended:
                    let value = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    return .interruptionEnded(shouldResume: AVAudioSession.InterruptionOptions(rawValue: value).contains(.shouldResume))
                @unknown default: return nil
                }
            }
            observe(AVAudioSession.routeChangeNotification) { notification in
                let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                guard value != AVAudioSession.RouteChangeReason.categoryChange.rawValue,
                    value != AVAudioSession.RouteChangeReason.override.rawValue else { return nil }
                return .routeChanged(disconnected: value == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue)
            }
            observe(AVAudioSession.mediaServicesWereLostNotification) { _ in .mediaServicesLost }
            observe(AVAudioSession.mediaServicesWereResetNotification) { _ in .mediaServicesReset }
        }
    #endif

    func installPad(_ asset: PCMAsset?, slot: Int) throws -> UInt64 {
        let generation = try core.setPadAsset(asset, slot: slot)
        if !outputActive { core.processControlsWhileIdle() }
        return generation
    }

    func triggerPad(_ slot: Int, generation: UInt64, enabled: Bool) throws {
        if enabled && !offline { try startOutput() }
        try core.playPad(slot, generation: generation, enabled: enabled)
        if !outputActive { core.processControlsWhileIdle() }
    }

    func setPadGain(_ value: Double) throws {
        try core.setPadGain(value)
        if !outputActive { core.processControlsWhileIdle() }
    }

    #if os(iOS)
        private var requestedCaptureDevice: String?
        private var attachedCaptureDevice: String?
        private var enabledCaptureDevice: String?
        var s2MicEnabled: Bool { enabledCaptureDevice == "S2 Mk3" }
        var s3ExtEnabled: Bool { enabledCaptureDevice == "S3" }

        var canOpenS2Mic: Bool { canOpenCapture(device: "S2 Mk3") }
        func canOpenCapture(device: String) -> Bool {
            attachedCaptureDevice == device
                || (outputStartTask == nil && recorder == nil && recordingStartTask == nil
                    && core.playingPads == 0 && core.previewGeneration == 0
                    && core.snapshot().map { !$0.anyDeckActive } == true)
        }

        func startNativePreviewOutput(device: String) throws {
            guard automaticOutputDevice == device, outputRoute == .masterAndHeadphones else {
                throw TransportError.cache("Connect the \(device) audio output before previewing.")
            }
            try startOutput()
            guard automaticOutputDevice == device, outputRoute == .masterAndHeadphones else {
                throw TransportError.cache("Connect the \(device) audio output before previewing.")
            }
        }

        func setS2MicEnabled(_ enabled: Bool) throws {
            try setCaptureEnabled(enabled, device: "S2 Mk3")
        }

        func setCaptureEnabled(_ enabled: Bool, device: String) throws {
            if !enabled {
                if enabledCaptureDevice == device {
                    core.setMicrophoneEnabled(false)
                    enabledCaptureDevice = nil
                }
                return
            }
            guard !offline, automaticOutputDevice == device, canOpenCapture(device: device),
                AVAudioApplication.shared.recordPermission == .granted
            else {
                throw TransportError.cache("Pause playback before opening the \(device) input.")
            }
            if attachedCaptureDevice != device {
                suspendOutput()
                discardOutputGraph()
                requestedCaptureDevice = device
            }
            do {
                try startOutput()
                guard attachedCaptureDevice == device,
                    AVAudioSession.sharedInstance().currentRoute.inputs.contains(where: {
                        Self.matchesInput($0, device: device)
                    })
                else {
                    throw TransportError.cache("The \(device) input is unavailable on this connection.")
                }
                if device == "S2 Mk3" { core.setExternalInputMix(level: 1, cue: false) }
                core.setMicrophoneEnabled(true)
                enabledCaptureDevice = device
            } catch {
                if !outputActive { discardOutputGraph() }
                throw error
            }
        }

        private static func matchesInput(_ port: AVAudioSessionPortDescription, device: String) -> Bool {
            AudioOutputDevice(name: port.portName, wired: port.portType == .usbAudio || port.portType == .lineIn)
                .automaticSplitOutputName == device
        }
    #endif

    private func startOutput(userInitiated: Bool = false) throws {
        guard !outputActive, outputStartTask == nil else { return }
        guard (!interrupted || userInitiated), !mediaServicesUnavailable, !resumeRequiresPlay else {
            throw TransportError.cache("Audio output is paused.")
        }
        #if os(iOS)
            observeAudioSession()
            let session = AVAudioSession.sharedInstance()
            let captureDevice = requestedCaptureDevice == automaticOutputDevice ? requestedCaptureDevice : nil
            try session.setCategory(captureDevice == nil ? .playback : .playAndRecord, mode: .default)
            try? session.setPrefersNoInterruptionsFromSystemAlerts(true)
            // Routes may refuse preferences. The renderer also supports converted buffers.
            try? session.setPreferredSampleRate(core.sampleRate)
            try? session.setPreferredIOBufferDuration(512 / core.sampleRate)
            try session.setActive(true)
            if userInitiated { interrupted = false }
            let previousRoute = outputRoute
            updateOutputDevice(Self.currentAudioOutputs)
            if outputRecoveryPending, !userInitiated,
                (previousRoute == .masterAndHeadphones && outputRoute != previousRoute ||
                    outputRoute == .stereoMaster && !outputPortIDs.isEmpty &&
                    outputPortIDs.isDisjoint(with: session.currentRoute.outputs.map(\.uid)))
            {
                resumeRequiresPlay = true
                throw TransportError.cache("Press Play to restore audio output.")
            }
            if previousRoute != outputRoute { discardOutputGraph() }
            if let captureDevice {
                guard automaticOutputDevice == captureDevice,
                    let port = session.availableInputs?.first(where: { Self.matchesInput($0, device: captureDevice) })
                else { throw TransportError.cache("The \(captureDevice) does not expose an audio input.") }
                if session.preferredInput?.uid != port.uid { try session.setPreferredInput(port) }
                guard session.currentRoute.inputs.contains(where: { $0.uid == port.uid }),
                    Self.currentAudioOutputs.count == 1,
                    Self.currentAudioOutputs.first?.automaticSplitOutputName == captureDevice
                else {
                    throw TransportError.cache("The \(captureDevice) input is unavailable on this connection.")
                }
            }
            if outputRoute == .masterAndHeadphones {
                guard session.maximumOutputNumberOfChannels >= 4 else {
                    throw TransportError.cache(
                        automaticOutputDevice.map { "The \($0) audio connection does not expose four channels. Reconnect the device." }
                            ?? "Separate headphone monitoring requires a four-channel output device.")
                }
                if session.outputNumberOfChannels != 4 { try session.setPreferredOutputNumberOfChannels(4) }
            }
        #endif
        if engine == nil {
            let engine = AVAudioEngine()
            let channels: AVAudioChannelCount = outputRoute == .masterAndHeadphones ? 4 : 2
            let hardware = engine.outputNode.outputFormat(forBus: 0)
            guard channels == 2 || hardware.channelCount >= 4 else {
                throw TransportError.cache(
                    "Separate headphone monitoring requires a four-channel output device. Master uses 1–2; headphones use 3–4."
                )
            }
            guard let format = AVAudioFormat(standardFormatWithSampleRate: core.sampleRate, channels: channels) else {
                throw TransportError.invalid
            }
            let ownership = core.nativeAudioRenderOwnership(metrics: callbackMetrics)
            guard
                let native = TDJNativeAudioSource(
                    channels: channels, core: ownership.engineHandle, recording: ownership.recordingHandle,
                    metrics: ownership.metricsHandle, traceThreadCPU: ownership.tracesThreadCPU,
                    validationSilence: validationMode, keepAlive: ownership)
            else { throw TransportError.allocation }
            guard let source = native.makeNode(format: format) else { throw TransportError.allocation }
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            if channels == 4 {
                guard let outputFormat = AVAudioFormat(standardFormatWithSampleRate: hardware.sampleRate, channels: 4)
                else { throw TransportError.invalid }
                engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)
            }
            #if os(iOS)
                if let captureDevice {
                    let input = engine.inputNode
                    let format = input.outputFormat(forBus: 0)
                    guard let sink = native.makeMicrophoneSink(format: format, stereo: captureDevice == "S3") else {
                        throw TransportError.cache("The \(captureDevice) input format is unavailable.")
                    }
                    engine.attach(sink)
                    engine.connect(input, to: sink, format: format)
                    attachedCaptureDevice = captureDevice
                }
            #endif
            self.engine = engine
            self.source = source
            self.nativeSource = native
            outputGraphIdentity &+= 1
            let identity = outputGraphIdentity
            engineObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.outputGraphIdentity == identity else { return }
                    self.receiveOutputEvent(.configurationChanged)
                }
            }
        }
        guard let engine, let source else { throw TransportError.allocation }
        let hardware = engine.outputNode.outputFormat(forBus: 0)
        let requiredChannels: AVAudioChannelCount = outputRoute == .masterAndHeadphones ? 4 : 2
        guard hardware.sampleRate.isFinite, hardware.sampleRate > 0, hardware.channelCount >= requiredChannels else {
            throw TransportError.cache("No audio output is available.")
        }
        guard nativeSource?.resume() ?? true else { throw TransportError.protectedDeck }
        engine.prepare()
        try core.configureMaximumOutputFrames(source.auAudioUnit.maximumFramesToRender)
        let state = core.snapshot()
        if state?.anyDeckActive == true {
            outputStartIdentity &+= 1
            let identity = outputStartIdentity
            let core = core
            outputStartTask = Task { [weak self] in
                defer { if self?.outputStartIdentity == identity { self?.outputStartTask = nil } }
                do {
                    while true {
                        try await core.prepareActiveSourcesForOutput()
                        try Task.checkCancellation()
                        guard let self, self.outputStartIdentity == identity else { return }
                        self.collectMessages()
                        let state = core.snapshot()
                        guard state?.anyDeckActive == true || self.recorder != nil
                        else { return }
                        let maximum = source.auAudioUnit.maximumFramesToRender
                        if maximum != core.configuredMaximumOutputFrames {
                            try core.configureMaximumOutputFrames(maximum)
                            continue
                        }
                        guard try core.outputSourcesAreReady() else { continue }
                        try self.startPreparedOutput(engine)
                        return
                    }
                } catch is CancellationError {} catch {
                    guard let self, self.outputStartIdentity == identity else { return }
                    self.recordOutputFailure(error)
                }
            }
        } else {
            try startPreparedOutput(engine)
        }
    }
    private func startPreparedOutput(_ engine: AVAudioEngine) throws {
        #if os(macOS)
            let activity = PlaybackTimingActivity()
        #endif
        outputActive = true
        do {
            try engine.start()
            outputWatchdog.arm(frame: core.renderedOutputFrame)
            outputRecoveryPending = false
            outputRetryAt = nil
            #if os(iOS)
                outputPortIDs = Set(AVAudioSession.sharedInstance().currentRoute.outputs.map(\.uid))
            #endif
            #if os(macOS)
                timingActivity = activity
            #endif
            startControlMaintenance()
        } catch {
            nativeSource?.suspendAndWait()
            outputActive = false
            throw error
        }
    }
}

extension PlaybackController {
    private enum SourceLane: Hashable, Sendable {
        case play(DeckID)
        case tempo
        case freeRate(DeckID)
        case sync(DeckID)
        case keylock(DeckID)
        case grid(DeckID)
        case seek(DeckID)
        case recall(DeckID)
        case performance(DeckID, Int32)
        case touchRelease(DeckID)
        case rollRelease(DeckID)
        init(_ control: SourceControl) {
            switch control {
            case .brake(_, _, let deck, _): self = .performance(deck, 23)
            case .play(let deck, _): self = .play(deck)
            case .tempo: self = .tempo
            case .freeRate(_, let deck, _): self = .freeRate(deck)
            case .sync(_, let deck, _), .restoreSync(let deck, _): self = .sync(deck)
            case .keylock(_, let deck, _): self = .keylock(deck)
            case .grid(_, let deck, _), .adaptiveMap(_, let deck, _): self = .grid(deck)
            case .seek(_, let deck, _): self = .seek(deck)
            case .cueRecall(let deck, _, _, _, _): self = .recall(deck)
            case .performance(let action, let deck, _, _, _, let enabled, _, _, _):
                switch (action, enabled) {
                case (.touch, false): self = .touchRelease(deck)
                case (.loopRoll, false): self = .rollRelease(deck)
                default: self = .performance(deck, action.rawValue)
                }
            }
        }
        var isRelease: Bool {
            switch self {
            case .touchRelease, .rollRelease: true
            default: false
            }
        }
        var retriesWhenFull: Bool {
            switch self {
            case .play, .touchRelease, .rollRelease: return true
            default: return false
            }
        }
        var deck: DeckID? {
            switch self {
            case .tempo: nil
            case .play(let deck), .freeRate(let deck), .sync(let deck), .keylock(let deck), .grid(let deck),
                .seek(let deck), .recall(let deck), .performance(let deck, _), .touchRelease(let deck), .rollRelease(let deck):
                deck
            }
        }
    }
    private struct TrackedSource: Sendable {
        let identity: UInt64
        let control: SourceControl
        let canPrepare: Bool
        var lane: SourceLane { .init(control) }
    }
    public var preparingSourceDecks: Set<DeckID> {
        Set(preparationTasks.keys.flatMap { lane in lane.deck.map { [$0] } ?? Array(generations.keys) })
    }
    public func flushSourcePreparations() async {
        while !preparationTasks.isEmpty || !sentSources.isEmpty || !pendingTransport.isEmpty || outputStartTask != nil {
            if Task.isCancelled { return }
            if !outputActive { core.processControlsWhileIdle() }
            collectMessages()
            flushPendingControls()
            do { try await Task.sleep(for: .milliseconds(5)) } catch { return }
        }
    }
    private func invalidateSource(_ lane: SourceLane) {
        pendingTransport[lane] = nil
        if case .touchRelease(let deck) = lane {
            touchAfterRelease[deck] = nil
        }
        if let identity = latestSources[lane] { preparedGridCommits[identity] = nil }
        latestSources[lane] = nil
        preparationTasks.removeValue(forKey: lane)?.cancel()
        preparationIdentities[lane] = nil
    }
    private func cancelSourcePreparations(deck: DeckID? = nil) {
        for lane in Array(latestSources.keys) where deck == nil || lane.deck == deck { invalidateSource(lane) }
    }
    private func cancelPerformancePreparations(deck: DeckID) {
        for lane in Array(latestSources.keys) {
            guard lane.deck == deck else { continue }
            switch lane {
            case .performance, .recall: invalidateSource(lane)
            default: break
            }
        }
    }
    @discardableResult private func submitSource(_ control: SourceControl, canPrepare: Bool = true) throws -> UInt64 {
        switch control {
        case .tempo, .keylock: break
        case .performance(.touch, let deck, _, _, _, _, _, _, _):
            invalidateRecovery(deck: deck, submitCancellation: false)
        case .play: invalidateRecovery(submitCancellation: false)
        default: invalidateRecovery(deck: control.deck)
        }
        let lane = SourceLane(control)
        invalidateSource(lane)
        nextSourceIdentity &+= 1
        let tracked = TrackedSource(identity: nextSourceIdentity, control: control, canPrepare: canPrepare)
        latestSources[lane] = tracked.identity
        if lane.retriesWhenFull, !pendingTransport.isEmpty {
            pendingTransport[lane] = tracked
            startControlMaintenance()
            return 0
        }
        do { return try submitTrackedSource(tracked) } catch TransportError.queueFull {
            if lane.retriesWhenFull {
                pendingTransport[lane] = tracked
                startControlMaintenance()
                return 0
            }
            latestSources[lane] = nil
            throw TransportError.queueFull
        } catch {
            if latestSources[lane] == tracked.identity { latestSources[lane] = nil }
            throw error
        }
    }
    @discardableResult private func submitTrackedSource(
        _ tracked: TrackedSource, preparations: [SourcePreparation] = []
    ) throws -> UInt64 {
        let identifier = try core.submit(tracked.control, preparations: preparations)
        sentSources[identifier] = tracked
        if let commit = preparedGridCommits.removeValue(forKey: tracked.identity) { gridCommits[identifier] = commit }
        if case .keylock(let enabled, let deck, _) = tracked.control {
            pendingKeylock[identifier] = (deck, enabled)
            latestKeylock[deck] = identifier
        }
        return identifier
    }
    private func handleSourceAcknowledgement(_ message: TransportAcknowledgement) -> Bool {
        guard let tracked = sentSources.removeValue(forKey: message.commandID) else { return false }
        if let commit = gridCommits.removeValue(forKey: message.commandID) {
            if message.error == nil {
                if let state = core.snapshot()?[commit.deck], state.generation == commit.generation,
                    state.grid == commit.grid
                {
                    commit.accepted()
                }
            } else if message.error == .sourceCold, latestSources[tracked.lane] == tracked.identity {
                preparedGridCommits[tracked.identity] = commit
            }
        }
        guard latestSources[tracked.lane] == tracked.identity else {
            if let (deck, _) = pendingKeylock.removeValue(forKey: message.commandID),
                latestKeylock[deck] == message.commandID
            {
                latestKeylock[deck] = nil
            }
            return true
        }
        if message.error == .sourceCold {
            pendingKeylock[message.commandID] = nil
            if tracked.canPrepare { startSourcePreparation(tracked) } else { latestSources[tracked.lane] = nil }
            return true
        }
        if message.error == .stale, case .tempo = tracked.control {
            startSourcePreparation(tracked)
            return true
        }
        latestSources[tracked.lane] = nil
        if message.error == .syncUnavailable, case .rollRelease(let deck) = tracked.lane,
            let generation = tracked.control.generation
        {
            parkRollRelease(deck: deck, generation: generation)
        }
        if case .touchRelease(let deck) = tracked.lane {
            let next = touchAfterRelease.removeValue(forKey: deck)
            if message.error == nil, let next, generations[deck] == next.generation {
                do { try submitSource(next) } catch {
                    appendMessage(.init(commandID: 0, generation: next.generation ?? 0,
                                        error: (error as? TransportError) ?? .invalid))
                }
            }
        }
        return false
    }
    private func parkRollRelease(deck: DeckID, generation: UInt64) {
        guard generations[deck] == generation else { return }
        _ = try? submitSource(
            .performance(.loopRoll, deck, generation, value: -1, end: 0, enabled: false, quantum: 0),
            canPrepare: false)
        if !outputActive { core.processControlsWhileIdle() }
    }
    private func startSourcePreparation(_ tracked: TrackedSource) {
        guard preparationTasks[tracked.lane] == nil else { return }
        sourcePreparationRequests += 1
        let core = core
        preparationIdentities[tracked.lane] = tracked.identity
        preparationTasks[tracked.lane] = Task { [weak self] in
            var preparations: [SourcePreparation] = []
            defer {
                self?.preparedGridCommits[tracked.identity] = nil
                for preparation in preparations { preparation.asset.releaseSourcePreparation(preparation.ticket) }
                if self?.preparationIdentities[tracked.lane] == tracked.identity {
                    self?.preparationTasks[tracked.lane] = nil
                    self?.preparationIdentities[tracked.lane] = nil
                }
            }
            do {
                guard let snapshot = core.snapshot() else { throw TransportError.stale }
                if let deck = tracked.control.deck, snapshot[deck].generation != tracked.control.generation {
                    throw TransportError.stale
                }
                for deck in snapshot.deckIDs where tracked.control.deck == nil || tracked.control.deck == deck {
                    let generation = snapshot[deck].generation
                    guard let asset = core.asset(generation: generation), asset.isStreamed else { continue }
                    let targets = tracked.control.preparationTargets(
                        snapshot: snapshot, deck: deck, frames: asset.frames)
                    guard !targets.isEmpty else { continue }
                    let ticket = try await asset.prepareSources(targets, generation: generation, requireReserve: false)
                    preparations.append(.init(asset: asset, deck: deck, generation: generation, ticket: ticket))
                }
                try Task.checkCancellation()
                guard let self, self.latestSources[tracked.lane] == tracked.identity else { return }
                guard !preparations.isEmpty || tracked.control.deck == nil else { throw TransportError.sourceCold }
                let transferred = preparations
                preparations.removeAll()
                do {
                    try self.submitTrackedSource(tracked, preparations: transferred)
                } catch TransportError.queueFull {
                    guard tracked.lane.retriesWhenFull else { throw TransportError.queueFull }
                    self.pendingTransport[tracked.lane] = tracked
                    self.startControlMaintenance()
                }
                if !self.outputActive {
                    core.processControlsWhileIdle()
                    let state = core.snapshot()
                    if !self.offline, state?.anyDeckActive == true {
                        try self.startOutput()
                    }
                }
            } catch is CancellationError {} catch {
                guard let self, self.latestSources[tracked.lane] == tracked.identity else { return }
                self.invalidateSource(tracked.lane)
                if case .touchRelease(let deck) = tracked.lane,
                    let generation = tracked.control.generation, self.generations[deck] == generation
                {
                    // Clear the hold even when the streaming worker cannot provide the return audio.
                    try? self.submitSource(.parkTouchRelease(deck: deck, generation: generation), canPrepare: false)
                    if !self.outputActive { core.processControlsWhileIdle() }
                }
                if case .rollRelease(let deck) = tracked.lane, let generation = tracked.control.generation {
                    self.parkRollRelease(deck: deck, generation: generation)
                }
                self.sourcePreparationFailures += 1
                if case .keylock(_, let deck, _) = tracked.control {
                    self.latestKeylock[deck] = nil
                    if let enabled = core.snapshot()?[deck].keylock { self.keylockPreference[deck] = enabled }
                }
                let failure = (error as? TransportError) ?? .cache(error.localizedDescription)
                self.appendMessage(.init(commandID: 0, generation: tracked.control.generation ?? 0, error: failure))
            }
        }
    }
}
