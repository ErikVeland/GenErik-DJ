import Foundation

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

@MainActor public final class ReplicaLifecycle: NSObject {
    private final class Entry {
        weak var model: ReplicaModel?
        init(_ model: ReplicaModel) { self.model = model }
    }
    private static var models: [ObjectIdentifier: Entry] = [:]
    #if os(iOS)
        private static var libraryAnalysisTasks: LibraryAnalysisBackgroundTasks?
        private static var libraryAnalysisEnvironment: LibraryAnalysisEnvironmentObserver?

        public static func configureBackgroundLibraryAnalysis(_ model: ReplicaModel) {
            guard libraryAnalysisTasks == nil else { return }
            libraryAnalysisEnvironment = LibraryAnalysisEnvironmentObserver(model: model)
            libraryAnalysisTasks = LibraryAnalysisBackgroundTasks(model: model)
        }

        @available(iOS 26, *)
        static func continueLibraryAnalysis(_ model: ReplicaModel) -> Bool {
            guard let libraryAnalysisTasks, libraryAnalysisTasks.model === model else { return false }
            return libraryAnalysisTasks.continueAnalysis()
        }
    #endif
    public static func register(_ model: ReplicaModel) {
        models = models.filter { $0.value.model != nil }
        models[ObjectIdentifier(model)] = Entry(model)
    }
    public static func suspend(_ model: ReplicaModel) {
        model.stopAudio()
        #if os(iOS)
            let lease = BackgroundSaveLease()
            lease.start()
            Task {
                await model.finishForShutdown()
                lease.end()
            }
        #else
            Task { await model.finishForShutdown() }
        #endif
    }
    public static func background(_ model: ReplicaModel) {
        #if os(iOS)
            model.pauseVisualUpdates()
            model.setLibraryAnalysisBackgrounded(true)
            let lease = BackgroundSaveLease()
            lease.start()
            Task {
                await model.prepareForBackground()
                if libraryAnalysisTasks?.model === model { libraryAnalysisTasks?.scheduleIdleAnalysis() }
                lease.end()
            }
        #endif
    }

    static func foreground(_ model: ReplicaModel) {
        model.setLibraryAnalysisBackgrounded(false)
        #if os(iOS)
            if libraryAnalysisTasks?.model === model {
                libraryAnalysisEnvironment?.refresh()
                libraryAnalysisTasks?.enteredForeground()
            }
        #endif
    }
}

#if os(macOS)
    extension ReplicaLifecycle: NSApplicationDelegate {
        public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
            let active = Self.models.values.compactMap(\.model)
            guard !active.isEmpty else { return .terminateNow }
            for model in active { model.stopPlaybackMonitor() }
            Task {
                for model in active { await model.finishForShutdown() }
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }
#else
    @MainActor private final class BackgroundSaveLease {
        private var identifier: UIBackgroundTaskIdentifier = .invalid
        func start() {
            identifier = UIApplication.shared.beginBackgroundTask(withName: "Finish DJ workspace writes") {
                [weak self] in Task { @MainActor in self?.end() }
            }
        }
        func end() {
            guard identifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }
    }
#endif
