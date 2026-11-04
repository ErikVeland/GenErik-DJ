import SwiftUI
import TDJInterface

@main struct GenErikDJAudioCheckApp: App {
    @State private var model = AudioCheckModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            Group {
                if let replica = model.liveReplica {
                    ReplicaView(
                        model: replica,
                        snapshotEffectsDeck: model.panelLayout.effectsOnA
                            ? .a : model.panelLayout.effectsOnB ? .b : nil,
                        snapshotMixerDecks: model.panelLayout.mixerOnA ? [.a] : model.panelLayout.mixerOnB ? [.b] : [],
                        snapshotFilterDecks: model.panelLayout.filterOnA
                            ? [.a] : model.panelLayout.filterOnB ? [.b] : []
                    ).disabled(true).allowsHitTesting(false).accessibilityHidden(true).overlay(alignment: .topTrailing)
                    {
                        HStack {
                            Text("Interface check").font(.caption)
                            Button("Cancel", role: .destructive) { model.cancel() }
                        }.padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding(8)
                    }
                } else {
                    AudioCheckView(model: model)
                }
            }.onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { model.becameActive() } else { model.cancel() }
            }
        }
    }
}
