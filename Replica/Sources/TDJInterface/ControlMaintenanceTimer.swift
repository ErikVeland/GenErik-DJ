import Foundation

/// Keeps control acknowledgements on the same queue as performance input.
final class ControlMaintenanceTimer: @unchecked Sendable {
    private let source: any DispatchSourceTimer

    init(action: @escaping @Sendable () -> Void) {
        source = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        source.setEventHandler { [weak self] in
            guard let self, !self.source.isCancelled else { return }
            action()
        }
        source.schedule(deadline: .now(), repeating: .milliseconds(10), leeway: .nanoseconds(0))
        source.resume()
    }

    deinit { source.cancel() }
}
