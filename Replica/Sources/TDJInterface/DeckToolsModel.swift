import Foundation
import TDJCore

/// Controls carried over from the later cross-platform app, on top of the original touch toolkit.
extension ReplicaModel {
    /// Tempo fader position in percent. Synced decks show the master tempo against the track tempo.
    public func deckTempoPercent(deck: DeckID) -> Double {
        guard let state = playbackSnapshot?[deck] else { return 0 }
        // Unsynced decks report their own fader; synced decks follow the master against the track tempo.
        let speed = state.synced ? state.speed : state.freeRate
        guard speed.isFinite, speed > 0 else { return 0 }
        return (speed - 1) * 100
    }

    /// Synced: moves the master tempo. Unsynced: changes only this deck's speed. Limited to ±50 %.
    public func setDeckTempo(percent: Double, deck: DeckID) {
        guard percent.isFinite else { return }
        let ratio = 1 + min(50, max(-50, percent)) / 100
        do {
            if playbackSnapshot?[deck].synced == true, let bpm = grid(deck)?.bpm {
                try playback.setMasterBPM(bpm * ratio)
            } else {
                try playback.setFreeRate(ratio, deck: deck)
            }
            refreshPlayback()
        } catch { status = error.localizedDescription }
    }

    /// Loop size stepper: one power of two per press, resizing an active loop from its start.
    public func stepLoopSize(direction: Int, deck: DeckID) {
        setLoopSize(PerformancePreparation.steppedLoopSize(from: performance.loopBeats(for: deck), direction: direction), deck: deck)
    }
    public func setLoopSize(_ beats: Double, deck: DeckID) {
        performance.setLoopBeats(beats, for: deck)
        if let state = playbackSnapshot?[deck], state.loopEnabled, let grid = grid(deck) {
            setLoop(start: state.loopStart, end: state.loopStart + beats * grid.framesPerBeat, deck: deck)
        }
        savePerformance()
    }

    /// Jumps by whole beats from the current position, keeping the beat phase.
    public func beatJump(beats: Double, deck: DeckID) {
        guard beats.isFinite, beats != 0, let grid = grid(deck), let frame = playbackSnapshot?[deck].sourceFrame else { return }
        jump(boundedFrame(frame + beats * grid.framesPerBeat, deck: deck), deck: deck, quantized: false)
    }

    /// CUE: while paused it marks the playhead; while playing it returns to the mark and pauses.
    public func pressCue(deck: DeckID) {
        guard track(deck) != nil, let state = playbackSnapshot?[deck] else { return }
        if state.phase.active {
            jump(cuePoints[deck] ?? 0, deck: deck, quantized: false)
            pressPlay(deck: deck)
        } else {
            cuePoints[deck] = state.sourceFrame
        }
    }

    /// The deck whose track seeds recommendations: the other deck when suggesting for a destination,
    /// otherwise the playing deck, then the most recently loaded one.
    public func recommendationSeedDeck(destination: DeckID?) -> DeckID? {
        if let destination {
            let other: DeckID = destination == .a ? .b : .a
            return loaded[other] == nil ? nil : other
        }
        if let playing = DeckID.allCases.first(where: { loaded[$0] != nil && controlDisplay[$0].phase.active }) { return playing }
        if let last = lastLoadedDeck, loaded[last] != nil { return last }
        return DeckID.allCases.first { loaded[$0] != nil }
    }

    /// The seed track as a browser entry, with collection or first-minute tempo and key when unprepared.
    public func recommendationSeed(deck: DeckID) -> LibraryBrowserEntry? {
        guard let track = track(deck) else { return nil }
        let sources = track.musicLibrarySources ?? []
        let item = musicLibraryCatalog?.items.first { sources.contains($0.source) }
        let hints = browserHints
        let hint = sources.lazy.compactMap { hints[$0.id] }.first
        return LibraryBrowserEntry(track: track, nativeItem: item, hint: hint)
    }

    /// Adds to the end of the prep list once; a queued entry is not duplicated.
    public func enqueue(_ entryID: String) {
        guard !queuedIDs.contains(entryID) else { return }
        queuedIDs.append(entryID); saveQueue()
    }
    public func dequeue(_ entryID: String) {
        queuedIDs.removeAll { $0 == entryID }; saveQueue()
    }
    private func saveQueue() {
        let ids = queuedIDs, url = store.root.appendingPathComponent("queue.json")
        Task { await nativeMusic.files.run { try? JSONEncoder().encode(ids).write(to: url, options: .atomic) } }
    }

    /// RESET: back to the collection grid, or the analysed grid when there is none.
    public func resetGrid(deck: DeckID) {
        guard let track = track(deck), !gridLocked.contains(deck) else { return }
        let analysis = track.analysis
        let original = track.traktorPreparation?.normalized.grid ?? analysis.bpm.flatMap { bpm in
            try? BeatGrid(bpm: bpm, anchorFrame: analysis.beatAnchorFrame ?? 0, sampleRate: analysis.sampleRate,
                          downbeatOffset: analysis.detectedDownbeatOffset ?? 0)
        }
        guard let original else { return }
        saveGrid(original, deck: deck)
    }
    /// Makes the given beat the first beat of its bar.
    public func setDownbeat(atBeat beat: Int, deck: DeckID) {
        guard !gridLocked.contains(deck) else { return }
        selectDownbeat(deck: deck, beat: ((beat % 4) + 4) % 4)
    }
    public func toggleHotcuePads(deck: DeckID) {
        if hotcuePadsVisible.remove(deck) == nil { hotcuePadsVisible.insert(deck) } else { hotcueDeleting.remove(deck) }
    }
}

/// Browser and feature preferences, stored per device.
public enum BrowserSettings {
    public static let onlyLoadToOffAirDecksKey = "browser.onlyLoadToOffAirDecks"
    public static let notificationCenterKey = "notifications.center"
    public static let fluxModeKey = "features.fluxMode"
    public static let superSlicerKey = "features.superSlicer"
    public static var onlyLoadToOffAirDecks: Bool { UserDefaults.standard.bool(forKey: onlyLoadToOffAirDecksKey) }
}
