import Foundation

public enum BassAssistanceMode: Int32, Codable, CaseIterable, Sendable {
    case off, measure, handover

    public var title: String {
        switch self {
        case .off: "Off"
        case .measure: "Measure only"
        case .handover: "Bass handover"
        }
    }
}

public struct BassAssistanceMeter: Equatable, Sendable {
    public let available: Bool
    public let leader: DeckID?
    public let correlation: Double
    public let cancellationDB: Double
    public let reductionADB: Double
    public let reductionBDB: Double

    public init(
        available: Bool = false, leader: DeckID? = nil, correlation: Double = 0, cancellationDB: Double = 0,
        reductionADB: Double = 0, reductionBDB: Double = 0
    ) {
        self.available = available
        self.leader = leader
        self.correlation = correlation
        self.cancellationDB = cancellationDB
        self.reductionADB = reductionADB
        self.reductionBDB = reductionBDB
    }
}
