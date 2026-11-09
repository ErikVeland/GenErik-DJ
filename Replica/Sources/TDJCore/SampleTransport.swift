import CTDJTransport
import Darwin
import Foundation

public enum TransportError: Error, LocalizedError, Equatable {
    case allocation, queueFull, stale, unresolved, protectedDeck, invalid, keylockRate, sourceCold, playbackCapacity,
        syncUnavailable, activePerformance, nativeSourceChanged
    case cache(String)
    public var errorDescription: String? {
        switch self {
        case .allocation: "The audio renderer could not allocate its state."
        case .queueFull: "The audio command queue is full."
        case .stale: "The deck changed before this action was accepted."
        case .unresolved: "This action is unavailable while the deck is waiting to start or playing."
        case .protectedDeck: "Pause this deck before replacing its track in the development build."
        case .invalid: "The transport action has invalid musical or audio data."
        case .keylockRate:
            "Keylock supports speed ratios from 0.125 to 8 in this build. Reduce the tempo change or disable Keylock."
        case .sourceCold: "This audio position is still being prepared. Current playback continues."
        case .playbackCapacity: "These playback settings exceed the available audio memory."
        case .syncUnavailable: "This section has no matching beat position."
        case .activePerformance: "Finish braking or release the waveform before this action."
        case .nativeSourceChanged: "The Music file changed during preparation. Load the song again to refresh it."
        case .cache(let message): "Cannot prepare playback: \(message)"
        }
    }
}

/// Immutable PCM storage. Retained by the producer until the render thread retires its generation.
public final class PCMAsset: @unchecked Sendable {
    let pointer: OpaquePointer
    var streamingWorker: PCMStreamWorker?
    var nextSourceRequest: UInt64 = 0
    var accountedStreamingTelemetry = tdj_stream_telemetry()
    public let frames: UInt64
    public let sampleRate: Double
    public init(interleavedStereo: [Float], sampleRate: Double) throws {
        guard !interleavedStereo.isEmpty, interleavedStereo.count.isMultiple(of: 2),
            interleavedStereo.allSatisfy(\.isFinite),
            let pointer = interleavedStereo.withUnsafeBufferPointer({
                tdj_asset_create($0.baseAddress, UInt64($0.count / 2), sampleRate)
            })
        else { throw TransportError.allocation }
        self.pointer = pointer
        frames = UInt64(interleavedStereo.count / 2)
        self.sampleRate = sampleRate
    }
    public init(mappedFile: URL, frames: UInt64, sampleRate: Double) throws {
        guard let pointer = mappedFile.path.withCString({ tdj_asset_map($0, frames, sampleRate) }) else {
            throw TransportError.cache("Invalid or incomplete PCM cache.")
        }
        self.pointer = pointer
        self.frames = frames
        self.sampleRate = sampleRate
    }
    public init(
        streamedFile: URL, frames: UInt64, sampleRate: Double, outputSampleRate: Double = 48000,
        maximumOutputFrames: UInt32 = 4096
    ) throws {
        var configuration = tdj_stream_config()
        configuration.output_rate = outputSampleRate
        configuration.forward_seconds = 2
        configuration.backward_seconds = 1
        configuration.max_output_frames = maximumOutputFrames
        var status = Int32(TDJ_STREAM_INVALID.rawValue)
        guard
            let pointer = streamedFile.path.withCString({
                tdj_asset_open_stream($0, frames, sampleRate, &configuration, &status)
            })
        else {
            try PCMStreamingError.check(status)
            throw TransportError.allocation
        }
        self.pointer = pointer
        self.frames = frames
        self.sampleRate = sampleRate
        streamingWorker = PCMStreamWorker(pointer: pointer)
    }
    init(streamPointer: OpaquePointer, frames: UInt64, sampleRate: Double) {
        pointer = streamPointer
        self.frames = frames
        self.sampleRate = sampleRate
        streamingWorker = PCMStreamWorker(pointer: streamPointer)
    }
    deinit { if let streamingWorker { streamingWorker.dispose() } else { PCMAssetDisposal.enqueue(pointer) } }
}

private final class PCMAssetDisposal: @unchecked Sendable {
    private static let queue = DispatchQueue(label: "org.generikdj.pcm-disposal", qos: .utility)
    private let pointer: OpaquePointer
    private init(_ pointer: OpaquePointer) { self.pointer = pointer }
    static func enqueue(_ pointer: OpaquePointer) {
        let ownership = PCMAssetDisposal(pointer)
        queue.async(qos: .utility, flags: .enforceQoS) { tdj_asset_destroy(ownership.pointer) }
    }
}

public enum PlaybackPhase: Int32, Codable, Sendable {
    case empty = 0
    case ready, queued, playing, paused, ended
    public var active: Bool { self == .playing || self == .queued }
}

public enum MixerParameter: Int32, Sendable {
    case crossfader = 0
    case master, monitor, cueBlend, volume, gain, low, mid, high, cue, filterX, filterY, filterEnabled
}

public struct DeckMixerSnapshot: Codable, Equatable, Sendable {
    public let volume: Double
    public let gain: Double
    public let low: Double
    public let mid: Double
    public let high: Double
    public let cue: Bool
    public let filterX: Double
    public let filterY: Double
    public let filterEnabled: Bool
    public let peak: Double
    fileprivate init(_ value: tdj_deck_snapshot) {
        volume = value.volume
        gain = value.gain
        low = value.low
        mid = value.mid
        high = value.high
        cue = value.cue != 0
        filterX = value.filter_x
        filterY = value.filter_y
        filterEnabled = value.filter_enabled != 0
        peak = value.peak
    }
}

public enum PerformanceAction: Int32, Sendable {
    case jump = 10
    case loop, flux, touch, rate
    case loopRoll = 27
}

public struct DeckPlaybackSnapshot: Codable, Equatable, Sendable {
    public let recoveryArmed: Bool
    public let recoveryActive: Bool
    public let recoveryMix: Bool
    public let recoveryStart: Double
    public let recoveryEnd: Double
    public let recoveryMixStart: Double
    public let braking: Bool
    public let brakeRate: Double
    public let loopEnabled: Bool
    private let rolling: Bool?
    public var loopRolling: Bool { rolling == true }
    public let fluxEnabled: Bool
    public let touchActive: Bool
    public let jumpPending: Bool
    public let loopStart: Double
    public let loopEnd: Double
    public let continuingFrame: Double
    public let performanceRate: Double
    public let freeRate: Double
    public let touchStart: Double
    public let touchEnd: Double
    public let touchWasPlaying: Bool
    public let pendingJumpFrame: Double
    public let pendingJumpBeat: Double
    public let pendingTouchEnd: Double
    public let pendingLoopEnd: Double
    public let pendingJumpIsLoop: Bool
    public let pendingTouchRate: Double
    public let pendingTouchRateValid: Bool
    public let generation: UInt64
    public let mixer: DeckMixerSnapshot
    public let phase: PlaybackPhase
    public let synced: Bool
    public let keylock: Bool
    public let sourceFrame: Double
    public let sourceBPM: Double
    public let grid: BeatGrid?
    public let adaptiveMap: BeatGridMap?
    public var timing: BeatTiming? { grid.map { BeatTiming(fixed: $0, adaptive: adaptiveMap) } }
    public let speed: Double
    public let targetBeat: Double?
    public let leadInSourceFrame: Double?
    public let lastStartOutputFrame: UInt64
    fileprivate init(_ value: tdj_deck_snapshot) {
        recoveryArmed = value.recovery_armed != 0
        recoveryActive = value.recovery_active != 0
        recoveryMix = value.recovery_mix != 0
        recoveryStart = value.recovery_start
        recoveryEnd = value.recovery_end
        recoveryMixStart = value.recovery_mix_start
        braking = value.braking != 0
        brakeRate = value.brake_rate
        loopEnabled = value.loop_enabled != 0
        rolling = value.loop_rolling != 0
        fluxEnabled = value.flux_enabled != 0
        touchActive = value.touch_active != 0
        jumpPending = value.jump_pending != 0
        loopStart = value.loop_start
        loopEnd = value.loop_end
        continuingFrame = value.continuing_frame
        performanceRate = value.performance_rate
        freeRate = value.free_rate
        touchStart = value.touch_start
        touchEnd = value.touch_end
        touchWasPlaying = value.touch_was_playing != 0
        pendingJumpFrame = value.jump_frame
        pendingJumpBeat = value.jump_beat
        pendingTouchEnd = value.pending_touch_end
        pendingLoopEnd = value.pending_loop_end
        pendingJumpIsLoop = value.jump_loop != 0
        pendingTouchRate = value.pending_touch_rate
        pendingTouchRateValid = value.pending_touch_rate_valid != 0
        mixer = .init(value)
        generation = value.generation
        phase = PlaybackPhase(rawValue: value.state) ?? .empty
        synced = value.synced != 0
        keylock = value.keylock != 0
        adaptiveMap = BeatGridMap(native: value.beatgrid)
        grid = try? BeatGrid(
            bpm: value.source_bpm, anchorFrame: value.grid_anchor, sampleRate: value.source_sample_rate,
            downbeatOffset: Int(value.grid_downbeat))
        sourceFrame = value.source_frame
        sourceBPM = value.local_bpm
        speed = value.source_rate
        targetBeat = phase == .queued ? value.target_beat : nil
        leadInSourceFrame = phase == .queued ? value.lead_in_source_frame : nil
        lastStartOutputFrame = value.last_start_frame
    }
}

public struct PlaybackSnapshot: Codable, Equatable, Sendable {
    public let pairedFrames: UInt64
    public let outputFrame: UInt64
    public let sampleRate: Double
    public let masterBPM: Double
    public let masterBeat: Double
    public let crossfader: Double
    public let masterGain: Double
    public let monitorGain: Double
    public let cueBlend: Double
    public let clockRunning: Bool
    public let a: DeckPlaybackSnapshot
    public let b: DeckPlaybackSnapshot
    public subscript(_ deck: DeckID) -> DeckPlaybackSnapshot { deck == .a ? a : b }
    fileprivate init(_ value: tdj_snapshot) {
        pairedFrames = value.paired_frames
        crossfader = value.crossfader
        masterGain = value.master_gain
        monitorGain = value.monitor_gain
        cueBlend = value.cue_blend
        outputFrame = value.output_frame
        sampleRate = value.sample_rate
        masterBPM = value.master_bpm
        masterBeat = value.master_beat
        clockRunning = value.clock_running != 0
        a = .init(value.a)
        b = .init(value.b)
    }
}

public struct TransportAcknowledgement: Sendable {
    public let commandID: UInt64
    public let generation: UInt64
    public let error: TransportError?
    public init(commandID: UInt64, generation: UInt64, error: TransportError?) {
        self.commandID = commandID
        self.generation = generation
        self.error = error
    }
}

/// One serial control producer and one render consumer. The callback touches only the C engine.
/// Unknown pending-action policies return an explicit error rather than selecting cancellation.
public struct NativeControlSubmissionTiming: Sendable {
    public let commandID: UInt64
    public let began: ContinuousClock.Instant
    public let beganMachTicks: UInt64
    public let acceptedMachTicks: UInt64
}

public final class SampleTransport: @unchecked Sendable {
    private let pointer: OpaquePointer
    private let keylockDiagnostics: AudioCallbackMetrics?
    public let recording: RecordingBuffer
    private var capturingFirstSubmission = false
    private var firstSubmission: NativeControlSubmissionTiming?
    private var nextCommand: UInt64 = 0
    private var nextGeneration: UInt64 = 0
    private var assets: [UInt64: PCMAsset] = [:]
    private var reservedLoads: [UInt64: tdj_command] = [:]
    private var pendingPreparations: [UInt64: [SourcePreparation]] = [:]
    private var optionalWarmings: [UInt64: SourcePreparation] = [:]
    private var retiredStreaming = PCMStreamingSummary()
    public let sampleRate: Double
    public private(set) var configuredMaximumOutputFrames: UInt32 = 0
    public init(sampleRate: Double = 48000, outputGain: Double = 0.5, keylockDiagnostics: AudioCallbackMetrics? = nil)
        throws
    {
        self.keylockDiagnostics = keylockDiagnostics?.tracesThreadCPU == true ? keylockDiagnostics : nil
        recording = try RecordingBuffer(capacity: 480_000)
        let engine: OpaquePointer?
        if let diagnostics = self.keylockDiagnostics {
            engine = tdj_engine_create_keylock_traced(sampleRate, outputGain, diagnostics.pointer)
        } else {
            engine = tdj_engine_create(sampleRate, outputGain)
        }
        guard let pointer = engine else { throw TransportError.allocation }
        self.pointer = pointer
        self.sampleRate = sampleRate
    }
    deinit {
        tdj_engine_destroy(pointer)
        for preparations in pendingPreparations.values { Self.release(preparations) }
        for preparation in optionalWarmings.values { preparation.asset.releaseSourcePreparation(preparation.ticket) }
    }

    @discardableResult public func load(
        _ asset: PCMAsset, deck: DeckID, grid: BeatGrid?, sourceFrame: Double = 0, synced: Bool = true,
        keylock: Bool = false, adaptiveMap: BeatGridMap? = nil
    ) throws -> UInt64 {
        let generation = try reserveLoad(
            asset, deck: deck, grid: grid, sourceFrame: sourceFrame, synced: synced, keylock: keylock,
            adaptiveMap: adaptiveMap)
        try submitPreparedLoad(generation: generation)
        return generation
    }
    public func reserveLoad(
        _ asset: PCMAsset, deck: DeckID, grid: BeatGrid?, sourceFrame: Double = 0, synced: Bool = true,
        keylock: Bool = false, adaptiveMap: BeatGridMap? = nil, resetMasterTempoWhenIdle: Bool = false
    ) throws -> UInt64 {
        if let adaptiveMap { try adaptiveMap.validate(frameCount: Int64(asset.frames)) }
        guard adaptiveMap.map({ $0.sampleRate == asset.sampleRate }) ?? true else { throw TransportError.invalid }
        guard grid.map({ $0.sampleRate == asset.sampleRate }) ?? true else { throw TransportError.invalid }
        nextGeneration += 1
        let generation = nextGeneration
        assets[generation] = asset
        var command = tdj_command()
        command.kind = TDJ_LOAD
        command.deck = index(deck)
        command.generation = generation
        command.flag = (synced ? 1 : 0) | (keylock ? 8 : 0) | Int32((grid?.downbeatOffset ?? 0) << 1)
        if resetMasterTempoWhenIdle { command.flag |= TDJ_LOAD_RESET_IDLE_TEMPO }
        command.value = sourceFrame
        if let adaptiveMap { command.beatgrid = adaptiveMap.native }
        command.value2 = grid?.bpm ?? 0
        command.value3 = grid?.anchorFrame ?? 0
        command.asset = asset.pointer
        reservedLoads[generation] = command
        return generation
    }
    public func cancelReservedLoad(generation: UInt64) {
        guard reservedLoads.removeValue(forKey: generation) != nil else { return }
        assets[generation] = nil
    }
    public func submitPreparedLoad(generation: UInt64, preparationTicket: UInt64 = 0) throws {
        guard var command = reservedLoads.removeValue(forKey: generation) else { throw TransportError.stale }
        command.preparation_ticket = preparationTicket
        let preparations =
            preparationTicket == 0
            ? []
            : assets[generation].map {
                [
                    SourcePreparation(
                        asset: $0, deck: command.deck == 0 ? .a : .b, generation: generation, ticket: preparationTicket)
                ]
            } ?? []
        do { try send(command, preparations: preparations) } catch {
            assets[generation] = nil
            throw error
        }
    }
    public func asset(generation: UInt64) -> PCMAsset? { assets[generation] }
    public func setOptionalWarming(generation: UInt64, preparation: SourcePreparation?) {
        if let previous = optionalWarmings.removeValue(forKey: generation) {
            previous.asset.releaseSourcePreparation(previous.ticket)
        }
        guard let preparation else { return }
        guard preparation.generation == generation, assets[generation] === preparation.asset, preparation.ticket != 0
        else {
            preparation.asset.releaseSourcePreparation(preparation.ticket)
            return
        }
        optionalWarmings[generation] = preparation
    }
    public func streamingSummary() -> PCMStreamingSummary {
        var result = retiredStreaming
        var seen = Set<ObjectIdentifier>()
        for asset in assets.values where seen.insert(ObjectIdentifier(asset)).inserted {
            result.include(asset, active: true)
        }
        result.refreshGlobalReservation()
        return result
    }
    @discardableResult public func submit(_ control: SourceControl, preparations: [SourcePreparation] = []) throws
        -> UInt64
    {
        var command = control.command
        var decks = Set<DeckID>()
        for preparation in preparations {
            guard preparation.ticket != 0, assets[preparation.generation] === preparation.asset,
                decks.insert(preparation.deck).inserted,
                command.kind == TDJ_TEMPO
                    || (command.deck == index(preparation.deck) && command.generation == preparation.generation)
            else {
                Self.release(preparations)
                throw TransportError.stale
            }
            if command.kind == TDJ_TEMPO, preparation.deck == .b {
                command.preparation_ticket_b = preparation.ticket
                command.preparation_generation_b = preparation.generation
            } else {
                command.preparation_ticket = preparation.ticket
                command.generation = preparation.generation
            }
        }
        return try send(command, preparations: preparations)
    }
    @discardableResult public func play(deck: DeckID, generation: UInt64) throws -> UInt64 {
        var command = tdj_command()
        command.kind = TDJ_PLAY
        command.deck = index(deck)
        command.generation = generation
        return try send(command)
    }
    @discardableResult public func eject(deck: DeckID, generation: UInt64) throws -> UInt64 {
        var command = tdj_command()
        command.kind = TDJ_EJECT
        command.deck = index(deck)
        command.generation = generation
        return try send(command)
    }
    public func setGridMetronome(offset: Double?, deck: DeckID, generation: UInt64) throws {
        var command = tdj_command()
        command.kind = TDJ_GRID_METRONOME
        command.deck = index(deck)
        command.generation = generation
        command.flag = offset == nil ? 0 : 1
        command.value = offset ?? 0
        try send(command)
    }
    public func setMasterBPM(_ bpm: Double) throws {
        var command = tdj_command()
        command.kind = TDJ_TEMPO
        command.value = bpm
        try send(command)
    }
    /// Speed ratio for an unsynced deck, from 0.5 to 1.5. Synced decks follow the master tempo.
    public func setFreeRate(_ rate: Double, deck: DeckID, generation: UInt64) throws {
        var command = tdj_command()
        command.kind = TDJ_FREE_RATE
        command.deck = index(deck)
        command.value = rate
        command.generation = generation
        try send(command)
    }
    public func setSync(_ enabled: Bool, deck: DeckID, generation: UInt64) throws {
        var command = tdj_command()
        command.kind = TDJ_SYNC
        command.deck = index(deck)
        command.generation = generation
        command.flag = enabled ? 1 : 0
        try send(command)
    }
    @discardableResult public func setKeylock(_ enabled: Bool, deck: DeckID, generation: UInt64) throws -> UInt64 {
        var command = tdj_command()
        command.kind = TDJ_KEYLOCK
        command.deck = index(deck)
        command.generation = generation
        command.flag = enabled ? 1 : 0
        return try send(command)
    }
    public func updateAdaptiveMap(_ map: BeatGridMap?, deck: DeckID, generation: UInt64) throws {
        if let map { try map.validate(frameCount: Int64.max) }
        try send(SourceControl.adaptiveMap(map, deck, generation).command)
    }
    public func updateGrid(_ grid: BeatGrid, deck: DeckID, generation: UInt64) throws {
        var command = tdj_command()
        command.kind = TDJ_GRID
        command.deck = index(deck)
        command.generation = generation
        command.value = grid.bpm
        command.value2 = grid.anchorFrame
        command.flag = Int32(grid.downbeatOffset)
        try send(command)
    }
    public func seek(frame: Double, deck: DeckID, generation: UInt64) throws {
        var command = tdj_command()
        command.kind = TDJ_SEEK
        command.deck = index(deck)
        command.generation = generation
        command.value = frame
        try send(command)
    }
    public func setMixer(_ parameter: MixerParameter, value: Double, deck: DeckID = .a) throws {
        var command = tdj_command()
        command.kind = TDJ_MIXER
        command.deck = index(deck)
        command.flag = parameter.rawValue
        command.value = value
        try send(command)
    }
    public func perform(
        _ action: PerformanceAction, deck: DeckID, generation: UInt64, value: Double = 0, end: Double = 0,
        enabled: Bool = true, quantum: Double = 0, touchRate: Double? = nil, followsPosition: Bool = false
    ) throws {
        var command = tdj_command()
        command.kind = action.rawValue
        command.deck = index(deck)
        command.generation = generation
        command.value = value
        command.value2 = end
        command.value3 = quantum
        command.flag = enabled ? 1 : 0
        if let touchRate {
            guard action == .touch, enabled else { throw TransportError.invalid }
            command.flag = followsPosition ? TDJ_TOUCH_FOLLOWS_POSITION : TDJ_TOUCH_WITH_RATE
            command.touch_rate = touchRate
        }
        try send(command)
    }
    public func setEffect(
        _ kind: Int, slot: Int, x: Double, y: Double, enabled: Bool, deck: DeckID, synced: Bool = true
    ) throws {
        guard (0..<3).contains(slot), (0..<PerformanceEffect.supportedCount).contains(kind) else {
            throw TransportError.invalid
        }
        var command = tdj_command()
        command.kind = TDJ_FX
        command.deck = index(deck)
        command.flag = Int32((slot << 8) | kind | (synced ? 0 : 128))
        command.value = x
        command.value2 = y
        command.value3 = enabled ? 1 : 0
        try send(command)
    }
    @discardableResult public func armRecoveryReplay(
        deck: DeckID, generation: UInt64, dropFrame: Double, endFrame: Double, preparations: [SourcePreparation] = []
    ) throws -> UInt64 {
        var command = tdj_command()
        command.kind = TDJ_RECOVERY_REPLAY
        command.deck = index(deck)
        command.generation = generation
        command.value = dropFrame
        command.value2 = endFrame
        command.preparation_ticket = preparations.first?.ticket ?? 0
        return try send(command, preparations: preparations)
    }
    @discardableResult public func armRecoveryMix(
        deck: DeckID, generation: UInt64, incomingGeneration: UInt64, incomingFrame: Double, startFrame: Double,
        endFrame: Double, preparations: [SourcePreparation] = []
    ) throws -> UInt64 {
        var command = tdj_command()
        command.kind = TDJ_RECOVERY_MIX
        command.deck = index(deck)
        command.generation = generation
        command.preparation_generation_b = incomingGeneration
        command.value = startFrame
        command.value2 = endFrame
        command.value3 = incomingFrame
        command.preparation_ticket_b = preparations.first?.ticket ?? 0
        return try send(command, preparations: preparations)
    }
    public func cancelRecovery(deck: DeckID, generation: UInt64) throws {
        var command = tdj_command()
        command.kind = TDJ_RECOVERY_CANCEL
        command.deck = index(deck)
        command.generation = generation
        try send(command)
    }
    public func stopAll() throws {
        var command = tdj_command()
        command.kind = TDJ_PANIC
        try send(command)
    }

    /// Configure the prepared host limit while device output is stopped.
    public func configureMaximumOutputFrames(_ frames: UInt32) throws {
        let status = tdj_engine_configure_maximum_output_frames(pointer, frames)
        guard status == TDJ_OK else {
            if status == TDJ_SOURCE_CAPACITY { throw TransportError.playbackCapacity }
            throw status == TDJ_PROTECTED ? TransportError.protectedDeck : TransportError.invalid
        }
        configuredMaximumOutputFrames = frames
    }

    /// Check adopted coverage while device output is stopped; this does not advance the renderer.
    public func outputSourcesAreReady() throws -> Bool {
        switch tdj_engine_output_sources_ready(pointer) {
        case TDJ_OK: return true
        case TDJ_SOURCE_COLD: return false
        case TDJ_PROTECTED: throw TransportError.protectedDeck
        default: throw TransportError.invalid
        }
    }

    public func acknowledgements() -> [TransportAcknowledgement] {
        var result: [TransportAcknowledgement] = []
        var message = tdj_message()
        while tdj_read_message(pointer, &message) {
            if let preparations = pendingPreparations.removeValue(forKey: message.command_id) {
                Self.release(preparations)
            }
            if message.status == TDJ_RETIRED {
                setOptionalWarming(generation: message.generation, preparation: nil)
                if let asset = assets[message.generation],
                    !assets.contains(where: { $0.key != message.generation && $0.value === asset })
                {
                    retiredStreaming.include(asset, active: false)
                }
                assets[message.generation] = nil
                continue
            }
            let error: TransportError? =
                switch message.status {
                case TDJ_OK: nil
                case TDJ_STALE: .stale
                case TDJ_UNRESOLVED: .unresolved
                case TDJ_PROTECTED: .protectedDeck
                case TDJ_KEYLOCK_RANGE: .keylockRate
                case TDJ_SOURCE_COLD: .sourceCold
                case TDJ_SOURCE_CAPACITY: .playbackCapacity
                case TDJ_ALIGNMENT_UNAVAILABLE: .syncUnavailable
                case TDJ_ACTIVE_PERFORMANCE: .activePerformance
                default: .invalid
                }
            result.append(.init(commandID: message.command_id, generation: message.generation, error: error))
        }
        return result
    }
    public var playingPads: UInt32 { tdj_playing_pads(pointer) }

    public func setPadAsset(_ asset: PCMAsset?, slot: Int) throws -> UInt64 {
        guard (0..<Int(TDJ_PAD_COUNT)).contains(slot),
            asset.map({ $0.streamingWorker == nil && $0.frames > 0 }) ?? true
        else { throw TransportError.invalid }
        nextGeneration += 1
        let generation = nextGeneration
        var command = tdj_command()
        command.kind = TDJ_PAD_LOAD
        command.deck = Int32(slot)
        command.generation = generation
        command.asset = asset?.pointer
        assets[generation] = asset
        do { try send(command) } catch {
            assets[generation] = nil
            throw error
        }
        return generation
    }

    public func playPad(_ slot: Int, generation: UInt64, enabled: Bool) throws {
        guard (0..<Int(TDJ_PAD_COUNT)).contains(slot) else { throw TransportError.invalid }
        var command = tdj_command()
        command.kind = TDJ_PAD_PLAY
        command.deck = Int32(slot)
        command.generation = generation
        command.flag = enabled ? 1 : 0
        try send(command)
    }

    public func setPadGain(_ value: Double) throws {
        guard value.isFinite, (0...1).contains(value) else { throw TransportError.invalid }
        var command = tdj_command()
        command.kind = TDJ_PAD_GAIN
        command.value = value
        try send(command)
    }

    public func setMicrophoneEnabled(_ enabled: Bool) {
        tdj_microphone_set_enabled(pointer, enabled)
    }

    public var renderedOutputFrame: UInt64 { tdj_rendered_output_frame(pointer) }

    public func snapshot() -> PlaybackSnapshot? {
        var value = tdj_snapshot()
        return tdj_read_snapshot(pointer, &value) ? .init(value) : nil
    }
    @discardableResult public func processControlsWhileIdle() -> Bool { tdj_render(pointer, 0, nil, nil) }
    /// Only call this on the render consumer. No Swift collections or ARC assets are accessed here.
    @discardableResult public func render(
        count: UInt32, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>
    ) -> Bool {
        let result = tdj_render_recorded_buses(
            pointer, recording.nativeAudioRenderPointer, count, left, right, nil, nil)
        return result
    }
    @discardableResult public func renderBuses(
        count: UInt32, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>,
        cueLeft: UnsafeMutablePointer<Float>, cueRight: UnsafeMutablePointer<Float>
    ) -> Bool {
        let result = tdj_render_recorded_buses(
            pointer, recording.nativeAudioRenderPointer, count, left, right, cueLeft, cueRight)
        return result
    }
    public func renderBusesOffline(frames: Int) -> (left: [Float], right: [Float], cueLeft: [Float], cueRight: [Float])
    {
        precondition(frames > 0 && frames <= Int(UInt32.max))
        var l = [Float](repeating: 0, count: frames)
        var r = l
        var cl = l
        var cr = l
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                cl.withUnsafeMutableBufferPointer { cp in
                    cr.withUnsafeMutableBufferPointer { dp in
                        _ = renderBuses(
                            count: UInt32(frames), left: lp.baseAddress!, right: rp.baseAddress!,
                            cueLeft: cp.baseAddress!, cueRight: dp.baseAddress!)
                    }
                }
            }
        }
        return (l, r, cl, cr)
    }
    public func renderOffline(frames: Int) -> (left: [Float], right: [Float]) {
        precondition(frames >= 0 && frames <= Int(UInt32.max))
        var left = [Float](repeating: 0, count: frames)
        var right = left
        if frames == 0 {
            processControlsWhileIdle()
            return (left, right)
        }
        _ = left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                render(count: UInt32(frames), left: l.baseAddress!, right: r.baseAddress!)
            }
        }
        return (left, right)
    }
    private func index(_ deck: DeckID) -> Int32 { deck == .a ? 0 : 1 }
    private static func release(_ preparations: [SourcePreparation]) {
        for preparation in preparations { preparation.asset.releaseSourcePreparation(preparation.ticket) }
    }
    /// Diagnostic scope on the single control producer. AudioOut never accesses this state.
    public func captureFirstControlSubmission(_ operation: () -> Void) -> NativeControlSubmissionTiming? {
        precondition(!capturingFirstSubmission)
        capturingFirstSubmission = true
        firstSubmission = nil
        defer {
            capturingFirstSubmission = false
            firstSubmission = nil
        }
        operation()
        return firstSubmission
    }

    @discardableResult private func send(_ value: tdj_command, preparations: [SourcePreparation] = []) throws -> UInt64
    {
        nextCommand += 1
        var command = value
        command.id = nextCommand
        let capture = capturingFirstSubmission && firstSubmission == nil
        let beganMachTicks = capture ? mach_absolute_time() : 0
        let began = capture ? ContinuousClock().now : nil
        guard tdj_submit(pointer, command) else {
            Self.release(preparations)
            throw TransportError.queueFull
        }
        if let began {
            firstSubmission = NativeControlSubmissionTiming(
                commandID: nextCommand, began: began, beganMachTicks: beganMachTicks,
                acceptedMachTicks: mach_absolute_time())
        }
        if !preparations.isEmpty { pendingPreparations[nextCommand] = preparations }
        return nextCommand
    }
}

extension SampleTransport {
    public func nativeAudioRenderOwnership(metrics: AudioCallbackMetrics?) -> NativeAudioRenderOwnership {
        NativeAudioRenderOwnership(
            transport: self, engine: pointer, recording: recording.nativeAudioRenderPointer, metrics: metrics)
    }
}
