import Foundation

/// Shared by optional preparation workers. The audio callback never uses this lock.
public final class PerformanceWorkGate: @unchecked Sendable {
    private let lock = NSLock()
    private var protected = false
    public init() {}
    public var isProtected: Bool { lock.withLock { protected } }
    public func setProtected(_ value: Bool) { lock.withLock { protected = value } }
}
