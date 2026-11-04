import Foundation
import Observation

/// The dock and retained deck surfaces share panel state and cancellation gates.
@MainActor
@Observable
final class DeckPanelPresentation {
    private var sizing = DeckPanelsState(extraVisible: false)
    private var hasTrack = false
    private var handleExtent = 44.0
    private var configuredWidth: Double?
    private var configuredPortrait: Bool?
    private var commands = Dictionary(uniqueKeysWithValues: PerformancePanel.allCases.map { ($0, UUID()) })
    private(set) var spaceRequestID = UUID()
    private(set) var spaceRequestKind: PerformancePanel?
    private var dragWasPresented: [PerformancePanel: Bool] = [:]
    let effectsInput = TouchSurfaceInputGate()
    let mixerInput = TouchSurfaceInputGate()
    var effectsVisible: Bool { sizing.isPresented(.effects) }
    var mixerVisible: Bool { sizing.isPresented(.mixer) }
    var extraVisible: Bool { sizing.isPresented(.extra) }
    var isDragging: Bool { sizing.isDragging }

    func configure(width: Double, portrait: Bool, handleExtent: Double = 44) {
        guard width != configuredWidth || portrait != configuredPortrait || self.handleExtent != handleExtent else { return }
        sizing.configure(width: width, portrait: portrait, handleExtent: handleExtent)
        self.handleExtent = handleExtent
        dragWasPresented.removeAll()
        configuredWidth = width; configuredPortrait = portrait
        for kind in PerformancePanel.allCases { commands[kind] = UUID() }
        updateGates()
    }
    func geometry(width: Double, height: Double) -> DeckPanelsGeometry {
        .init(width: width, height: height, effects: sizing.extent(.effects), mixer: sizing.extent(.mixer), extra: sizing.extent(.extra), handleExtent: handleExtent)
    }
    func maximum(_ kind: PerformancePanel) -> Double { sizing.maximum(kind) }
    func presentationID(for kind: PerformancePanel) -> UUID { commands[kind]! }
    func isPresented(_ kind: PerformancePanel) -> Bool { sizing.isPresented(kind) }
    func setTrackAvailable(_ available: Bool) {
        guard available != hasTrack else { return }
        hasTrack = available
        if !available {
            for kind in PerformancePanel.allCases {
                sizing.cancel(kind); sizing.setPresented(kind, false); commands[kind] = UUID()
            }
            updateGates()
        }
    }
    func toggle(_ kind: PerformancePanel) {
        guard hasTrack else { return }
        let opening = !sizing.isPresented(kind)
        let before = Set(PerformancePanel.allCases.filter { sizing.isPresented($0) })
        sizing.setPresented(kind, opening)
        commands[kind] = UUID()
        for other in PerformancePanel.allCases where before.contains(other) != sizing.isPresented(other) { commands[other] = UUID() }
        updateGates()
        if opening && sizing.isPresented(kind) { requestSpace(kind) }
    }
    func begin(_ kind: PerformancePanel) {
        guard hasTrack else { return }
        dragWasPresented[kind] = sizing.isPresented(kind)
        sizing.begin(kind); updateGates()
    }
    func update(_ kind: PerformancePanel, translation: Double) { sizing.update(kind, translation: translation) }
    func end(_ kind: PerformancePanel, velocity: Double) {
        let opening = dragWasPresented.removeValue(forKey: kind) == false
        sizing.end(kind, velocity: velocity); updateGates()
        if opening && sizing.isPresented(kind) { requestSpace(kind) }
    }
    func cancel(_ kind: PerformancePanel) { dragWasPresented[kind] = nil; sizing.cancel(kind); updateGates() }
    func adjust(_ kind: PerformancePanel, by delta: Double) {
        guard hasTrack else { return }
        let opening = !sizing.isPresented(kind)
        sizing.adjust(kind, by: delta); updateGates()
        if opening && sizing.isPresented(kind) { requestSpace(kind) }
    }
    func toggleEffects() { toggle(.effects) }
    func toggleMixer() { toggle(.mixer) }
    private func requestSpace(_ kind: PerformancePanel) {
        spaceRequestKind = kind; spaceRequestID = UUID()
    }
    private func updateGates() {
        effectsInput.setEnabled(effectsVisible)
        mixerInput.setEnabled(mixerVisible)
    }

}
