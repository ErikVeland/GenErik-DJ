import SwiftUI
import Observation
import TDJCore

/// The dock and retained deck surfaces share panel state and cancellation gates.
@MainActor
@Observable
final class DeckPanelPresentation {
    private(set) var effectsVisible = false
    private(set) var mixerVisible = false
    let effectsInput = TouchSurfaceInputGate()
    let mixerInput = TouchSurfaceInputGate()

    func toggleEffects() {
        effectsInput.setEnabled(!effectsVisible)
        effectsVisible.toggle()
    }

    func toggleMixer() {
        mixerInput.setEnabled(!mixerVisible)
        mixerVisible.toggle()
    }
}

@MainActor
struct PerformanceDock: View {
    @Bindable var model: ReplicaModel
    let panelsA: DeckPanelPresentation
    let panelsB: DeckPanelPresentation
    let geometry: PerformanceDockGeometry

    var body: some View {
        ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                stack(deck: .a, panels: panelsA, buttons: geometry.aButtons)
                CrossfaderView(model: model, width: geometry.crossfader.width, showsDeckLabels: false)
                    .frame(height: geometry.crossfader.height)
                    .position(x: localX(geometry.crossfader), y: geometry.crossfader.midY)
                stack(deck: .b, panels: panelsB, buttons: geometry.bButtons)
            }
            .frame(width: PerformanceDockGeometry.dockWidth, height: geometry.contentHeight)
        }
        .scrollDisabled(geometry.fits)
        .scrollIndicators(.hidden)
        .frame(width: PerformanceDockGeometry.dockWidth, height: geometry.workArea.height)
        .background(PerformancePalette.frame)
    }

    private func stack(deck: DeckID, panels: DeckPanelPresentation, buttons: [CGRect]) -> some View {
        ZStack(alignment: .topLeading) {
            Text(deck.rawValue.uppercased()).font(.system(size: 13, weight: .bold))
                .frame(width: buttons[0].width, height: 20)
                .position(x: localX(buttons[0]), y: buttons[0].minY - 10)
                .accessibilityHidden(true)
            Button("FX") { panels.toggleEffects() }
                .foregroundStyle(panels.effectsVisible ? Color.orange : PerformancePalette.secondaryText)
                .accessibilityLabel("Effects for deck \(deck.rawValue.uppercased())")
                .dockTarget(buttons[0], originX: geometry.workArea.width)
            Button("EQ") { panels.toggleMixer() }
                .foregroundStyle(panels.mixerVisible ? PerformancePalette.cyan : PerformancePalette.secondaryText)
                .accessibilityLabel("EQ and filter for deck \(deck.rawValue.uppercased())")
                .dockTarget(buttons[1], originX: geometry.workArea.width)
            Button { model.toggleLoop(deck: deck) } label: { Image(systemName: "repeat") }
                .foregroundStyle(model.playbackSnapshot?[deck].loopEnabled == true ? PerformancePalette.syncGreen : PerformancePalette.text)
                .disabled(model.track(deck) == nil)
                .accessibilityLabel("Loop on deck \(deck.rawValue.uppercased())")
                .dockTarget(buttons[2], originX: geometry.workArea.width)
            DeckPlaybackButton(model: model, deck: deck)
                .dockTarget(buttons[3], originX: geometry.workArea.width)
        }
        .font(.system(size: 22, weight: .heavy))
        .buttonStyle(DeckRailButtonStyle())
    }

    private func localX(_ rectangle: CGRect) -> CGFloat { rectangle.midX - geometry.workArea.width }
}

private extension View {
    func dockTarget(_ rectangle: CGRect, originX: CGFloat) -> some View {
        frame(width: rectangle.width, height: rectangle.height)
            .position(x: rectangle.midX - originX, y: rectangle.midY)
    }
}
