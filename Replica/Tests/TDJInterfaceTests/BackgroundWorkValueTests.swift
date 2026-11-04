import Foundation
import Testing

@testable import TDJInterface

private final class WorkValueReleaseRecord: @unchecked Sendable {
    private let lock = NSLock()
    private var mainThread: Bool?
    func record() { lock.withLock { mainThread = Thread.isMainThread } }
    var releasedOnMain: Bool? { lock.withLock { mainThread } }
}
private final class WorkValueReleaseProbe: @unchecked Sendable {
    let record: WorkValueReleaseRecord
    init(_ record: WorkValueReleaseRecord) { self.record = record }
    deinit { record.record() }
}
private func makeWorkValue(_ record: WorkValueReleaseRecord) -> BackgroundWorkValue<WorkValueReleaseProbe> {
    BackgroundWorkValue(WorkValueReleaseProbe(record), worker: BackgroundFileWork(label: "test.background-payload"))
}

@Test @MainActor func backgroundWorkValueReleasesItsPayloadAwayFromTheMainThread() async {
    let record = WorkValueReleaseRecord()
    let value = makeWorkValue(record)
    #expect(record.releasedOnMain == nil)
    await value.clear()
    #expect(record.releasedOnMain == false)
    await value.clear()
    #expect(record.releasedOnMain == false)
}

@Test @MainActor func backgroundWorkValueSerializesUpdatesAndRefusesWorkAfterClear() async {
    let value = BackgroundWorkValue(0, worker: BackgroundFileWork(label: "test.background-updates"))
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 { group.addTask { _ = await value.update { $0 += 1 } } }
    }
    #expect(await value.update { $0 } == 100)
    await value.clear()
    #expect(
        await value.update {
            $0 += 1
            return $0
        } == nil)
}
