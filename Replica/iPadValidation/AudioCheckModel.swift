import Foundation
import Observation
import TDJRuntimeChecks
import TDJInterface
#if canImport(UIKit)
import UIKit
import Darwin
#endif

@MainActor @Observable
final class AudioCheckModel {
    enum Phase: Equatable { case ready, running, stopping, passed, failed, cancelled }
    private(set) var phase=Phase.ready
    private(set) var progress="Choose a check to begin."
    private(set) var shareURLs: [URL]=[]
    private(set) var runDirectory: URL?
    private(set) var liveReplica: ReplicaModel?
    private(set) var panelLayout=AudioCheckPanelLayout.fxAFilterB
    @ObservationIgnored private var displayObservationError: String?
    #if canImport(UIKit)
    @ObservationIgnored private var displayProbe: AudioCheckDisplayProbe?
    #endif
    @ObservationIgnored private var task: Task<Void,Never>?
    @ObservationIgnored private var handledLaunchRequest=false

    var busy: Bool { phase == .running || phase == .stopping }

    func becameActive(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard !handledLaunchRequest else { return }
        handledLaunchRequest=true
        do {
            if let request=try AudioRuntimeCheckLaunch.parse(arguments:arguments) {
                start(preset:request,controlConfiguration:try AudioRuntimeControlConfiguration.parse(arguments:arguments))
            }
        } catch {
            phase = .failed
            progress=error.localizedDescription
        }
    }

    func start(preset: AudioRuntimeCheckLaunch, controlConfiguration: AudioRuntimeControlConfiguration = .init()) {
        let sequential=preset.sequential,liveInterface=preset.liveInterface
        guard !busy else { return }
        shareURLs=[];displayObservationError=nil;panelLayout = .fxAFilterB
        do {
            let parent=URL.documentsDirectory.appendingPathComponent("GenErikDJ-AudioChecks",isDirectory:true)
            try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:true)
            let directory=parent.appendingPathComponent("run-\(Int(Date.now.timeIntervalSince1970))-\(UUID().uuidString)",isDirectory:true)
            // The runner creates this unique child. Never reuse or overwrite an earlier run.
            runDirectory=directory
            phase = .running
            progress="Preparing the check…"
            #if canImport(UIKit)
            let previousIdleTimer=UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled=true
            #endif
            task=Task(priority:.userInitiated) { @MainActor [weak self] in
                defer {
                    #if canImport(UIKit)
                    UIApplication.shared.isIdleTimerDisabled=previousIdleTimer
                    #endif
                    self?.task=nil
                }
                do {
                    let outcome=try await AudioRuntimeChecks.run(outputDirectory:directory,
                        seconds:preset.durationSeconds,sequential:sequential,keylockStress:preset.keylockStress,
                        fixtureSampleRate:preset.fixtureSampleRate,searchCatalogTracks:115219,controlConfiguration:controlConfiguration,
                        presentation:liveInterface ? .init(modelReady:{ [weak self] replica in
                            self?.displayReplica(replica,directory:directory,preset:preset)
                        }):nil) { [weak self] update in
                            self?.progress=String(update.prefix(320))
                        }
                    self?.shareURLs=Self.existing([outcome.resultURL,outcome.recordingURL,
                        directory.appendingPathComponent("ui-frame-observations.json")])
                    let observationsSaved=self?.displayObservationError == nil
                    self?.phase=outcome.passed && observationsSaved ? .passed:.failed
                    self?.progress = !observationsSaved ? "Audio finished, but screen timing could not be saved."
                        : outcome.passed ? "The check passed. Results and recorded audio are ready to share."
                        : "The check found failures. Share the results and recording for review."
                } catch {
                    let cancelled=error is CancellationError || Task.isCancelled
                    self?.shareURLs=Self.existing([directory.appendingPathComponent("failure.json"),
                        directory.appendingPathComponent("keylock-stress-configuration.json"),
                        directory.appendingPathComponent("fixture-source-configuration.json"),
                        directory.appendingPathComponent("ui-frame-observations.json")])
                    self?.phase=cancelled ? .cancelled:.failed
                    self?.progress=cancelled ? "The check was cancelled. Any failure report is ready to share."
                        : error.localizedDescription
                }
            }
        } catch {
            phase = .failed
            progress=error.localizedDescription
        }
    }

    func cancel() {
        guard phase == .running else { return }
        phase = .stopping
        progress="Stopping audio and saving available results…"
        task?.cancel()
    }


    private func displayReplica(_ replica: ReplicaModel?,directory: URL,preset: AudioRuntimeCheckLaunch) {
        if let replica {
            liveReplica=replica
            #if canImport(UIKit)
            displayProbe=AudioCheckDisplayProbe(panelMotion:preset.panelMotion,updatePanels:{ [weak self] layout in
                self?.panelLayout=layout
            }) { [weak replica] in replica?.playbackSnapshot?.outputFrame }
            if displayProbe?.panelMotionClockValid == false {
                displayObservationError="Panel-motion clock is unavailable."
            }
            #endif
        } else {
            #if canImport(UIKit)
            if let displayProbe {
                let report=AudioCheckDisplayReport(preset:preset.rawValue,metrics:displayProbe.finish(),panelMotion:displayProbe.panelMotionSummary)
                do {
                    let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
                    try encoder.encode(report).write(to:directory.appendingPathComponent("ui-frame-observations.json"),options:.atomic)
                    if report.metrics.callbacks == 0 { displayObservationError="No display callbacks were measured." }
                } catch { displayObservationError=error.localizedDescription }
            }
            displayProbe=nil
            #endif
            liveReplica=nil
        }
    }

    private static func existing(_ urls: [URL]) -> [URL] {
        urls.filter { FileManager.default.fileExists(atPath:$0.path) }
    }

    deinit { task?.cancel() }
}

#if canImport(UIKit)
private struct AudioCheckDisplayReport: Encodable {
    let format="generik-dj.live-interface-observations/v1"
    let sourceFingerprint=Bundle.main.object(forInfoDictionaryKey:"TDJValidationSourceSHA256") as? String ?? "unrecorded"
    let operatingSystem=ProcessInfo.processInfo.operatingSystemVersionString
    let hardwareOutputSilenced=true
    let layout="ReplicaView with read-only controls. Static ui60 shows FX on A and filter on B; panelMotion records the requested drawer sequence in the explicit panel modes."
    let preset: String
    let metrics: AudioCheckDisplayMetrics
    let panelMotion: AudioCheckPanelMotionMetrics?
}

@MainActor
private final class AudioCheckDisplayTarget: NSObject {
    weak var owner: AudioCheckDisplayProbe?
    @objc func tick(_ link: CADisplayLink) {
        guard let owner else { link.invalidate();return }
        owner.observe(link)
    }
}

@MainActor
private final class AudioCheckDisplayProbe {
    private let target=AudioCheckDisplayTarget()
    private var link: CADisplayLink?
    private var observations: AudioCheckDisplayAccumulator
    private var motion: AudioCheckPanelMotionAccumulator?
    private let motionRequested: Bool
    private let startedMachTicks: UInt64
    private let nanosecondsPerMachTick: Double?
    private let updatePanels: @MainActor (AudioCheckPanelLayout) -> Void
    private let readOutputFrame: @MainActor () -> UInt64?
    init(panelMotion: Bool, updatePanels: @escaping @MainActor (AudioCheckPanelLayout) -> Void,
         readOutputFrame: @escaping @MainActor () -> UInt64?) {
        var timebase=mach_timebase_info_data_t()
        let status=mach_timebase_info(&timebase)
        let scale=status == KERN_SUCCESS && timebase.denom>0 ? Double(timebase.numer)/Double(timebase.denom):nil
        let validScale=scale.flatMap { $0.isFinite && $0>0 ? $0:nil }
        nanosecondsPerMachTick=validScale
        observations=AudioCheckDisplayAccumulator(nanosecondsPerMachTick:validScale)
        motion=panelMotion ? AudioCheckPanelMotionAccumulator():nil
        motionRequested=panelMotion
        startedMachTicks=mach_absolute_time()
        self.updatePanels=updatePanels
        self.readOutputFrame=readOutputFrame
        target.owner=self
        let link=CADisplayLink(target:target,selector:#selector(AudioCheckDisplayTarget.tick(_:)))
        self.link=link
        link.add(to:.main,forMode:.common)
    }
    func observe(_ link: CADisplayLink) {
        let arrivalMachTicks=mach_absolute_time()
        observations.observe(timestamp:link.timestamp,expectedInterval:link.targetTimestamp-link.timestamp,
            outputFrame:readOutputFrame(),arrivalMachTicks:arrivalMachTicks)
        if motionRequested, let scale=nanosecondsPerMachTick, arrivalMachTicks>=startedMachTicks {
            let elapsed=Double(arrivalMachTicks-startedMachTicks)*scale/1_000_000_000
            if let layout=motion?.observe(elapsedSeconds:elapsed,arrivalMachTicks:arrivalMachTicks) {
                updatePanels(layout)
            }
        }
    }
    var panelMotionClockValid: Bool { !motionRequested || nanosecondsPerMachTick != nil }
    var panelMotionSummary: AudioCheckPanelMotionMetrics? { motion?.summary }
    func finish() -> AudioCheckDisplayMetrics {
        link?.invalidate();link=nil
        return observations.summary
    }
}
#endif
