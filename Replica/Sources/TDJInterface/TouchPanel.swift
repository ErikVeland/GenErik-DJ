import SwiftUI

struct TouchPanelHandle: View {
    let presented: Bool
    let maximumExtent: Double
    let presentationID: UUID
    let toggle: () -> Void
    let begin: () -> Void
    let update: (Double) -> Void
    let end: (Double) -> Void
    let cancel: () -> Void
    let adjust: (Double) -> Void
    @GestureState private var active = false
    @State private var vertical: Bool?
    @State private var ignoreUntilRelease = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggle) {
                Image(systemName: presented ? "chevron.down" : "chevron.up")
                    .frame(width: 44, height: 44)
            }.accessibilityLabel(presented ? "Hide music library" : "Show music library")
            Spacer(minLength: 0)
            Capsule().fill(PerformancePalette.secondaryText).frame(width: 44, height: 4)
            Spacer(minLength: 0)
            Text("LIBRARY").font(.system(size: 11, weight: .semibold)).padding(.trailing, 12)
        }
        .frame(height: AdaptivePerformanceLayout.libraryHandleHeight)
        .background(PerformancePalette.frame)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($active) { _, active, _ in active = true }
            .onChanged { value in
                guard !ignoreUntilRelease else { return }
                if vertical == nil {
                    vertical = abs(value.translation.height) >= abs(value.translation.width)
                    if vertical == true { begin() }
                }
                if vertical == true { update(-value.translation.height) }
            }
            .onEnded { value in
                if vertical == true, !ignoreUntilRelease {
                    update(-value.translation.height)
                    end(-value.velocity.height)
                }
                vertical = nil
                ignoreUntilRelease = false
            })
        .onChange(of: active) { _, active in
            if !active { cancel(); vertical = nil; ignoreUntilRelease = false }
        }
        .onChange(of: maximumExtent) { _, _ in invalidateDrag() }
        .onChange(of: presentationID) { _, _ in invalidateDrag() }
        .onDisappear { cancel() }
        .accessibilityLabel("Music library resize handle")
        .accessibilityAdjustableAction { direction in adjust(direction == .increment ? 44 : -44) }
    }

    private func invalidateDrag() {
        if active { cancel(); ignoreUntilRelease = true }
    }
}
