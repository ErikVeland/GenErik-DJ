import Foundation
import CTDJTransport

public enum PerformanceEffect: Int, CaseIterable, Sendable {
    case delay, reverb, flanger, gater, beatmasher, digitalLoFi, highPass, lowPass
    case iceverb, transposeStretch, reverseGrain
    public static var supportedCount: Int { Int(TDJ_EFFECT_COUNT) }
    public var name: String {
        switch self {
        case .delay: "Delay"
        case .reverb: "Reverb"
        case .flanger: "Flanger"
        case .gater: "Gater"
        case .beatmasher: "Beatmasher 2"
        case .digitalLoFi: "Digital LoFi"
        case .highPass: "High-pass"
        case .lowPass: "Low-pass"
        case .iceverb: "Iceverb"
        case .transposeStretch: "Transpose Stretch"
        case .reverseGrain: "Reverse Grain"
        }
    }
    /// Beat-grid length chosen by X; matches the renderer's division laws. Nil for untimed effects.
    public func gridBeats(x: Double) -> Double? {
        guard x.isFinite else { return nil }
        let x=min(1,max(0,x))
        switch self {
        case .delay: return 0.25*pow(2,(x*4).rounded())
        case .flanger: return pow(2,(x*4).rounded())
        case .gater: return pow(2,(x*4).rounded()-5)
        case .beatmasher: return pow(2,(x*3).rounded()-3)
        default: return nil
        }
    }
    public static func beatLabel(_ beats: Double) -> String {
        if beats >= 1 { let count=Int(beats.rounded()); return count == 1 ? "1 beat" : "\(count) beats" }
        return "1/\(Int((1/beats).rounded())) beat"
    }
}
