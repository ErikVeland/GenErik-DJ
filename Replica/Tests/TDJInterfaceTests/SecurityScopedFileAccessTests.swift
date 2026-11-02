import Foundation
import Darwin
import Testing
@testable import TDJInterface

private final class ScopeEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [(String, Bool, UInt32)] = []
    func record(_ name: String) { lock.withLock { entries.append((name, Thread.isMainThread, qos_class_self().rawValue)) } }
    var names: [String] { lock.withLock { entries.map(\.0) } }
    var permissionCallsOffMain: Bool { lock.withLock { entries.filter { $0.0 != "operation" }.allSatisfy { !$0.1 && $0.2 == QOS_CLASS_BACKGROUND.rawValue } } }
}
private enum ScopeFailure: Error { case expected }

@Test @MainActor func securityScopeKeepsAccessUntilSuccessfulOperationEndsOffMain() async throws {
    let events = ScopeEvents(), url = URL(fileURLWithPath: "/synthetic/import.wav")
    let access = SecurityScopedFileAccess(start: { received in
        #expect(received == url); events.record("start"); return true
    }, stop: { received in #expect(received == url); events.record("stop") })
    let value = try await access.withAccess(to: url) {
        MainActor.preconditionIsolated()
        #expect(events.names == ["start"]); events.record("operation"); return 73
    }
    #expect(value == 73 && events.names == ["start", "operation", "stop"])
    #expect(events.permissionCallsOffMain)
}

@Test @MainActor func securityScopeDoesNotStopAccessThatWasNotGranted() async throws {
    let events = ScopeEvents()
    let access = SecurityScopedFileAccess(start: { _ in events.record("start"); return false }, stop: { _ in events.record("stop") })
    let value = try await access.withAccess(to: URL(fileURLWithPath: "/synthetic/local.wav")) {
        events.record("operation"); return 19
    }
    #expect(value == 19 && events.names == ["start", "operation"])
    #expect(events.permissionCallsOffMain)
}

@Test @MainActor func securityScopeAwaitsReleaseBeforeRethrowingImportError() async {
    let events = ScopeEvents()
    let access = SecurityScopedFileAccess(start: { _ in events.record("start"); return true }, stop: { _ in events.record("stop") })
    do {
        let _: Int = try await access.withAccess(to: URL(fileURLWithPath: "/synthetic/broken.wav")) {
            events.record("operation"); throw ScopeFailure.expected
        }
        Issue.record("The import error must reach its caller.")
    } catch ScopeFailure.expected { }
    catch { Issue.record("Unexpected error: \(error)") }
    #expect(events.names == ["start", "operation", "stop"])
    #expect(events.permissionCallsOffMain)
}

@Test @MainActor func cancelledSecurityScopeOwnerRetainsAccessUntilOperationActuallyFinishes() async {
    let events = ScopeEvents(), entered = AsyncStream<Void>.makeStream(), finish = AsyncStream<Void>.makeStream()
    let access = SecurityScopedFileAccess(start: { _ in events.record("start"); return true }, stop: { _ in events.record("stop") })
    let owner = Task { @MainActor in
        try await access.withAccess(to: URL(fileURLWithPath: "/synthetic/held.wav")) {
            events.record("operation"); entered.continuation.yield(())
            // The producer owns its read until it returns, even after cancellation.
            let held = Task.detached { for await _ in finish.stream { break } }
            await held.value; try Task.checkCancellation()
        }
    }
    for await _ in entered.stream { break }
    owner.cancel(); #expect(events.names == ["start", "operation"])
    finish.continuation.yield(())
    do { try await owner.value; Issue.record("Expected cancellation.") }
    catch is CancellationError { }
    catch { Issue.record("Unexpected error: \(error)") }
    #expect(events.names == ["start", "operation", "stop"])
    #expect(events.permissionCallsOffMain)
}
