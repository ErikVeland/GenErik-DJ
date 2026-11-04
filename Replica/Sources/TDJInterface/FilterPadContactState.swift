import Foundation

/// Contact bookkeeping does not affect the filter pane's appearance.
@MainActor final class FilterPadContactState {
    private var axes = TouchAxisSession()
    private(set) var isTouching = false

    func update(_ event: SurfaceEvent) -> Bool {
        let updateX = axes.updatesX(event)
        isTouching = event.phase != .cancelled && !event.remaining.isEmpty
        return updateX
    }
    func reset() {
        isTouching = false
        axes = TouchAxisSession()
    }
}
