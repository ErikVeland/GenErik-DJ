import Foundation
import TDJCore

struct ArrangementCache: Codable, Sendable {
    var version = 1
    var content: String
    var configuration: String
    var context: MusicalStructureContext? = nil
    var arrangement: TrackArrangement
    var automaticCues: [Int: PerformanceCue]? = nil
    var rhythmProfile: String? = nil

    func isCurrent(for analysis: AudioAnalysis, context: MusicalStructureContext) -> Bool {
        version == MusicalStructureAnalyzer.version && content == analysis.contentSHA256
            && configuration == analysis.configurationID && self.context == context
            && rhythmProfile == analysis.acceptedDeepBeatAnalysis?.profile.id
    }

    func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

extension ReplicaModel {
    func arrangementURL(_ id: String) -> URL {
        let safeID = id.utf8.map { String(format: "%02x", $0) }.joined()
        return store.root.appendingPathComponent("Arrangements", isDirectory: true).appendingPathComponent(
            safeID + ".json")
    }
    private func readArrangementCache(track: Track) async -> ArrangementCache? {
        let url = arrangementURL(track.id)
        let analysis = track.analysis
        return await nativeMusic.files.run {
            guard let data = try? Data(contentsOf: url),
                let cache = try? JSONDecoder().decode(ArrangementCache.self, from: data),
                cache.content == analysis.contentSHA256,
                cache.arrangement.isValid(fileEnd: Double(analysis.frameCount))
            else { return nil }
            return cache
        }
    }

    func hasCurrentLibraryArrangement(_ track: Track) async -> Bool {
        guard let cache = await readArrangementCache(track: track) else { return false }
        return cache.isCurrent(for: track.analysis, context: .init(title: track.title, genre: track.genre))
            && cache.automaticCues != nil
    }

    func prepareLibraryArrangement(track: Track, source: URL?) async throws -> ArrangementCache? {
        let analysis = track.analysis
        let context = MusicalStructureContext(title: track.title, genre: track.genre)
        let previous: ArrangementCache?
        do {
            let span = AnalysisMeasurement.begin("structureCacheLookup")
            defer { span?.finish() }
            previous = await readArrangementCache(track: track)
        }
        AnalysisMeasurement.current?.update { $0.structureVersion = MusicalStructureAnalyzer.version }
        try Task.checkCancellation()
        if let previous, previous.isCurrent(for: analysis, context: context), previous.automaticCues != nil {
            AnalysisMeasurement.current?.cacheHit("structureAndCues")
            AnalysisMeasurement.current?.update { $0.source = "structureCache" }
            showLibraryArrangement(previous, track: track)
            return previous
        }

        var value: TrackArrangement
        if let previous, previous.isCurrent(for: analysis, context: context) {
            AnalysisMeasurement.current?.cacheHit("structure")
            AnalysisMeasurement.current?.update { $0.source = "structureCache" }
            value = previous.arrangement
        } else {
            guard let source else { return nil }
            AnalysisMeasurement.current?.update { $0.source = "structureFresh" }
            let files = nativeMusic.files
            let directory = store.root.appendingPathComponent(".native-source-" + UUID().uuidString, isDirectory: true)
            let pcm = directory.appendingPathComponent("structure.pcm")
            let result = await withStructurePCM(
                source: source, pcm: pcm, matching: analysis, context: context, files: files)
            switch result {
            case .ready(let arrangement): value = arrangement
            case .failed(let message): throw CoreError.invalidAudio(message)
            case .cancelled: throw CancellationError()
            }
            if let previous { value.retainCorrections(from: previous.arrangement) }
        }

        try Task.checkCancellation()
        guard value.isValid(fileEnd: Double(analysis.frameCount)) else {
            throw CoreError.invalidAudio("Musical structure analysis returned invalid boundaries.")
        }
        let cues = SectionCueAllocator.allocate(sections: value.sections, existing: [:], alreadyPrepared: false)
        let cache = ArrangementCache(
            version: MusicalStructureAnalyzer.version, content: analysis.contentSHA256,
            configuration: analysis.configurationID, context: context, arrangement: value, automaticCues: cues,
            rhythmProfile: analysis.acceptedDeepBeatAnalysis?.profile.id)
        let url = arrangementURL(track.id)
        do {
            let span = AnalysisMeasurement.begin("structurePersistence")
            defer { span?.finish() }
            try await nativeMusic.files.run { Result { try cache.write(to: url) } }.get()
        }
        try Task.checkCancellation()
        showLibraryArrangement(cache, track: track)
        return cache
    }

    private func withStructurePCM(
        source: URL, pcm: URL, matching analysis: AudioAnalysis, context: MusicalStructureContext,
        files: BackgroundFileWork
    ) async -> ArrangementPreparationResult {
        let directory = pcm.deletingLastPathComponent()
        let result: ArrangementPreparationResult
        do {
            try await files.run {
                Result { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
            }.get()
            do {
                let span = AnalysisMeasurement.begin("structurePCM")
                defer { span?.finish() }
                try await PCMCache.writeStructurePCM(source: source, destination: pcm, matching: analysis)
            }
            do {
                let span = AnalysisMeasurement.begin("structureAnalysis")
                defer { span?.finish() }
                result = await ArrangementPreparationQueue.shared.prepare(
                    pcm: pcm, analysis: analysis, context: context)
            }
        } catch is CancellationError {
            result = .cancelled
        } catch {
            result = .failed(error.localizedDescription)
        }
        await files.run { try? FileManager.default.removeItem(at: directory) }
        return result
    }

    private func showLibraryArrangement(_ cache: ArrangementCache, track: Track) {
        guard loaded.values.contains(track.id) else { return }
        arrangements[track.id] = cache.arrangement
        arrangementVersions[track.id] = cache.version
        arrangementContexts[track.id] = cache.context
        installSectionCues(cache.arrangement, trackID: track.id, cachedCues: cache.automaticCues)
    }

    func prepareArrangement(deck: DeckID) async {
        guard !preparingPlayback.contains(deck), let track = track(deck) else {
            return
        }
        let id = track.id
        let analysis = track.analysis
        let canonical = library.track(id: id) ?? track
        let context = MusicalStructureContext(title: canonical.title, genre: canonical.genre)
        if let value = arrangements[id], arrangementVersions[id] == MusicalStructureAnalyzer.version,
            arrangementContexts[id] == context
        {
            installSectionCues(value, trackID: id)
            return
        }
        let old = await readArrangementCache(track: track)
        guard !Task.isCancelled, loaded[deck] == id else { return }
        if arrangements[id] == nil {
            if let old {
                arrangements[id] = old.arrangement
                arrangementContexts[id] = old.context
                arrangementVersions[id] =
                    old.configuration == analysis.configurationID && old.context == context ? old.version : 1
            } else if !analysis.waveform.isEmpty {
                arrangements[id] = TrackArrangement.prepare(analysis: analysis)
                arrangementVersions[id] = 1
            }
        }
        if arrangementVersions[id] == MusicalStructureAnalyzer.version, arrangementContexts[id] == context,
            let value = arrangements[id]
        {
            installSectionCues(value, trackID: id, cachedCues: old?.automaticCues)
            return
        }
        guard !nativeMusic.wanted, !arrangementPlaybackActive, !analysis.waveform.isEmpty else { return }
        structureAnalyzing.insert(id)
        let task: Task<ArrangementPreparationResult, Never>
        if let pending = arrangementTasks[id], !pending.isCancelled, arrangementTaskContexts[id] == context {
            task = pending
        } else {
            arrangementTasks[id]?.cancel()
            let pcm = BandWaveforms.cacheURL(track: track, store: store)
            task = Task.detached(priority: .utility) {
                let deadline = Date().addingTimeInterval(30)
                while (try? pcm.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ Int64($0) }) != analysis
                    .frameCount * 8
                {
                    guard !Task.isCancelled, Date() < deadline else {
                        return .failed(
                            "The audio cache is not ready. Reload the track to retry musical structure analysis.")
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                }
                return await ArrangementPreparationQueue.shared.prepare(pcm: pcm, analysis: analysis, context: context)
            }
            arrangementTasks[id] = task
            arrangementTaskContexts[id] = context
        }
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, !self.loaded.values.contains(id) else { return }
                task.cancel()
            }
        }
        if arrangementTasks[id] == task {
            arrangementTasks[id] = nil
            arrangementTaskContexts[id] = nil
            structureAnalyzing.remove(id)
        }
        guard !Task.isCancelled, !task.isCancelled, !arrangementPlaybackActive, loaded[deck] == id,
            self.track(deck).map({ MusicalStructureContext(title: $0.title, genre: $0.genre) }) == context
        else { return }
        switch result {
        case .ready(var value):
            if let previous = arrangements[id] { value.retainCorrections(from: previous) }
            guard value.isValid(fileEnd: Double(analysis.frameCount)) else {
                status = "Musical structure analysis returned invalid boundaries. Saved preparation is retained."
                return
            }
            arrangements[id] = value
            arrangementVersions[id] = MusicalStructureAnalyzer.version
            arrangementContexts[id] = context
            persistArrangement(trackID: id)
            installSectionCues(value, trackID: id)
        case .failed(let message): status = message
        case .cancelled: break
        }
    }
    var arrangementPlaybackActive: Bool {
        DeckID.primary.contains {
            playbackSnapshot?[$0].phase.active == true || playbackSnapshot?[$0].touchActive == true
        }
    }
    func updateArrangementScheduling(wasPlaying: Bool) {
        if arrangementPlaybackActive {
            for task in arrangementTasks.values { task.cancel() }
            for task in gridDetectionTasks.values { task.cancel() }
        } else if wasPlaying {
            for deck in DeckID.primary where loaded[deck] != nil {
                Task { [weak self] in await self?.prepareArrangement(deck: deck) }
            }
        }
    }
    private func installSectionCues(
        _ arrangement: TrackArrangement, trackID: String, cachedCues: [Int: PerformanceCue]? = nil
    ) {
        guard
            arrangement.sections.contains(where: {
                $0.role != .unknown || $0.behaviour != .sustaining || !$0.name.isEmpty
            })
        else { return }
        let old = performance.cues[trackID] ?? [:]
        let prepared = performance.sectionCueTracks?.contains(trackID) == true
        let candidates =
            (old.isEmpty && !prepared ? cachedCues : nil)
            ?? SectionCueAllocator.allocate(sections: arrangement.sections, existing: old, alreadyPrepared: prepared)
        let deleted = performance.traktorCueHistory?[trackID]?.protectedEmptySlots ?? []
        let cues = candidates.filter { old[$0.key] != nil || !deleted.contains($0.key) }
        guard cues != old || !prepared else { return }
        performance.cues[trackID] = cues
        if performance.sectionCueTracks == nil { performance.sectionCueTracks = [] }
        performance.sectionCueTracks?.insert(trackID)
        savePerformance()
    }
    func persistArrangement(trackID: String) {
        guard let value = arrangements[trackID],
            let track = DeckID.primary.compactMap({ self.track($0) }).first(where: { $0.id == trackID })
        else { return }
        let url = arrangementURL(trackID)
        let cache = ArrangementCache(
            version: arrangementVersions[trackID] ?? 1, content: track.analysis.contentSHA256,
            configuration: track.analysis.configurationID, context: arrangementContexts[trackID], arrangement: value,
            automaticCues: SectionCueAllocator.allocate(
                sections: value.sections, existing: [:], alreadyPrepared: false),
            rhythmProfile: track.analysis.acceptedDeepBeatAnalysis?.profile.id
        )
        let writer = arrangementWriters[trackID] ?? CoalescingFileWriter<ArrangementCache>()
        arrangementWriters[trackID] = writer
        writer.enqueue(
            cache,
            write: { try $0.write(to: url) }, reportError: { [weak self] in self?.status = $0 })
    }
    @discardableResult func updateArrangement(_ value: TrackArrangement, deck: DeckID) -> Bool {
        guard let track = track(deck) else { return false }
        let end = Double(track.analysis.frameCount)
        guard
            value.sections.allSatisfy({
                $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end > $0.start && $0.end <= end
            }),
            value.landmarks.allSatisfy({
                $0.frame.isFinite && $0.frame >= 0 && $0.frame <= end
                    && ($0.end.map { $0.isFinite && $0 <= end && $0 >= 0 } ?? true)
            })
        else {
            status = "Keep section boundaries and landmarks inside the track."
            return false
        }
        for landmark in value.landmarks {
            if let finish = landmark.end, finish <= landmark.frame {
                status = "Place the region end after its start."
                return false
            }
        }
        let sorted = value.sections.sorted { $0.start < $1.start }
        guard zip(sorted, sorted.dropFirst()).allSatisfy({ $0.end <= $1.start }) else {
            status = "Keep sections in order without overlap."
            return false
        }
        var corrected = value
        if let end = value.landmarks.first(where: { $0.kind == .musicalEnd && $0.locked && $0.state != .dismissed }) {
            corrected.musicalEnd = end.frame
            corrected.endIsEstimated = false
        }
        corrected.rhythmicEnd =
            value.landmarks.first(where: { $0.kind == .rhythmicEnd && $0.state != .dismissed })?.frame
        guard corrected.isValid(fileEnd: end) else {
            status = "Keep the rhythmic ending before the musical ending."
            return false
        }
        corrected.landmarks.sort { $0.frame < $1.frame }
        corrected.sections = sorted
        arrangements[track.id] = corrected
        persistArrangement(trackID: track.id)
        installSectionCues(corrected, trackID: track.id)
        return true
    }
    func promoteLandmark(_ landmark: ArrangementLandmark, deck: DeckID) {
        guard let track = track(deck), let slot = (0..<8).first(where: { performance.cues[track.id]?[$0] == nil })
        else {
            status = "All hot cue slots are in use."
            return
        }
        // Preserve audible pickups exactly. Promotion never snaps to the beat grid.
        performance.cues[track.id, default: [:]][slot] = .init(frame: landmark.frame, loopEnd: landmark.end)
        savePerformance()
        status = "Added \(landmark.name) to hot cue \(slot+1)."
    }
    func arrangementStatus(deck: DeckID, prepareBars: Int = 32) -> ArrangementStatus? {
        guard let track = track(deck), let arrangement = arrangements[track.id] else { return nil }
        let state = playbackSnapshot?[deck]
        let reliable =
            track.preparation.gridIsManual || track.preparation.gridLocked || track.analysis.tempoConfidence >= 0.6
        return arrangement.status(
            frame: state?.sourceFrame ?? 0, continuingFrame: state?.continuingFrame,
            fileEnd: Double(track.analysis.frameCount), sampleRate: track.analysis.sampleRate,
            timing: state?.timing ?? timing(deck), reliableGrid: reliable, playing: state?.phase == .playing,
            rate: (state?.performanceRate ?? 1) * (state?.speed ?? 1), loop: state?.loopEnabled ?? false,
            slip: state?.fluxEnabled ?? false, prepareBars: prepareBars)
    }
    func arrangementAudible(deck: DeckID) -> Bool {
        guard let snapshot = playbackSnapshot else { return false }
        let state = snapshot[deck]
        let cross = deck == .a ? 1 - snapshot.crossfader : snapshot.crossfader
        return state.mixer.volume > 0.05 && state.mixer.gain > 0.01 && snapshot.masterGain > 0.01 && cross > 0.05
    }
}

enum ArrangementPreparationResult: Sendable {
    case ready(TrackArrangement)
    case failed(String)
    case cancelled
}

/// Serial preparation keeps two deck loads from running classifiers together.
private actor ArrangementPreparationQueue {
    static let shared = ArrangementPreparationQueue()
    func prepare(pcm: URL, analysis: AudioAnalysis, context: MusicalStructureContext) async
        -> ArrangementPreparationResult
    {
        let cancellation = VocalInferenceCancellation()
        return await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                let features = try MusicalStructureAnalyzer.analyze(
                    pcm: pcm, analysis: analysis, checkCancellation: cancellation.check)
                var phrases = [VocalPhrase]()
                if features.filter({ ($0.vocal ?? 0) >= 0.3 }).count >= 3 {
                    guard let model = VocalPhraseRecognizer.bundledModel else {
                        return .failed("The offline vocal model is missing. Reinstall the app to restore it.")
                    }
                    phrases = try VocalPhraseRecognizer.phrases(
                        pcm: pcm, analysis: analysis, model: model, cancellation: cancellation)
                    let prepared = try VocalPhraseRecognizer.refine(
                        pcm: pcm, analysis: analysis, features: features, context: context, initial: phrases,
                        model: model, cancellation: cancellation)
                    return .ready(prepared.arrangement)
                }
                try cancellation.check()
                return .ready(
                    TrackArrangement.prepare(
                        analysis: analysis, features: features, context: context, vocalPhrases: phrases))
            } catch is CancellationError { return .cancelled } catch {
                return .failed("Musical structure analysis failed: \(error.localizedDescription)")
            }
        } onCancel: {
            cancellation.cancel()
        }
    }
}
