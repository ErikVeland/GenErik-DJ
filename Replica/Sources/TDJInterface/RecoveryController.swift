import Foundation
import TDJCore

extension PlaybackController {
    func invalidateRecovery(deck: DeckID? = nil, submitCancellation: Bool = true) {
        for id in DeckID.allCases where deck == nil || deck == id {
            recoveryRevisions[id, default: 0] &+= 1
            // Accepted crossfader and volume commands cancel recovery in the audio consumer.
            if submitCancellation, let generation = generations[id] {
                try? core.cancelRecovery(deck: id, generation: generation)
            }
        }
    }

    public func prepareRecoveryReplay(_ plan: RecoveryPlan, deck: DeckID) async throws {
        guard let generation = generations[deck], let asset = core.asset(generation: generation),
            let state = core.snapshot()?[deck], let dropFrame = plan.dropFrame
        else { throw TransportError.stale }
        let revision = recoveryRevisions[deck, default: 0]
        var speed = state.speed
        if let map = state.adaptiveMap {
            for anchor in map.anchors {
                speed = max(speed, (core.snapshot()?.masterBPM ?? 120) / map.bpm(atFrame: anchor.frame))
            }
        }
        let deadline = ContinuousClock.now + .seconds(5)
        let ticket = try await asset.prepareSources(
            [
                .init(position: state.sourceFrame, speed: speed, keylock: state.keylock),
                .init(
                    position: dropFrame, speed: speed, loopStart: dropFrame, loopEnd: plan.endFrame,
                    keylock: state.keylock),
            ], generation: generation,
            whileWaiting: {
                self.maintainControlState()
                guard ContinuousClock.now < deadline else { throw TransportError.sourceCold }
                guard self.generations[deck] == generation, self.recoveryRevisions[deck, default: 0] == revision else {
                    throw CancellationError()
                }
            })
        var transferred = false
        defer { if !transferred { asset.releaseSourcePreparation(ticket) } }
        try Task.checkCancellation()
        guard generations[deck] == generation, recoveryRevisions[deck, default: 0] == revision else {
            throw CancellationError()
        }
        transferred = true
        let command = try core.armRecoveryReplay(
            deck: deck, generation: generation, dropFrame: dropFrame, endFrame: plan.endFrame,
            preparations: ticket == 0 ? [] : [.init(asset: asset, deck: deck, generation: generation, ticket: ticket)])
        try await awaitRecoveryCommand(command, deck: deck, generation: generation, revision: revision)
    }

    public func prepareRecoveryMix(_ plan: RecoveryPlan, deck: DeckID, incomingFrame: Double, leadBars: Int)
        async throws
    {
        let incoming: DeckID = deck == .a ? .b : .a
        guard let generation = generations[deck], let nextGeneration = generations[incoming],
            let asset = core.asset(generation: nextGeneration), let snapshot = core.snapshot(),
            let start = plan.mixStartFrame(leadBars: leadBars), snapshot[incoming].sourceBPM > 0
        else { throw TransportError.invalid }
        let revision = recoveryRevisions[deck, default: 0]
        let nextRevision = recoveryRevisions[incoming, default: 0]
        let state = snapshot[incoming]
        var speed = snapshot.masterBPM / state.sourceBPM
        if let map = state.adaptiveMap {
            for anchor in map.anchors { speed = max(speed, snapshot.masterBPM / map.bpm(atFrame: anchor.frame)) }
        }
        let deadline = ContinuousClock.now + .seconds(5)
        let ticket = try await asset.prepareSources(
            [.init(position: incomingFrame, speed: speed, keylock: state.keylock)], generation: nextGeneration,
            whileWaiting: {
                self.maintainControlState()
                guard ContinuousClock.now < deadline else { throw TransportError.sourceCold }
                guard self.generations[deck] == generation, self.generations[incoming] == nextGeneration,
                    self.recoveryRevisions[deck, default: 0] == revision,
                    self.recoveryRevisions[incoming, default: 0] == nextRevision
                else { throw CancellationError() }
            })
        var transferred = false
        defer { if !transferred { asset.releaseSourcePreparation(ticket) } }
        try Task.checkCancellation()
        guard generations[deck] == generation, generations[incoming] == nextGeneration,
            recoveryRevisions[deck, default: 0] == revision, recoveryRevisions[incoming, default: 0] == nextRevision
        else { throw CancellationError() }
        transferred = true
        let command = try core.armRecoveryMix(
            deck: deck, generation: generation, incomingGeneration: nextGeneration, incomingFrame: incomingFrame,
            startFrame: start, endFrame: plan.endFrame,
            preparations: ticket == 0
                ? [] : [.init(asset: asset, deck: incoming, generation: nextGeneration, ticket: ticket)])
        try await awaitRecoveryCommand(command, deck: deck, generation: generation, revision: revision)
    }

    private func awaitRecoveryCommand(_ command: UInt64, deck: DeckID, generation: UInt64, revision: UInt64)
        async throws
    {
        recoveryAwaitedCommands.insert(command)
        defer {
            recoveryAwaitedCommands.remove(command)
            recoveryAcknowledgements[command] = nil
        }
        for _ in 0..<200 {
            maintainControlState()
            try Task.checkCancellation()
            guard generations[deck] == generation, recoveryRevisions[deck, default: 0] == revision else {
                throw CancellationError()
            }
            if let acknowledgement = recoveryAcknowledgements[command] {
                if let error = acknowledgement.error { throw error }
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw TransportError.sourceCold
    }
}
