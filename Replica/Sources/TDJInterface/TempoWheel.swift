import SwiftUI

struct TempoWheel: View {
    @Bindable var model: ReplicaModel
    @State private var gesture = TempoWheelGestureSession()
    private let blue = Color(red: 0.40, green: 0.57, blue: 0.98)
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle().fill(Color(red: 0.085, green: 0.105, blue: 0.16).opacity(0.98))
                Circle().fill(Color.black.opacity(0.7)).padding(12)
                Circle().stroke(blue.opacity(0.3), lineWidth: 13).padding(24)
                Circle().fill(blue.opacity(0.4)).frame(width: 48, height: 48)
                Text(String(format: "%.2f", model.playbackSnapshot?.masterBPM ?? 120)).font(
                    .system(size: 13, weight: .medium, design: .monospaced))
                TouchSurface { event in
                    gesture.handle(
                        event, width: Double(geometry.size.width), height: Double(geometry.size.height),
                        bpm: model.playbackSnapshot?.masterBPM ?? 120, resetTempo: { model.resetMasterTempo() }
                    ) { model.setMasterBPM($0) }
                }
            }
        }.frame(width: 168, height: 168).accessibilityLabel("Master tempo wheel").accessibilityHint(
            "Double-tap to reset to the sync master track's original BPM"
        ).accessibilityAction(named: "Reset to original BPM") { model.resetMasterTempo() }.onDisappear {
            gesture.handle(
                .init(phase: .cancelled, points: [], ending: []), width: 168, height: 168,
                bpm: model.playbackSnapshot?.masterBPM ?? 120, change: { _ in })
        }
    }
}
