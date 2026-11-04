import Foundation
import Testing

@testable import TDJCore

private final class ReferenceWorkerEntries: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [TraktorNMLElement] = []
    private var mainThreadEntries = 0
    func append(_ entry: TraktorNMLElement) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
        if Thread.isMainThread { mainThreadEntries += 1 }
    }
    var result: ([TraktorNMLElement], Int) {
        lock.lock()
        defer { lock.unlock() }
        return (entries, mainThreadEntries)
    }
}

@Test @MainActor func traktorReferenceWorkerKeepsParsingOffTheMainActorAndRetainsRawFields() async throws {
    let entries = ReferenceWorkerEntries()
    let xml = Data(
        "<NML VERSION=\"synthetic\"><COLLECTION ENTRIES=\"1\"><ENTRY AUDIO_ID=\"opaque\"><UNKNOWN VALUE=\"untouched\"/></ENTRY></COLLECTION></NML>"
            .utf8)
    let summary = try await TraktorPreparationReferenceWorker.scanCollection(xml) { entries.append($0) }
    let result = entries.result
    #expect(summary.document.entryCount == 1 && result.0.count == 1 && result.1 == 0)
    #expect(result.0[0].children.first?.attributes["VALUE"] == "untouched")
}

@Test @MainActor func traktorReferenceWorkerHonoursCancellationBeforeItCanDeliverEntries() async {
    let entries = ReferenceWorkerEntries()
    let xml = Data("<NML VERSION=\"synthetic\"><COLLECTION><ENTRY/></COLLECTION></NML>".utf8)
    let task = Task { try await TraktorPreparationReferenceWorker.scanCollection(xml) { entries.append($0) } }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(entries.result.0.isEmpty)
}

private enum SyntheticReferenceCallbackFailure: Error { case rejected }
@Test func traktorReferenceWorkerPropagatesConsumerFailureAndCanProcessTheNextCollection() async throws {
    let xml = Data("<NML VERSION=\"synthetic\"><COLLECTION ENTRIES=\"1\"><ENTRY/></COLLECTION></NML>".utf8)
    await #expect(throws: SyntheticReferenceCallbackFailure.rejected) {
        try await TraktorPreparationReferenceWorker.scanCollection(xml) { _ in
            throw SyntheticReferenceCallbackFailure.rejected
        }
    }
    let result = try await TraktorPreparationReferenceWorker.scanCollection(xml) { _ in }
    #expect(result.document.entryCount == 1)
}
