import Foundation

extension SourceControl {
    public var deck: DeckID? {
        switch self {
        case .tempo: nil
        case .brake(_, _, let deck, _), .play(let deck, _), .freeRate(_, let deck, _), .sync(_, let deck, _),
            .restoreSync(let deck, _), .keylock(_, let deck, _), .grid(_, let deck, _), .adaptiveMap(_, let deck, _),
            .seek(_, let deck, _), .cueRecall(let deck, _, _, _, _), .performance(_, let deck, _, _, _, _, _, _, _):
            deck
        }
    }
    public var generation: UInt64? {
        switch self {
        case .tempo: nil
        case .brake(_, _, _, let generation), .play(_, let generation), .freeRate(_, _, let generation),
            .sync(_, _, let generation), .restoreSync(_, let generation), .keylock(_, _, let generation),
            .grid(_, _, let generation), .adaptiveMap(_, _, let generation), .seek(_, _, let generation),
            .cueRecall(_, let generation, _, _, _), .performance(_, _, let generation, _, _, _, _, _, _):
            generation
        }
    }

    /// Conservative preparation only. The C consumer validates and schedules the action.
    public func preparationTargets(snapshot: PlaybackSnapshot, deck: DeckID, frames: UInt64) -> [PCMSourceTarget] {
        guard self.deck == nil || self.deck == deck, frames > 0 else { return [] }
        let state = snapshot[deck]
        guard state.phase != .empty else { return [] }
        func bounded(_ position: Double) -> Double { min(Double(frames - 1), max(0, position)) }
        let heldLoop = state.touchActive && state.touchEnd > state.touchStart
        var target = PCMSourceTarget(
            position: state.sourceFrame, speed: state.speed, performanceRate: state.performanceRate,
            loopStart: heldLoop ? state.touchStart : state.loopEnabled ? state.loopStart : 0,
            loopEnd: heldLoop ? state.touchEnd : state.loopEnabled ? state.loopEnd : 0,
            continuingPosition: state.continuingFrame, keylock: state.keylock,
            reserveContinuing: (state.fluxEnabled || state.loopRolling) && (state.touchActive || state.loopEnabled))
        var preservePending = state.jumpPending
        var alignmentBeat: Double?
        var alignmentTiming = state.timing
        let hasReference = snapshot.deckIDs.contains {
            $0 != deck && snapshot[$0].synced && snapshot[$0].sourceBPM > 0 && snapshot[$0].phase == .playing
        }
        let entryBeat: Double? = hasReference ? 0 : snapshot.clockRunning ? snapshot.masterBeat : nil
        switch self {
        case .tempo(let bpm): if state.synced, state.sourceBPM > 0 { target.speed = bpm / state.sourceBPM }
        case .freeRate(let rate, _, _): if !state.synced { target.speed = rate }
        case .sync(let enabled, _, _):
            target.speed =
                enabled && state.sourceBPM > 0
                ? snapshot.masterBPM / state.sourceBPM
                : state.phase == .playing || state.phase == .paused ? state.speed : state.freeRate
            if enabled, state.phase == .playing, !state.touchActive, !state.braking, state.performanceRate == 1 {
                alignmentBeat = snapshot.masterBeat
            }
        case .restoreSync:
            guard let grid = state.timing else { return [] }
            let lower = state.loopEnabled ? max(0, state.loopStart) : 0
            let upper = state.loopEnabled ? min(Double(frames), state.loopEnd) : Double(frames)
            guard lower < upper,
                let position = grid.nearestPhaseAlignedFrame(
                    to: state.sourceFrame, masterBeat: snapshot.masterBeat, within: lower..<upper)
            else { return [] }
            target.position = position
            target.speed = snapshot.masterBPM / state.sourceBPM
        case .keylock(let enabled, _, _): target.keylock = enabled
        case .grid(let grid, _, _):
            if state.synced { target.speed = snapshot.masterBPM / grid.bpm }
            alignmentTiming = BeatTiming(fixed: grid)
            if state.phase == .playing, !state.touchActive, !state.braking, state.performanceRate == 1 {
                alignmentBeat = snapshot.masterBeat
            }
        case .adaptiveMap: break
        case .seek(let position, _, _):
            target.position = bounded(position)
            if !state.touchActive, !state.braking, state.performanceRate == 1 { alignmentBeat = 0 }
        case .cueRecall(_, _, let position, let loopEnd, _):
            target.position = bounded(position)
            alignmentBeat = entryBeat
            preservePending = false
            if state.phase == .ended { target.continuingPosition = target.position }
            if let loopEnd {
                if !heldLoop {
                    target.loopStart = position
                    target.loopEnd = loopEnd
                }
                if state.phase != .ended && !state.loopEnabled && !state.touchActive {
                    target.continuingPosition = state.sourceFrame
                }
                target.reserveContinuing = state.fluxEnabled
            }
        case .performance(
            let action, _, _, let value, let end, let enabled, let quantum, let touchRate, let followsPosition):
            switch action {
            case .jump:
                target.position = bounded(value)
                if !state.touchActive, !state.braking, state.performanceRate == 1 {
                    alignmentBeat = state.phase == .playing
                        ? end > 0 ? (floor(snapshot.masterBeat / end) + 1) * end : snapshot.masterBeat : 0
                }
                preservePending = false
            case .loop, .loopRoll:
                preservePending = false
                if enabled {
                    if quantum > 0 || target.position < value || target.position >= end {
                        target.position = bounded(value)
                    }
                    if !heldLoop {
                        target.loopStart = value
                        target.loopEnd = end
                    }
                    if !state.loopEnabled && !state.touchActive { target.continuingPosition = state.sourceFrame }
                    target.reserveContinuing = state.fluxEnabled || action == .loopRoll
                    if !state.touchActive, !state.braking, state.performanceRate == 1 {
                        alignmentBeat = state.phase == .playing
                            ? quantum > 0 ? (floor(snapshot.masterBeat / quantum) + 1) * quantum : snapshot.masterBeat : 0
                    }
                } else {
                    if state.loopEnabled && (state.fluxEnabled || state.loopRolling) && !state.touchActive {
                        target.position = bounded(state.continuingFrame)
                    }
                    if !heldLoop {
                        target.loopStart = 0
                        target.loopEnd = 0
                    }
                    target.reserveContinuing = state.fluxEnabled && state.touchActive
                    if !state.touchActive, !state.braking, state.performanceRate == 1 {
                        alignmentBeat = state.phase == .playing ? snapshot.masterBeat : 0
                    }
                }
            case .touch:
                preservePending = false
                if enabled {
                    target.position =
                        state.touchActive && touchRate != nil && !followsPosition ? state.sourceFrame : bounded(value)
                    target.loopStart = end > value ? value : state.loopEnabled ? state.loopStart : 0
                    target.loopEnd = end > value ? end : state.loopEnabled ? state.loopEnd : 0
                    if !state.touchActive && !state.loopEnabled { target.continuingPosition = state.sourceFrame }
                    target.reserveContinuing = state.fluxEnabled
                    if let touchRate { target.performanceRate = touchRate }
                } else {
                    target.performanceRate = 1
                    target.loopStart = state.loopEnabled ? state.loopStart : 0
                    target.loopEnd = state.loopEnabled ? state.loopEnd : 0
                    if state.fluxEnabled && !state.loopEnabled { target.position = bounded(state.continuingFrame) }
                    target.reserveContinuing = state.fluxEnabled && state.loopEnabled
                    alignmentBeat = state.touchWasPlaying ? snapshot.masterBeat : 0
                }
            case .rate:
                target.performanceRate = value
                if value == 1, !state.touchActive, !state.braking {
                    alignmentBeat = state.phase == .playing ? snapshot.masterBeat : 0
                }
            case .flux:
                target.reserveContinuing = enabled && (state.touchActive || state.loopEnabled)
                target.continuingPosition = state.sourceFrame
            }
        case .brake(let action, _, _, _):
            if action == .resume {
                alignmentBeat = state.braking ? snapshot.masterBeat : entryBeat
                if state.synced, state.sourceBPM > 0 { target.speed = snapshot.masterBPM / state.sourceBPM }
            }
        case .play:
            if state.phase == .ended {
                target.position = 0
                target.continuingPosition = 0
                preservePending = false
            }
            if !state.phase.active, !state.touchActive { alignmentBeat = entryBeat }
        }
        let proposedSynced: Bool
        switch self {
        case .restoreSync: proposedSynced = true
        case .sync(let enabled, _, _): proposedSynced = enabled
        default: proposedSynced = state.synced
        }
        if proposedSynced, let beat = alignmentBeat, let timing = alignmentTiming {
            let lower = target.loopEnd > target.loopStart ? max(0, target.loopStart) : 0
            let upper = target.loopEnd > target.loopStart ? min(Double(frames), target.loopEnd) : Double(frames)
            if lower < upper {
                let range = lower..<upper
                if let aligned = timing.nearestPhaseAlignedFrame(to: target.position, masterBeat: beat, within: range) {
                    target.position = aligned
                } else if case .performance(.touch, _, _, _, _, false, _, _, _) = self,
                    let entry = timing.nearestPhaseAlignedFrame(to: target.position, masterBeat: 0, within: range)
                {
                    target.position = entry
                }
            }
        }
        if proposedSynced, let map = state.adaptiveMap {
            let master: Double
            if case .tempo(let bpm) = self { master = bpm } else { master = snapshot.masterBPM }
            for pair in zip(map.anchors, map.anchors.dropFirst()) {
                let bpm = 60 * map.sampleRate * (pair.1.beat - pair.0.beat) / (pair.1.frame - pair.0.frame)
                target.speed = max(target.speed, master / bpm)
            }
        }
        if state.braking { target.speed = max(target.speed, state.freeRate) }
        if state.recoveryActive && !heldLoop && !state.loopEnabled {
            target.loopStart = state.recoveryStart
            target.loopEnd = state.recoveryEnd
        }
        var targets = [target]
        if preservePending {
            var pending = target
            pending.position = bounded(state.pendingJumpFrame)
            if state.pendingJumpIsLoop {
                pending.loopStart = state.pendingJumpFrame
                pending.loopEnd = state.pendingLoopEnd
                if proposedSynced, let timing = state.timing, pending.loopStart < pending.loopEnd,
                    let aligned = timing.nearestPhaseAlignedFrame(
                        to: pending.position, masterBeat: state.pendingJumpBeat,
                        within: pending.loopStart..<pending.loopEnd)
                {
                    pending.position = aligned
                }
            } else if state.touchActive {
                if state.pendingTouchEnd > state.pendingJumpFrame {
                    pending.loopStart = state.pendingJumpFrame
                    pending.loopEnd = state.pendingTouchEnd
                } else {
                    pending.loopStart = state.loopEnabled ? state.loopStart : 0
                    pending.loopEnd = state.loopEnabled ? state.loopEnd : 0
                }
                if state.pendingTouchRateValid { pending.performanceRate = state.pendingTouchRate }
            }
            targets.append(pending)
        }
        if state.recoveryArmed && state.recoveryStart >= 0 {
            var replay = target
            replay.position = state.recoveryStart
            replay.loopStart = state.recoveryStart
            replay.loopEnd = state.recoveryEnd
            replay.performanceRate = 1
            replay.reserveContinuing = false
            targets.append(replay)
        }
        let mayChooseNativeTempo: Bool
        switch self {
        case .play, .cueRecall: mayChooseNativeTempo = !snapshot.clockRunning && state.synced
        default: mayChooseNativeTempo = false
        }
        if mayChooseNativeTempo {
            for var native in targets {
                native.speed = 1
                targets.append(native)
            }
        }
        return targets.filter { target in
            target.speed.isFinite && target.speed > 0 && (!target.keylock || (0.125...8).contains(target.speed))
        }
    }
}
