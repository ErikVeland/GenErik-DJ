import Foundation

extension SourceControl {
    public var deck: DeckID? {
        switch self {
        case .tempo: nil
        case .brake(_, _, let deck, _), .play(let deck, _), .freeRate(_, let deck, _), .sync(_, let deck, _), .restoreSync(let deck, _), .keylock(_, let deck, _),
             .grid(_, let deck, _), .adaptiveMap(_, let deck, _), .seek(_, let deck, _), .cueRecall(let deck, _, _, _, _),
             .performance(_, let deck, _, _, _, _, _, _, _): deck
        }
    }
    public var generation: UInt64? {
        switch self {
        case .tempo: nil
        case .brake(_, _, _, let generation), .play(_, let generation), .freeRate(_, _, let generation), .sync(_, _, let generation), .restoreSync(_, let generation), .keylock(_, _, let generation),
             .grid(_, _, let generation), .adaptiveMap(_, _, let generation), .seek(_, _, let generation),
             .cueRecall(_, let generation, _, _, _),
             .performance(_, _, let generation, _, _, _, _, _, _): generation
        }
    }

    /// Conservative preparation only. The C consumer validates and schedules the action.
    public func preparationTargets(snapshot: PlaybackSnapshot, deck: DeckID, frames: UInt64) -> [PCMSourceTarget] {
        guard self.deck == nil || self.deck == deck, frames > 0 else { return [] }
        let state = snapshot[deck]
        guard state.phase != .empty else { return [] }
        func bounded(_ position: Double) -> Double { min(Double(frames - 1), max(0, position)) }
        let heldLoop = state.touchActive && state.touchEnd > state.touchStart
        var target = PCMSourceTarget(position: state.sourceFrame, speed: state.speed,
            performanceRate: state.performanceRate,
            loopStart: heldLoop ? state.touchStart : state.loopEnabled ? state.loopStart : 0,
            loopEnd: heldLoop ? state.touchEnd : state.loopEnabled ? state.loopEnd : 0,
            continuingPosition: state.continuingFrame, keylock: state.keylock,
            reserveContinuing: state.fluxEnabled && (state.touchActive || state.loopEnabled))
        var preservePending = state.jumpPending
        switch self {
        case .tempo(let bpm):
            if state.synced, state.sourceBPM > 0 { target.speed = bpm / state.sourceBPM }
        case .freeRate(let rate, _, _):
            if !state.synced { target.speed=rate }
        case .sync(let enabled, _, _):
            target.speed = enabled && state.sourceBPM > 0 ? snapshot.masterBPM / state.sourceBPM
                : state.phase == .playing || state.phase == .paused ? state.speed : state.freeRate
        case .restoreSync:
            guard let grid=state.timing else { return [] }
            let lower=state.loopEnabled ? max(0,state.loopStart):0
            let upper=state.loopEnabled ? min(Double(frames),state.loopEnd):Double(frames)
            guard lower<upper,
                  let position=grid.nearestPhaseAlignedFrame(to:state.sourceFrame,
                      masterBeat:snapshot.masterBeat,within:lower..<upper) else { return [] }
            target.position=position
            target.speed=snapshot.masterBPM/state.sourceBPM
        case .keylock(let enabled, _, _): target.keylock = enabled
        case .grid(let grid, _, _):
            if state.synced { target.speed = snapshot.masterBPM / grid.bpm }
        case .adaptiveMap: break
        case .seek(let position, _, _): target.position = bounded(position)
        case .cueRecall(_, _, let position, let loopEnd, _):
            target.position = bounded(position); preservePending = false
            if state.phase == .ended { target.continuingPosition = target.position }
            if let loopEnd {
                if !heldLoop { target.loopStart = position; target.loopEnd = loopEnd }
                if state.phase != .ended && !state.loopEnabled && !state.touchActive {
                    target.continuingPosition = state.sourceFrame
                }
                target.reserveContinuing = state.fluxEnabled
            }
        case .performance(let action, _, _, let value, let end, let enabled, let quantum, let touchRate, let followsPosition):
            switch action {
            case .jump:
                target.position = bounded(value); preservePending = false
            case .loop:
                preservePending = false
                if enabled {
                    if quantum > 0 || target.position < value || target.position >= end { target.position = bounded(value) }
                    if !heldLoop { target.loopStart = value; target.loopEnd = end }
                    if !state.loopEnabled && !state.touchActive { target.continuingPosition = state.sourceFrame }
                    target.reserveContinuing = state.fluxEnabled
                } else {
                    if state.loopEnabled && state.fluxEnabled && !state.touchActive { target.position = bounded(state.continuingFrame) }
                    if !heldLoop { target.loopStart = 0; target.loopEnd = 0 }
                    target.reserveContinuing = state.fluxEnabled && state.touchActive
                }
            case .touch:
                preservePending = false
                if enabled {
                    target.position = state.touchActive && touchRate != nil && !followsPosition ? state.sourceFrame : bounded(value)
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
                }
            case .rate: target.performanceRate = value
            case .flux:
                target.reserveContinuing = enabled && (state.touchActive || state.loopEnabled)
                target.continuingPosition = state.sourceFrame
            }
        case .brake: break
        case .play:
            if state.phase == .ended {
                target.position=0; target.continuingPosition=0; preservePending=false
            }
        }
        let proposedSynced: Bool
        switch self {
        case .restoreSync: proposedSynced=true
        case .sync(let enabled, _, _): proposedSynced=enabled
        default: proposedSynced=state.synced
        }
        if proposedSynced, let map=state.adaptiveMap {
            let master: Double
            if case .tempo(let bpm)=self { master=bpm } else { master=snapshot.masterBPM }
            for pair in zip(map.anchors, map.anchors.dropFirst()) {
                let bpm=60*map.sampleRate*(pair.1.beat-pair.0.beat)/(pair.1.frame-pair.0.frame)
                target.speed=max(target.speed,master/bpm)
            }
        }
        if state.recoveryActive && !heldLoop && !state.loopEnabled {
            target.loopStart = state.recoveryStart; target.loopEnd = state.recoveryEnd
        }
        var targets = [target]
        if preservePending {
            var pending = target
            pending.position = bounded(state.pendingJumpFrame)
            if state.pendingJumpIsLoop {
                pending.loopStart = state.pendingJumpFrame; pending.loopEnd = state.pendingLoopEnd
            } else if state.touchActive {
                if state.pendingTouchEnd > state.pendingJumpFrame {
                    pending.loopStart = state.pendingJumpFrame; pending.loopEnd = state.pendingTouchEnd
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
            replay.position = state.recoveryStart; replay.loopStart = state.recoveryStart
            replay.loopEnd = state.recoveryEnd; replay.performanceRate = 1; replay.reserveContinuing = false
            targets.append(replay)
        }
        let mayChooseNativeTempo: Bool
        switch self {
        case .play, .cueRecall: mayChooseNativeTempo = !snapshot.clockRunning && state.synced
        default: mayChooseNativeTempo = false
        }
        if mayChooseNativeTempo {
            for var native in targets { native.speed = 1; targets.append(native) }
        }
        return targets.filter { target in
            target.speed.isFinite && target.speed > 0 && (!target.keylock || (0.125...8).contains(target.speed))
        }
    }
}
