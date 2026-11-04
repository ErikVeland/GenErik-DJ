import CTDJTransport
import Foundation

/// Fixed native allocation policy. These values are read outside the render callback.
public enum PCMStreamingLimits {
    public static let assetPCMBytes =
        UInt64(TDJ_STREAM_BLOCK_COUNT) * UInt64(TDJ_STREAM_BLOCK_FRAMES) * 2 * UInt64(MemoryLayout<Float>.size)
    // The native cap permits four pools. Replacement-pressure tests verify agreement.
    public static let globalPCMBytes = 4 * assetPCMBytes
}

public struct PCMStreamingSummary: Codable, Sendable {
    public private(set) var activeAssets = 0
    public private(set) var allocatedPCMBytes: UInt64 = 0
    public private(set) var globalReservedPCMBytes: UInt64 = 0
    public private(set) var sourceReadMisses: UInt64 = 0
    public private(set) var missingOutputFrames: UInt64 = 0
    public private(set) var ioErrors: UInt64 = 0
    public private(set) var capacityFailures: UInt64 = 0
    public private(set) var rejectedColdCommands: UInt64 = 0
    public private(set) var lowReserveCallbacks: UInt64 = 0
    public private(set) var retirementBackpressure: UInt64 = 0
    public private(set) var requestBackpressure: UInt64 = 0
    public private(set) var bytesRead: UInt64 = 0
    public private(set) var maximumServiceNanoseconds: UInt64 = 0
    public private(set) var latestMissingSourceFrame: UInt64 = 0
    public private(set) var firstMissingOutputFrame: UInt64 = 0
    public var continuityFailed: Bool { sourceReadMisses > 0 || missingOutputFrames > 0 || ioErrors > 0 }
    public init() {}
    mutating func refreshGlobalReservation() { globalReservedPCMBytes = tdj_stream_reserved_pcm_bytes() }

    mutating func include(_ asset: PCMAsset, active: Bool) {
        guard asset.isStreamed else { return }
        var value = tdj_stream_telemetry()
        tdj_asset_stream_telemetry(asset.pointer, &value)
        let before = asset.accountedStreamingTelemetry
        if !active { asset.accountedStreamingTelemetry = value }
        let hadMissing = sourceReadMisses > 0 || missingOutputFrames > 0
        if active {
            activeAssets += 1
            allocatedPCMBytes += value.resident_pcm_bytes
        }
        globalReservedPCMBytes = tdj_stream_reserved_pcm_bytes()
        sourceReadMisses += value.source_read_misses &- before.source_read_misses
        missingOutputFrames += value.missing_output_frames &- before.missing_output_frames
        ioErrors += value.io_errors &- before.io_errors
        capacityFailures += value.capacity_failures &- before.capacity_failures
        rejectedColdCommands += value.rejected_cold_commands &- before.rejected_cold_commands
        lowReserveCallbacks += value.low_reserve_callbacks &- before.low_reserve_callbacks
        retirementBackpressure += value.retirement_backpressure &- before.retirement_backpressure
        requestBackpressure += value.request_backpressure &- before.request_backpressure
        bytesRead += value.bytes_read &- before.bytes_read
        maximumServiceNanoseconds = max(maximumServiceNanoseconds, value.max_service_nanoseconds)
        if value.source_read_misses > before.source_read_misses
            || value.missing_output_frames > before.missing_output_frames
        {
            latestMissingSourceFrame = value.latest_missing_source_frame
            if !hadMissing { firstMissingOutputFrame = value.first_missing_output_frame }
        }
    }
}
