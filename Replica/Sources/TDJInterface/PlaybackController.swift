import AVFoundation
import Foundation
import TDJCore
import CTDJAudioSource

public enum AudioOutputRoute: String, CaseIterable, Sendable {
    case stereoMaster, masterAndHeadphones
}

@MainActor
public final class PlaybackController {
    public let core: SampleTransport
    public private(set) var generations: [DeckID: UInt64] = [:]
    // Development startup policy. Original default and persistence remain unmeasured.
    private var keylockPreference: [DeckID: Bool] = [.a: true, .b: true]
    private var pendingKeylock: [UInt64: (DeckID, Bool)] = [:]
    private var latestKeylock: [DeckID: UInt64] = [:]
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
    public func setOutputRoute(_ route: AudioOutputRoute) throws {
        guard recorder == nil, recordingStartTask == nil else { throw TransportError.cache("Stop recording before changing audio routing.") }
        guard route != outputRoute else { return }
        stopAudio()
        engine?.stop()
        observers.forEach { NotificationCenter.default.removeObserver($0) }; observers.removeAll()
        engine = nil; source = nil; nativeSource = nil
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
    private var recordingFinishTask: Task<Void,Never>?
    public private(set) var recordingFinishing = false
    public private(set) var recordingError: String?
    public var isRecording: Bool { recorder != nil && !recordingFinishing }

    public func startRecording(directory: URL, location: String = "") async throws {
        if let recordingStartTask { try await recordingStartTask.value; return }
        guard recorder == nil, !recordingFinishing else { return }
        recordingError = nil
        recordingRegisteredGenerations.removeAll()
        startingRecordingTracks = Dictionary(uniqueKeysWithValues: latestRecordingTracks.values.map { ($0.key, $0) })
        recordingStartShouldStop = false
        let ring = core.recording, sampleRate = core.sampleRate
        let task = Task {
            let prepared = try await Task.detached(priority: .utility) {
                try SetRecorder(directory: directory, sampleRate: sampleRate, buffer: ring, location: location)
            }.value
            await recordingPreparedCheckpoint?()
            self.recorder = prepared
            for metadata in startingRecordingTracks.values { enqueueRecordingTrack(metadata, recorder: prepared) }
            startingRecordingTracks.removeAll()
            do { if !offline && !recordingStartShouldStop { try startOutput() } }
            catch {
                _ = try? await prepared.finish()
                self.recorder = nil
                throw error
            }
        }
        recordingStartTask = task
        defer { recordingStartTask = nil; startingRecordingTracks.removeAll() }
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
        recorder.registerTrack(deck: metadata.deck == .a ? 0 : 1, generation: metadata.generation,
                               artist: metadata.artist, title: metadata.title)
    }
    public func finishRecording() async {
        if let recordingStartTask {
            recordingStartShouldStop = true
            _ = try? await recordingStartTask.value
        }
        if let recordingFinishTask { await recordingFinishTask.value; return }
        guard let recorder else { return }
        recorder.stopCapture()
        recordingFinishing = true
        let task=Task {
            do { _ = try await recorder.finish() }
            catch { recordingError = error.localizedDescription }
            self.recorder = nil
            recordingFinishing = false
            recordingFinishTask=nil
        }
        recordingFinishTask=task
        await task.value
    }
    private var outputStartTask: Task<Void, Never>?
    private var outputStartIdentity: UInt64 = 0
    private var engine: AVAudioEngine?
    private var source: AVAudioSourceNode?
    private var nativeSource: TDJNativeAudioSource?
    private var observers: [NSObjectProtocol] = []
    private enum LoadResult { case waiting, accepted, rejected(TransportError) }
    private let streamingPlayback: Bool
    private var adaptiveResults: [UInt64: LoadResult] = [:]
    private var loadResults: [UInt64: LoadResult] = [:]
    private var loadCommits: [UInt64:(deck: DeckID, accepted: (UInt64) -> Void)] = [:]
    private struct GridCommit {
        let deck: DeckID
        let generation: UInt64
        let grid: BeatGrid
        let accepted: () -> Void
    }
    private var gridCommits: [UInt64:GridCommit] = [:]
    private var preparedGridCommits: [UInt64:GridCommit] = [:]
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

    public init(offline: Bool = false, sampleRate: Double = 48000, validationMode: Bool = false,
                streamingPlayback: Bool? = nil) throws {
        let metrics=validationMode ? try AudioCallbackMetrics(sampleRate:sampleRate,
            traceThreadCPU:ProcessInfo.processInfo.environment["TDJ_DIAGNOSE_AUDIO_CPU"] == "1") : nil
        callbackMetrics=metrics
        core=try SampleTransport(sampleRate:sampleRate,keylockDiagnostics:metrics)
        self.offline = offline
        self.streamingPlayback = streamingPlayback ?? !offline
        self.validationMode = validationMode
    }
    deinit {
        outputStartTask?.cancel()
        for task in preparationTasks.values { task.cancel() }
    }
    enum LoadCheckpoint { case decoded, submitted(UInt64), accepted(UInt64) }
    var loadCheckpoint: ((LoadCheckpoint) async throws -> Void)?

    public func load(track: Track, store: WorkspaceStore, deck: DeckID, sourceURL: URL? = nil,
                     committed: @escaping (UInt64) -> Void = { _ in }) async throws {
        guard core.snapshot()?[deck].phase.active != true else { throw TransportError.protectedDeck }
        cancelSourcePreparations(deck: deck)
        let asset = try await PCMCache.prepareAsync(track: track, store: store, streamed: streamingPlayback,
                                                   outputSampleRate: core.sampleRate,
                                                   maximumOutputFrames: core.configuredMaximumOutputFrames == 0 ? 4096 : core.configuredMaximumOutputFrames, sourceURL: sourceURL)
        try Task.checkCancellation()
        if let loadCheckpoint { try await loadCheckpoint(.decoded) }
        // The output route can change while the decoder is working. A cold LOAD
        // updates the asset's bound; prepare it again before retrying ownership.
        for attempt in 0..<3 {
            do { try await submitLoad(asset: asset, track: track, deck: deck, committed: committed); return }
            catch TransportError.sourceCold where attempt < 2 { try Task.checkCancellation() }
        }
    }
    private func submitLoad(asset: PCMAsset, track: Track, deck: DeckID,
                            committed: @escaping (UInt64) -> Void) async throws {
        guard core.snapshot()?[deck].phase.active != true else { throw TransportError.protectedDeck }
        let keylock = keylockPreference[deck] ?? true
        let generation = try core.reserveLoad(asset, deck: deck, grid: track.grid, keylock: keylock, adaptiveMap: track.adaptiveMap)
        var submitted = false
        var ownedTicket: UInt64 = 0
        defer {
            if ownedTicket != 0 { asset.releaseSourcePreparation(ownedTicket) }
            if !submitted { core.cancelReservedLoad(generation: generation) }
        }
        let ratio = track.grid.map { (core.snapshot()?.masterBPM ?? $0.bpm) / $0.bpm } ?? 1
        let preloadSpeed = keylock ? min(8, max(1, ratio)) : max(1, ratio)
        ownedTicket = try await asset.prepareSource(.init(position: 0, speed: preloadSpeed, keylock: keylock), generation: generation)
        try Task.checkCancellation()
        let ticket = ownedTicket; ownedTicket = 0
        cancelSourcePreparations(deck: deck)
        loadCommits[generation]=(deck,committed)
        do { try core.submitPreparedLoad(generation:generation,preparationTicket:ticket) }
        catch { loadCommits[generation]=nil;throw error }
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
    public func play(_ deck: DeckID) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        let lane = SourceLane.play(deck)
        let pending = latestSources[lane] != nil || latestSources[.recall(deck)] != nil
        let warming = preparationTasks[lane] != nil || preparationTasks[.recall(deck)] != nil
        cancelPerformancePreparations(deck: deck)
        if pending {
            invalidateSource(lane)
            if warming { return }
        }
        if !offline { try startOutput() }
        try submitSource(.play(deck, generation), canPrepare: !pending)
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func recallCue(_ cue: PerformanceCue, deck: DeckID, quantum: Double) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        if !offline { try startOutput() }
        try submitSource(.cueRecall(deck, generation, frame: cue.frame, loopEnd: cue.loopEnd, quantum: quantum))
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func perform(_ action: PerformanceAction, deck: DeckID, value: Double = 0, end: Double = 0, enabled: Bool = true, quantum: Double = 0,
                        touchRate: Double? = nil) throws {
        guard let generation=generations[deck] else { throw TransportError.stale }
        if action == .touch && enabled && !offline { try startOutput() }
        if action == .touch, !enabled {
            invalidateSource(.performance(deck, PerformanceAction.touch.rawValue))
            invalidateSource(.performance(deck, PerformanceAction.rate.rawValue))
        }
        try submitSource(.performance(action, deck, generation, value:value, end:end,
            enabled:enabled, quantum:quantum, touchRate:touchRate))
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func setEffect(_ kind: Int, slot: Int, x: Double, y: Double, enabled: Bool, deck: DeckID, synced: Bool = true) throws {
        try core.setEffect(kind,slot:slot,x:x,y:y,enabled:enabled,deck:deck,synced:synced)
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func setMixer(_ parameter: MixerParameter, value: Double, deck: DeckID = .a) throws {
        try core.setMixer(parameter, value: value, deck: deck)
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func setFreeRate(_ rate: Double, deck: DeckID) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        try core.setFreeRate(rate, deck: deck, generation: generation)
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
        guard let generation=generations[deck] else { throw TransportError.stale }
        try submitSource(.restoreSync(deck,generation))
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func setKeylock(_ enabled: Bool, deck: DeckID) throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        guard core.snapshot()?[deck].phase != .queued else { throw TransportError.unresolved }
        try submitSource(.keylock(enabled, deck, generation))
        keylockPreference[deck] = enabled
        if !outputActive { core.processControlsWhileIdle() }
    }
    public func requestedKeylock(_ deck: DeckID) -> Bool { keylockPreference[deck] ?? true }
    public func warmCuePositions(_ cues: [PerformanceCue], deck: DeckID) {
        guard let generation = generations[deck], let asset = core.asset(generation: generation), asset.isStreamed else { return }
        let targets = cues.prefix(8).flatMap { cue -> [PCMSourceTarget] in
            guard cue.frame.isFinite, cue.frame >= 0, cue.frame < Double(asset.frames) else { return [] }
            let start = cue.loopEnd == nil ? 0 : cue.frame, end = cue.loopEnd ?? 0
            return [
                .init(position: cue.frame, speed: 8, loopStart: start, loopEnd: end, keylock: true),
                .init(position: cue.frame, speed: 8, performanceRate: -1, loopStart: start, loopEnd: end)
            ]
        }
        if targets.isEmpty { core.setOptionalWarming(generation: generation, preparation: nil); return }
        guard let ticket = try? asset.requestOptionalWarming(targets, generation: generation), ticket != 0 else { return }
        core.setOptionalWarming(generation: generation,
            preparation: .init(asset: asset, deck: deck, generation: generation, ticket: ticket))
    }
    public func updateAdaptiveMap(_ map: BeatGridMap?, deck: DeckID) async throws {
        guard let generation = generations[deck] else { throw TransportError.stale }
        if let map, let asset=core.asset(generation:generation) {
            try map.validate(frameCount:Int64(asset.frames))
            guard map.sampleRate==asset.sampleRate else { throw TransportError.invalid }
        }
        let identifier = try submitSource(.adaptiveMap(map, deck, generation), canPrepare: false)
        adaptiveResults[identifier] = .waiting
        defer { adaptiveResults[identifier] = nil }
        for _ in 0..<200 {
            if !outputActive { core.processControlsWhileIdle() }
            collectMessages()
            switch adaptiveResults[identifier] {
            case .accepted:
                guard generations[deck]==generation, let state=core.snapshot()?[deck],
                      state.generation==generation, state.adaptiveMap==map else { throw TransportError.stale }
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
        guard generations[deck] == generation, core.snapshot()?[deck].generation == generation else { throw TransportError.stale }
        let identifier = try submitSource(.grid(grid,deck,generation))
        gridCommits[identifier] = .init(deck:deck,generation:generation,grid:grid,accepted:accepted)
        if !outputActive {
            core.processControlsWhileIdle()
            collectMessages()
        }
    }
    public func stopAudio() {
        controlMaintenanceTimer = nil
        outputStartIdentity &+= 1
        outputStartTask?.cancel(); outputStartTask = nil
        cancelSourcePreparations()
        if recordingStartTask != nil { recordingStartShouldStop = true }
        nativeSource?.suspendAndWait()
        engine?.pause()
#if os(macOS)
        timingActivity = nil
#endif
        outputActive = false
        if recorder != nil || recordingStartTask != nil { Task { await finishRecording() } }
        // Make room for Stop even after a burst fills the command/message rings.
        // Device output is paused before the control thread becomes the consumer.
        collectMessages()
        core.processControlsWhileIdle()
        collectMessages()
        try? core.stopAll()
        core.processControlsWhileIdle()
    }
    public func snapshotAndMessages() -> (PlaybackSnapshot?, [TransportAcknowledgement]) {
        maintainControlState()
        let result = messages; messages.removeAll(keepingCapacity: true)
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
            if let success = messages.firstIndex(where: { $0.error == nil }) { messages.remove(at: success) }
            else { messages.removeFirst() }
        }
        messages.append(message)
    }
    private func collectMessages() {
        for message in core.acknowledgements() {
            if adaptiveResults[message.commandID] != nil {
                adaptiveResults[message.commandID] = message.error.map { .rejected($0) } ?? .accepted
            }
            if handleSourceAcknowledgement(message) { continue }
            if message.error != nil { rejectedCommandCount += 1 }
            if let (deck, enabled) = pendingKeylock.removeValue(forKey: message.commandID), latestKeylock[deck] == message.commandID {
                keylockPreference[deck] = message.error == nil ? enabled : core.snapshot()?[deck].keylock ?? enabled
                latestKeylock[deck] = nil
            }
            if let load=loadCommits.removeValue(forKey:message.generation), message.error == nil {
                generations[load.deck]=message.generation
                load.accepted(message.generation)
            }
            if loadResults[message.generation] != nil {
                loadResults[message.generation] = message.error.map { .rejected($0) } ?? .accepted
            }
            appendMessage(message)
        }
    }
    private func startOutput() throws {
        guard !outputActive, outputStartTask == nil else { return }
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        // Routes may refuse preferences. The renderer also supports converted buffers.
        try? session.setPreferredSampleRate(core.sampleRate)
        try? session.setPreferredIOBufferDuration(512 / core.sampleRate)
        try session.setActive(true)
        if outputRoute == .masterAndHeadphones {
            guard session.maximumOutputNumberOfChannels >= 4 else {
                throw TransportError.cache("Separate headphone monitoring requires a four-channel output device.")
            }
            try session.setPreferredOutputNumberOfChannels(4)
        }
#endif
        if engine == nil {
            let engine = AVAudioEngine()
            let channels: AVAudioChannelCount = outputRoute == .masterAndHeadphones ? 4 : 2
            let hardware = engine.outputNode.outputFormat(forBus: 0)
            guard channels == 2 || hardware.channelCount >= 4 else {
                throw TransportError.cache("Separate headphone monitoring requires a four-channel output device. Master uses 1–2; headphones use 3–4.")
            }
            guard let format = AVAudioFormat(standardFormatWithSampleRate: core.sampleRate, channels: channels) else {
                throw TransportError.invalid
            }
            let ownership = core.nativeAudioRenderOwnership(metrics: callbackMetrics)
            guard let native = TDJNativeAudioSource(channels: channels,
                core: ownership.engineHandle, recording: ownership.recordingHandle,
                metrics: ownership.metricsHandle, traceThreadCPU: ownership.tracesThreadCPU,
                validationSilence: validationMode, keepAlive: ownership) else {
                throw TransportError.allocation
            }
            guard let source = native.makeNode(format: format) else { throw TransportError.allocation }
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            if channels == 4 {
                guard let outputFormat = AVAudioFormat(standardFormatWithSampleRate: hardware.sampleRate, channels: 4) else { throw TransportError.invalid }
                engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)
            }
            self.engine = engine; self.source = source; self.nativeSource = native
            let token = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
                object: engine, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.stopAudio() }
                }
            observers.append(token)
#if os(iOS)
            observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.stopAudio() }
                })
#endif
        }
        guard let engine, let source else { throw TransportError.allocation }
        let hardware=engine.outputNode.outputFormat(forBus:0)
        guard hardware.sampleRate.isFinite, hardware.sampleRate>0, hardware.channelCount>0 else {
            throw TransportError.cache("No audio output is available.")
        }
        guard nativeSource?.resume() ?? true else { throw TransportError.protectedDeck }
        engine.prepare()
        try core.configureMaximumOutputFrames(source.auAudioUnit.maximumFramesToRender)
        let state = core.snapshot()
        if state?.a.phase.active == true || state?.b.phase.active == true {
            outputStartIdentity &+= 1
            let identity = outputStartIdentity, core = core
            outputStartTask = Task { [weak self] in
                defer { if self?.outputStartIdentity == identity { self?.outputStartTask = nil } }
                do {
                    while true {
                        try await core.prepareActiveSourcesForOutput()
                        try Task.checkCancellation()
                        guard let self, self.outputStartIdentity == identity else { return }
                        self.collectMessages()
                        let state = core.snapshot()
                        guard state?.a.phase.active == true || state?.b.phase.active == true || self.recorder != nil else { return }
                        let maximum = source.auAudioUnit.maximumFramesToRender
                        if maximum != core.configuredMaximumOutputFrames {
                            try core.configureMaximumOutputFrames(maximum)
                            continue
                        }
                        guard try core.outputSourcesAreReady() else { continue }
                        try self.startPreparedOutput(engine)
                        return
                    }
                } catch is CancellationError { }
                catch {
                    self?.appendMessage(.init(commandID: 0, generation: 0,
                        error: (error as? TransportError) ?? .cache(error.localizedDescription)))
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
        case play(DeckID), tempo, sync(DeckID), keylock(DeckID), grid(DeckID), seek(DeckID), recall(DeckID)
        case performance(DeckID, Int32)
        init(_ control: SourceControl) {
            switch control {
            case .play(let deck, _): self = .play(deck)
            case .tempo: self = .tempo
            case .sync(_, let deck, _), .restoreSync(let deck, _): self = .sync(deck)
            case .keylock(_, let deck, _): self = .keylock(deck)
            case .grid(_, let deck, _), .adaptiveMap(_, let deck, _): self = .grid(deck)
            case .seek(_, let deck, _): self = .seek(deck)
            case .cueRecall(let deck, _, _, _, _): self = .recall(deck)
            case .performance(let action, let deck, _, _, _, _, _, _): self = .performance(deck, action.rawValue)
            }
        }
        var deck: DeckID? {
            switch self {
            case .tempo: nil
            case .play(let deck), .sync(let deck), .keylock(let deck), .grid(let deck), .seek(let deck),
                 .recall(let deck), .performance(let deck, _): deck
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
        while !preparationTasks.isEmpty || !sentSources.isEmpty || outputStartTask != nil {
            if Task.isCancelled { return }
            if !outputActive { core.processControlsWhileIdle() }
            collectMessages()
            do { try await Task.sleep(for: .milliseconds(5)) } catch { return }
        }
    }
    private func invalidateSource(_ lane: SourceLane) {
        if let identity = latestSources[lane] { preparedGridCommits[identity] = nil }
        latestSources[lane] = nil
        preparationTasks.removeValue(forKey: lane)?.cancel()
        preparationIdentities[lane] = nil
    }
    private func cancelSourcePreparations(deck: DeckID? = nil) {
        for lane in Array(latestSources.keys) where deck == nil || lane.deck == deck {
            invalidateSource(lane)
        }
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
        let lane = SourceLane(control)
        invalidateSource(lane)
        nextSourceIdentity &+= 1
        let tracked = TrackedSource(identity: nextSourceIdentity, control: control, canPrepare: canPrepare)
        latestSources[lane] = tracked.identity
        do { return try submitTrackedSource(tracked) }
        catch { if latestSources[lane] == tracked.identity { latestSources[lane] = nil }; throw error }
    }
    @discardableResult private func submitTrackedSource(_ tracked: TrackedSource, preparations: [SourcePreparation] = []) throws -> UInt64 {
        let identifier = try core.submit(tracked.control, preparations: preparations)
        sentSources[identifier] = tracked
        if let commit = preparedGridCommits.removeValue(forKey:tracked.identity) { gridCommits[identifier] = commit }
        if case .keylock(let enabled, let deck, _) = tracked.control {
            pendingKeylock[identifier] = (deck, enabled); latestKeylock[deck] = identifier
        }
        return identifier
    }
    private func handleSourceAcknowledgement(_ message: TransportAcknowledgement) -> Bool {
        guard let tracked = sentSources.removeValue(forKey: message.commandID) else { return false }
        if let commit = gridCommits.removeValue(forKey:message.commandID) {
            if message.error == nil {
                if let state = core.snapshot()?[commit.deck], state.generation == commit.generation, state.grid == commit.grid {
                    commit.accepted()
                }
            } else if message.error == .sourceCold, latestSources[tracked.lane] == tracked.identity {
                preparedGridCommits[tracked.identity] = commit
            }
        }
        guard latestSources[tracked.lane] == tracked.identity else {
            if let (deck, _) = pendingKeylock.removeValue(forKey: message.commandID), latestKeylock[deck] == message.commandID {
                latestKeylock[deck] = nil
            }
            return true
        }
        if message.error == .sourceCold {
            pendingKeylock[message.commandID] = nil
            if tracked.canPrepare { startSourcePreparation(tracked) }
            else { latestSources[tracked.lane] = nil }
            return true
        }
        if message.error == .stale, case .tempo = tracked.control {
            startSourcePreparation(tracked)
            return true
        }
        latestSources[tracked.lane] = nil
        return false
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
                if let deck = tracked.control.deck, snapshot[deck].generation != tracked.control.generation { throw TransportError.stale }
                for deck in DeckID.allCases where tracked.control.deck == nil || tracked.control.deck == deck {
                    let generation = snapshot[deck].generation
                    guard let asset = core.asset(generation: generation), asset.isStreamed else { continue }
                    let targets = tracked.control.preparationTargets(snapshot: snapshot, deck: deck, frames: asset.frames)
                    guard !targets.isEmpty else { continue }
                    let ticket = try await asset.prepareSources(targets, generation: generation, requireReserve: false)
                    preparations.append(.init(asset: asset, deck: deck, generation: generation, ticket: ticket))
                }
                try Task.checkCancellation()
                guard let self, self.latestSources[tracked.lane] == tracked.identity else { return }
                guard !preparations.isEmpty || tracked.control.deck == nil else { throw TransportError.sourceCold }
                let transferred = preparations; preparations.removeAll()
                try self.submitTrackedSource(tracked, preparations: transferred)
                if !self.outputActive {
                    core.processControlsWhileIdle()
                    let state = core.snapshot()
                    if !self.offline, state?.a.phase.active == true || state?.b.phase.active == true {
                        try self.startOutput()
                    }
                }
            } catch is CancellationError { }
            catch {
                guard let self, self.latestSources[tracked.lane] == tracked.identity else { return }
                self.latestSources[tracked.lane] = nil
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
