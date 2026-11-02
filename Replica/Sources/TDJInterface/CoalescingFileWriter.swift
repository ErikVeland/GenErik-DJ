import Foundation

/// UI mutations replace pending snapshots. Encoding and atomic I/O run serially off the main actor.
@MainActor
final class CoalescingFileWriter<Value: Sendable> {
    private let worker=BackgroundFileWork(label:"org.generikdj.coalescing-file-writer")
    private var pending: (Value, @Sendable (Value) throws -> Void)?
    private var task: Task<Void, Never>?
    private var reportError: ((String) -> Void)?

    func enqueue(_ value: Value, write: @escaping @Sendable (Value) throws -> Void,
                 reportError: @escaping (String) -> Void) {
        pending=(value,write)
        self.reportError=reportError
        guard task == nil else { return }
        task=Task {
            while let (value,write)=pending {
                pending=nil
                let error=await worker.run { () -> String? in
                    do { try write(value); return nil }
                    catch { return error.localizedDescription }
                }
                if let error { self.reportError?(error) }
            }
            task=nil
        }
    }
    func flush() async { await task?.value }
}
