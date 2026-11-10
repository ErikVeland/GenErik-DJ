#if os(iOS)
    import BackgroundTasks
    import UIKit

    @MainActor final class LibraryAnalysisBackgroundTasks {
        weak var model: ReplicaModel?
        private let idleIdentifier: String
        private let continuedIdentifier: String
        private var idleRegistered = false
        private var active: (id: UUID, task: BGTask, worker: Task<Void, Never>)?

        init?(model: ReplicaModel) {
            guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
            self.model = model
            idleIdentifier = bundleID + ".library-analysis.idle"
            continuedIdentifier = bundleID + ".library-analysis.continued"
            let scheduler = BGTaskScheduler.shared
            idleRegistered = scheduler.register(forTaskWithIdentifier: idleIdentifier, using: .main) { [weak self] task in
                guard let self, UIApplication.shared.applicationState == .background else {
                    task.setTaskCompleted(success: false)
                    return
                }
                self.model?.setLibraryAnalysisBackgrounded(true)
                self.start(task)
            }
        }

        func scheduleIdleAnalysis() {
            if #available(iOS 26, *) { return }
            guard idleRegistered, let model, UIApplication.shared.applicationState == .background else { return }
            let scheduler = BGTaskScheduler.shared
            guard model.libraryAnalysisNeedsWork else {
                scheduler.cancel(taskRequestWithIdentifier: idleIdentifier)
                return
            }
            guard active == nil else { return }
            let request = BGProcessingTaskRequest(identifier: idleIdentifier)
            request.requiresExternalPower = true
            request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
            do { try scheduler.submit(request) } catch {
                model.logAnalysis("Could not schedule idle analysis: \(error.localizedDescription)")
            }
        }

        @available(iOS 26, *)
        func continueAnalysis() -> Bool {
            guard let model, UIApplication.shared.applicationState == .active, active == nil,
                model.backgroundAnalysisStatus == .idle, model.libraryAnalysisNeedsWork,
                !model.arrangementPlaybackActive, !model.playback.isRecording, !model.playback.recordingFinishing
            else { return false }
            let scheduler = BGTaskScheduler.shared
            let identifier = continuedIdentifier + "." + UUID().uuidString
            let registered = scheduler.register(forTaskWithIdentifier: identifier, using: .main) { [weak self] task in
                guard let self, let continued = task as? BGContinuedProcessingTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                self.start(continued, progress: continued.progress)
            }
            guard registered else {
                model.logAnalysis("Could not register background analysis.")
                return false
            }
            let request = BGContinuedProcessingTaskRequest(
                identifier: identifier, title: "Analysing library", subtitle: "Preparing tracks")
            request.strategy = .queue
            model.backgroundAnalysisStatus = .queued
            do {
                try scheduler.submit(request)
                model.logAnalysis("Background analysis request accepted.")
                return true
            } catch {
                model.backgroundAnalysisStatus = .idle
                let failure = error as NSError
                model.logAnalysis(
                    "Could not submit background analysis (\(failure.domain) \(failure.code)): \(failure.localizedDescription)")
                return false
            }
        }

        func enteredForeground() {
            if let active, active.task is BGProcessingTask { finish(active.id, success: false) }
        }

        private func start(_ task: BGTask, progress: Progress? = nil) {
            model?.updateLibraryAnalysisConditions(LibraryAnalysisEnvironmentObserver.current)
            if let model, progress != nil, !model.libraryAnalysisNeedsWork {
                model.backgroundAnalysisStatus = .idle
                model.logAnalysis("Background analysis did not start because the library was already checked.")
                task.setTaskCompleted(success: true)
                return
            }
            let systemProgress = progress.map { progress in
                LibrarySystemProgress(progress: progress, model: model)
            }
            guard let model, active == nil, let id = model.beginBackgroundLibraryAnalysis(
                systemProgress: systemProgress.map { tracker in tracker.report }, report: { _, _ in }
            ) else {
                if progress != nil {
                    if active == nil { model?.backgroundAnalysisStatus = .idle }
                    model?.logAnalysis("Background analysis could not start while the app or playback was busy.")
                }
                task.setTaskCompleted(success: false)
                return
            }
            if progress != nil { model.backgroundAnalysisStatus = .running }
            let worker = Task(priority: .background) { [weak self, weak model] in
                let complete = await model?.runBackgroundLibraryAnalysis(id) ?? false
                self?.finish(id, success: complete)
            }
            active = (id, task, worker)
            model.logAnalysis(progress == nil ? "Idle library analysis started." : "Continued library analysis started.")
            if UIApplication.shared.applicationState == .background {
                model.setLibraryAnalysisBackgrounded(true)
            }
            task.expirationHandler = { @Sendable [weak self] in
                Task { @MainActor in self?.finish(id, success: false, expired: true) }
            }
        }

        private func finish(_ id: UUID, success: Bool, expired: Bool = false) {
            guard let work = active, work.id == id else { return }
            active = nil
            model?.endBackgroundLibraryAnalysis(id)
            if !(work.task is BGProcessingTask) {
                model?.backgroundAnalysisStatus = .idle
                if expired {
                    model?.logAnalysis("iOS ended background analysis before it finished.")
                } else if !success {
                    model?.logAnalysis("Background analysis stopped with library work remaining.")
                }
            }
            work.worker.cancel()
            work.task.expirationHandler = nil
            work.task.setTaskCompleted(success: success)
            if work.task is BGProcessingTask, !success { scheduleIdleAnalysis() }
        }
    }

    @MainActor private final class LibrarySystemProgress {
        private let progress: Progress
        private weak var model: ReplicaModel?
        private var base: Int64 = 0
        private var lastLog: ContinuousClock.Instant?

        init(progress: Progress, model: ReplicaModel?) {
            self.progress = progress
            self.model = model
            progress.totalUnitCount = 1_000_000_000
        }

        func report(_ fraction: Double) {
            if fraction == 0 {
                base = progress.completedUnitCount
                return
            }
            let remaining = progress.totalUnitCount - base
            let completed = base + Int64(Double(remaining) * min(0.999999, fraction))
            guard completed > progress.completedUnitCount else { return }
            progress.completedUnitCount = completed
            let now = ContinuousClock.now
            if lastLog.map({ $0.duration(to: now) >= .seconds(10) }) ?? true {
                lastLog = now
                model?.logAnalysis("Background analysis progress: \(completed) of \(progress.totalUnitCount).")
            }
        }
    }
#endif
