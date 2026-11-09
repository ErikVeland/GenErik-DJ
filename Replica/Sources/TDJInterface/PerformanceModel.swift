import Foundation
import TDJCore

extension ReplicaModel {
    public func synchronizeGridCue(trackID: String, grid: BeatGrid) {
        guard let track = library.tracks.first(where: { $0.id == trackID }), grid.anchorFrame >= 0,
            grid.anchorFrame < Double(track.analysis.frameCount)
        else { return }
        if performance.synchronizeGridCue(trackID: trackID, frame: grid.anchorFrame) { savePerformance() }
    }
    public func savePerformance() {
        for deck in DeckID.allCases { warmCuePositions(deck: deck) }
        let url = store.root.appendingPathComponent("performance.json")
        performancePersistence.enqueue(
            performance, write: { try $0.save(to: url) }, reportError: { [weak self] in self?.status = $0 })
    }
    func warmCuePositions(deck: DeckID) {
        guard let trackID = loaded[deck] else { return }
        let cues = (performance.cues[trackID] ?? [:]).sorted { $0.key < $1.key }.prefix(8).map(\.value)
        playback.warmCuePositions(cues, deck: deck)
    }
    public func flushPerformanceWrites() async {
        savePerformance()
        saveEffects()
        await performancePersistence.flush()
        await effectsPersistence.flush()
    }
    public func perform(
        _ action: PerformanceAction, deck: DeckID, value: Double = 0, end: Double = 0, enabled: Bool = true,
        quantum: Double = 0, touchRate: Double? = nil, followsPosition: Bool = false
    ) {
        guard !preparingPlayback.contains(deck) else { return }
        do {
            try playback.perform(
                action, deck: deck, value: value, end: end, enabled: enabled, quantum: quantum, touchRate: touchRate,
                followsPosition: followsPosition)
            refreshPlayback()
        } catch { status = error.localizedDescription }
    }
    public func boundedFrame(_ frame: Double, deck: DeckID) -> Double {
        guard let track = track(deck), frame.isFinite else { return 0 }
        return min(Double(track.analysis.frameCount) - 1, max(0, frame))
    }
    public func snappedFrame(_ frame: Double, deck: DeckID) -> Double {
        guard let grid = timing(deck) else { return boundedFrame(frame, deck: deck) }
        return boundedFrame(grid.frame(atBeat: grid.beat(atFrame: frame).rounded()), deck: deck)
    }
    public func jump(_ frame: Double, deck: DeckID, quantized: Bool = true) {
        perform(.jump, deck: deck, value: boundedFrame(frame, deck: deck), end: quantized ? performance.quantize : 0)
        if !frozen.contains(deck) { previewing.remove(deck) }
    }
    public func returnToPlayhead(deck: DeckID) {
        guard !frozen.contains(deck), !editing.contains(deck) else { return }
        refreshPlayback()
        guard let state = playbackSnapshot?[deck] else { return }
        previewing.remove(deck)
        viewport[deck] = state.sourceFrame
    }
    public func setLoop(start: Double, end: Double, deck: DeckID, quantized: Bool = false) {
        guard let track = track(deck) else { return }
        let lower = max(0, min(start, end))
        let upper = min(Double(track.analysis.frameCount), max(start, end))
        guard upper - lower >= 1 else { return }
        if !quantized, let state = playbackSnapshot?[deck], state.loopEnabled, state.loopStart == lower,
            state.loopEnd == upper
        {
            return
        }
        perform(.loop, deck: deck, value: lower, end: upper, quantum: quantized ? performance.quantize : 0)
    }
    public func toggleLoop(deck: DeckID, quantized: Bool = true) {
        if playbackSnapshot?[deck].loopEnabled == true {
            perform(.loop, deck: deck, enabled: false)
        } else if let grid = timing(deck) {
            let frame = playbackSnapshot?[deck].sourceFrame ?? 0
            let start = quantized ? snappedFrame(frame, deck: deck) : boundedFrame(frame, deck: deck)
            setLoop(
                start: start, end: start + grid.span(beats: performance.loopBeats(for: deck), from: start), deck: deck)
        }
    }
    public func toggleFreeze(deck: DeckID) {
        perform(.touch, deck: deck, enabled: false)
        if frozen.contains(deck) {
            frozen.remove(deck)
            previewing.remove(deck)
        } else {
            frozen.insert(deck)
            previewing.insert(deck)
        }
    }
    public func superSlicerFamily(deck: DeckID) -> SuperSlicerFamily { superSlicerFamilies[deck] ?? .loopStutter }
    public func selectSuperSlicerFamily(_ family: SuperSlicerFamily, deck: DeckID) {
        if superSlicerFamily(deck: deck) != family {
            perform(.touch, deck: deck, enabled: false)
            superSlicerFamilies[deck] = family
        }
        if !frozen.contains(deck) { toggleFreeze(deck: deck) }
    }
    public func toggleGridEditing(deck: DeckID) {
        perform(.touch, deck: deck, enabled: false)
        if editing.contains(deck) { editing.remove(deck) } else { editing.insert(deck) }
    }
    public func cue(slot: Int, deck: DeckID, delete: Bool = false, quantized: Bool = true) {
        guard (0..<8).contains(slot), let track = track(deck), let state = playbackSnapshot?[deck] else { return }
        if delete {
            performance.cues[track.id]?[slot] = nil
            savePerformance()
            return
        }
        if let cue = performance.cues[track.id]?[slot] {
            if state.phase != .playing && state.phase != .queued {
                do {
                    try playback.recallCue(cue, deck: deck, quantum: quantized ? performance.quantize : 0)
                    if cue.loopEnd == nil && !frozen.contains(deck) { previewing.remove(deck) }
                    refreshPlayback()
                } catch { status = error.localizedDescription }
            } else if let end = cue.loopEnd {
                setLoop(start: cue.frame, end: end, deck: deck, quantized: quantized)
            } else {
                jump(cue.frame, deck: deck, quantized: quantized)
            }
        } else {
            let position = quantized ? snappedFrame(state.sourceFrame, deck: deck) : boundedFrame(state.sourceFrame, deck: deck)
            let frame = state.loopEnabled ? state.loopStart : position
            performance.cues[track.id, default: [:]][slot] = .init(
                frame: frame, loopEnd: state.loopEnabled ? state.loopEnd : nil)
            savePerformance()
        }
    }
    @discardableResult public func filterTouch(x: Double, y: Double, deck: DeckID, updateX: Bool = true) -> Bool {
        var submitted = false
        if updateX { submitted = submitMixer(.filterX, value: min(1, max(-1, x * 2 - 1)), deck: deck) }
        // Submit every axis before polling and publishing the playback state.
        let submittedY = submitMixer(.filterY, value: min(1, max(0, 1 - y)), deck: deck)
        let submittedEnable = submitMixer(.filterEnabled, value: 1, deck: deck)
        if submitted || submittedY || submittedEnable { refreshPlayback() }
        return (!updateX || submitted) && submittedY && submittedEnable
    }
    @discardableResult public func releaseFilter(deck: DeckID, cancelled: Bool = false) -> Bool {
        var submitted = true
        if cancelled || !filterLocked.contains(deck) {
            submitted = submitMixer(.filterEnabled, value: 0, deck: deck)
            if submitted { refreshPlayback() }
        }
        persistMixerPreferences()
        return submitted
    }
}
