import TDJCore

extension ReplicaModel {
    public func resetMasterTempo() {
        guard let snapshot = playback.core.snapshot() else { return }
        let candidates = [DeckID.a, .b].filter {
            let state = snapshot[$0]
            return state.synced && state.sourceBPM.isFinite && state.sourceBPM > 0
                && [.playing, .paused, .ready].contains(state.phase)
        }
        let reference = candidates.min {
            let left = snapshot[$0], right = snapshot[$1]
            let leftPriority = left.phase == .playing ? 0 : left.phase == .paused ? 1 : 2
            let rightPriority = right.phase == .playing ? 0 : right.phase == .paused ? 1 : 2
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            return left.lastStartOutputFrame < right.lastStartOutputFrame
        }
        guard let reference else { return }
        setMasterBPM(snapshot[reference].sourceBPM)
    }
}
