import CTDJTransport

public struct AudioCallbackTimingAnomaly: Codable, Sendable {
    public let callbackIndex: UInt64
    public let beganMachTicks: UInt64
    public let endedMachTicks: UInt64
    public let frames: UInt32
    public let durationMicroseconds: Double
    public let sampleTime: Double?
    public let expectedSampleTime: Double?
    public let previousBeganMachTicks: UInt64?
    public let previousEndedMachTicks: UInt64?
    public let previousFrames: UInt32?
    public let sampleGapFrames: Double?
    public let deadlineOverrun: Bool
    public let invalidTimestamp: Bool
}

public struct AudioCallbackCPUProbeEvent: Codable, Sendable {
    public let callbackIndex: UInt64
    public let threadCPUMicroseconds: Double?
    public let clockReadMicroseconds: Double
    public let wallMicroseconds: Double?
    public let machThread: UInt32?
    public let isMainThread: Bool?
    public let armFPCR: UInt64?
}
public struct AudioCallbackCPUProbeSummary: Codable, Sendable {
    public let measuredCallbacks: UInt64
    public let clockFailures: UInt64
    public let maximumThreadCPUMicroseconds: Double?
    public let maximumClockReadMicroseconds: Double
    public let events: [AudioCallbackCPUProbeEvent]
    public let eventsDropped: UInt64
}

public struct AudioKeylockPrimeEvent: Codable, Sendable {
    public let callbackIndex: UInt64
    public let beganMachTicks: UInt64
    public let resetDoneMachTicks: UInt64
    public let historyDoneMachTicks: UInt64
    public let endedMachTicks: UInt64
    public let deck: UInt32
    public let sourceFrame: Double
    public let speed: Double
    public let resetMicroseconds: Double
    public let historyMicroseconds: Double
    public let prerollMicroseconds: Double
    public let totalMicroseconds: Double
    public let threadCPUMicroseconds: Double?
    public let cpuClockReadMicroseconds: Double
    public let machThread: UInt32?
    public let isMainThread: Bool?
    public let armFPCR: UInt64?
}
public struct AudioKeylockPrimeProbeSummary: Codable, Sendable {
    public let events: [AudioKeylockPrimeEvent]
    public let eventsDropped: UInt64
    public let invalidMeasurements: UInt64
    public let unavailableCPUReadings: UInt64
}

public struct AudioCallbackSummary: Codable, Sendable {
    public let callbacks: UInt64
    public let frames: UInt64
    public let deadlineOverruns: UInt64
    public let timestampGaps: UInt64
    public let invalidTimestamps: UInt64
    public let renderFailures: UInt64
    public let maximumMicroseconds: Double
    public let minimumFrames: UInt32
    public let maximumFrames: UInt32
    // Optional fields retain decoding compatibility with earlier saved summaries.
    public let timingAnomalies: [AudioCallbackTimingAnomaly]?
    public let timingAnomaliesDropped: UInt64?
    public let threadCPUProbe: AudioCallbackCPUProbeSummary?
    public let keylockPrimeProbe: AudioKeylockPrimeProbeSummary?
}

/// Optional validation counters. The source callback owns timestamp sequencing.
public final class AudioCallbackMetrics: @unchecked Sendable {
    let pointer: OpaquePointer
    public let tracesThreadCPU: Bool
    public init(sampleRate: Double, traceThreadCPU: Bool = false) throws {
        guard let pointer = tdj_callback_metrics_create(sampleRate) else { throw TransportError.allocation }
        self.pointer = pointer
        tracesThreadCPU = traceThreadCPU
    }
    deinit { tdj_callback_metrics_destroy(pointer) }
    public func begin() -> UInt64 {
        tracesThreadCPU ? tdj_callback_metrics_begin_cpu(pointer) : tdj_callback_metrics_begin()
    }
    public func end(began: UInt64, frames: UInt32, sampleTime: Double, validTime: Bool) {
        if tracesThreadCPU {
            tdj_callback_metrics_end_cpu(pointer, began, frames, sampleTime, validTime)
        } else {
            tdj_callback_metrics_end(pointer, began, frames, sampleTime, validTime)
        }
    }
    public func markRenderFailure() { tdj_callback_metrics_failure(pointer) }
    public func summary() -> AudioCallbackSummary {
        let s = tdj_callback_metrics_summary(pointer)
        var anomalies: [AudioCallbackTimingAnomaly] = []
        let count = tdj_callback_metrics_anomaly_count(pointer)
        anomalies.reserveCapacity(Int(count))
        for index in 0..<count {
            var event = tdj_callback_timing_anomaly()
            guard tdj_callback_metrics_anomaly(pointer, index, &event) else { continue }
            let sample = event.sample_time_valid && event.sample_time.isFinite ? event.sample_time : nil
            let expected =
                event.expected_sample_time_valid && event.expected_sample_time.isFinite
                ? event.expected_sample_time : nil
            let gap = event.flags & UInt32(TDJ_CALLBACK_TIMING_SAMPLE_GAP) != 0
            anomalies.append(
                .init(
                    callbackIndex: event.callback_index, beganMachTicks: event.began_ticks,
                    endedMachTicks: event.ended_ticks, frames: event.frames,
                    durationMicroseconds: event.duration_microseconds, sampleTime: sample, expectedSampleTime: expected,
                    previousBeganMachTicks: event.previous_callback_valid ? event.previous_began_ticks : nil,
                    previousEndedMachTicks: event.previous_callback_valid ? event.previous_ended_ticks : nil,
                    previousFrames: event.previous_callback_valid ? event.previous_frames : nil,
                    sampleGapFrames: gap ? sample.flatMap { sample in expected.map { sample - $0 } } : nil,
                    deadlineOverrun: event.flags & UInt32(TDJ_CALLBACK_TIMING_DEADLINE) != 0,
                    invalidTimestamp: event.flags & UInt32(TDJ_CALLBACK_TIMING_INVALID_TIME) != 0))
        }
        var cpuProbe: AudioCallbackCPUProbeSummary?
        var primeProbe: AudioKeylockPrimeProbeSummary?
        if tracesThreadCPU {
            let cpu = tdj_callback_metrics_cpu_summary(pointer)
            var events: [AudioCallbackCPUProbeEvent] = []
            let count = tdj_callback_metrics_cpu_event_count(pointer)
            events.reserveCapacity(Int(count))
            for index in 0..<count {
                var event = tdj_callback_cpu_event()
                guard tdj_callback_metrics_cpu_event(pointer, index, &event) else { continue }
                events.append(
                    .init(
                        callbackIndex: event.callback_index,
                        threadCPUMicroseconds: event.cpu_time_valid ? event.cpu_microseconds : nil,
                        clockReadMicroseconds: event.clock_read_microseconds, wallMicroseconds: event.wall_microseconds,
                        machThread: event.thread_context_valid ? event.mach_thread : nil,
                        isMainThread: event.thread_context_valid ? event.is_main_thread : nil,
                        armFPCR: event.arm_fpcr_valid ? event.arm_fpcr : nil))
            }
            cpuProbe = .init(
                measuredCallbacks: cpu.measured_callbacks, clockFailures: cpu.clock_failures,
                maximumThreadCPUMicroseconds: cpu.measured_callbacks > 0
                    ? Double(cpu.maximum_cpu_nanoseconds) / 1000 : nil,
                maximumClockReadMicroseconds: cpu.maximum_clock_read_microseconds, events: events,
                eventsDropped: tdj_callback_metrics_cpu_events_dropped(pointer))
            var primes: [AudioKeylockPrimeEvent] = []
            let primeCount = tdj_callback_metrics_keylock_prime_count(pointer)
            primes.reserveCapacity(Int(primeCount))
            for index in 0..<primeCount {
                var event = tdj_keylock_prime_event()
                guard tdj_callback_metrics_keylock_prime_event(pointer, index, &event) else { continue }
                primes.append(
                    .init(
                        callbackIndex: event.callback_index, beganMachTicks: event.began_ticks,
                        resetDoneMachTicks: event.reset_done_ticks, historyDoneMachTicks: event.history_done_ticks,
                        endedMachTicks: event.ended_ticks, deck: event.deck, sourceFrame: event.source_frame,
                        speed: event.speed, resetMicroseconds: event.reset_microseconds,
                        historyMicroseconds: event.history_microseconds,
                        prerollMicroseconds: event.preroll_microseconds, totalMicroseconds: event.total_microseconds,
                        threadCPUMicroseconds: event.cpu_time_valid ? event.cpu_microseconds : nil,
                        cpuClockReadMicroseconds: event.cpu_clock_microseconds,
                        machThread: event.thread_context_valid ? event.mach_thread : nil,
                        isMainThread: event.thread_context_valid ? event.is_main_thread : nil,
                        armFPCR: event.arm_fpcr_valid ? event.arm_fpcr : nil))
            }
            primeProbe = .init(
                events: primes, eventsDropped: tdj_callback_metrics_keylock_prime_dropped(pointer),
                invalidMeasurements: tdj_callback_metrics_keylock_prime_invalid(pointer),
                unavailableCPUReadings: tdj_callback_metrics_keylock_prime_cpu_unavailable(pointer))
        }
        return .init(
            callbacks: s.callbacks, frames: s.frames, deadlineOverruns: s.deadline_overruns,
            timestampGaps: s.timestamp_gaps, invalidTimestamps: s.invalid_timestamps, renderFailures: s.render_failures,
            maximumMicroseconds: s.maximum_microseconds, minimumFrames: s.minimum_frames,
            maximumFrames: s.maximum_frames, timingAnomalies: anomalies,
            timingAnomaliesDropped: tdj_callback_metrics_anomalies_dropped(pointer), threadCPUProbe: cpuProbe,
            keylockPrimeProbe: primeProbe)
    }
}
