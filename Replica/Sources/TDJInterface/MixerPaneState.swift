import Foundation

/// Pane gates register with the drawer gate, preserving synchronous outer cancellation.
@MainActor final class MixerPaneInputSession {
    let equalizer = TouchSurfaceInputGate()
    let filter = TouchSurfaceInputGate()
    private(set) var selection = MixerPanel.equalizer
    private var presented = false
    private var bound = false
    private weak var parent: TouchSurfaceInputGate?
    private var parentRegistration: UUID?

    init() { closePanes() }

    func bindParent(_ next: TouchSurfaceInputGate?) {
        guard !bound || parent !== next else { return }
        closePanes()
        parent?.removeEnabledObserver(parentRegistration)
        parent = next
        bound = true
        parentRegistration = next?.observeEnabled { [weak self] _ in self?.updateGates() }
        updateGates()
    }
    func synchronize(selection: MixerPanel, presented: Bool) {
        if self.selection != selection || !presented { closePanes() }
        self.selection = selection
        self.presented = presented
        updateGates()
    }
    func select(_ next: MixerPanel, commit: () -> Void) {
        if selection != next { closePanes() }
        selection = next
        // The outgoing contacts have ended before the binding changes.
        commit()
        updateGates()
    }
    func unbind() {
        presented = false
        closePanes()
        parent?.removeEnabledObserver(parentRegistration)
        parentRegistration = nil
        parent = nil
        bound = false
    }
    private func closePanes() {
        equalizer.setEnabled(false)
        filter.setEnabled(false)
    }
    private func updateGates() {
        let allowed = bound && presented && parent?.isEnabled != false
        equalizer.setEnabled(allowed && selection == .equalizer)
        filter.setEnabled(allowed && selection == .filter)
    }
}

/// An inactive retained pane does not read or observe its live source.
struct MixerPaneDisplayCache<Value> {
    private(set) var frozen: Value
    init(_ initial: Value) { frozen = initial }
    func value(active: Bool, read: () -> Value) -> Value { active ? read() : frozen }
    mutating func freeze(_ value: Value) { frozen = value }
}

struct MixerEqualizerDisplayValue: Equatable {
    let low: Double, mid: Double, high: Double, volume: Double
    init(low: Double = 1, mid: Double = 1, high: Double = 1, volume: Double = 1) {
        self.low = low
        self.mid = mid
        self.high = high
        self.volume = volume
    }
    @MainActor init(_ state: MixerControlDisplay) {
        self.init(low: state.low, mid: state.mid, high: state.high, volume: state.volume)
    }
}

struct MixerFilterDisplayValue: Equatable {
    let x: Double, y: Double
    let enabled: Bool
    init(x: Double = 0, y: Double = 0, enabled: Bool = false) {
        self.x = x
        self.y = y
        self.enabled = enabled
    }
    @MainActor init(_ state: MixerControlDisplay) {
        self.init(x: state.filterX, y: state.filterY, enabled: state.filterEnabled)
    }
}
