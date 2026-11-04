import Foundation
import TDJCore
import TDJInterface

/// Explicit synthetic workload. This is not an original-app fidelity policy.
public enum AudioRuntimeKeylockStress: String, Encodable, Sendable {
    case detectedGrid = "detected-grid"
    case manual60BPM = "manual-60-bpm-near2x"
    public var requestedFixtureBPM: Double? { self == .manual60BPM ? 60 : nil }
    public var expectedMinimumSpeed: Double? { requestedFixtureBPM.map { 112 / $0 } }
    public var expectedMaximumSpeed: Double? { requestedFixtureBPM.map { 128 / $0 } }

    @MainActor func prepareLoadedFixture(_ configured: Track, model: ReplicaModel) async throws {
        guard self == .manual60BPM, let grid = configured.grid else { throw TransportError.invalid }
        // Both decks load the library entry before this manual stress preparation.
        await model.flushHistoryWrites()
        for deck in DeckID.allCases { model.saveGrid(grid, deck: deck) }
        await model.flushWrites()
        await model.flushHistoryWrites()
        for deck in DeckID.allCases {
            try model.playback.setSync(true, deck: deck)
            try model.playback.setKeylock(true, deck: deck)
        }
        try model.playback.setMasterBPM(120)
        await model.playback.flushSourcePreparations()
        model.refreshPlayback()
    }

    func configuredFixture(_ original: Track) throws -> Track {
        guard let bpm = requestedFixtureBPM else { return original }
        var result = original
        result.preparation.grid = try BeatGrid(
            bpm: bpm, anchorFrame: 0, sampleRate: original.analysis.sampleRate, downbeatOffset: 0)
        result.preparation.gridIsManual = true
        return result
    }
}

struct RuntimeKeylockStressReport: Encodable, Sendable {
    let format = "generik-dj.keylock-stress/v1"
    let policy: AudioRuntimeKeylockStress
    let requestedFixtureBPM: Double?
    let requestedFixtureGrid: BeatGrid?
    let detectedFixtureBPM: Double?
    let detectedFixtureGrid: BeatGrid?
    let actualInitialGridA: BeatGrid?
    let actualInitialGridB: BeatGrid?
    let actualInitialSpeedA: Double?
    let actualInitialSpeedB: Double?
    let requestedControlMinimumBPM = 112.0
    let requestedControlMaximumBPM = 128.0
    let expectedMinimumSpeed: Double?
    let expectedMaximumSpeed: Double?
    let observedMinimumMasterBPM: Double?
    let observedMaximumMasterBPM: Double?
    let observedMinimumSpeedA: Double?
    let observedMaximumSpeedA: Double?
    let observedMinimumSpeedB: Double?
    let observedMaximumSpeedB: Double?
    let observedSnapshots: Int
    let invalidObservations: Int
    let configurationMatches: Bool
    let observedWorkloadMatches: Bool
    let scope =
        "Synthetic manual-grid stress at approximately 1.867–2.133 tempo ratio. Detected analysis is retained. Not original fidelity, detector accuracy or frame-presentation evidence."
}

/// Scalar observations reuse the existing control snapshot. No extra timer, clock or render work.
struct RuntimeKeylockStressObservation {
    let policy: AudioRuntimeKeylockStress
    let original: Track
    let configured: Track
    let initial: PlaybackSnapshot?
    private(set) var observedSnapshots = 0
    private(set) var invalidObservations = 0
    private var minimumBPM: Double?, maximumBPM: Double?
    private var minimumA: Double?, maximumA: Double?, minimumB: Double?, maximumB: Double?

    init(policy: AudioRuntimeKeylockStress, original: Track, configured: Track, initial: PlaybackSnapshot?) {
        self.policy = policy
        self.original = original
        self.configured = configured
        self.initial = initial
    }
    var configurationMatches: Bool {
        guard let bpm = policy.requestedFixtureBPM, let requested = configured.grid, requested.bpm == bpm,
            configured.preparation.gridIsManual, let initial
        else { return false }
        return initial.a.grid == requested && initial.b.grid == requested && initial.a.synced && initial.b.synced
            && initial.a.keylock && initial.b.keylock && initial.masterBPM.isFinite && initial.masterBPM >= 112
            && initial.masterBPM <= 128 && initial.a.speed.isFinite && initial.b.speed.isFinite
            && abs(initial.a.speed - initial.masterBPM / bpm) < 1e-9
            && abs(initial.b.speed - initial.masterBPM / bpm) < 1e-9
    }
    mutating func observe(_ snapshot: PlaybackSnapshot?) {
        guard let snapshot, let bpm = policy.requestedFixtureBPM, snapshot.masterBPM.isFinite,
            snapshot.a.speed.isFinite, snapshot.b.speed.isFinite
        else {
            invalidObservations += 1
            return
        }
        observedSnapshots += 1
        let expected = snapshot.masterBPM / bpm
        if snapshot.a.grid != configured.grid || snapshot.b.grid != configured.grid || !snapshot.a.synced
            || !snapshot.b.synced || !snapshot.a.keylock || !snapshot.b.keylock
            || abs(snapshot.a.speed - expected) > 1e-9 || abs(snapshot.b.speed - expected) > 1e-9
        {
            invalidObservations += 1
        }
        minimumBPM = min(minimumBPM ?? snapshot.masterBPM, snapshot.masterBPM)
        maximumBPM = max(maximumBPM ?? snapshot.masterBPM, snapshot.masterBPM)
        minimumA = min(minimumA ?? snapshot.a.speed, snapshot.a.speed)
        maximumA = max(maximumA ?? snapshot.a.speed, snapshot.a.speed)
        minimumB = min(minimumB ?? snapshot.b.speed, snapshot.b.speed)
        maximumB = max(maximumB ?? snapshot.b.speed, snapshot.b.speed)
    }
    var report: RuntimeKeylockStressReport {
        let low = policy.expectedMinimumSpeed
        let high = policy.expectedMaximumSpeed
        var observedMatches = false
        if let low, let high, let minimumA, let maximumA, let minimumB, let maximumB {
            // Require both ends of the requested sweep; report exact observed values as well.
            observedMatches =
                observedSnapshots > 0 && invalidObservations == 0 && minimumA >= low - 1e-6 && minimumB >= low - 1e-6
                && maximumA <= high + 1e-6 && maximumB <= high + 1e-6 && minimumA <= low + 1e-4
                && minimumB <= low + 1e-4 && maximumA >= high - 1e-4 && maximumB >= high - 1e-4
        }
        return .init(
            policy: policy, requestedFixtureBPM: policy.requestedFixtureBPM, requestedFixtureGrid: configured.grid,
            detectedFixtureBPM: original.analysis.bpm, detectedFixtureGrid: original.grid,
            actualInitialGridA: initial?.a.grid, actualInitialGridB: initial?.b.grid,
            actualInitialSpeedA: initial?.a.speed, actualInitialSpeedB: initial?.b.speed, expectedMinimumSpeed: low,
            expectedMaximumSpeed: high, observedMinimumMasterBPM: minimumBPM, observedMaximumMasterBPM: maximumBPM,
            observedMinimumSpeedA: minimumA, observedMaximumSpeedA: maximumA, observedMinimumSpeedB: minimumB,
            observedMaximumSpeedB: maximumB, observedSnapshots: observedSnapshots,
            invalidObservations: invalidObservations, configurationMatches: configurationMatches,
            observedWorkloadMatches: configurationMatches && observedMatches)
    }
}
