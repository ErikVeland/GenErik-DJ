import Darwin
import Foundation
import Testing

@testable import TDJCore
@testable import TDJRuntimeChecks

private enum ProbeEnd: Error { case complete }
private func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
}

@Suite(.serialized) @MainActor struct DirectControlDriverTests {
    @Test func optInFlagsLeaveTheExistingDefaultUntouched() throws {
        let defaults = try AudioRuntimeControlConfiguration.parse(arguments: ["app", "--audio-check=loop60"])
        #expect(defaults.driver == .asyncContinuation && !defaults.traceSubmissions)
        let direct = try AudioRuntimeControlConfiguration.parse(arguments: [
            "app", "--audio-control-driver=direct-main-event", "--audio-control-submit-trace",
        ])
        #expect(direct.driver == .directMainEvent && direct.traceSubmissions)
        let async = try AudioRuntimeControlConfiguration.parse(arguments: [
            "app", "--audio-control-driver=async-continuation",
        ])
        #expect(async.driver == .asyncContinuation && !async.traceSubmissions)
        for flags in [
            ["--audio-control-driver"], ["--audio-control-driver=invalid"],
            ["--audio-control-driver=direct-main-event", "--audio-control-driver=async-continuation"],
            ["--audio-control-submit-trace", "--audio-control-submit-trace"], ["--audio-control-submit-trace=1"],
        ] {
            #expect(throws: AudioRuntimeControlConfiguration.InvalidArgument.self) {
                try AudioRuntimeControlConfiguration.parse(arguments: ["app"] + flags)
            }
        }
    }
    @Test func absoluteScheduleAdvancesByTwentyAndPreservesTheOverdueYieldPolicy() {
        let began = ContinuousClock().now
        var schedule = RuntimeControlSchedule(began: began)
        let armed0 = schedule.advance(after: began + .milliseconds(1))
        #expect(armed0)
        #expect(schedule.target == began + .milliseconds(20))
        let armed1 = schedule.advance(after: began + .milliseconds(38))
        #expect(armed1)
        #expect(schedule.target == began + .milliseconds(40))
        let armed2 = schedule.advance(after: began + .milliseconds(100))
        #expect(!armed2)
        #expect(schedule.target == began + .milliseconds(100))
        let armed3 = schedule.advance(after: began + .milliseconds(101))
        #expect(armed3)
        #expect(schedule.target == began + .milliseconds(120))
    }
    @Test func batchesExecuteInTheMainEventBeforeFinalTaskCompletion() async throws {
        let driver = RuntimeDirectControlDriver()
        let clock = ContinuousClock()
        let began = clock.now
        var calls = 0
        var completed = false
        var due: [ContinuousClock.Instant] = []
        var wakes: [RuntimeControlWake] = []
        do {
            try await driver.run(began: began, seconds: 1) { target, wake in
                #expect(Thread.isMainThread && !completed)
                due.append(target)
                calls += 1
                if let wake {
                    #expect(wake.thread.isMainThread)
                    wakes.append(wake)
                }
                if calls == 3 { throw ProbeEnd.complete }
            }
            Issue.record("The injected completion did not propagate.")
        } catch ProbeEnd.complete {}
        completed = true
        #expect(calls == 3 && due.first == began && !wakes.isEmpty)
        let captured = calls
        try await Task.sleep(for: .milliseconds(40))
        #expect(calls == captured)
    }
    @Test func initialOverdueWorkKeepsItsOriginalDeadlineAndIsStillAMiss() async throws {
        let driver = RuntimeDirectControlDriver()
        let clock = ContinuousClock()
        let began = clock.now - .milliseconds(35)
        var initialDue: ContinuousClock.Instant?
        var lateness = 0.0
        do {
            try await driver.run(began: began, seconds: 1) { due, _ in
                initialDue = due
                lateness = seconds(due.duration(to: clock.now)) * 1000
                throw ProbeEnd.complete
            }
        } catch ProbeEnd.complete {}
        #expect(initialDue == began && lateness > 20)
    }
    @Test func alreadyCancelledTaskNeverSubmitsABatch() async {
        let driver = RuntimeDirectControlDriver()
        var calls = 0
        let task = Task { @MainActor in
            try await driver.run(began: ContinuousClock().now, seconds: 1) { _, _ in calls += 1 }
        }
        task.cancel()
        do {
            try await task.value
            Issue.record("Cancellation was lost.")
        } catch { #expect(error is CancellationError) }
        #expect(calls == 0)
    }
    @Test func cancellationInsideAnEventStopsFutureBatches() async throws {
        let driver = RuntimeDirectControlDriver()
        var calls = 0
        var task: Task<Void, Error>?
        task = Task { @MainActor in
            try await driver.run(began: ContinuousClock().now, seconds: 1) { _, _ in
                calls += 1
                if calls == 2 { task?.cancel() }
            }
        }
        do {
            try await task?.value
            Issue.record("Cancellation was lost.")
        } catch { #expect(error is CancellationError) }
        #expect(calls == 2)
        try await Task.sleep(for: .milliseconds(50))
        #expect(calls == 2)
    }
    @Test func endedWindowDoesNotRunAndAnInstanceCannotBeReused() async throws {
        let driver = RuntimeDirectControlDriver()
        var calls = 0
        try await driver.run(began: ContinuousClock().now - .seconds(1), seconds: 0.1) { _, _ in calls += 1 }
        #expect(calls == 0)
        do {
            try await driver.run(began: ContinuousClock().now, seconds: 0.1) { _, _ in calls += 1 }
            Issue.record("Reused driver was accepted.")
        } catch { #expect(error is RuntimeDirectControlDriver.DriverError) }
        #expect(calls == 0)
    }
    @Test func firstSubmissionProbeCapturesNativeAcceptanceAndClearsItsScope() throws {
        let core = try SampleTransport()
        let first = core.captureFirstControlSubmission {
            try? core.setMixer(.low, value: 0.8)
            try? core.setMixer(.volume, value: 0.7)
        }
        let timing = try #require(first)
        #expect(timing.beganMachTicks <= timing.acceptedMachTicks)
        core.processControlsWhileIdle()
        let acknowledgements = core.acknowledgements()
        #expect(acknowledgements.count == 2 && acknowledgements.first?.commandID == timing.commandID)
        #expect(core.captureFirstControlSubmission {} == nil)
        let second = core.captureFirstControlSubmission { try? core.setMixer(.volume, value: 0.6) }
        #expect((second?.commandID ?? 0) > timing.commandID)
        #expect(core.captureFirstControlSubmission { _ = core.renderOffline(frames: 32) } == nil)
    }
    @Test func submissionProbePreservesExactOfflineAudio() throws {
        let baseline = try SampleTransport()
        let traced = try SampleTransport()
        let samples = (0..<8192).flatMap { i -> [Float] in [Float(i % 97) / 200, -Float(i % 71) / 200] }
        func setup(_ core: SampleTransport) throws {
            let asset = try PCMAsset(interleavedStereo: samples, sampleRate: 48000)
            let generation = try core.load(asset, deck: .a, grid: nil, synced: false)
            core.processControlsWhileIdle()
            try core.play(deck: .a, generation: generation)
        }
        try setup(baseline)
        try setup(traced)
        try baseline.setMixer(.low, value: 0.7)
        try baseline.setMixer(.volume, value: 0.6)
        let timing = traced.captureFirstControlSubmission {
            try? traced.setMixer(.low, value: 0.7)
            try? traced.setMixer(.volume, value: 0.6)
        }
        #expect(timing != nil)
        let a = baseline.renderOffline(frames: 2048)
        let b = traced.renderOffline(frames: 2048)
        #expect(a.left.map(\.bitPattern) == b.left.map(\.bitPattern))
        #expect(a.right.map(\.bitPattern) == b.right.map(\.bitPattern))
    }
    @Test func traceKeepsTheFullTwentyMillisecondPredicates() throws {
        let core = try SampleTransport()
        let clock = ContinuousClock()
        let entry = mach_absolute_time()
        let due = clock.now - .milliseconds(30)
        let submission = try #require(core.captureFirstControlSubmission { try? core.setMixer(.low, value: 1) })
        let end = clock.now
        let endMach = mach_absolute_time()
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        var trace = RuntimeControlSubmissionTrace()
        trace.observe(
            batch: 0, began: due, due: due, wake: nil, entry: entry, late: 30, work: 0.1, ended: end,
            endedMachTicks: endMach, submission: submission,
            nanosecondsPerMachTick: Double(timebase.numer) / Double(timebase.denom))
        #expect(trace.valid && trace.missExamples.count == 1)
        #expect(trace.missExamples.first?.failedOriginalControlGate == true)
        #expect((trace.missExamples.first?.dueToSubmissionMilliseconds ?? 0) >= 30)
        #expect(trace.missExamples.first?.firstNativeSubmissionMachTicks == submission.beganMachTicks)
        #expect(!(try JSONEncoder().encode(trace)).isEmpty)
        trace.observe(
            batch: 1, began: due, due: due, wake: nil, entry: entry, late: 0, work: 0, ended: end,
            endedMachTicks: endMach, submission: nil, nanosecondsPerMachTick: 1)
        #expect(!trace.valid && trace.missingSubmissions == 1)
    }
}

extension DirectControlDriverTests {
    @Test func boundedNativeControlMicrocomparisonPreservesDeadlinesAndCommands() async throws {
        let clock = ContinuousClock()
        func commands(_ core: SampleTransport, _ batch: Int) throws {
            try core.setMasterBPM(120 + sin(Double(batch) * 0.03) * 8)
            for deck in DeckID.allCases {
                for slot in 0..<3 {
                    try core.setEffect(
                        (slot + batch / 100) % PerformanceEffect.supportedCount, slot: slot,
                        x: 0.2 + 0.1 * sin(Double(batch) * 0.07), y: 0.3, enabled: true, deck: deck)
                }
                try core.setMixer(.filterY, value: 0.2 + 0.1 * sin(Double(batch) * 0.05), deck: deck)
            }
            _ = core.snapshot()
        }
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        let scale = Double(tb.numer) / Double(tb.denom)
        func batch(
            _ core: SampleTransport, _ index: Int, _ began: ContinuousClock.Instant, _ due: ContinuousClock.Instant,
            _ wake: RuntimeControlWake?, _ trace: inout RuntimeControlSubmissionTrace
        ) throws {
            let entry = mach_absolute_time()
            let start = clock.now
            var error: Error?
            let submission = core.captureFirstControlSubmission {
                do { try commands(core, index) } catch let failure { error = failure }
            }
            if let error { throw error }
            let ended = clock.now
            let endMach = mach_absolute_time()
            trace.observe(
                batch: index, began: began, due: due, wake: wake, entry: entry,
                late: seconds(due.duration(to: start)) * 1000, work: seconds(start.duration(to: ended)) * 1000,
                ended: ended, endedMachTicks: endMach, submission: submission, nanosecondsPerMachTick: scale)
            core.processControlsWhileIdle()
            let acknowledgements = core.acknowledgements()
            #expect(acknowledgements.count == 9 && acknowledgements.allSatisfy { $0.error == nil })
        }
        let asyncCore = try SampleTransport()
        let timer = RuntimeControlDeadlineTimer()
        let asyncBegan = clock.now
        var schedule = RuntimeControlSchedule(began: asyncBegan)
        var wake: RuntimeControlWake?
        var asyncTrace = RuntimeControlSubmissionTrace()
        for index in 0..<12 {
            try batch(asyncCore, index, asyncBegan, schedule.target, wake, &asyncTrace)
            if index < 11 {
                if schedule.advance(after: clock.now) {
                    wake = try await timer.wait(until: schedule.target)
                } else {
                    wake = nil
                    await Task.yield()
                }
            }
        }
        let directCore = try SampleTransport()
        let direct = RuntimeDirectControlDriver()
        let directBegan = clock.now
        var directTrace = RuntimeControlSubmissionTrace()
        var count = 0
        do {
            try await direct.run(began: directBegan, seconds: 1) { due, wake in
                try batch(directCore, count, directBegan, due, wake, &directTrace)
                count += 1
                if count == 12 { throw ProbeEnd.complete }
            }
        } catch ProbeEnd.complete {}
        #expect(count == 12 && asyncTrace.observedBatches == 12)
        #expect(asyncTrace.valid && directTrace.valid)
        struct Comparison: Encodable {
            let scope =
                "Bounded scheduling microcomparison: 12 batches of 9 native controls each, idle processing. No app UI, background workload, live audio or device. Not performance acceptance."
            let asyncContinuation: RuntimeControlSubmissionTrace
            let directMainEvent: RuntimeControlSubmissionTrace
        }
        let encoded = try JSONEncoder().encode(Comparison(asyncContinuation: asyncTrace, directMainEvent: directTrace))
        print("CONTROL_MICRO_COMPARISON " + String(decoding: encoded, as: UTF8.self))
    }
}

extension DirectControlDriverTests {
    @Test func slowWorkUsesOneYieldAndDoesNotResetItsFailedDeadlineAtFire() async throws {
        let driver = RuntimeDirectControlDriver()
        let clock = ContinuousClock()
        let began = clock.now
        var count = 0
        var firstEnd: ContinuousClock.Instant?
        var firstWork = 0.0
        do {
            try await driver.run(began: began, seconds: 1) { due, wake in
                count += 1
                if count == 1 {
                    #expect(due == began)
                    let start = clock.now
                    Thread.sleep(forTimeInterval: 0.035)
                    firstEnd = clock.now
                    firstWork = seconds(start.duration(to: clock.now)) * 1000
                } else {
                    #expect(count == 2 && wake == nil)
                    #expect(due >= firstEnd!)
                    #expect(firstWork > 20)
                    throw ProbeEnd.complete
                }
            }
        } catch ProbeEnd.complete {}
        #expect(count == 2)
    }
    @Test func cancellationFromAnotherThreadStopsAfterTheRunningBoundedBatch() async throws {
        let driver = RuntimeDirectControlDriver()
        let started = DispatchSemaphore(value: 0)
        let cancelled = DispatchSemaphore(value: 0)
        var calls = 0
        let task = Task { @MainActor in
            try await driver.run(began: ContinuousClock().now, seconds: 1) { _, _ in
                calls += 1
                started.signal()
                #expect(cancelled.wait(timeout: .now() + 1) == .success)
            }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            _ = started.wait(timeout: .now() + 1)
            task.cancel()
            cancelled.signal()
        }
        do {
            try await task.value
            Issue.record("Cross-thread cancellation was lost.")
        } catch { #expect(error is CancellationError) }
        try await Task.sleep(for: .milliseconds(40))
        #expect(calls == 1)
    }
}
