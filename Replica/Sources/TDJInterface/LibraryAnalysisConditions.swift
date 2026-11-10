import Foundation

#if os(iOS)
    import UIKit
#endif

struct LibraryAnalysisConditions: Equatable, Sendable {
    var externalPower: Bool
    var thermalState: ProcessInfo.ThermalState

    static var initial: Self {
        #if os(iOS)
            .init(externalPower: false, thermalState: ProcessInfo.processInfo.thermalState)
        #else
            .init(externalPower: true, thermalState: .nominal)
        #endif
    }

    var pauseMessage: String? {
        guard externalPower else { return "Connect power to continue detailed analysis." }
        switch thermalState {
        case .nominal, .fair: return nil
        case .serious, .critical: return "Detailed analysis will resume when the device cools."
        @unknown default: return "Detailed analysis is waiting for a suitable device temperature."
        }
    }
}

extension ReplicaModel {
    func updateLibraryAnalysisConditions(_ conditions: LibraryAnalysisConditions) {
        let state = nativeMusic
        guard state.conditions != conditions else { return }
        state.conditions = conditions
        if let message = conditions.pauseMessage {
            macSourceTransferWork?.cancel()
            if state.activePass != .matching, state.activePass != nil, libraryAnalysisOwner != nil {
                state.waitingForStructure = (musicLibraryCatalogVersion, library.revision)
                cancelNativeMusicAnalysis()
            }
            if state.waitingForStructure != nil { analysisProgress?.message = message }
        } else {
            startNativeMusicAnalysis()
        }
    }
}

#if os(iOS)
    @MainActor final class LibraryAnalysisEnvironmentObserver: NSObject {
        private weak var model: ReplicaModel?

        init(model: ReplicaModel) {
            self.model = model
            super.init()
            UIDevice.current.isBatteryMonitoringEnabled = true
            let center = NotificationCenter.default
            center.addObserver(
                self, selector: #selector(changed), name: UIDevice.batteryStateDidChangeNotification, object: nil)
            center.addObserver(
                self, selector: #selector(changed), name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
            refresh()
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        @objc private nonisolated func changed() {
            Task { @MainActor [weak self] in self?.refresh() }
        }

        static var current: LibraryAnalysisConditions {
            let battery = UIDevice.current.batteryState
            return .init(
                externalPower: battery == .charging || battery == .full,
                thermalState: ProcessInfo.processInfo.thermalState)
        }

        func refresh() { model?.updateLibraryAnalysisConditions(Self.current) }
    }
#endif
