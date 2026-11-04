import Foundation
import TDJCore

struct RuntimeControlSubmissionRecord: Encodable {
    let batch: Int
    let scheduledElapsedSeconds: Double
    let eventKind: String
    let eventMachTicks: UInt64
    let controlEntryMachTicks: UInt64
    let firstNativeSubmissionMachTicks: UInt64
    let nativeAcceptedMachTicks: UInt64
    let workEndedMachTicks: UInt64
    let commandID: UInt64
    let dueToEventMilliseconds: Double
    let eventToSubmissionMilliseconds: Double
    let dueToSubmissionMilliseconds: Double
    let dueToWorkEndMilliseconds: Double
    let nativeQueueCallMicroseconds: Double
    let failedOriginalControlGate: Bool
}

struct RuntimeControlSubmissionTrace: Encodable {
    let format = "generik-dj.control-submission-trace/v1"
    let scope =
        "Explicit diagnostic tracing. Original deadline is retained. No subtraction of async return time. Submission tracing adds no instrumentation to AudioOut. These samples measure command submission, not physical touch or audible response."
    private(set) var observedBatches = 0
    private(set) var missingSubmissions = 0
    private(set) var invalidTimelines = 0
    private(set) var maximumDueToSubmissionMilliseconds = 0.0
    private(set) var maximumEventToSubmissionMilliseconds = 0.0
    private(set) var maximumDueToWorkEndMilliseconds = 0.0
    private(set) var examples: [RuntimeControlSubmissionRecord] = []
    private(set) var missExamples: [RuntimeControlSubmissionRecord] = []
    private(set) var missExamplesDropped = 0
    var valid: Bool { observedBatches > 0 && missingSubmissions == 0 && invalidTimelines == 0 }
    init() {
        examples.reserveCapacity(4)
        missExamples.reserveCapacity(32)
    }
    mutating func observe(
        batch: Int, began: ContinuousClock.Instant, due: ContinuousClock.Instant, wake: RuntimeControlWake?,
        entry: UInt64, late: Double, work: Double, ended: ContinuousClock.Instant, endedMachTicks: UInt64,
        submission: NativeControlSubmissionTiming?, nanosecondsPerMachTick: Double
    ) {
        observedBatches += 1
        guard let submission else {
            missingSubmissions += 1
            return
        }
        let event = wake?.resumedMachTicks ?? entry
        guard nanosecondsPerMachTick.isFinite, nanosecondsPerMachTick > 0, event <= entry,
            entry <= submission.beganMachTicks, submission.beganMachTicks <= submission.acceptedMachTicks,
            submission.acceptedMachTicks <= endedMachTicks
        else {
            invalidTimelines += 1
            return
        }
        let dueToSubmission = durationSeconds(due.duration(to: submission.began)) * 1000
        let dueToEnd = durationSeconds(due.duration(to: ended)) * 1000
        let eventToSubmission = Double(submission.beganMachTicks - event) * nanosecondsPerMachTick / 1_000_000
        maximumDueToSubmissionMilliseconds = max(maximumDueToSubmissionMilliseconds, dueToSubmission)
        maximumEventToSubmissionMilliseconds = max(maximumEventToSubmissionMilliseconds, eventToSubmission)
        maximumDueToWorkEndMilliseconds = max(maximumDueToWorkEndMilliseconds, dueToEnd)
        let failed = late > 20 || work > 20
        let record = RuntimeControlSubmissionRecord(
            batch: batch, scheduledElapsedSeconds: durationSeconds(began.duration(to: due)),
            eventKind: wake == nil ? "control-entry-without-native-timer-event" : "native-main-timer",
            eventMachTicks: event, controlEntryMachTicks: entry,
            firstNativeSubmissionMachTicks: submission.beganMachTicks,
            nativeAcceptedMachTicks: submission.acceptedMachTicks, workEndedMachTicks: endedMachTicks,
            commandID: submission.commandID, dueToEventMilliseconds: wake?.latenessMilliseconds ?? late,
            eventToSubmissionMilliseconds: eventToSubmission, dueToSubmissionMilliseconds: dueToSubmission,
            dueToWorkEndMilliseconds: dueToEnd,
            nativeQueueCallMicroseconds: Double(submission.acceptedMachTicks - submission.beganMachTicks)
                * nanosecondsPerMachTick / 1000, failedOriginalControlGate: failed)
        if examples.count < 4 { examples.append(record) }
        if failed { if missExamples.count < 32 { missExamples.append(record) } else { missExamplesDropped += 1 } }
    }
}

private func durationSeconds(_ value: Duration) -> Double {
    Double(value.components.seconds) + Double(value.components.attoseconds) / 1e18
}
