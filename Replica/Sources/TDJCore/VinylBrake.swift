import Foundation

public enum VinylBrakeAction: Int32, Sendable {
    case begin = 1, strength = 2, resume = 3
}

extension SampleTransport {
    public func brake(_ action: VinylBrakeAction, duration: Double = 1, strength: Double = 1,
                      deck: DeckID, generation: UInt64) throws {
        try submit(.brake(action, action == .strength ? strength : duration, deck, generation))
    }
}
