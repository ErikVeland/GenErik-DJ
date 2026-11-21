import Foundation
import TDJCore

struct PerformanceRecommendationHistory: Sendable, Codable {
    static let filename = "performance-recommendations.json"
    var startedAt: Date?
    var identities: Set<String> = []

    static func restore(_ data: Data?, for startedAt: Date?) -> Self {
        guard let startedAt, let data,
            let saved = try? JSONDecoder().decode(Self.self, from: data), saved.startedAt == startedAt
        else { return .init(startedAt: startedAt) }
        return saved
    }

    static func isOnMaster(
        phase: PlaybackPhase, touching: Bool, forwardRender: Bool, peak: Double, volume: Double,
        assignment: CrossfaderAssignment?, crossfader: Double, master: Double
    ) -> Bool {
        guard phase == .playing, !touching, forwardRender, peak.isFinite, volume.isFinite, master.isFinite,
            peak > 0, volume > 0, master > 0, crossfader.isFinite
        else { return false }
        let cross = min(1, max(0, crossfader))
        let gain: Double = switch assignment {
        case .left: 1 - max(0, 2 * cross - 1)
        case .right: 1 - max(0, 1 - 2 * cross)
        case .through, nil: 1
        }
        return peak * volume * gain * master > 0.000_000_1
    }
}
