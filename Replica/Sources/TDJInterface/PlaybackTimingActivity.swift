#if os(macOS)
import Foundation

/// Retains timer and I/O precision for the live output engine.
final class PlaybackTimingActivity: @unchecked Sendable {
    private let processInfo: ProcessInfo
    private let token: any NSObjectProtocol

    init() {
        let processInfo = ProcessInfo.processInfo
        self.processInfo = processInfo
        token = processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "Playing and recording DJ audio")
    }

    deinit { processInfo.endActivity(token) }
}
#endif
