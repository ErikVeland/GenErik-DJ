import Foundation

// After initialization, access and release the payload only on its worker.
final class BackgroundWorkValue<Value: Sendable>: @unchecked Sendable {
    private var value: Value?
    private let worker: BackgroundFileWork
    init(_ value: Value, worker: BackgroundFileWork) {
        self.value = value
        self.worker = worker
    }
    func update<Result: Sendable>(_ work: @escaping @Sendable (inout Value) -> Result) async -> Result? {
        await worker.run {
            guard self.value != nil else { return nil }
            return work(&self.value!)
        }
    }
    @MainActor func clear() async { await worker.run { self.value = nil } }
}
