import Foundation
import Observation
import TDJCore

@MainActor @Observable final class RecoveryState {
    var tasks: [DeckID: Task<Void, Never>] = [:]
    var identities: [DeckID: UUID] = [:]
    var attempted: [DeckID: UInt64] = [:]
    var feedback: [DeckID: String] = [:]
    var settings = RecoverySettings()
    func cancel() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        identities.removeAll()
        attempted.removeAll()
        feedback.removeAll()
    }
}

extension ReplicaModel {
    func maintainRecovery(_ snapshot: PlaybackSnapshot) {
        if recoveryState.settings != performance.recovery {
            recoveryState.cancel()
            playback.invalidateRecovery()
            recoveryState.settings = performance.recovery
        }
        guard performance.recovery.mode != .off, recoveryState.tasks.isEmpty else { return }
        for deck in snapshot.deckIDs {
            let state = snapshot[deck]
            let other: DeckID = deck.opposite
            let side: CrossfaderAssignment = deck.leftSide ? .left : .right
            let otherSide: CrossfaderAssignment = deck.leftSide ? .right : .left
            let assignment = state.mixer.crossfaderAssignment ?? side
            let crossfaderAudible = switch assignment {
            case .left: snapshot.crossfader < 1
            case .right: snapshot.crossfader > 0
            case .through: true
            }
            guard state.phase == .playing, !state.loopEnabled, !state.touchActive,
                !state.jumpPending, !state.braking, state.performanceRate == 1, state.mixer.volume > 0,
                crossfaderAudible,
                recoveryState.attempted[deck] != state.generation, !preparingPlayback.contains(deck),
                let track = track(deck), let timing = track.timing, !track.analysis.waveform.isEmpty
            else { continue }
            recoveryState.attempted[deck] = state.generation
            recoveryState.tasks[deck]?.cancel()
            let generation = state.generation
            let revision = playback.recoveryRevisions[deck, default: 0]
            let settings = performance.recovery
            let destinationIdentity = loadIdentity(other)
            let identity = UUID()
            recoveryState.identities[deck] = identity
            recoveryState.feedback[deck] = "Preparing recovery"
            recoveryState.tasks[deck] = Task { [weak self] in
                let plan = await Task.detached(priority: .utility) {
                    RecoveryPlan(
                        waveform: track.analysis.waveform, framesPerBin: track.analysis.waveformFramesPerBin,
                        frameCount: track.analysis.frameCount, timing: timing,
                        dropOverride: settings.dropFrames[track.id])
                }.value
                guard let self else { return }
                defer { if self.recoveryState.identities[deck] == identity { self.recoveryState.tasks[deck] = nil } }
                do {
                    try Task.checkCancellation()
                    guard self.playback.generations[deck] == generation,
                        self.playback.recoveryRevisions[deck, default: 0] == revision
                    else { throw CancellationError() }
                    guard let plan else {
                        self.recoveryState.feedback[deck] = "Set the last drop in Playback settings"
                        return
                    }
                    if plan.dropFrame != nil {
                        try await self.playback.prepareRecoveryReplay(plan, deck: deck)
                        self.recoveryState.feedback[deck] = nil
                    } else {
                        self.recoveryState.feedback[deck] = "Set the last drop in Playback settings"
                    }
                    guard settings.mode == .autoMix, let latest = self.playback.core.snapshot(),
                        (latest[deck].mixer.crossfaderAssignment ?? side) == side,
                        (latest[other].mixer.crossfaderAssignment ?? otherSide) == otherSide,
                        !latest.deckIDs.contains(where: { $0 != deck && latest[$0].phase.active })
                    else { return }
                    let context = SuggestionContext(
                        referenceTrackID: track.id, destination: other, performanceBPM: snapshot.masterBPM,
                        usePerformanceBPM: state.synced, loadedTrackIDs: [track.id],
                        libraryRevision: self.library.revision, historyRevision: self.library.adaptiveMemory.revision)
                    let ranked = try await PerformerSuggestions.rankAsync(
                        librarySource: self.libraryReadSource(), context: context, referenceOverride: track)
                    try Task.checkCancellation()
                    guard self.playback.recoveryRevisions[deck, default: 0] == revision,
                        self.loadIdentity(other) == destinationIdentity, let latest = self.playback.core.snapshot(),
                        (latest[deck].mixer.crossfaderAssignment ?? side) == side,
                        (latest[other].mixer.crossfaderAssignment ?? otherSide) == otherSide,
                        !latest[other].phase.active, let start = plan.mixStartFrame(leadBars: settings.leadBars),
                        latest[deck].sourceFrame < start, let candidate = ranked.first,
                        let next = self.library.track(id: candidate.id)?.resolvingTraktorPreparation(),
                        let nextTiming = next.timing
                    else { return }
                    self.load(trackID: next.id, deck: other)
                    let requestedLoad = self.loadIdentity(other)
                    let nativeOwner = self.nativeMusic.loadOwners[other]
                    await self.flushWrites()
                    try Task.checkCancellation()
                    guard self.loaded[other] == next.id,
                        nativeOwner != nil
                            ? self.nativeMusic.loadOwners[other] == nativeOwner
                            : self.loadIdentity(other) == requestedLoad,
                        self.playback.recoveryRevisions[deck, default: 0] == revision,
                        self.playback.generations[deck] == generation
                    else { throw CancellationError() }
                    guard let incoming = plan.incomingFrame(timing: nextTiming, leadBars: settings.leadBars) else {
                        return
                    }
                    try await self.playback.prepareRecoveryMix(
                        plan, deck: deck, incomingFrame: incoming, leadBars: settings.leadBars)
                    self.recoveryState.feedback[deck] = nil
                } catch is CancellationError {} catch {
                    if self.playback.core.snapshot()?[deck].recoveryArmed != true {
                        self.recoveryState.feedback[deck] = "Recovery unavailable: \(error.localizedDescription)"
                    }
                }
            }
            break
        }
    }

    public func setRecoveryMode(_ mode: RecoveryMode) {
        performance.recovery.mode = mode
        resetRecoverySettings()
    }
    public func setRecoveryLeadBars(_ bars: Int) {
        guard [8, 16].contains(bars) else { return }
        performance.recovery.leadBars = bars
        resetRecoverySettings()
    }
    public func setRecoveryDropFromPlayhead(deck: DeckID) {
        guard let track = track(deck), let state = playback.core.snapshot()?[deck] else { return }
        performance.recovery.dropFrames[track.id] = state.sourceFrame
        resetRecoverySettings()
    }
    public func clearRecoveryDrop(deck: DeckID) {
        guard let track = track(deck) else { return }
        performance.recovery.dropFrames[track.id] = nil
        resetRecoverySettings()
    }
    private func resetRecoverySettings() {
        recoveryState.cancel()
        playback.invalidateRecovery()
        recoveryState.settings = performance.recovery
        savePerformance()
        refreshPlayback()
    }
    public func recoveryLabel(deck: DeckID) -> String? {
        guard performance.recovery.mode != .off, let state = playbackSnapshot?[deck], state.phase == .playing else {
            return nil
        }
        if state.recoveryActive { return "Replaying recovery section" }
        if state.recoveryArmed {
            let target = state.recoveryMix ? state.recoveryMixStart : state.recoveryEnd
            let remaining = max(
                0, (target - state.sourceFrame) / max(1, state.speed * (state.grid?.sampleRate ?? 48000)))
            let mode = state.recoveryMix ? "Auto-mix" : "Recovery replay"
            return remaining > 0 ? "\(mode) · \(Int(ceil(remaining)))s" : mode
        }
        return recoveryState.feedback[deck]
    }
}
