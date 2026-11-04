import Foundation
import Testing

@testable import TDJRuntimeChecks

@Test func controlCompletionKeepsTheExactTwentyMillisecondBoundaryAndRoundTrips() throws {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    #expect(!value.qualified)
    value.observe(
        batch: 0, due: origin, workBegan: origin.advanced(by: .milliseconds(1)),
        workEnded: origin.advanced(by: .milliseconds(20)))
    #expect(value.qualified && value.deadlineMisses == 0 && value.maximumMilliseconds == 20)
    value.observe(
        batch: 1, due: origin, workBegan: origin.advanced(by: .milliseconds(1)),
        workEnded: origin.advanced(by: .nanoseconds(20_000_001)))
    #expect(!value.qualified && value.deadlineMisses == 1 && value.samples == 2)
    #expect(abs(value.maximumMilliseconds - 20.000001) < 0.000000001)
    let decoded = try JSONDecoder().decode(RuntimeControlCompletionTiming.self, from: JSONEncoder().encode(value))
    #expect(decoded.samples == 2 && decoded.deadlineMisses == 1 && decoded.worstSample == value.worstSample)
}

@Test func controlCompletionPairsOneBatchInsteadOfSummingIndependentGlobalMaxima() {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    value.observe(
        batch: 0, due: origin, workBegan: origin.advanced(by: .nanoseconds(18_481_500)),
        workEnded: origin.advanced(by: .nanoseconds(18_600_000)))
    value.observe(batch: 1, due: origin, workBegan: origin, workEnded: origin.advanced(by: .nanoseconds(2_155_666)))
    #expect(value.qualified && value.deadlineMisses == 0 && value.maximumMilliseconds == 18.6)
    #expect(value.worstSample?.batch == 0)
    #expect(18.4815 + 2.155666 > 20)
}

@Test func controlCompletionCountsTheWholeDeadlineIntervalIncludingTimeBeforeWork() {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    value.observe(
        batch: 42, due: origin, workBegan: origin.advanced(by: .milliseconds(19)),
        workEnded: origin.advanced(by: .milliseconds(21)))
    let sample = value.worstSample
    #expect(sample?.beforeWorkMilliseconds == 19 && sample?.workMilliseconds == 2)
    #expect(sample?.totalMilliseconds == 21 && value.deadlineMisses == 1 && !value.qualified)
}

@Test func controlCompletionRejectsInvalidChronologyWithoutReportingAFalsePass() {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    value.observe(
        batch: 0, due: origin, workBegan: origin.advanced(by: .milliseconds(5)),
        workEnded: origin.advanced(by: .milliseconds(4)))
    #expect(value.samples == 1 && value.invalidTimelines == 1 && !value.qualified && value.worstSample == nil)
}

@Test func controlCompletionAllowsEarlyCompletionWithoutResettingTheScheduledDeadline() {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    value.observe(
        batch: 0, due: origin.advanced(by: .milliseconds(10)), workBegan: origin,
        workEnded: origin.advanced(by: .milliseconds(1)))
    #expect(value.qualified && value.deadlineMisses == 0 && value.invalidTimelines == 0)
    #expect(value.maximumMilliseconds == 0 && value.worstSample?.totalMilliseconds == -9)
    value.observe(
        batch: 1, due: origin.advanced(by: .milliseconds(10)), workBegan: origin,
        workEnded: origin.advanced(by: .milliseconds(9)))
    #expect(value.maximumMilliseconds == 0 && value.worstSample?.batch == 1)
    #expect(value.worstSample?.totalMilliseconds == -1 && value.qualified)
}

@Test func exactCompletionMissRetainsPairedTimelineAndCapturedLineage() throws {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    value.observe(
        batch: 2953, due: origin, workBegan: origin.advanced(by: .nanoseconds(15_732_625)),
        workEnded: origin.advanced(by: .nanoseconds(22_942_375)), dueElapsedMilliseconds: 59060,
        threadCPUWorkMilliseconds: 0.1, nativeTimerEventLatenessMilliseconds: 5,
        nativeTimerEventToControlMilliseconds: 10)
    let miss = try #require(value.missExamples.first)
    #expect(value.deadlineMisses == 1 && !value.qualified)
    #expect(miss.sample.batch == 2953 && miss.sample.totalMilliseconds == 22.942375)
    #expect(miss.sample.beforeWorkMilliseconds == 15.732625 && miss.sample.workMilliseconds == 7.20975)
    #expect(miss.dueElapsedMilliseconds == 59060)
    #expect(miss.workBeganElapsedMilliseconds == 59075.732625)
    #expect(miss.workEndedElapsedMilliseconds == 59082.942375)
    #expect(miss.threadCPUWorkMilliseconds == 0.1 && miss.nativeTimerEventLatenessMilliseconds == 5)
    #expect(miss.nativeTimerEventToControlMilliseconds == 10 && miss.unavailableFields.isEmpty)
    let decoded = try JSONDecoder().decode(RuntimeControlCompletionTiming.self, from: JSONEncoder().encode(value))
    #expect(decoded.missExamples == value.missExamples)
}

@Test func exactCompletionExamplesStayBoundedWhileEveryMissCounts() {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    for batch in 0..<100 {
        value.observe(
            batch: batch, due: origin, workBegan: origin, workEnded: origin.advanced(by: .milliseconds(21 + batch)))
    }
    #expect(value.samples == 100 && value.deadlineMisses == 100 && value.missExamples.count == 32)
    #expect(value.missExamples.first?.sample.batch == 0 && value.missExamples.last?.sample.batch == 31)
    #expect(value.worstSample?.batch == 99 && value.maximumMilliseconds == 120 && !value.qualified)
}

@Test func exactCompletionExamplesMarkMissingLineageInsteadOfInventingZeroes() throws {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    value.observe(batch: 1, due: origin, workBegan: origin, workEnded: origin.advanced(by: .milliseconds(21)))
    let miss = try #require(value.missExamples.first)
    #expect(
        miss.dueElapsedMilliseconds == nil && miss.workBeganElapsedMilliseconds == nil
            && miss.workEndedElapsedMilliseconds == nil)
    #expect(
        miss.threadCPUWorkMilliseconds == nil && miss.nativeTimerEventLatenessMilliseconds == nil
            && miss.nativeTimerEventToControlMilliseconds == nil)
    #expect(
        miss.unavailableFields == [
            "controlLoopElapsedTimeline", "threadCPUWorkMilliseconds", "nativeTimerEventLatenessMilliseconds",
            "nativeTimerEventToControlMilliseconds",
        ])
    let decoded = try JSONDecoder().decode(RuntimeControlCompletionTiming.self, from: JSONEncoder().encode(value))
    #expect(decoded.missExamples == value.missExamples)
}

@Test func exactCompletionExamplesKeepEachBatchLineageSeparate() throws {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    value.observe(
        batch: 1, due: origin, workBegan: origin, workEnded: origin.advanced(by: .milliseconds(25)),
        dueElapsedMilliseconds: 40, threadCPUWorkMilliseconds: 0.2, nativeTimerEventLatenessMilliseconds: 11)
    value.observe(
        batch: 2, due: origin, workBegan: origin, workEnded: origin.advanced(by: .milliseconds(21)),
        dueElapsedMilliseconds: 60, threadCPUWorkMilliseconds: 0.1, nativeTimerEventToControlMilliseconds: 2)
    #expect(value.missExamples.count == 2 && value.worstSample?.batch == 1)
    let first = try #require(value.missExamples.first)
    let last = try #require(value.missExamples.last)
    #expect(first.threadCPUWorkMilliseconds == 0.2 && first.nativeTimerEventToControlMilliseconds == nil)
    #expect(last.threadCPUWorkMilliseconds == 0.1 && last.nativeTimerEventLatenessMilliseconds == nil)
    #expect(first.workEndedElapsedMilliseconds == 65 && last.workEndedElapsedMilliseconds == 81)
}

@Test func exactCompletionExamplesExcludeBoundaryPassesAndInvalidTimelines() {
    let origin = ContinuousClock().now
    var value = RuntimeControlCompletionTiming()
    value.observe(batch: 0, due: origin, workBegan: origin, workEnded: origin.advanced(by: .milliseconds(20)))
    value.observe(
        batch: 1, due: origin, workBegan: origin.advanced(by: .milliseconds(22)),
        workEnded: origin.advanced(by: .milliseconds(21)))
    #expect(value.missExamples.isEmpty && value.deadlineMisses == 0 && value.invalidTimelines == 1 && !value.qualified)
}

@Test func completionDiagnosticsCanReadReportsWithoutTheAdditiveExamples() throws {
    let data = Data(
        #"{"samples":1,"deadlineMisses":1,"invalidTimelines":0,"maximumMilliseconds":21,"worstSample":{"batch":7,"totalMilliseconds":21,"beforeWorkMilliseconds":19,"workMilliseconds":2}}"#
            .utf8)
    let value = try JSONDecoder().decode(RuntimeControlCompletionTiming.self, from: data)
    #expect(value.samples == 1 && value.deadlineMisses == 1 && !value.qualified)
    #expect(value.worstSample?.batch == 7 && value.missExamples.isEmpty)
}
