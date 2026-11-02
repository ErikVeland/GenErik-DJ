import Foundation

/// Synchronous secondary file work has a QoS boundary independent of an awaiting task.
/// Cancellation does not discard submitted work: callers retain their cache/write lifecycle.
final class BackgroundFileWork: Sendable {
    private let queue: DispatchQueue
    init(label: String) { queue=DispatchQueue(label:label,qos:.background) }

    func run<Value: Sendable>(_ work: @escaping @Sendable () -> Value) async -> Value {
        await withCheckedContinuation { continuation in
            queue.async(qos:.background,flags:.enforceQoS) {
                continuation.resume(returning:work())
            }
        }
    }
}
