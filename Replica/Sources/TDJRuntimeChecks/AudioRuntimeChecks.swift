import AVFoundation
import Darwin
import Foundation
import TDJCore
import TDJInterface

#if os(macOS)
    import CoreAudio
#endif

private struct RuntimeCheckHost: Encodable {
    let platform: String
    let machine: String
    let operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
    let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
    let activeProcessors = ProcessInfo.processInfo.activeProcessorCount
    let thermalState = ProcessInfo.processInfo.thermalState.rawValue
    let lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    let recordedUTC = Date().ISO8601Format()
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unrecorded"
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unrecorded"
    let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unrecorded"
    let sourceFingerprint = RuntimeCheckHost.fingerprint
    let appBuildConfiguration = RuntimeCheckHost.stampedConfiguration
    #if DEBUG
        let compilerConfiguration = "Debug"
    #else
        let compilerConfiguration = "Release"
    #endif
    private static var fingerprint: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TDJValidationSourceSHA256") as? String,
            value.utf8.count == 64, value.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
        else { return "unrecorded" }
        return value
    }
    private static var stampedConfiguration: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TDJValidationBuildConfiguration") as? String,
            value == "Release" || value == "Debug"
        else { return "unrecorded" }
        return value
    }
    static var scope: String {
        "Production AVAudioSourceNode callback, SetRecorder, model polling and in-process synthetic analysis/search on the reported host. Hardware output is silenced. No auditory-quality, SwiftUI frame-pacing, original-DSP or other-device acceptance claim."
    }
    init() {
        #if targetEnvironment(simulator)
            platform = "iOS Simulator"
        #elseif os(iOS)
            platform = "iOS"
        #else
            platform = "macOS"
        #endif
        var value = utsname()
        if uname(&value) == 0 {
            machine = withUnsafePointer(to: &value.machine) {
                String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
            }
        } else {
            machine = "Unavailable"
        }
    }
}
private struct RuntimeCheckFailure: Encodable {
    let format = "generik-dj.audio-check-failure/v1"
    let passed = false
    let hardwareOutputSilenced = true
    let host = RuntimeCheckHost()
    let cancelled: Bool
    let error: String
}
private struct RuntimeCheckAudioRoute: Encodable {
    let renderSampleRate: Double
    let outputPortTypes: [String]
    let hardwareSampleRate: Double?
    let hardwareBufferDurationSeconds: Double?
    let defaultOutputDeviceUID: String?
    let coreAudioTransportType: UInt32?
    init(renderSampleRate: Double) {
        self.renderSampleRate = renderSampleRate
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            outputPortTypes = session.currentRoute.outputs.map { $0.portType.rawValue }
            hardwareSampleRate = session.sampleRate
            hardwareBufferDurationSeconds = session.ioBufferDuration
            defaultOutputDeviceUID = nil
            coreAudioTransportType = nil
        #else
            let device = RuntimeMacAudioRoute.scalar(
                AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultOutputDevice,
                initial: AudioDeviceID(0))
            let rate = device.flatMap {
                RuntimeMacAudioRoute.scalar($0, selector: kAudioDevicePropertyNominalSampleRate, initial: Double(0))
            }
            let frames = device.flatMap {
                RuntimeMacAudioRoute.scalar($0, selector: kAudioDevicePropertyBufferFrameSize, initial: UInt32(0))
            }
            outputPortTypes = ["CoreAudio/default-output"]
            hardwareSampleRate = rate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            hardwareBufferDurationSeconds = hardwareSampleRate.flatMap { rate in frames.map { Double($0) / rate } }
            defaultOutputDeviceUID = device.flatMap(RuntimeMacAudioRoute.uid)
            coreAudioTransportType = device.flatMap {
                RuntimeMacAudioRoute.scalar($0, selector: kAudioDevicePropertyTransportType, initial: UInt32(0))
            }
        #endif
    }
}

#if os(macOS)
    /// Read route metadata outside the timed control loop; never change device preferences.
    private enum RuntimeMacAudioRoute {
        static func scalar<T: BitwiseCopyable>(
            _ device: AudioObjectID, selector: AudioObjectPropertySelector, initial: T
        ) -> T? {
            guard device != kAudioObjectUnknown else { return nil }
            var address = AudioObjectPropertyAddress(
                mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var result = initial
            var size = UInt32(MemoryLayout<T>.size)
            let status = withUnsafeMutablePointer(to: &result) {
                AudioObjectGetPropertyData(device, &address, 0, nil, &size, UnsafeMutableRawPointer($0))
            }
            return status == noErr && size == UInt32(MemoryLayout<T>.size) ? result : nil
        }
        static func uid(_ device: AudioObjectID) -> String? {
            guard device != kAudioObjectUnknown else { return nil }
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var value: Unmanaged<CFString>? = nil
            var size = UInt32(MemoryLayout.size(ofValue: value))
            let status = withUnsafeMutablePointer(to: &value) {
                AudioObjectGetPropertyData(device, &address, 0, nil, &size, UnsafeMutableRawPointer($0))
            }
            let string = value?.takeRetainedValue()
            return status == noErr ? string.map { $0 as String } : nil
        }
    }
#endif

private struct BackgroundResult: Sendable {
    var completed = 0
    var failures = 0
}
// Sample wall and Mach time together so callback events can be correlated with host logs.
private struct RuntimeTimingClockAnchor: Encodable {
    let wallClockUnixSeconds: Double
    let machAbsoluteTicks: UInt64
    let nanosecondsPerMachTick: Double
    let captureUncertaintyNanoseconds: Double
    init() {
        var timebase = mach_timebase_info_data_t()
        let available = mach_timebase_info(&timebase) == KERN_SUCCESS && timebase.denom != 0
        let scale = available ? Double(timebase.numer) / Double(timebase.denom) : 0
        let lower = mach_absolute_time()
        let wall = Date().timeIntervalSince1970
        let upper = mach_absolute_time()
        wallClockUnixSeconds = wall
        machAbsoluteTicks = lower + (upper - lower) / 2
        nanosecondsPerMachTick = scale
        captureUncertaintyNanoseconds = Double(upper - lower) * scale
    }
}
private enum RuntimeControlCPUClock {
    static func now() -> UInt64? {
        var value = timespec()
        guard clock_gettime(CLOCK_THREAD_CPUTIME_ID, &value) == 0, value.tv_sec >= 0, value.tv_nsec >= 0 else {
            return nil
        }
        return UInt64(value.tv_sec) * 1_000_000_000 + UInt64(value.tv_nsec)
    }
    static func milliseconds(from start: UInt64?, to end: UInt64?) -> Double? {
        guard let start, let end, end >= start else { return nil }
        return Double(end - start) / 1_000_000
    }
}

struct RuntimeControlThread: Encodable, Sendable {
    let isMainThread = Thread.isMainThread
    let machThread = pthread_mach_thread_np(pthread_self())
    let qosClass = qos_class_self().rawValue
}

struct RuntimeControlWake: Sendable {
    let resumedMachTicks: UInt64
    let latenessMilliseconds: Double
    let thread: RuntimeControlThread

    static func sleeper(clock: ContinuousClock, until deadline: ContinuousClock.Instant) -> Task<Self, Error> {
        Task.detached(priority: .userInitiated) {
            try await clock.sleep(until: deadline, tolerance: .zero)
            return Self(
                resumedMachTicks: mach_absolute_time(),
                latenessMilliseconds: deadline.duration(to: clock.now).seconds * 1000, thread: RuntimeControlThread())
        }
    }
}

private final class RuntimeDeadlineSource: @unchecked Sendable {
    let source: any DispatchSourceTimer
    init() {
        source = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        source.schedule(deadline: .distantFuture)
        source.resume()
    }
    deinit { source.cancel() }
}

@MainActor final class RuntimeControlDeadlineTimer {
    private let timer = RuntimeDeadlineSource()
    private var continuation: CheckedContinuation<RuntimeControlWake, Error>?
    private var deadline: ContinuousClock.Instant?
    private let clock = ContinuousClock()

    init() { timer.source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.fire() } } }

    func wait(until deadline: ContinuousClock.Instant) async throws -> RuntimeControlWake {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                precondition(self.continuation == nil)
                self.continuation = continuation
                self.deadline = deadline
                let delay = max(0, clock.now.duration(to: deadline).seconds)
                let nanoseconds = Int((delay * 1_000_000_000).rounded(.up))
                timer.source.schedule(deadline: .now() + .nanoseconds(nanoseconds), leeway: .nanoseconds(0))
            }
        } onCancel: {
            DispatchQueue.main.async { [weak self] in self?.cancel() }
        }
    }

    private func fire() {
        guard let continuation, let deadline else { return }
        self.continuation = nil
        self.deadline = nil
        let wake = RuntimeControlWake(
            resumedMachTicks: mach_absolute_time(),
            latenessMilliseconds: deadline.duration(to: clock.now).seconds * 1000, thread: RuntimeControlThread())
        continuation.resume(returning: wake)
    }

    private func cancel() {
        let continuation = self.continuation
        self.continuation = nil
        deadline = nil
        timer.source.schedule(deadline: .distantFuture)
        continuation?.resume(throwing: CancellationError())
    }
}

private struct ControlMiss: Encodable {
    let elapsedSeconds: Double
    let batch: Int
    let latenessMilliseconds: Double
    let workMilliseconds: Double
    let beganMachTicks: UInt64
    let endedMachTicks: UInt64
    let threadCPUWorkMilliseconds: Double?
    let controlThread: RuntimeControlThread
    let diagnosticOffActorWakeMachTicks: UInt64?
    let diagnosticOffActorWakeLatenessMilliseconds: Double?
    let diagnosticWakeToControlMilliseconds: Double?
    let diagnosticWakeThread: RuntimeControlThread?
    let nativeTimerEventLatenessMilliseconds: Double?
    let nativeTimerEventToControlMilliseconds: Double?
}
private struct StartupReport: Encodable {
    let coldIncomingStartedOutput: Bool
    let cancelledIncomingStayedStopped: Bool
    let backgroundControlProgressed: Bool
    let sourcePreparationRequests: Int
    let sourcePreparationFailures: Int
    let passed: Bool
}
private struct Report: Encodable {
    let format = "generik-dj.swift-runtime-validation/v1"
    let requestedSeconds: Double
    let playbackScenario: String
    let keylockStress: RuntimeKeylockStressReport?
    let sourceSeconds: Double
    let fixtureSource: RuntimeFixtureSourceReport
    let elapsedSeconds: Double
    let callback: AudioCallbackSummary
    let startup: StartupReport
    let preparedMaximumOutputFrames: UInt32
    let audioRoute: RuntimeCheckAudioRoute
    let audioRouteAtControlEnd: RuntimeCheckAudioRoute
    let hostAtPlaybackStart: RuntimeCheckHost
    let capturedFrames: UInt64
    let fileFrames: Int64
    let droppedFrames: UInt64
    let recordingError: String?
    let nonfiniteSamples: Int
    let peak: Float
    let analysisRuns: Int
    let analysisFailures: Int
    let searchRuns: Int
    let searchCatalogTracks: Int
    let searchCatalogOrder = "deterministic Fisher-Yates shuffle"
    let exercisedEffectKinds: [String]
    let controlBatches: Int
    let cueRecalls: Int
    let rejectedCommands: UInt64
    let streaming: PCMStreamingSummary
    let sourcePreparationRequests: Int
    let sourcePreparationFailures: Int
    let controlErrors: Int
    let controlDeadlineMisses: Int
    let controlCompletionTiming: RuntimeControlCompletionTiming
    let controlMissExamples: [ControlMiss]
    let controlTimerToleranceMilliseconds = 0
    let controlDriverPriority = "userInitiated"
    let maximumControlWorkMilliseconds: Double
    let maximumControlLatenessMilliseconds: Double
    let maximumControlCPUWorkMilliseconds: Double?
    let controlCPUClock = "CLOCK_THREAD_CPUTIME_ID"
    let controlThreadAtStart: RuntimeControlThread
    let controlWakeTracing: Bool
    let sourceThreadCPUTracing: Bool
    let timingAcceptanceEligible: Bool
    let controlWakeDriver: String
    let controlSubmissionTrace: RuntimeControlSubmissionTrace?
    let modelFXControl: RuntimeModelFXStressReport?
    let modelFilterControl: RuntimeModelFilterStressReport?
    let preparationImport: RuntimePreparationImportReport?
    let maximumDiagnosticOffActorWakeLatenessMilliseconds: Double?
    let maximumDiagnosticWakeToControlMilliseconds: Double?
    let maximumNativeTimerEventLatenessMilliseconds: Double?
    let maximumNativeTimerEventToControlMilliseconds: Double?
    let timingClockAtControlStart: RuntimeTimingClockAnchor
    let timingClockAtControlEnd: RuntimeTimingClockAnchor
    let playbackTimingActivityAtControlStart: Bool?
    let playbackTimingActivityAtControlEnd: Bool?
    let playbackTimingActivityAfterShutdown: Bool?
    let deckAPhase: String
    let deckBPhase: String
    let hardwareOutputSilenced = true
    let host = RuntimeCheckHost()
    let scope = RuntimeCheckHost.scope
    let passed: Bool
}

public struct AudioRuntimeCheckOutcome: Sendable {
    public let passed: Bool
    public let resultURL: URL
    public let recordingURL: URL
}

/// Runs a silent synthetic check through the production callback and recorder.
public enum AudioRuntimeChecks {
    @MainActor private static var running = false

    @MainActor public static func run(
        outputDirectory root: URL, seconds: Double, sequential: Bool = false,
        keylockStress: AudioRuntimeKeylockStress = .detectedGrid, fixtureSampleRate: Double = 48000,
        searchCatalogTracks: Int = 115_219, controlConfiguration: AudioRuntimeControlConfiguration = .init(),
        presentation: AudioRuntimeCheckPresentation? = nil,
        progress: @escaping @MainActor @Sendable (String) -> Void = { _ in }
    ) async throws -> AudioRuntimeCheckOutcome {
        try Task.checkCancellation()
        guard seconds.isFinite, (5...3600).contains(seconds), !sequential || seconds >= 60,
            (1...250_000).contains(searchCatalogTracks), AudioRuntimeFixture.validSampleRate(fixtureSampleRate),
            fixtureSampleRate == 48000 || keylockStress == .manual60BPM,
            keylockStress == .detectedGrid || (!sequential && (seconds == 60 || seconds == 300))
        else { throw TransportError.invalid }
        guard
            controlConfiguration.driver != .directMainEvent
                || ProcessInfo.processInfo.environment["TDJ_DIAGNOSE_CONTROL_WAKE"] != "1"
        else { throw TransportError.invalid }
        guard !running else { throw TransportError.cache("An audio check is already running.") }
        guard !FileManager.default.fileExists(atPath: root.path) else {
            throw TransportError.cache("Choose a new validation directory.")
        }
        running = true
        defer {
            running = false
            presentation?.modelReady(nil)
        }
        var ownsDirectory = false
        var cleanupController: PlaybackController?
        var cleanupModel: ReplicaModel?
        var preparationImportTask: Task<RuntimePreparationImportReport, Never>?
        var preparationImportExpectation: (grids: [DeckID: BeatGrid], generations: [DeckID: UInt64])?
        var analysisTask: Task<BackgroundResult, Never>?
        var searchTask: Task<Int, Never>?
        defer {
            analysisTask?.cancel()
            searchTask?.cancel()
            preparationImportTask?.cancel()
        }
        do {
            let sourceSeconds = sequential ? max(90, ceil(seconds * 2.25 + 16)) : 16
            try FileManager.default.createDirectory(
                at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard mkdir(root.path, 0o700) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            ownsDirectory = true
            progress("Preparing the synthetic audio source")
            let source = root.appendingPathComponent("dense-source.wav")
            try await prepare { try createSource(at: source, seconds: sourceSeconds, sampleRate: fixtureSampleRate) }
            let generatedSource = try RuntimeFixtureFile(url: source)
            try Task.checkCancellation()
            let workspace = root.appendingPathComponent("Workspace", isDirectory: true)
            let controller = try PlaybackController(validationMode: true)
            cleanupController = controller
            let preparationLibrary =
                controlConfiguration.preparationImport
                ? RuntimePreparationLibrary(source: source, duration: sourceSeconds) : nil
            let model = try ReplicaModel(
                root: workspace, playback: controller, musicLibraryProvider: preparationLibrary)
            cleanupModel = model
            let filterSession = controlConfiguration.modelFilter ? RuntimeFilterContactSession() : nil
            defer { filterSession?.cancelAll(model: model) }
            progress("Preparing playback audio")
            if let preparationLibrary {
                await model.refreshMusicLibrary()
                await model.importMusicLibraryItems([preparationLibrary.item.id])
            } else {
                await model.importFiles([source])
            }
            try Task.checkCancellation()
            guard let detectedTrack = model.library.tracks.first else {
                throw NSError(domain: "Validation", code: 3, userInfo: [NSLocalizedDescriptionKey: model.status])
            }
            let track = try keylockStress.configuredFixture(detectedTrack)
            let preparationCollections: [RuntimePreparationCollection]?
            if controlConfiguration.preparationImport {
                preparationCollections = try await prepare {
                    try RuntimePreparationImportStress.prepareCollections(directory: root, duration: sourceSeconds)
                }
            } else {
                preparationCollections = nil
            }
            progress("Checking startup and cancellation")
            let startup = try await verifyStoppedOutputStartup(track: track, store: model.store)
            let startupEncoder = JSONEncoder()
            startupEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try startupEncoder.encode(startup).write(
                to: root.appendingPathComponent("startup-result.json"), options: .atomic)
            guard startup.passed else { throw TransportError.cache("Stopped-output startup regression failed.") }
            progress("Preparing the search library")
            let catalogTracks = try await prepare { try searchCatalog(from: track, count: searchCatalogTracks) }
            try Task.checkCancellation()
            for deck in DeckID.allCases { model.load(trackID: track.id, deck: deck) }
            await model.flushWrites()
            try Task.checkCancellation()
            guard model.loaded.count == 2 else { throw TransportError.cache(model.status) }
            if keylockStress == .manual60BPM { try await keylockStress.prepareLoadedFixture(track, model: model) }
            if ProcessInfo.processInfo.environment["TDJ_ADAPTIVE_GRID_CHECK"] == "1" {
                var maps: [String: BeatGridMap] = [:]
                for deck in DeckID.allCases {
                    let rate = track.analysis.sampleRate
                    let end = Double(track.analysis.frameCount - 1)
                    let map = BeatGridMap(
                        anchors: [
                            .init(beat: 0, frame: 0), .init(beat: 4, frame: rate * 2 * (deck == .a ? 1.005 : 0.995)),
                            .init(beat: end / rate * 2, frame: end),
                        ], sampleRate: rate)
                    try map.validate(frameCount: track.analysis.frameCount)
                    try await controller.updateAdaptiveMap(map, deck: deck)
                    guard let state = controller.core.snapshot()?[deck],
                        state.generation == controller.generations[deck], state.adaptiveMap == map
                    else { throw TransportError.stale }
                    maps[deck.rawValue] = map
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(maps).write(to: root.appendingPathComponent("adaptive-maps.json"), options: .atomic)
            }
            var modelFXSetupSubmissions = 0
            var modelFilterSetupTouches = 0
            for deck in DeckID.allCases {
                if let filterSession {
                    guard filterSession.apply(model: model, deck: deck, x: 0.6, y: 0.7) else {
                        throw TransportError.invalid
                    }
                    modelFilterSetupTouches += 1
                }
                if !sequential {
                    try controller.perform(.loop, deck: deck, value: 0, end: track.analysis.sampleRate * 4)
                }
                for slot in 0..<3 {
                    if controlConfiguration.modelFX {
                        guard
                            model.applyRuntimeEffectControl(
                                kind: slot, slot: slot, x: 0.3, y: 0.3, enabled: true, deck: deck, persist: false)
                        else { throw TransportError.invalid }
                        modelFXSetupSubmissions += 1
                    } else {
                        try controller.setEffect(slot, slot: slot, x: 0.3, y: 0.3, enabled: true, deck: deck)
                    }
                }
            }
            await controller.flushSourcePreparations()
            model.refreshPlayback()
            let fixtureSource = try RuntimeFixtureSourceReport(
                requestedSampleRate: fixtureSampleRate, sourceSeconds: sourceSeconds, generated: generatedSource,
                track: track, core: controller.core, snapshot: model.playbackSnapshot)
            let fixtureEncoder = JSONEncoder()
            fixtureEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try fixtureEncoder.encode(fixtureSource).write(
                to: root.appendingPathComponent("fixture-source-configuration.json"), options: .atomic)
            guard fixtureSource.matchesRequestedSource else {
                throw TransportError.cache(
                    "The generated fixture or native source rate did not match the requested configuration.")
            }
            var stressObservation: RuntimeKeylockStressObservation?
            if keylockStress == .manual60BPM {
                let observation = RuntimeKeylockStressObservation(
                    policy: keylockStress, original: detectedTrack, configured: track, initial: model.playbackSnapshot)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(observation.report).write(
                    to: root.appendingPathComponent("keylock-stress-configuration.json"), options: .atomic)
                guard observation.configurationMatches else {
                    throw TransportError.cache(
                        "The native near-2× Keylock configuration did not match the requested manual grid.")
                }
                stressObservation = observation
            }
            if !sequential {
                model.cue(slot: 1, deck: .a)
                guard model.performance.cues[track.id]?[1]?.loopEnd != nil else { throw TransportError.invalid }
            }
            model.startPlaybackMonitor()
            presentation?.modelReady(model)
            await model.toggleRecording()
            guard controller.isRecording else { throw TransportError.cache(model.status) }
            model.pressPlay(deck: .a)
            model.pressPlay(deck: .b)
            await model.flushTransportRequests()
            let audioRoute = RuntimeCheckAudioRoute(renderSampleRate: controller.core.sampleRate)
            let hostAtPlaybackStart = RuntimeCheckHost()
            let analysisService = try LibraryService(
                store: WorkspaceStore(root: root.appendingPathComponent("Analysis", isDirectory: true)))
            let analysisSession = UUID()
            let analysis = Task.detached(priority: .background) {
                var result = BackgroundResult()
                while !Task.isCancelled {
                    do {
                        _ = try await analysisService.importAudio(url: source)
                        _ = try await analysisService.record(
                            .init(
                                sessionID: analysisSession, kind: .load, timestamp: Date(), fromTrackID: nil,
                                toTrackID: track.id))
                        result.completed += 1
                    } catch is CancellationError { break } catch {
                        result.failures += 1
                        break
                    }
                }
                return result
            }
            analysisTask = analysis
            let search = Task.detached(priority: .background) {
                var runs = 0
                while !Task.isCancelled {
                    do {
                        _ = try await CollectionProjection.build(
                            tracks: catalogTracks, suggestionIDs: nil, search: runs % 2 == 0 ? "dense" : "",
                            sort: .title, category: .songs, group: nil, playlists: .init(), catalog: nil)
                        runs += 1
                        try await Task.sleep(for: .milliseconds(40))
                    } catch { break }
                }
                return runs
            }
            searchTask = search
            if let preparationCollections {
                let grids = Dictionary(
                    uniqueKeysWithValues: DeckID.allCases.compactMap { deck in
                        model.track(deck)?.grid.map { (deck, $0) }
                    })
                let generations = RuntimePreparationImportStress.generations(model: model)
                guard grids.count == 2, generations.count == 2, generations.values.allSatisfy({ $0 > 0 }) else {
                    throw TransportError.invalid
                }
                preparationImportExpectation = (grids, generations)
                preparationImportTask = Task(priority: .background) {
                    await RuntimePreparationImportStress.run(
                        model: model, collections: preparationCollections, track: detectedTrack, expectedGrids: grids,
                        expectedGenerations: generations)
                }
            }
            progress("Running playback and recording")
            let clock = ContinuousClock()
            let timingClockAtControlStart = RuntimeTimingClockAnchor()
            let playbackTimingActivityAtControlStart = controller.playbackTimingActivityActive
            let controlThreadAtStart = RuntimeControlThread()
            // This adds a task hop only in explicit diagnostic runs.
            let controlWakeTracing = ProcessInfo.processInfo.environment["TDJ_DIAGNOSE_CONTROL_WAKE"] == "1"
            let deadlineTimer = RuntimeControlDeadlineTimer()
            let began = clock.now
            var target = began
            var batches = 0
            var errors = 0
            var controlMisses = 0
            var recalls = 0
            var modelFXControlSubmissions = 0
            var modelFXPersistenceRequests = 0
            var modelFilterTouches = 0
            var filterObservation = RuntimeFilterStressObservation()
            var missExamples: [ControlMiss] = []
            var exercisedEffects = Set<Int>()
            var maxWork = 0.0
            var maxLate = 0.0
            var maxCPUWork: Double?
            var controlCompletionTiming = RuntimeControlCompletionTiming()
            var previousWake: RuntimeControlWake?
            var previousNativeWake: RuntimeControlWake?
            var maxOffActorWake: Double?
            var maxWakeToControl: Double?
            var maxNativeTimerLate: Double?
            var maxNativeTimerToControl: Double?
            func performControlCommands() {
                do {
                    try controller.setMasterBPM(120 + sin(Double(batches) * 0.03) * 8)
                    for deck in DeckID.allCases {
                        for slot in 0..<3 {
                            let kind = (slot + batches / 100) % PerformanceEffect.supportedCount
                            if controlConfiguration.modelFX {
                                let persist = batches % 100 == 99
                                guard
                                    model.applyRuntimeEffectControl(
                                        kind: kind, slot: slot, x: 0.2 + 0.1 * sin(Double(batches) * 0.07), y: 0.3,
                                        enabled: true, deck: deck, persist: persist)
                                else { throw TransportError.invalid }
                                modelFXControlSubmissions += 1
                                if persist { modelFXPersistenceRequests += 1 }
                            } else {
                                try controller.setEffect(
                                    kind, slot: slot, x: 0.2 + 0.1 * sin(Double(batches) * 0.07), y: 0.3, enabled: true,
                                    deck: deck)
                            }
                            exercisedEffects.insert(kind)
                        }
                        if let filterSession {
                            let offset = deck == .a ? 0.0 : 1.0
                            guard
                                filterSession.apply(
                                    model: model, deck: deck, x: 0.5 + 0.3 * sin(Double(batches) * 0.07 + offset),
                                    y: 0.7 + 0.1 * sin(Double(batches) * 0.05 + offset))
                            else { throw TransportError.invalid }
                            modelFilterTouches += 1
                        } else {
                            try controller.setMixer(
                                .filterY, value: 0.2 + 0.1 * sin(Double(batches) * 0.05), deck: deck)
                        }
                    }
                    model.refreshPlayback()
                    stressObservation?.observe(model.playbackSnapshot)
                    if filterSession != nil { filterObservation.observe(model.playbackSnapshot) }
                    if !sequential && batches > 0 && batches % 100 == 0 {
                        for deck in DeckID.allCases where model.playbackSnapshot?[deck].phase == .playing {
                            model.cue(slot: 1, deck: deck)
                            recalls += 1
                        }
                    }
                } catch { errors += 1 }
            }
            var submissionTrace: RuntimeControlSubmissionTrace? = controlConfiguration.traceSubmissions ? .init() : nil
            func performControlBatch() throws {
                try Task.checkCancellation()
                let controlArrived = mach_absolute_time()
                let late = target.duration(to: clock.now).seconds * 1000
                maxLate = max(maxLate, late)
                let wakeToControl = previousWake.flatMap { wake -> Double? in
                    guard controlArrived >= wake.resumedMachTicks else { return nil }
                    return Double(controlArrived - wake.resumedMachTicks)
                        * timingClockAtControlStart.nanosecondsPerMachTick / 1_000_000
                }
                if let previousWake { maxOffActorWake = max(maxOffActorWake ?? 0, previousWake.latenessMilliseconds) }
                if let wakeToControl { maxWakeToControl = max(maxWakeToControl ?? 0, wakeToControl) }
                let nativeTimerToControl = previousNativeWake.flatMap { wake -> Double? in
                    guard controlArrived >= wake.resumedMachTicks else { return nil }
                    return Double(controlArrived - wake.resumedMachTicks)
                        * timingClockAtControlStart.nanosecondsPerMachTick / 1_000_000
                }
                if let previousNativeWake {
                    maxNativeTimerLate = max(maxNativeTimerLate ?? 0, previousNativeWake.latenessMilliseconds)
                }
                if let nativeTimerToControl {
                    maxNativeTimerToControl = max(maxNativeTimerToControl ?? 0, nativeTimerToControl)
                }
                let cpuBegan = RuntimeControlCPUClock.now()
                let workBegan = clock.now
                let workBeganMachTicks = mach_absolute_time()
                let submission: NativeControlSubmissionTiming?
                if controlConfiguration.traceSubmissions {
                    submission = controller.core.captureFirstControlSubmission { performControlCommands() }
                } else {
                    performControlCommands()
                    submission = nil
                }
                let workEnded = clock.now
                let workEndedMachTicks = controlConfiguration.traceSubmissions ? mach_absolute_time() : 0
                let cpuWork = RuntimeControlCPUClock.milliseconds(from: cpuBegan, to: RuntimeControlCPUClock.now())
                let work = workBegan.duration(to: workEnded).seconds * 1000
                if let cpuWork { maxCPUWork = max(maxCPUWork ?? 0, cpuWork) }
                maxWork = max(maxWork, work)
                if late > 20 || work > 20 {
                    controlMisses += 1
                    if missExamples.count < 32 {
                        missExamples.append(
                            .init(
                                elapsedSeconds: began.duration(to: clock.now).seconds, batch: batches,
                                latenessMilliseconds: late, workMilliseconds: work, beganMachTicks: workBeganMachTicks,
                                endedMachTicks: mach_absolute_time(), threadCPUWorkMilliseconds: cpuWork,
                                controlThread: RuntimeControlThread(),
                                diagnosticOffActorWakeMachTicks: previousWake?.resumedMachTicks,
                                diagnosticOffActorWakeLatenessMilliseconds: previousWake?.latenessMilliseconds,
                                diagnosticWakeToControlMilliseconds: wakeToControl,
                                diagnosticWakeThread: previousWake?.thread,
                                nativeTimerEventLatenessMilliseconds: previousNativeWake?.latenessMilliseconds,
                                nativeTimerEventToControlMilliseconds: nativeTimerToControl))
                    }
                }
                controlCompletionTiming.observe(
                    batch: batches, due: target, workBegan: workBegan, workEnded: workEnded,
                    dueElapsedMilliseconds: began.duration(to: target).seconds * 1000,
                    threadCPUWorkMilliseconds: cpuWork,
                    nativeTimerEventLatenessMilliseconds: previousNativeWake?.latenessMilliseconds,
                    nativeTimerEventToControlMilliseconds: nativeTimerToControl)
                if controlConfiguration.traceSubmissions {
                    submissionTrace?.observe(
                        batch: batches, began: began, due: target, wake: previousNativeWake, entry: controlArrived,
                        late: late, work: work, ended: workEnded, endedMachTicks: workEndedMachTicks,
                        submission: submission, nanosecondsPerMachTick: timingClockAtControlStart.nanosecondsPerMachTick
                    )
                }
                batches += 1
            }
            if controlConfiguration.driver == .directMainEvent {
                let direct = RuntimeDirectControlDriver()
                try await direct.run(began: began, seconds: seconds) { due, wake in
                    target = due
                    previousWake = nil
                    previousNativeWake = wake
                    try performControlBatch()
                }
            } else {
                while began.duration(to: clock.now).seconds < seconds {
                    try performControlBatch()
                    target += .milliseconds(20)
                    previousWake = nil
                    previousNativeWake = nil
                    if target > clock.now {
                        if controlWakeTracing {
                            let sleeper = RuntimeControlWake.sleeper(clock: clock, until: target)
                            previousWake = try await withTaskCancellationHandler {
                                try await sleeper.value
                            } onCancel: {
                                sleeper.cancel()
                            }
                        } else {
                            previousNativeWake = try await deadlineTimer.wait(until: target)
                        }
                    } else {
                        target = clock.now
                        await Task.yield()
                    }
                }
            }
            let timingClockAtControlEnd = RuntimeTimingClockAnchor()
            let playbackTimingActivityAtControlEnd = controller.playbackTimingActivityActive
            let audioRouteAtControlEnd = RuntimeCheckAudioRoute(renderSampleRate: controller.core.sampleRate)
            let cancelledFilterContacts = filterSession?.cancelAll(model: model) ?? 0
            progress("Finishing the recording")
            analysis.cancel()
            search.cancel()
            preparationImportTask?.cancel()
            let analysisResult = await analysis.value
            let searchRuns = await search.value
            var preparationImportResult = await preparationImportTask?.value
            model.refreshPlayback()
            let phaseA = String(describing: model.playbackSnapshot?.a.phase)
            let phaseB = String(describing: model.playbackSnapshot?.b.phase)
            let playing = model.playbackSnapshot?.a.phase == .playing && model.playbackSnapshot?.b.phase == .playing
            await controller.flushSourcePreparations()
            if let expected = preparationImportExpectation, var report = preparationImportResult {
                RuntimePreparationImportStress.observe(
                    model: model, track: detectedTrack, expectedGrids: expected.grids,
                    expectedGenerations: expected.generations, report: &report)
                preparationImportResult = report
            }
            await controller.finishRecording()
            model.refreshRecordings()
            await model.flushRecordingList()
            let captured = controller.core.recording.capturedFrames
            let dropped = controller.core.recording.droppedFrames
            let recordingError = controller.recordingError
            await model.finishForShutdown()
            let playbackTimingActivityAfterShutdown = controller.playbackTimingActivityActive
            let streaming = controller.core.streamingSummary()
            let callback = controller.callbackSummary!
            let recording = try model.recordings.first.unwrap("No recording was saved.")
            progress("Checking the saved audio")
            let savedAudio = try await prepare { try inspectRecording(recording) }
            let invalid = savedAudio.nonfiniteSamples
            let peak = savedAudio.peak
            let playbackActivityBalanced =
                playbackTimingActivityAtControlStart != false && playbackTimingActivityAtControlEnd != false
                && playbackTimingActivityAfterShutdown != true
            let stressReport = stressObservation?.report
            let modelFXReport: RuntimeModelFXStressReport?
            if controlConfiguration.modelFX {
                let persisted = await model.runtimeEffectsMatchSavedState()
                modelFXReport = .init(
                    batches: batches, setupSubmissions: modelFXSetupSubmissions,
                    controlSubmissions: modelFXControlSubmissions,
                    controlPersistenceRequests: modelFXPersistenceRequests, persistedStateMatches: persisted)
            } else {
                modelFXReport = nil
            }
            let modelFilterReport: RuntimeModelFilterStressReport?
            if let filterSession {
                let persisted = await filterSession.preferencesMatchSavedState(model: model)
                modelFilterReport = .init(
                    batches: batches, setupTouches: modelFilterSetupTouches, controlTouches: modelFilterTouches,
                    cancelledContacts: cancelledFilterContacts,
                    cancellationFailures: filterSession.cancellationFailures, observation: filterObservation,
                    persistedStateMatches: persisted,
                    filtersDisabledAfterShutdown: filterSession.filtersAreDisabled(model: model))
            } else {
                modelFilterReport = nil
            }
            let passed =
                controlCompletionTiming.qualified && controlCompletionTiming.samples == batches
                && RuntimePreparationImportReport.qualifies(
                    enabled: controlConfiguration.preparationImport, report: preparationImportResult)
                && (modelFilterReport?.passed ?? true) && (modelFXReport?.passed ?? true)
                && (submissionTrace?.valid ?? true) && (stressReport?.observedWorkloadMatches ?? true)
                && playbackActivityBalanced && startup.passed && callback.callbacks > 0
                && callback.deadlineOverruns == 0 && callback.timestampGaps == 0 && callback.invalidTimestamps == 0
                && callback.renderFailures == 0 && captured > 0 && captured == UInt64(savedAudio.frames) && dropped == 0
                && recordingError == nil && invalid == 0 && peak > 0.001 && analysisResult.completed > 0
                && analysisResult.failures == 0 && searchRuns > 0 && errors == 0 && controller.rejectedCommandCount == 0
                && controlMisses == 0 && playing && streaming.activeAssets == 2
                && streaming.allocatedPCMBytes == 2 * PCMStreamingLimits.assetPCMBytes
                && streaming.globalReservedPCMBytes <= PCMStreamingLimits.globalPCMBytes && !streaming.continuityFailed
                && controller.sourcePreparationFailures == 0 && controller.core.configuredMaximumOutputFrames > 0
                && callback.maximumFrames <= controller.core.configuredMaximumOutputFrames
                && (!sequential || streaming.bytesRead > streaming.allocatedPCMBytes)
            let report = Report(
                requestedSeconds: seconds,
                playbackScenario: sequential
                    ? "sequential read-ahead beyond the PCM pool" : "four-second loops with saved-loop recalls",
                keylockStress: stressReport, sourceSeconds: sourceSeconds, fixtureSource: fixtureSource,
                elapsedSeconds: began.duration(to: clock.now).seconds, callback: callback, startup: startup,
                preparedMaximumOutputFrames: controller.core.configuredMaximumOutputFrames, audioRoute: audioRoute,
                audioRouteAtControlEnd: audioRouteAtControlEnd, hostAtPlaybackStart: hostAtPlaybackStart,
                capturedFrames: captured, fileFrames: savedAudio.frames, droppedFrames: dropped,
                recordingError: recordingError, nonfiniteSamples: invalid, peak: peak,
                analysisRuns: analysisResult.completed, analysisFailures: analysisResult.failures,
                searchRuns: searchRuns, searchCatalogTracks: catalogTracks.count,
                exercisedEffectKinds: PerformanceEffect.allCases.filter { exercisedEffects.contains($0.rawValue) }.map(
                    \.name), controlBatches: batches, cueRecalls: recalls,
                rejectedCommands: controller.rejectedCommandCount, streaming: streaming,
                sourcePreparationRequests: controller.sourcePreparationRequests,
                sourcePreparationFailures: controller.sourcePreparationFailures, controlErrors: errors,
                controlDeadlineMisses: controlMisses, controlCompletionTiming: controlCompletionTiming,
                controlMissExamples: missExamples, maximumControlWorkMilliseconds: maxWork,
                maximumControlLatenessMilliseconds: maxLate, maximumControlCPUWorkMilliseconds: maxCPUWork,
                controlThreadAtStart: controlThreadAtStart, controlWakeTracing: controlWakeTracing,
                sourceThreadCPUTracing: controller.sourceThreadCPUTracing,
                timingAcceptanceEligible: !controlWakeTracing && !controller.sourceThreadCPUTracing
                    && !controlConfiguration.traceSubmissions,
                controlWakeDriver: controlConfiguration.driver == .directMainEvent
                    ? "strict-DispatchSourceTimer-main-inline"
                    : controlWakeTracing ? "detached-userInitiated-Clock.sleep" : "strict-DispatchSourceTimer-main",
                controlSubmissionTrace: submissionTrace, modelFXControl: modelFXReport,
                modelFilterControl: modelFilterReport, preparationImport: preparationImportResult,
                maximumDiagnosticOffActorWakeLatenessMilliseconds: maxOffActorWake,
                maximumDiagnosticWakeToControlMilliseconds: maxWakeToControl,
                maximumNativeTimerEventLatenessMilliseconds: maxNativeTimerLate,
                maximumNativeTimerEventToControlMilliseconds: maxNativeTimerToControl,
                timingClockAtControlStart: timingClockAtControlStart, timingClockAtControlEnd: timingClockAtControlEnd,
                playbackTimingActivityAtControlStart: playbackTimingActivityAtControlStart,
                playbackTimingActivityAtControlEnd: playbackTimingActivityAtControlEnd,
                playbackTimingActivityAfterShutdown: playbackTimingActivityAfterShutdown, deckAPhase: phaseA,
                deckBPhase: phaseB, passed: passed)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let resultURL = root.appendingPathComponent("result.json")
            try encoder.encode(report).write(to: resultURL, options: .atomic)
            progress(passed ? "Check passed" : "Check failed")
            return .init(passed: passed, resultURL: resultURL, recordingURL: recording)
        } catch {
            cleanupController?.stopAudio()
            analysisTask?.cancel()
            searchTask?.cancel()
            preparationImportTask?.cancel()
            _ = await preparationImportTask?.value
            _ = await analysisTask?.value
            _ = await searchTask?.value
            await cleanupModel?.finishForShutdown()
            if ownsDirectory {
                let failure = RuntimeCheckFailure(
                    cancelled: error is CancellationError, error: error.localizedDescription)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try? encoder.encode(failure).write(to: root.appendingPathComponent("failure.json"), options: .atomic)
            }
            progress(error is CancellationError ? "Check cancelled" : "Check could not finish")
            throw error
        }
    }

    /// Exercise a cold incoming action after the previous active deck is paused
    /// while output startup is pending. The validation controller silences hardware.
    @MainActor private static func verifyStoppedOutputStartup(track: Track, store: WorkspaceStore) async throws
        -> StartupReport
    {
        let controller = try PlaybackController(validationMode: true)
        defer { controller.stopAudio() }
        for deck in DeckID.allCases { try await controller.load(track: track, store: store, deck: deck) }
        let a = try controller.generations[.a].unwrap("Missing startup deck.")
        try controller.core.play(deck: .a, generation: a)
        controller.core.processControlsWhileIdle()
        guard controller.core.snapshot()?.a.phase == .playing, !controller.outputActive else {
            throw TransportError.invalid
        }
        try controller.recallCue(.init(frame: 12 * track.analysis.sampleRate), deck: .b, quantum: 0)
        try controller.play(.a)
        _ = controller.snapshotAndMessages()
        guard controller.core.snapshot()?.a.phase == .paused, !controller.outputActive,
            controller.sourcePreparationRequests > 0
        else { throw TransportError.invalid }
        await controller.flushSourcePreparations()
        try await Task.sleep(for: .milliseconds(50))
        let started =
            controller.outputActive && controller.core.snapshot()?.b.phase == .playing
            && (controller.callbackSummary?.callbacks ?? 0) > 0 && !controller.core.streamingSummary().continuityFailed
        controller.stopAudio()

        // A second Play cancels the cold incoming recall before it can start output.
        try controller.core.play(deck: .a, generation: a)
        controller.core.processControlsWhileIdle()
        try controller.recallCue(.init(frame: 4 * track.analysis.sampleRate), deck: .b, quantum: 0)
        _ = controller.snapshotAndMessages()
        let requests = controller.sourcePreparationRequests
        try controller.play(.b)
        try controller.play(.a)
        await controller.flushSourcePreparations()
        try await Task.sleep(for: .milliseconds(50))
        let state = controller.core.snapshot()
        let cancelled =
            !controller.outputActive && state?.a.phase.active == false && state?.b.phase.active == false && requests > 1
            && !controller.core.streamingSummary().continuityFailed
        controller.stopAudio()
        try controller.play(.a)
        let beforeBackground = controller.sourcePreparationRequests
        try controller.recallCue(.init(frame: 8 * track.analysis.sampleRate), deck: .b, quantum: 0)
        // No model polling, snapshotAndMessages or flush drives this interval.
        try await Task.sleep(for: .milliseconds(300))
        let backgroundState = controller.core.snapshot()
        let background =
            controller.outputActive && backgroundState?.b.phase.active == true
            && controller.sourcePreparationRequests > beforeBackground && controller.preparingSourceDecks.isEmpty
            && !controller.core.streamingSummary().continuityFailed
        let failures = controller.sourcePreparationFailures
        return .init(
            coldIncomingStartedOutput: started, cancelledIncomingStayedStopped: cancelled,
            backgroundControlProgressed: background, sourcePreparationRequests: controller.sourcePreparationRequests,
            sourcePreparationFailures: failures,
            passed: started && cancelled && background && failures == 0 && controller.rejectedCommandCount == 0)
    }

    // Synthetic metadata exercises library filtering without duplicating PCM or waveform storage.
    private static func searchCatalog(from track: Track, count: Int) throws -> [Track] {
        let encoded = try JSONEncoder().encode(track)
        let template = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        let order = try catalogOrder(count: count)
        let records = try (0..<count).map { index -> [String: Any] in
            try Task.checkCancellation()
            var item = template
            let identifier = String(format: "%064x", index + 1)
            item["id"] = identifier
            item["title"] = "Dense validation track \(order[index]+1)"
            item["artist"] = "Artist \(index%200)"
            item["album"] = "Album \(index%500)"
            var analysis = item["analysis"] as! [String: Any]
            analysis["contentSHA256"] = identifier
            item["analysis"] = analysis
            return item
        }
        return try JSONDecoder().decode([Track].self, from: JSONSerialization.data(withJSONObject: records))
    }

    // A mixed catalog prevents the sort from taking its monotonic-input fast path.
    static func catalogOrder(count: Int) throws -> [Int] {
        guard count > 1 else { return count == 1 ? [0] : [] }
        var order = Array(0..<count)
        var state: UInt64 = 0x5444_4a31
        for index in stride(from: count - 1, through: 1, by: -1) {
            try Task.checkCancellation()
            state = state &* 6_364_136_223_846_793_005 &+ 1
            order.swapAt(index, Int(state % UInt64(index + 1)))
        }
        return order
    }

    private static func prepare<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        let task = Task.detached(priority: .background, operation: work)
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func inspectRecording(_ url: URL) throws -> (frames: Int64, nonfiniteSamples: Int, peak: Float) {
        let file = try AVAudioFile(forReading: url)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 8192)!
        var invalid = 0
        var peak: Float = 0
        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer)
            if buffer.frameLength == 0 { break }
            for channel in 0..<Int(buffer.format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    let sample = buffer.floatChannelData![channel][frame]
                    if sample.isFinite { peak = max(peak, abs(sample)) } else { invalid += 1 }
                }
            }
        }
        return (file.length, invalid, peak)
    }

    static func createSource(at url: URL, seconds: Double, sampleRate rate: Double = 48000) throws {
        let frames = try AudioRuntimeFixture.frameCount(seconds: seconds, sampleRate: rate)
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        var settings = format.settings
        settings[AVLinearPCMIsNonInterleaved] = false
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192)!
        var state: UInt64 = 0x5444_4a31
        var offset = 0
        while offset < frames {
            try Task.checkCancellation()
            let count = min(Int(buffer.frameCapacity), frames - offset)
            buffer.frameLength = UInt32(count)
            for i in 0..<count {
                let t = Double(offset + i) / rate
                state = state &* 6_364_136_223_846_793_005 &+ 1
                let noise = Double(Int64(bitPattern: state) >> 40) / Double(1 << 23)
                let beat = t.truncatingRemainder(dividingBy: 0.5)
                let kick = exp(-beat * 35) * sin(2 * .pi * 55 * t)
                let value = 0.12 * sin(2 * .pi * 110 * t) + 0.06 * sin(2 * .pi * 330 * t) + 0.03 * noise + 0.2 * kick
                buffer.floatChannelData![0][i] = Float(value)
                buffer.floatChannelData![1][i] = Float(value * 0.8 + 0.03 * sin(2 * .pi * 137 * t))
            }
            try file.write(from: buffer)
            offset += count
        }
    }
}
extension Duration {
    fileprivate var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
extension Optional {
    fileprivate func unwrap(_ message: String) throws -> Wrapped {
        guard let value = self else {
            throw NSError(domain: "Validation", code: 4, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return value
    }
}
