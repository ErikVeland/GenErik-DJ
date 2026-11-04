import Dispatch

private enum ResourceRetirement {
    static let queue = DispatchQueue(label: "org.generikdj.resource-retirement", qos: .background)
}

final class BackgroundOwnedResource<Resource: AnyObject & Sendable>: @unchecked Sendable {
    private struct Ownership: @unchecked Sendable { let resource: Unmanaged<Resource> }

    private let ownership: Ownership
    private let retirementQueue: DispatchQueue

    init(retirementQueue: DispatchQueue? = nil, make: () -> Resource) {
        ownership = Ownership(resource: .passRetained(make()))
        self.retirementQueue = retirementQueue ?? ResourceRetirement.queue
    }

    // The resource reference must not escape. Value projections can retain separate data aliases.
    func withResource<Result>(_ operation: (Resource) -> Result) -> Result {
        withExtendedLifetime(self) { operation(ownership.resource.takeUnretainedValue()) }
    }

    deinit {
        // This handle has no ARC release when the local goes out of scope.
        let ownership = ownership
        retirementQueue.async(qos: .background, flags: .enforceQoS) { ownership.resource.release() }
    }
}

package func drainQueuedBackgroundRetirements() async {
    await withCheckedContinuation { continuation in
        ResourceRetirement.queue.async(qos: .background, flags: .enforceQoS) { continuation.resume() }
    }
}
