import SwiftUI
import TDJCore

struct RecoverySettingsView: View {
    @Bindable var model: ReplicaModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Recovery", selection: Binding(get: { model.performance.recovery.mode }, set: model.setRecoveryMode))
            { ForEach(RecoveryMode.allCases, id: \.self) { mode in Text(mode.title).tag(mode) } }
            if model.performance.recovery.mode == .autoMix {
                Picker(
                    "Start auto-mix",
                    selection: Binding(get: { model.performance.recovery.leadBars }, set: model.setRecoveryLeadBars)
                ) {
                    Text("8 bars before the end").tag(8)
                    Text("16 bars before the end").tag(16)
                }
                Text("If the next track is not ready, replay the best available section at the final beat.").font(
                    .caption
                ).foregroundStyle(.secondary)
            }
            if model.performance.recovery.mode != .off {
                Text(
                    "Replay waits until the final beat. It uses your marker, a detected drop, or a recent audible section."
                ).font(.caption).foregroundStyle(.secondary)
                ForEach(DeckID.allCases, id: \.self) { deck in
                    if let track = model.track(deck) {
                        HStack {
                            Button("Deck \(deck.rawValue.uppercased()): use playhead as last drop") {
                                model.setRecoveryDropFromPlayhead(deck: deck)
                            }
                            if model.performance.recovery.dropFrames[track.id] != nil {
                                Button("Use estimate") { model.clearRecoveryDrop(deck: deck) }
                            }
                        }
                    }
                }
            }
        }
    }
}
