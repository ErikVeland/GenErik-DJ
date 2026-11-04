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
            let lease = BackgroundSaveLease()
            lease.start()
            Task {
                await model.prepareForBackground()
                lease.end()
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
