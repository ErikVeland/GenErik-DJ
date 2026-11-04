import SwiftUI

struct DeckSplitHandle: View {
    let interruption: UUID
    let aShare: Double
    let begin: () -> Void
    let update: (Double) -> Void
    let end: () -> Void
    let cancel: () -> Void
    let balance: () -> Void
    let adjust: (Double) -> Void
    @AppStorage(DeckToolSettings.largePanelHandles) private var largeHandles = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    private var metrics: PanelHandleMetrics { .init(expanded: largeHandles || voiceOver) }
    @GestureState private var active = false
    @State private var ownsDrag: Bool?
    @State private var ignoreUntilRelease = false

    var body: some View {
        Group {
            if metrics.expanded {
                HStack(spacing: 8) {
                    Label("A", systemImage: "chevron.up").padding(.leading, 12)
                    Spacer(minLength: 0)
                    Capsule().fill(PerformancePalette.secondaryText).frame(width: 44, height: 4)
                    Spacer(minLength: 0)
                    Label("B", systemImage: "chevron.down").padding(.trailing, 12)
                }.font(.system(size: 11, weight: .semibold)).frame(height: DeckSplitGeometry.handleHeight).background(
                    PerformancePalette.frame)
            } else {
                Capsule().fill(PerformancePalette.secondaryText.opacity(active ? 0.65 : 0.12)).frame(
                    width: 28, height: 1
                ).frame(maxWidth: .infinity).frame(height: metrics.extent)
            }
        }.contentShape(Rectangle()).gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global).updating($active) { _, active, _ in active = true
            }.onChanged { value in
                guard !ignoreUntilRelease else { return }
                if ownsDrag == nil {
                    ownsDrag = abs(value.translation.height) >= abs(value.translation.width)
                    if ownsDrag == true { begin() }
                }
                if ownsDrag == true { update(value.translation.height) }
            }.onEnded { value in
                if ownsDrag == true, !ignoreUntilRelease {
                    update(value.translation.height)
                    end()
                }
                ownsDrag = nil
                ignoreUntilRelease = false
            }
        ).onTapGesture(count: 2, perform: balance).onChange(of: active) { _, active in
            if !active {
                cancel()
                ownsDrag = nil
                ignoreUntilRelease = false
            }
        }.onChange(of: interruption) { _, _ in
            if active {
                cancel()
                ignoreUntilRelease = true
            }
        }.onDisappear(perform: cancel).accessibilityElement(children: .ignore).accessibilityLabel(
            "Deck A/B resize handle"
        ).accessibilityValue("A \(Int(aShare * 100)) percent, B \(Int((1 - aShare) * 100)) percent").accessibilityHint(
            "Drag to resize. Double-tap to give both decks equal space."
        ).accessibilityAdjustableAction { adjust($0 == .increment ? 44 : -44) }.accessibilityAction(
            named: Text("Equal deck sizes"), balance)
    }
}
