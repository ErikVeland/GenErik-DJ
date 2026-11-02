import CTDJTransport
import Foundation

final class PCMStreamWorker: @unchecked Sendable {
    private final class State: @unchecked Sendable {
        let pointer: OpaquePointer
        let queue = DispatchQueue(label: "org.generikdj.playback-read-ahead", qos: .userInitiated,
                                  autoreleaseFrequency: .workItem)
        var timer: DispatchSourceTimer?
        var disposed = false

        init(pointer: OpaquePointer) { self.pointer = pointer }
        func start() {
            guard !disposed, timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(5), leeway: .microseconds(250))
            timer.setEventHandler { [weak self] in self?.service() }
            self.timer = timer
            timer.resume()
        }
        func service() {
            guard !disposed else { return }
            _ = tdj_asset_service(pointer, 16)
        }
        func dispose() {
            guard !disposed else { return }
            disposed = true
            timer?.setEventHandler {}
            timer?.cancel(); timer = nil
            tdj_asset_cancel_service(pointer)
            tdj_asset_destroy(pointer)
        }
    }
    private let state: State
    init(pointer: OpaquePointer) {
        let state = State(pointer: pointer)
        self.state = state
    }
    func wake() {
        let state = state
        state.queue.async(qos: .userInitiated, flags: .enforceQoS) {
            state.start()
            state.service()
        }
    }
    func dispose() {
        let state = state
        tdj_asset_cancel_service(state.pointer)
        state.queue.async(qos: .userInitiated, flags: .enforceQoS) { state.dispose() }
    }
}


public enum PCMStreamingError: Error, LocalizedError, Equatable {
    case capacity, readFailed, unsupported, invalid
    public var errorDescription: String? {
        switch self {
        case .capacity: "Playback memory is busy. Wait for preparation to finish, then try again."
        case .readFailed: "The local audio could not be read. Current playback continues where possible."
        case .unsupported: "This device cannot safely use the playback cache."
        case .invalid: "The requested playback region is invalid."
        }
    }
    static func check(_ status: Int32) throws {
        guard status < 0 else { return }
        if status == Int32(TDJ_STREAM_CANCELLED.rawValue) { throw CancellationError() }
        switch status {
        case Int32(TDJ_STREAM_CAPACITY.rawValue): throw Self.capacity
        case Int32(TDJ_STREAM_IO_ERROR.rawValue): throw Self.readFailed
        case Int32(TDJ_STREAM_UNSUPPORTED_ATOMICS.rawValue): throw Self.unsupported
        default: throw Self.invalid
        }
    }
}

public struct PCMSourceTarget: Equatable, Sendable {
    public var position: Double
    public var speed: Double
    public var performanceRate: Double
    public var loopStart: Double
    public var loopEnd: Double
    public var continuingPosition: Double
    public var keylock: Bool
    public var reserveContinuing: Bool
    public init(position: Double, speed: Double = 1, performanceRate: Double = 1,
                loopStart: Double = 0, loopEnd: Double = 0, continuingPosition: Double? = nil,
                keylock: Bool = false, reserveContinuing: Bool = false) {
        self.position = position; self.speed = speed; self.performanceRate = performanceRate
        self.loopStart = loopStart; self.loopEnd = loopEnd
        self.continuingPosition = continuingPosition ?? position
        self.keylock = keylock; self.reserveContinuing = reserveContinuing
    }
    var native: tdj_stream_target {
        var result = tdj_stream_target()
        result.position = position; result.source_speed = speed; result.performance_rate = performanceRate
        result.loop_start = loopStart; result.loop_end = loopEnd
        result.continuing_position = continuingPosition
        result.keylock = keylock ? 1 : 0; result.reserve_continuing = reserveContinuing ? 1 : 0
        return result
    }
}

extension PCMAsset {
    public var isStreamed: Bool { streamingWorker != nil }

    @MainActor public func prepareSource(_ target: PCMSourceTarget, generation: UInt64) async throws -> UInt64 {
        try await prepareSources([target], generation: generation)
    }
    @MainActor public func prepareSources(_ targets: [PCMSourceTarget], generation: UInt64,
                                          requireReserve: Bool = true,
                                          whileWaiting: @MainActor () throws -> Void = {}) async throws -> UInt64 {
        guard let worker = streamingWorker else { return 0 }
        try Task.checkCancellation()
        let ticket = try sourceRequest(targets, generation: generation, requireReserve: requireReserve, optionalOnly: false)
        var delivered = false
        defer { if !delivered { tdj_asset_release_preparation(pointer, ticket) } }
        worker.wake()
        while true {
            try Task.checkCancellation()
            try whileWaiting()
            let status = tdj_asset_prepare_status(pointer, ticket)
            try PCMStreamingError.check(status)
            if status == Int32(TDJ_STREAM_READY.rawValue) { delivered = true; return ticket }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
    @MainActor public func requestOptionalWarming(_ targets: [PCMSourceTarget], generation: UInt64) throws -> UInt64 {
        guard let worker = streamingWorker, !targets.isEmpty else { return 0 }
        let ticket = try sourceRequest(targets, generation: generation, requireReserve: false, optionalOnly: true)
        worker.wake()
        return ticket
    }
    @MainActor private func sourceRequest(_ targets: [PCMSourceTarget], generation: UInt64,
                                          requireReserve: Bool, optionalOnly: Bool) throws -> UInt64 {
        nextSourceRequest &+= 1
        var request = tdj_stream_request()
        request.request_id = nextSourceRequest; request.deck_generation = generation
        func append(_ target: PCMSourceTarget, reserve: Bool, optional: Bool) throws {
            var native = target.native
            var part = tdj_stream_request()
            let status = reserve ? tdj_asset_plan_target(pointer, &native, nextSourceRequest, generation, &part)
                : tdj_asset_plan_minimum(pointer, &native, nextSourceRequest, generation, &part)
            if status < 0, optional { return }
            try PCMStreamingError.check(status)
            let offset = Int(request.count), count = Int(part.count)
            if offset + count > Int(TDJ_STREAM_MAX_RANGES) {
                if optional { return }
                throw PCMStreamingError.capacity
            }
            if optional {
                withUnsafeMutableBytes(of: &part.ranges) { bytes in
                    let ranges = bytes.bindMemory(to: tdj_stream_range.self)
                    for index in 0..<count { ranges[index].priority = 1 }
                }
            }
            withUnsafeBytes(of: part.ranges) { source in
                withUnsafeMutableBytes(of: &request.ranges) { destination in
                    destination.baseAddress!.advanced(by: offset * MemoryLayout<tdj_stream_range>.stride)
                        .copyMemory(from: source.baseAddress!, byteCount: count * MemoryLayout<tdj_stream_range>.stride)
                }
            }
            request.count += part.count
        }
        for target in targets {
            if optionalOnly { try append(target, reserve: false, optional: true) }
            else if requireReserve { try append(target, reserve: true, optional: false) }
            else {
                try append(target, reserve: false, optional: false)
                try append(target, reserve: true, optional: true)
            }
        }
        guard request.count > 0 else { throw PCMStreamingError.invalid }
        let ticket = tdj_asset_request_prepare(pointer, &request)
        guard ticket != 0 else { throw PCMStreamingError.capacity }
        return ticket
    }

    public func releaseSourcePreparation(_ ticket: UInt64) {
        if ticket != 0 { tdj_asset_release_preparation(pointer, ticket) }
    }
}
