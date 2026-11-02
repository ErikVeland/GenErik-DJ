import Foundation

final class SecurityScopedFileAccess: Sendable {
    private let files = BackgroundFileWork(label: "org.generikdj.import-access")
    private let start: @Sendable (URL) -> Bool
    private let stop: @Sendable (URL) -> Void
    init(start: @escaping @Sendable (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
         stop: @escaping @Sendable (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }) {
        self.start = start; self.stop = stop
    }
    @MainActor func withAccess<Value: Sendable>(to url: URL,
        operation: @MainActor () async throws -> Value) async throws -> Value {
        let scoped = await files.run { self.start(url) }
        let outcome: Result<Value, any Error>
        do { outcome = .success(try await operation()) }
        catch { outcome = .failure(error) }
        // Release remains owned and awaited after errors or cancellation.
        if scoped { await files.run { self.stop(url) } }
        return try outcome.get()
    }
}
