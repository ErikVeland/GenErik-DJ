import Dispatch
import Foundation
import Testing
@testable import TDJCore

private struct LookupRetirementEvent: Sendable {
    let onMain: Bool
    let onExpectedQueue: Bool
}

private final class RetirementQueueIdentity: @unchecked Sendable {
    private let key = DispatchSpecificKey<UInt8>()
    init(queue: DispatchQueue) { queue.setSpecific(key: key, value: 1) }
    var isCurrent: Bool { DispatchQueue.getSpecific(key: key) == 1 }
}

private final class RetiredLookupResource: Sendable {
    let events: AsyncStream<LookupRetirementEvent>.Continuation
    let queueIdentity: RetirementQueueIdentity
    init(events: AsyncStream<LookupRetirementEvent>.Continuation, queueIdentity: RetirementQueueIdentity) {
        self.events = events
        self.queueIdentity = queueIdentity
    }
    deinit {
        events.yield(.init(onMain: Thread.isMainThread, onExpectedQueue: queueIdentity.isCurrent))
    }
}

@MainActor private final class WeakRetirementResource {
    weak var value: RetiredLookupResource?
}

@inline(never) @MainActor
private func retirementResourceIsAlive(_ observation: WeakRetirementResource) -> Bool {
    observation.value != nil
}

@Test @MainActor func lookupPayloadWaitsForHeldBackgroundRetirementQueue() async throws {
    let queue = DispatchQueue(label: "test.lookup-retirement-held", qos: .background)
    let identity = RetirementQueueIdentity(queue: queue)
    let events = AsyncStream<LookupRetirementEvent>.makeStream()
    let observation = WeakRetirementResource()
    queue.suspend()
    var suspended = true
    defer { if suspended { queue.resume() } }
    var owner: BackgroundOwnedResource<RetiredLookupResource>? = BackgroundOwnedResource(retirementQueue: queue) {
        let resource = RetiredLookupResource(events: events.continuation, queueIdentity: identity)
        observation.value = resource
        return resource
    }
    owner?.withResource { _ in }
    owner = nil
    #expect(retirementResourceIsAlive(observation))
    queue.resume()
    suspended = false
    await withCheckedContinuation { continuation in
        queue.async { events.continuation.finish(); continuation.resume() }
    }
    var count = 0
    for await event in events.stream {
        #expect(!event.onMain)
        #expect(event.onExpectedQueue)
        count += 1
    }
    #expect(count == 1)
    #expect(!retirementResourceIsAlive(observation))
}

@Test @MainActor func fastBackgroundRetirementReleasesEveryPayloadExactlyOnce() async throws {
    let queue = DispatchQueue(label: "test.lookup-retirement-fast", qos: .background, attributes: .concurrent)
    let identity = RetirementQueueIdentity(queue: queue)
    let events = AsyncStream<LookupRetirementEvent>.makeStream()
    for _ in 0..<256 {
        let owner = BackgroundOwnedResource(retirementQueue: queue) {
            RetiredLookupResource(events: events.continuation, queueIdentity: identity)
        }
        owner.withResource { _ in }
        withExtendedLifetime(owner) { }
    }
    await withCheckedContinuation { continuation in
        queue.async(flags: .barrier) { events.continuation.finish(); continuation.resume() }
    }
    var count = 0
    for await event in events.stream {
        #expect(!event.onMain)
        #expect(event.onExpectedQueue)
        count += 1
    }
    #expect(count == 256)
}
