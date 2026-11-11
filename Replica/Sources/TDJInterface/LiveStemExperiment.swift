import Foundation
import Observation
import OSLog
import TDJCore

/**
 * Separates vocal audio on the preparation worker.
 */
protocol LiveVocalSeparating {
    func vocals(in input: [Float]) throws -> [Float]
}

/**
 * Supplies playback and metrics without owning output setup.
 */
@MainActor protocol LiveStemPlayback: AnyObject, Sendable {
    var core: SampleTransport { get }
    var callbackSummary: AudioCallbackSummary? { get }
}

extension SpleeterVocalMask: LiveVocalSeparating {}
extension PlaybackController: LiveStemPlayback {}

@MainActor @Observable final class LiveStemExperiment {
    enum Mode: Int32, CaseIterable {
        case mix, vocal, instrumental
        var title: String {
            switch self {
            case .mix: "Mix"
            case .vocal: "Vocal"
            case .instrumental: "Inst"
            }
        }
    }

    nonisolated private static let log = Logger(subsystem: "org.generikdj.replica", category: "LiveStems")
    private(set) var deck: DeckID?
    private(set) var mode: Mode = .mix
    private(set) var status = ""
    private(set) var first: UInt64 = 0
    private(set) var end: UInt64 = 0
    private(set) var generation: UInt64 = 0
    private(set) var isEnabled = false
    private(set) var isSeparating = false
    private(set) var isStopping = false
    @ObservationIgnored private var separationTask: Task<Void, Never>?
    @ObservationIgnored private let makeSeparator: @Sendable () throws -> any LiveVocalSeparating

    init(makeSeparator: @escaping @Sendable () throws -> any LiveVocalSeparating = { try SpleeterVocalMask() }) {
        self.makeSeparator = makeSeparator
    }

    deinit { separationTask?.cancel() }

    func setEnabled(_ enabled: Bool, playback: any LiveStemPlayback) {
        isEnabled = enabled
        if !enabled { stop(playback: playback) }
    }

    func canSelect(_ mode: Mode, deck: DeckID) -> Bool {
        guard isEnabled, self.deck == nil || self.deck == deck else { return false }
        return mode == .mix || (!isStopping && (self.deck == nil || isSeparating || end > first))
    }

    private func stop(playback: any LiveStemPlayback) {
        mode = .mix
        playback.core.setLiveVocalMode(0)
        separationTask?.cancel()
        isStopping = separationTask != nil
        status = isStopping ? "Stopping separation" : "Original mix"
    }

    func select(_ mode: Mode, deck: DeckID, playback: any LiveStemPlayback) {
        guard canSelect(mode, deck: deck) else { return }
        if mode == .mix {
            stop(playback: playback)
            return
        }
        let core = playback.core
        if self.deck == deck {
            self.mode = mode
            core.setLiveVocalMode(mode.rawValue)
            return
        }
        guard self.deck == nil, mode != .mix else { return }
        guard let snapshot = core.snapshot(), snapshot.a.phase == .playing, snapshot.b.phase == .playing else {
            status = "Play decks A and B"
            return
        }
        guard let asset = core.asset(generation: snapshot[deck].generation), !asset.hasStems,
            asset.sampleRate == Double(SpleeterVocalMask.sampleRate)
        else {
            status = "Use a 44.1 kHz track"
            return
        }

        self.deck = deck
        self.mode = mode
        self.generation = snapshot[deck].generation
        status = "Loading model"
        let generation = self.generation
        let before = playback.callbackSummary
        let began = ProcessInfo.processInfo.systemUptime
        let makeSeparator = self.makeSeparator
        isSeparating = true
        separationTask = Task.detached(priority: .utility) { [weak self] in
            do {
                try Task.checkCancellation()
                let model = try makeSeparator()
                let read = try asset.liveVocalReader()
                let first = try Self.playhead(core, deck: deck, generation: generation)
                guard first < asset.frames else { throw TransportError.invalid }
                let capacity = min(UInt64(90 * SpleeterVocalMask.sampleRate), asset.frames - first)
                guard core.beginLiveVocal(deck: deck, generation: generation, first: first, capacity: capacity) else {
                    throw TransportError.allocation
                }
                await self?.started(first: first, core: core)
                try Task.checkCancellation()
                var input = [Float](repeating: 0, count: 2 * SpleeterVocalMask.inputFrames)
                var offset: UInt64 = 0
                var previousTail: [Float] = []
                let overlap = 2048
                while offset < capacity {
                    let playhead = try Self.playhead(core, deck: deck, generation: generation)
                    if first + offset > playhead + 15 * UInt64(SpleeterVocalMask.sampleRate) {
                        try await Task.sleep(for: .milliseconds(150))
                        continue
                    }
                    let blockBegan = ProcessInfo.processInfo.systemUptime
                    let inputStart = Int64(first + offset) - Int64(SpleeterVocalMask.context * SpleeterVocalMask.hop)
                    try input.withUnsafeMutableBufferPointer { buffer in
                        let destination = buffer.baseAddress!
                        destination.update(repeating: 0, count: buffer.count)
                        let begin = max(0, inputStart)
                        let end = min(Int64(asset.frames), inputStart + Int64(SpleeterVocalMask.inputFrames))
                        var frame = begin
                        while frame < end {
                            try Task.checkCancellation()
                            let count = Int(min(32768, end - frame))
                            try read(UInt64(frame), count, destination.advanced(by: Int(frame - inputStart) * 2))
                            frame += Int64(count)
                        }
                    }
                    var vocals = try model.vocals(in: input)
                    for index in 0..<previousTail.count {
                        let fade = Float(index / 2) / Float(overlap)
                        vocals[index] = previousTail[index] * (1 - fade) + vocals[index] * fade
                    }
                    let stride = SpleeterVocalMask.outputFrames - overlap
                    let count = Int(min(UInt64(stride), capacity - offset))
                    previousTail = Array(vocals[(2 * stride)...])
                    _ = try Self.playhead(core, deck: deck, generation: generation)
                    guard vocals.withUnsafeBufferPointer({
                        core.appendLiveVocal(UnsafeBufferPointer(start: $0.baseAddress, count: 2 * count))
                    }) else { throw TransportError.invalid }
                    offset += UInt64(count)
                    let blockTime = ProcessInfo.processInfo.systemUptime - blockBegan
                    let elapsed = ProcessInfo.processInfo.systemUptime - began
                    await self?.published(end: first + offset, blockTime: blockTime, elapsed: elapsed)
                }
                try Task.checkCancellation()
                await self?.finish("Test window ready", playback: playback, baseline: before)
            } catch is CancellationError {
                core.setLiveVocalMode(0)
                await self?.finish("Relaunch to prepare", playback: playback, baseline: before, reset: true)
            } catch {
                core.setLiveVocalMode(0)
                Self.log.error("Separation stopped: \(String(describing: error), privacy: .public)")
                let thermal = ProcessInfo.processInfo.thermalState
                let message = thermal == .serious || thermal == .critical ? "Stopped · iPad hot" : "Stopped · original mix"
                await self?.finish(message, playback: playback, baseline: before, reset: true)
            }
        }
    }

    nonisolated private static func playhead(_ core: SampleTransport, deck: DeckID, generation: UInt64) throws -> UInt64 {
        try Task.checkCancellation()
        let thermal = ProcessInfo.processInfo.thermalState
        guard thermal != .serious && thermal != .critical,
            let snapshot = core.snapshot(), snapshot[deck].generation == generation,
            snapshot.a.phase.active, snapshot.b.phase.active
        else { throw CancellationError() }
        return UInt64(max(0, snapshot[deck].sourceFrame))
    }

    private func started(first: UInt64, core: SampleTransport) {
        self.first = first
        guard isEnabled, !isStopping else {
            core.setLiveVocalMode(0)
            return
        }
        status = "Separating"
        core.setLiveVocalMode(mode.rawValue)
    }

    private func published(end: UInt64, blockTime: Double, elapsed: Double) {
        guard isEnabled, !isStopping else { return }
        self.end = end
        status = String(format: "Chunk %.1fs", blockTime)
        Self.log.info("Processed chunk in \(blockTime, privacy: .public)s, elapsed \(elapsed, privacy: .public)s")
    }

    private func finish(
        _ message: String, playback: any LiveStemPlayback, baseline: AudioCallbackSummary?, reset: Bool = false
    ) {
        if reset { mode = .mix }
        separationTask = nil
        isSeparating = false
        isStopping = false
        status = message
        if let baseline, let now = playback.callbackSummary {
            Self.log.info("""
                Callback changes: overruns \(now.deadlineOverruns &- baseline.deadlineOverruns),                 timestamp gaps \(now.timestampGaps &- baseline.timestampGaps),                 render failures \(now.renderFailures &- baseline.renderFailures)
                """)
        }
    }

    func isCovered(in snapshot: PlaybackSnapshot?) -> Bool {
        guard let deck, let current = snapshot?[deck], current.generation == generation else { return false }
        return current.sourceFrame >= Double(first) && current.sourceFrame + 4096 < Double(end)
    }
}
