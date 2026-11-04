import Foundation

/// Pull-down dismissal for the songs pane. The pane follows the finger 1:1. Release closes it
/// after a long enough pull or a downward flick; otherwise it springs back.
struct PaneDismissGesture {
    static let distance = 120.0
    /// Points per second.
    static let flickVelocity = 600.0
    static func offset(translation: Double) -> Double { translation.isFinite ? max(0, translation) : 0 }
    static func dismisses(translation: Double, velocity: Double) -> Bool {
        guard translation.isFinite, velocity.isFinite else { return false }
        return translation >= distance || (translation > 12 && velocity >= flickVelocity)
    }
}
