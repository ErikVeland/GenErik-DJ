import Foundation
import Observation

/// The dock and retained deck surfaces share panel state and cancellation gates.
@MainActor
@Observable
final class DeckPanelPresentation {
    private var sizing = DeckPanelsState()
    private var configuredWidth: Double?
    private var configuredPortrait: Bool?
    private(set) var presentationID = UUID()
    let effectsInput = TouchSurfaceInputGate()
    let mixerInput = TouchSurfaceInputGate()
    var effectsVisible: Bool { sizing.isPresented(.effects) }
    var mixerVisible: Bool { sizing.isPresented(.mixer) }
    var extraVisible: Bool { sizing.isPresented(.extra) }
    var isDragging: Bool { sizing.isDragging }

    func configure(width: Double, portrait: Bool) {
        guard width != configuredWidth || portrait != configuredPortrait else { return }
        sizing.configure(width: width, portrait: portrait)
        configuredWidth = width; configuredPortrait = portrait
        presentationID = UUID()
        updateGates()
    }
    func geometry(width: Double, height: Double) -> DeckPanelsGeometry {
        .init(width: width, height: height, effects: sizing.extent(.effects), mixer: sizing.extent(.mixer), extra: sizing.extent(.extra))
    }
    func maximum(_ kind: PerformancePanel) -> Double { sizing.maximum(kind) }
    func isPresented(_ kind: PerformancePanel) -> Bool { sizing.isPresented(kind) }
    func toggle(_ kind: PerformancePanel) {
        sizing.setPresented(kind, !sizing.isPresented(kind)); presentationID = UUID(); updateGates()
    }
    func begin(_ kind: PerformancePanel) { sizing.begin(kind); updateGates() }
    func update(_ kind: PerformancePanel, translation: Double) { sizing.update(kind, translation: translation) }
    func end(_ kind: PerformancePanel, velocity: Double) { sizing.end(kind, velocity: velocity); updateGates() }
    func cancel(_ kind: PerformancePanel) { sizing.cancel(kind); updateGates() }
    func adjust(_ kind: PerformancePanel, by delta: Double) { sizing.adjust(kind, by: delta); updateGates() }
    func toggleEffects() { toggle(.effects) }
    func toggleMixer() { toggle(.mixer) }
    private func updateGates() {
        effectsInput.setEnabled(effectsVisible)
        mixerInput.setEnabled(mixerVisible)
    }

}

