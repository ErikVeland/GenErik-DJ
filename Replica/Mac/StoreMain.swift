import SwiftUI
import TDJInterface

@main struct GenErikDJStoreApp: App {
    @NSApplicationDelegateAdaptor(ReplicaLifecycle.self) private var lifecycle

    private var workspace: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GenErikDJ", isDirectory: true)
    }

    var body: some Scene {
        WindowGroup("GenErik DJ") {
            Group {
                if let model = try? ReplicaModel(root: workspace, discoverSyncedTraktor: false) {
                    ReplicaView(model: model)
                } else {
                    Text("Cannot open the saved library. Your files remain unchanged.").padding(30)
                }
            }.frame(minWidth: 800, minHeight: 600)
        }.defaultSize(width: 1024, height: 768)
    }
}
