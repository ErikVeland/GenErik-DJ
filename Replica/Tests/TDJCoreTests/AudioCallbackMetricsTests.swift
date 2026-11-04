import Darwin
import Foundation
import Testing

@testable import TDJCore

@Test @MainActor func firstTracedCallbackRetainsContextWithoutAnOverrunAndDecodesOlderEvents() throws {
    let metrics = try AudioCallbackMetrics(sampleRate: 48000, traceThreadCPU: true)
    metrics.end(began: metrics.begin(), frames: 48000, sampleTime: 0, validTime: true)
    let summary = metrics.summary()
    #expect(summary.deadlineOverruns == 0)
    let probe = try #require(summary.threadCPUProbe)
    let event = try #require(probe.events.first)
    #expect(probe.events.count == 1 && event.callbackIndex == 1)
    #expect(event.wallMicroseconds == summary.maximumMicroseconds)
    #expect(event.machThread == pthread_mach_thread_np(pthread_self()))
    #expect(event.isMainThread == Thread.isMainThread)
    #if arch(arm64)
        #expect(event.armFPCR != nil)
    #else
        #expect(event.armFPCR == nil)
    #endif
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
    var oldProbe = try #require(object["threadCPUProbe"] as? [String: Any])
    var oldEvents = try #require(oldProbe["events"] as? [[String: Any]])
    for field in ["wallMicroseconds", "machThread", "isMainThread", "armFPCR"] {
        oldEvents[0].removeValue(forKey: field)
    }
    oldProbe["events"] = oldEvents
    object["threadCPUProbe"] = oldProbe
    let decoded = try JSONDecoder().decode(
        AudioCallbackSummary.self, from: JSONSerialization.data(withJSONObject: object))
    let legacy = try #require(decoded.threadCPUProbe?.events.first)
    #expect(
        legacy.wallMicroseconds == nil && legacy.machThread == nil && legacy.isMainThread == nil
            && legacy.armFPCR == nil)
}

@Test func audioCallbackMetricsCountFramesAndDetectTimelineGaps() throws {
    let metrics = try AudioCallbackMetrics(sampleRate: 48000)
    for (frames, time, valid) in [(UInt32(512), 0.0, true), (512, 512, true), (128, 2000, true), (128, 0, false)] {
        let began = metrics.begin()
        metrics.end(began: began, frames: frames, sampleTime: time, validTime: valid)
    }
    metrics.end(began: metrics.begin(), frames: 0, sampleTime: 0, validTime: false)
    metrics.markRenderFailure()
    let result = metrics.summary()
    #expect(result.callbacks == 4)
    #expect(result.frames == 1280)
    #expect(result.timestampGaps == 1)
    #expect(result.invalidTimestamps == 1)
    #expect(result.renderFailures == 1)
    #expect(result.minimumFrames == 128)
    #expect(result.maximumFrames == 512)
    #expect(result.maximumMicroseconds >= 0)
}

@Test func callbackTimingEventsRetainExactGapAndCallbackPosition() throws {
    let metrics = try AudioCallbackMetrics(sampleRate: 48000)
    metrics.end(began: 0, frames: 512, sampleTime: 0, validTime: true)
    metrics.end(began: 0, frames: 512, sampleTime: 1536, validTime: true)
    let summary = metrics.summary()
    let events = try #require(summary.timingAnomalies)
    #expect(summary.callbacks == 2 && summary.timestampGaps == 1)
    #expect(events.count == 2)
    #expect(events[0].callbackIndex == 1 && events[0].expectedSampleTime == nil)
    #expect(events[1].callbackIndex == 2 && events[1].frames == 512)
    #expect(events[1].sampleTime == 1536 && events[1].expectedSampleTime == 512)
    #expect(events[1].sampleGapFrames == 1024)
    #expect(events[1].deadlineOverrun && !events[1].invalidTimestamp)
    #expect(events[1].endedMachTicks >= events[1].beganMachTicks)
    #expect(summary.timingAnomaliesDropped == 0)
}

@Test func callbackTimingEventsStayBoundedAndEncodeInvalidTimesWithoutNonfiniteJSON() throws {
    let metrics = try AudioCallbackMetrics(sampleRate: 48000)
    for _ in 0..<80 { metrics.end(began: 0, frames: 512, sampleTime: .nan, validTime: false) }
    let summary = metrics.summary()
    let events = try #require(summary.timingAnomalies)
    #expect(summary.callbacks == 80 && summary.invalidTimestamps == 80)
    #expect(events.count == 64 && summary.timingAnomaliesDropped == 16)
    #expect(events.map(\.callbackIndex) == Array(1...64).map(UInt64.init))
    #expect(events.allSatisfy { $0.invalidTimestamp && $0.sampleTime == nil && $0.expectedSampleTime == nil })
    let encoded = try JSONEncoder().encode(summary)
    let decoded = try JSONDecoder().decode(AudioCallbackSummary.self, from: encoded)
    #expect(decoded.timingAnomalies?.count == 64 && decoded.invalidTimestamps == 80)
}

@Test func callbackTimingSummaryDecodesOlderFilesAndSkipsZeroFrameEvents() throws {
    let metrics = try AudioCallbackMetrics(sampleRate: 48000)
    metrics.end(began: 0, frames: 0, sampleTime: .nan, validTime: false)
    let summary = metrics.summary()
    #expect(summary.callbacks == 0 && summary.timingAnomalies?.isEmpty == true)
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
    object.removeValue(forKey: "timingAnomalies")
    object.removeValue(forKey: "timingAnomaliesDropped")
    let decoded = try JSONDecoder().decode(
        AudioCallbackSummary.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(decoded.callbacks == 0 && decoded.timingAnomalies == nil && decoded.timingAnomaliesDropped == nil)
}

@Test func optionalCallbackCPUProbeRetainsBoundedValidEventsAndLegacyDecoding() throws {
    let normal = try AudioCallbackMetrics(sampleRate: 48000)
    #expect(!normal.tracesThreadCPU && normal.summary().threadCPUProbe == nil)
    let traced = try AudioCallbackMetrics(sampleRate: 48000, traceThreadCPU: true)
    traced.end(began: traced.begin(), frames: 0, sampleTime: 0, validTime: true)
    #expect(traced.summary().threadCPUProbe?.measuredCallbacks == 0)
    for i in 0..<80 {
        _ = traced.begin()
        // Force a wall anomaly while retaining the actual paired CPU clocks.
        traced.end(began: 0, frames: 512, sampleTime: Double(i) * 512, validTime: true)
    }
    let summary = traced.summary()
    let cpu = try #require(summary.threadCPUProbe)
    #expect(cpu.measuredCallbacks == 80 && cpu.clockFailures == 0)
    #expect(cpu.events.count == 64 && cpu.eventsDropped == 16)
    #expect(cpu.events.map(\.callbackIndex) == Array(1...64).map(UInt64.init))
    #expect(cpu.events.allSatisfy { ($0.threadCPUMicroseconds ?? -1) >= 0 && $0.clockReadMicroseconds >= 0 })
    let decoded = try JSONDecoder().decode(AudioCallbackSummary.self, from: JSONEncoder().encode(summary))
    #expect(decoded.threadCPUProbe?.events.count == 64)
    var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
    legacy.removeValue(forKey: "threadCPUProbe")
    let older = try JSONDecoder().decode(
        AudioCallbackSummary.self, from: JSONSerialization.data(withJSONObject: legacy))
    #expect(older.threadCPUProbe == nil && older.callbacks == 80)
}

@Test func callbackArrivalEvidenceRetainsThePreviousRenderedBufferAndDecodesOlderEvents() throws {
    let metrics = try AudioCallbackMetrics(sampleRate: 48000)
    metrics.end(began: 0, frames: 512, sampleTime: 0, validTime: true)
    metrics.end(began: metrics.begin(), frames: 0, sampleTime: 999, validTime: false)
    let began = metrics.begin()
    metrics.end(began: began, frames: 480, sampleTime: 1024, validTime: true)
    let summary = metrics.summary()
    let events = try #require(summary.timingAnomalies)
    let gap = try #require(events.last)
    #expect(summary.callbacks == 2 && summary.frames == 992 && summary.timestampGaps == 1)
    #expect(events.first?.previousBeganMachTicks == nil)
    #expect(gap.previousBeganMachTicks == 0 && gap.previousFrames == 512)
    #expect(try #require(gap.previousEndedMachTicks) <= began)
    #expect(gap.beganMachTicks == began && gap.frames == 480 && gap.sampleGapFrames == 512)
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
    var oldEvents = try #require(object["timingAnomalies"] as? [[String: Any]])
    for i in oldEvents.indices {
        for field in ["previousBeganMachTicks", "previousEndedMachTicks", "previousFrames"] {
            oldEvents[i].removeValue(forKey: field)
        }
    }
    object["timingAnomalies"] = oldEvents
    let decoded = try JSONDecoder().decode(
        AudioCallbackSummary.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(decoded.timestampGaps == 1 && decoded.timingAnomalies?.last?.previousFrames == nil)
}
