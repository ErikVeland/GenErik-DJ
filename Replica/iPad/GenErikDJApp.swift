import SwiftUI
import TDJInterface

@main struct GenErikDJApp: App {
    private let model: ReplicaModel?
    init() {
        let root = URL.documentsDirectory.appendingPathComponent("GenErikDJ-Development", isDirectory: true)
        // A collection export placed in the app's Documents (Files › On My iPad) imports automatically.
        // It is only read; the original stays where it is.
        let inbox = ["collection.nml.gz", "collection.nml"].map { URL.documentsDirectory.appendingPathComponent($0) }
        model = try? ReplicaModel(root: root, discoverSyncedTraktor: true, automaticTraktorSources: inbox)
        if let model { ReplicaLifecycle.configureBackgroundLibraryAnalysis(model) }
    }
    var body: some Scene {
        WindowGroup {
            if let model {
                ReplicaView(model: model)
            } else {
                Text("Cannot open the development workspace. Its original files were retained.").padding()
            }
        }
    }
}
