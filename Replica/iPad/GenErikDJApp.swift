import SwiftUI
import TDJInterface
import UIKit

@main struct GenErikDJApp: App {
    private let model: ReplicaModel?
    @Environment(\.scenePhase) private var scenePhase
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
                    .onChange(of: scenePhase == .active && model.analysisIsRunning, initial: true) { _, analyzing in
                        updateIdleTimer(whileAnalyzing: analyzing)
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
                            .receive(on: RunLoop.main)
                    ) { _ in
                        updateIdleTimer(whileAnalyzing: scenePhase == .active && model.analysisIsRunning)
                    }
                    .onDisappear { updateIdleTimer(whileAnalyzing: false) }
            } else {
                Text("Cannot open the development workspace. Its original files were retained.").padding()
            }
        }
    }

    private func updateIdleTimer(whileAnalyzing analyzing: Bool) {
        guard analyzing else {
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let state = device.batteryState
        UIApplication.shared.isIdleTimerDisabled = state == .charging || state == .full
    }
}
