import Foundation

public struct AudioCheckDisplayGap: Encodable, Sendable {
    public let callback: Int
    public let previousArrivalMachTicks: UInt64?
    public let arrivalMachTicks: UInt64?
    public let previousDisplayTimestamp: Double
    public let displayTimestamp: Double
    public let previousOutputFrame: UInt64?
    public let outputFrame: UInt64?
    public let displayIntervalMilliseconds: Double
    public let arrivalIntervalMilliseconds: Double?
    public let expectedIntervalMilliseconds: Double?
}

public struct AudioCheckDisplayGapMetrics: Encodable, Sendable {
    public let arrivalClock = "mach_absolute_time"
    public let nanosecondsPerMachTick: Double?
    public let thresholdMilliseconds: Double
    public let capacity: Int
    public let events: [AudioCheckDisplayGap]
    public let eventsDropped: Int
    public let invalidArrivalTimestamps: Int
    public let scope =
        "Full mounted-interface lifetime, including setup and cleanup. Raw arrival ticks can be joined to control-clock anchors."
}

public struct AudioCheckDisplayMetrics: Encodable, Sendable {
    public let callbacks: Int
    public let invalidTimestamps: Int
    public let elapsedSeconds: Double
    public let meanCallbackIntervalMilliseconds: Double?
    public let maximumCallbackIntervalMilliseconds: Double
    public let maximumIntervalToExpectedPeriodRatio: Double
    public let observedSnapshotVersions: Int
    public let meanSnapshotUpdateIntervalMilliseconds: Double?
    public let maximumSnapshotUpdateIntervalMilliseconds: Double
    public let gaps: AudioCheckDisplayGapMetrics
    public let scope =
        "Display callbacks and observed playback snapshots. These do not prove waveform presentation, touch fidelity or listening quality."
}

/// Bounded observations only. Reading or encoding the summary happens after the check.
public struct AudioCheckDisplayAccumulator: Sendable {
    private var first: Double?, last: Double?, lastSnapshotTime: Double?
    private var lastOutputFrame: UInt64?
    private var callbacks = 0, invalid = 0, intervals = 0, snapshotVersions = 0, snapshotIntervals = 0
    private var intervalTotal = 0.0, intervalMaximum = 0.0, maximumPeriodRatio = 0.0
    private var snapshotTotal = 0.0, snapshotMaximum = 0.0
    private var gapStorage: [AudioCheckDisplayGap?]
    private var gapCount = 0, gapDropped = 0, invalidArrival = 0
    private let gapThreshold: Double
    private let nanosecondsPerMachTick: Double?
    private var lastArrivalMachTicks: UInt64?
    private var lastCallbackOutputFrame: UInt64?
    public init(gapCapacity: Int = 128, gapThresholdMilliseconds: Double = 50, nanosecondsPerMachTick: Double? = nil) {
        gapStorage = Array(repeating: nil, count: max(0, min(4096, gapCapacity)))
        gapThreshold = gapThresholdMilliseconds.isFinite && gapThresholdMilliseconds > 0 ? gapThresholdMilliseconds : 50
        self.nanosecondsPerMachTick = nanosecondsPerMachTick.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    public mutating func observe(
        timestamp: Double, expectedInterval: Double, outputFrame: UInt64?, arrivalMachTicks: UInt64? = nil
    ) {
        guard timestamp.isFinite, timestamp >= 0, timestamp <= Double.greatestFiniteMagnitude / 1000,
            last.map({ timestamp > $0 }) ?? true
        else {
            invalid += 1
            return
        }
        defer {
            lastArrivalMachTicks = arrivalMachTicks
            lastCallbackOutputFrame = outputFrame
        }
        if let last {
            var arrivalInterval: Double?
            if let previous = lastArrivalMachTicks, let arrivalMachTicks {
                if arrivalMachTicks >= previous {
                    if let scale = nanosecondsPerMachTick {
                        let milliseconds = Double(arrivalMachTicks - previous) * scale / 1_000_000
                        if milliseconds.isFinite { arrivalInterval = milliseconds } else { invalidArrival += 1 }
                    }
                } else {
                    invalidArrival += 1
                }
            }
            let displayInterval = (timestamp - last) * 1000
            if displayInterval > gapThreshold || (arrivalInterval ?? 0) > gapThreshold {
                let event = AudioCheckDisplayGap(
                    callback: callbacks + 1, previousArrivalMachTicks: lastArrivalMachTicks,
                    arrivalMachTicks: arrivalMachTicks, previousDisplayTimestamp: last, displayTimestamp: timestamp,
                    previousOutputFrame: lastCallbackOutputFrame, outputFrame: outputFrame,
                    displayIntervalMilliseconds: displayInterval, arrivalIntervalMilliseconds: arrivalInterval,
                    expectedIntervalMilliseconds: expectedInterval.isFinite && expectedInterval > 0
                        && expectedInterval <= Double.greatestFiniteMagnitude / 1000 ? expectedInterval * 1000 : nil)
                if gapCount < gapStorage.count {
                    gapStorage[gapCount] = event
                    gapCount += 1
                } else {
                    gapDropped += 1
                }
            }
            let interval = timestamp - last
            intervalTotal += interval
            intervalMaximum = max(intervalMaximum, interval)
            intervals += 1
            if expectedInterval.isFinite, expectedInterval > 0 {
                let ratio = interval / expectedInterval
                if ratio.isFinite { maximumPeriodRatio = max(maximumPeriodRatio, ratio) }
            }
        } else {
            first = timestamp
        }
        last = timestamp
        callbacks += 1
        if let outputFrame, outputFrame != lastOutputFrame {
            if let previous = lastSnapshotTime {
                let interval = timestamp - previous
                snapshotTotal += interval
                snapshotMaximum = max(snapshotMaximum, interval)
                snapshotIntervals += 1
            }
            lastOutputFrame = outputFrame
            lastSnapshotTime = timestamp
            snapshotVersions += 1
        }
    }

    public var summary: AudioCheckDisplayMetrics {
        .init(
            callbacks: callbacks, invalidTimestamps: invalid, elapsedSeconds: max(0, (last ?? 0) - (first ?? 0)),
            meanCallbackIntervalMilliseconds: intervals > 0 ? intervalTotal / Double(intervals) * 1000 : nil,
            maximumCallbackIntervalMilliseconds: intervalMaximum * 1000,
            maximumIntervalToExpectedPeriodRatio: maximumPeriodRatio, observedSnapshotVersions: snapshotVersions,
            meanSnapshotUpdateIntervalMilliseconds: snapshotIntervals > 0
                ? snapshotTotal / Double(snapshotIntervals) * 1000 : nil,
            maximumSnapshotUpdateIntervalMilliseconds: snapshotMaximum * 1000,
            gaps: .init(
                nanosecondsPerMachTick: nanosecondsPerMachTick, thresholdMilliseconds: gapThreshold,
                capacity: gapStorage.count, events: gapStorage.compactMap { $0 }, eventsDropped: gapDropped,
                invalidArrivalTimestamps: invalidArrival))
    }
}
