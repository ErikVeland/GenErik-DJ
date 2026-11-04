import Darwin
import Foundation

public enum AudioRuntimeControlDriver: String, Sendable {
    case asyncContinuation = "async-continuation"
    case directMainEvent = "direct-main-event"
}

public struct AudioRuntimeControlConfiguration: Sendable {
    public let driver: AudioRuntimeControlDriver
    public let traceSubmissions: Bool
    public let modelFX: Bool
    public let modelFilter: Bool
    public let preparationImport: Bool
    public init(
        driver: AudioRuntimeControlDriver = .asyncContinuation, traceSubmissions: Bool = false, modelFX: Bool = false,
        modelFilter: Bool = false, preparationImport: Bool = false
    ) {
        self.driver = driver
        self.traceSubmissions = traceSubmissions
        self.modelFX = modelFX
        self.modelFilter = modelFilter
        self.preparationImport = preparationImport
    }
    public enum InvalidArgument: Error, LocalizedError {
        case unsupportedOrRepeated
        public var errorDescription: String? { "Choose one control driver. Use each control option at most once." }
    }
    public static func parse(arguments: [String]) throws -> Self {
        let flags = arguments.dropFirst().filter {
            $0 == "--audio-control-driver" || $0.hasPrefix("--audio-control-driver=")
        }
        let traces = arguments.dropFirst().filter {
            $0 == "--audio-control-submit-trace" || $0.hasPrefix("--audio-control-submit-trace=")
        }
        let models = arguments.dropFirst().filter {
            $0 == "--audio-control-model-fx" || $0.hasPrefix("--audio-control-model-fx=")
        }
        let filters = arguments.dropFirst().filter {
            $0 == "--audio-control-model-filter" || $0.hasPrefix("--audio-control-model-filter=")
        }
        let imports = arguments.dropFirst().filter {
            $0 == "--audio-control-preparation-import" || $0.hasPrefix("--audio-control-preparation-import=")
        }
        guard imports.count <= 1, imports.allSatisfy({ $0 == "--audio-control-preparation-import" }),
            filters.count <= 1, filters.allSatisfy({ $0 == "--audio-control-model-filter" }), flags.count <= 1,
            traces.count <= 1, traces.allSatisfy({ $0 == "--audio-control-submit-trace" }), models.count <= 1,
            models.allSatisfy({ $0 == "--audio-control-model-fx" })
        else { throw InvalidArgument.unsupportedOrRepeated }
        var driver = AudioRuntimeControlDriver.asyncContinuation
        if let flag = flags.first {
            guard flag.hasPrefix("--audio-control-driver="),
                let parsed = AudioRuntimeControlDriver(
                    rawValue: String(flag.dropFirst("--audio-control-driver=".count)))
            else { throw InvalidArgument.unsupportedOrRepeated }
            driver = parsed
        }
        return .init(
            driver: driver, traceSubmissions: !traces.isEmpty, modelFX: !models.isEmpty, modelFilter: !filters.isEmpty,
            preparationImport: !imports.isEmpty)
    }
}

/// The original absolute target advances after work. An overdue batch yields rather than bursting.
struct RuntimeControlSchedule {
    private(set) var target: ContinuousClock.Instant
    init(began: ContinuousClock.Instant) { target = began }
    mutating func advance(after workEnded: ContinuousClock.Instant) -> Bool {
        target += .milliseconds(20)
        if target > workEnded { return true }
        target = workEnded
        return false
    }
}

private final class RuntimeControlCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

private final class RuntimeDirectDeadlineSource: @unchecked Sendable {
    let source: any DispatchSourceTimer
    init() {
        source = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        source.schedule(deadline: .distantFuture)
        source.resume()
    }
    deinit { source.cancel() }
}

/// Executes each batch in its main event and resumes the caller only at final completion.
@MainActor final class RuntimeDirectControlDriver {
    private let timer = RuntimeDirectDeadlineSource()
    private let cancellation = RuntimeControlCancellation()
    private let clock = ContinuousClock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var operation: (@MainActor (ContinuousClock.Instant, RuntimeControlWake?) throws -> Void)?
    private var began: ContinuousClock.Instant?
    private var schedule: RuntimeControlSchedule?
    private var seconds = 0.0
    private var used = false

    init() { timer.source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.event(isTimer: true) } } }
    func run(
        began: ContinuousClock.Instant, seconds: Double,
        operation: @escaping @MainActor (ContinuousClock.Instant, RuntimeControlWake?) throws -> Void
    ) async throws {
        try Task.checkCancellation()
        guard !used, seconds.isFinite, seconds > 0, seconds <= 3600 else { throw DriverError.invalid }
        used = true
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.operation = operation
                self.began = began
                self.seconds = seconds
                self.schedule = RuntimeControlSchedule(began: began)
                step(wake: nil)
            }
        } onCancel: {
            self.cancellation.cancel()
            DispatchQueue.main.async { [weak self] in self?.finish(.failure(CancellationError())) }
        }
    }
    enum DriverError: Error { case invalid }
    private func event(isTimer: Bool) {
        guard continuation != nil, let schedule else { return }
        let wake =
            isTimer
            ? RuntimeControlWake(
                resumedMachTicks: mach_absolute_time(),
                latenessMilliseconds: runtimeSeconds(schedule.target.duration(to: clock.now)) * 1000,
                thread: RuntimeControlThread()) : nil
        step(wake: wake)
    }
    private func step(wake: RuntimeControlWake?) {
        guard continuation != nil, let began, var schedule, let operation else { return }
        guard !cancellation.isCancelled else {
            finish(.failure(CancellationError()))
            return
        }
        guard runtimeSeconds(began.duration(to: clock.now)) < seconds else {
            finish(.success(()))
            return
        }
        do { try operation(schedule.target, wake) } catch {
            finish(.failure(error))
            return
        }
        // Advance from the original target, not from event arrival. Preserve overdue reset/yield.
        let armTimer = schedule.advance(after: clock.now)
        self.schedule = schedule
        if armTimer {
            let delay = max(0, runtimeSeconds(clock.now.duration(to: schedule.target)))
            let ns = Int((delay * 1_000_000_000).rounded(.up))
            timer.source.schedule(deadline: .now() + .nanoseconds(ns), leeway: .nanoseconds(0))
        } else {
            DispatchQueue.main.async { [weak self] in self?.event(isTimer: false) }
        }
    }
    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        operation = nil
        began = nil
        schedule = nil
        timer.source.schedule(deadline: .distantFuture)
        continuation.resume(with: result)
    }
}

private func runtimeSeconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
}
