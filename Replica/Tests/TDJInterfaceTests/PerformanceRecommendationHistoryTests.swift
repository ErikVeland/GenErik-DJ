import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func recommendationMasterSignalIgnoresCueOnlyOrSilentDecks() {
    func onMaster(_ phase: PlaybackPhase = .playing, touching: Bool = false, advanced: Bool = true,
                  peak: Double = 0.4, volume: Double = 1, cross: Double = 0.5, master: Double = 1,
                  assignment: CrossfaderAssignment? = .left) -> Bool {
        PerformanceRecommendationHistory.isOnMaster(
            phase: phase, touching: touching, forwardRender: advanced, peak: peak, volume: volume,
            assignment: assignment, crossfader: cross, master: master)
    }
    #expect(onMaster())
    #expect(onMaster(cross: 1, assignment: .through))
    #expect(!onMaster(.queued))
    #expect(!onMaster(.ready))
    #expect(!onMaster(.paused))
    #expect(!onMaster(touching: true))
    #expect(!onMaster(advanced: false))
    #expect(!onMaster(peak: 0))
    #expect(!onMaster(volume: 0))
    #expect(!onMaster(cross: 1))
    #expect(!onMaster(cross: 0, assignment: .right))
    #expect(!onMaster(master: 0))
}

@Test func recommendationHistoryResumesOnlyTheSamePerformance() throws {
    let start = Date(timeIntervalSince1970: 1_000)
    let old = PerformanceRecommendationHistory(startedAt: start, identities: ["first"])
    let data = try JSONEncoder().encode(old)
    #expect(PerformanceRecommendationHistory.restore(data, for: start).identities == ["first"])
    #expect(PerformanceRecommendationHistory.restore(data, for: nil).identities.isEmpty)
    #expect(PerformanceRecommendationHistory.restore(data, for: start.addingTimeInterval(1)).identities.isEmpty)
}
