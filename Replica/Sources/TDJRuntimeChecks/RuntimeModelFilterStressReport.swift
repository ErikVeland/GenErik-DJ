import Foundation
import TDJCore

struct RuntimeFilterStressObservation {
    struct Range {
        var activeBatches = 0
        var minimumX: Double?, maximumX: Double?, minimumY: Double?, maximumY: Double?
        mutating func observe(_ state: DeckMixerSnapshot) {
            guard state.filterEnabled else { return }
            activeBatches += 1
            minimumX = min(minimumX ?? state.filterX, state.filterX)
            maximumX = max(maximumX ?? state.filterX, state.filterX)
            minimumY = min(minimumY ?? state.filterY, state.filterY)
            maximumY = max(maximumY ?? state.filterY, state.filterY)
        }
        var x: [Double] { minimumX.flatMap { a in maximumX.map { [a, $0] } } ?? [] }
        var y: [Double] { minimumY.flatMap { a in maximumY.map { [a, $0] } } ?? [] }
    }
    var a = Range(), b = Range()
    mutating func observe(_ snapshot: PlaybackSnapshot?) {
        guard let snapshot else { return }
        a.observe(snapshot.a.mixer)
        b.observe(snapshot.b.mixer)
    }
}

struct RuntimeModelFilterStressReport: Codable, Sendable {
    let path: String
    let setupTouches: Int, controlTouches: Int, expectedControlTouches: Int, cancelledContacts: Int,
        cancellationFailures: Int
    let activeBatchesA: Int, activeBatchesB: Int
    let filterARangeX: [Double], filterARangeY: [Double], filterBRangeX: [Double], filterBRangeY: [Double]
    let persistedStateMatches: Bool, filtersDisabledAfterShutdown: Bool, passed: Bool
    let scope: String
    init(
        batches: Int, setupTouches: Int, controlTouches: Int, cancelledContacts: Int, cancellationFailures: Int,
        observation: RuntimeFilterStressObservation, persistedStateMatches: Bool, filtersDisabledAfterShutdown: Bool
    ) {
        path = "FilterPadContactState.update/ReplicaModel.filterTouch"
        scope =
            "Two active model filter touches per batch. Native snapshots must show both filters active and both axes changing. Physical input, presented frames and NI parity remain separate."
        self.setupTouches = setupTouches
        self.controlTouches = controlTouches
        expectedControlTouches = batches * 2
        self.cancellationFailures = cancellationFailures
        self.cancelledContacts = cancelledContacts
        activeBatchesA = observation.a.activeBatches
        activeBatchesB = observation.b.activeBatches
        filterARangeX = observation.a.x
        filterARangeY = observation.a.y
        filterBRangeX = observation.b.x
        filterBRangeY = observation.b.y
        self.persistedStateMatches = persistedStateMatches
        self.filtersDisabledAfterShutdown = filtersDisabledAfterShutdown
        let varied = [observation.a.x, observation.a.y, observation.b.x, observation.b.y].allSatisfy {
            $0.count == 2 && $0.allSatisfy(\.isFinite) && $0[1] > $0[0]
        }
        passed =
            batches > 0 && setupTouches == 2 && controlTouches == expectedControlTouches && cancelledContacts == 2
            && cancellationFailures == 0 && activeBatchesA == batches && activeBatchesB == batches && varied
            && persistedStateMatches && filtersDisabledAfterShutdown
    }
}
