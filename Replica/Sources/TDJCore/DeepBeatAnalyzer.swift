import AVFoundation
import CoreML
import Foundation

enum DeepBeatAnalyzer {
    private static let compiledModel = Result {
        guard
            let source = Bundle.module.url(
                forResource: "BeatThisFullANE", withExtension: "mlpackage", subdirectory: "BeatThisAssets")
        else { throw CoreError.invalidAudio("The deep beat model is missing.") }
        return try MLModel.compileModel(at: source)
    }

    static func analyze(
        url: URL, analysis: AudioAnalysis, root: URL,
        progress: @Sendable (Int, Int) -> Void, checkCancellation: @Sendable () throws -> Void
    ) throws -> DeepBeatAnalysis {
        guard BeatThisWindows.frameCount(analysis) > 0 else {
            throw CoreError.invalidAudio("Deep analysis supports audio up to 24 hours long.")
        }
        let checkpoints = DeepAnalysisCheckpoints(root: root, analysis: analysis)
        if let result = checkpoints.result() { return result }
        let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        guard try AudioAnalyzer.sha256(url: url, checkCancellation: checkCancellation) == analysis.contentSHA256 else {
            throw CoreError.invalidAudio("The audio changed. Existing deep analysis was retained.")
        }
        let file = try AVAudioFile(forReading: url)
        guard file.length == analysis.frameCount, file.processingFormat.sampleRate == analysis.sampleRate,
            file.processingFormat.channelCount == analysis.channelCount
        else {
            throw CoreError.invalidAudio("The deep-analysis source has different audio dimensions.")
        }
        let audio = try BeatThisAudio(url: url, sourceFrames: analysis.frameCount)
        let settings = MLModelConfiguration()
        settings.computeUnits = .cpuAndNeuralEngine
        // A deep-stage failure stays resumable. Do not start a large CPU fallback on the iPad.
        var model: MLModel?
        let features = try MLMultiArray(shape: [1, 1500, 128], dataType: .float32)
        let input = try MLDictionaryFeatureProvider(dictionary: ["spectrogram": features])
        return try run(checkpoints: checkpoints, progress: progress, checkCancellation: checkCancellation, guidedPhase: { bpm, beats in
            try AudioAnalyzer.guidedBeatPhase(url: url, matching: analysis, bpm: bpm, neuralBeats: beats,
                                             checkCancellation: checkCancellation)
        }, analyzeKey: {
            let current = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            guard current.fileSize == before.fileSize, current.contentModificationDate == before.contentModificationDate else {
                throw CoreError.invalidAudio("The audio changed before key analysis.")
            }
            let key = try withoutActuallyEscaping(checkCancellation) { boundedCheck in
                try LearnedKeyAnalyzer.analyze(url: url, analysis: analysis, root: root, checkCancellation: boundedCheck)
            }
            guard try AudioAnalyzer.sha256(url: url, checkCancellation: checkCancellation) == analysis.contentSHA256 else {
                throw CoreError.invalidAudio("The audio changed during deep analysis.")
            }
            return key
        }) {
            index, start in
            try checkCancellation()
            if model == nil {
                model = try MLModel(contentsOf: compiledModel.get(), configuration: settings)
                let metadata = model?.modelDescription.metadata[.creatorDefinedKey] as? [String: String]
                guard metadata?["checkpointSHA256"] == DeepAnalysisProfile.current.weightsSHA256,
                    metadata?["variant"] == "final0-fp16-v1"
                else {
                    throw CoreError.invalidAudio("The bundled deep model has a different version.")
                }
                AnalysisMeasurement.current?.update {
                    $0.modelID = "BeatThis/final0-fp16-v1"
                    $0.beatThisRequestedComputeUnits = "cpuAndNeuralEngine"
                    $0.beatThisEffectiveComputeUnits = "cpuAndNeuralEngine"
                }
            }
            return try autoreleasepool {
                try features.withUnsafeMutableBufferPointer(ofType: Float.self) { values, _ in
                    values.update(repeating: 0)
                    try audio.fill(
                        start..<(start + 1500), into: values.baseAddress!, checkCancellation: checkCancellation)
                }
                try checkCancellation()
                let prediction = try AnalysisMeasurement.measure("deepBeatInference") {
                    try model!.prediction(from: input)
                }
                try BeatThisAnalyzer.validateLogits(prediction)
                var beats: [Float] = []
                var downbeats: [Float] = []
                try BeatThisAnalyzer.append(prediction, name: "beats", range: 0..<1500, to: &beats)
                try BeatThisAnalyzer.append(prediction, name: "downbeats", range: 0..<1500, to: &downbeats)
                let after = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                guard before.fileSize == after.fileSize, before.contentModificationDate == after.contentModificationDate
                else {
                    throw CoreError.invalidAudio("The audio changed during deep analysis.")
                }
                return .init(index: index, start: start, beats: beats, downbeats: downbeats)
            }
        }
    }

    static func run(
        checkpoints: DeepAnalysisCheckpoints, progress: (Int, Int) -> Void,
        checkCancellation: @Sendable () throws -> Void,
        guidedPhase: (Double, [Double]) throws -> GuidedBeatPhase? = { _, _ in nil },
        analyzeKey: () throws -> LearnedKeyAnalysis? = { nil }, predict: (Int, Int) throws -> DeepPredictionWindow
    ) throws -> DeepBeatAnalysis {
        if let result = checkpoints.result() { return result }
        let frames = BeatThisWindows.frameCount(checkpoints.analysis)
        var beats: [Float] = []
        var downbeats: [Float] = []
        for (index, start) in checkpoints.starts.enumerated() {
            try checkCancellation()
            let window: DeepPredictionWindow
            if let saved = checkpoints.read(index) {
                window = saved
                AnalysisMeasurement.current?.cacheHit("deepWindow")
            } else {
                window = try predict(index, start)
                try checkpoints.write(window)
            }
            let first = max(6, beats.count - start)
            let end = min(1494, frames - start)
            guard first <= end else { throw CoreError.invalidAudio("Invalid deep-analysis window coverage.") }
            beats.append(contentsOf: window.beats[first..<end])
            downbeats.append(contentsOf: window.downbeats[first..<end])
            progress(index + 1, checkpoints.starts.count)
        }
        try checkCancellation()
        guard beats.count == frames else {
            throw CoreError.invalidAudio("Deep analysis has incomplete audio coverage.")
        }
        let grid = try BeatThisAnalyzer.fit(
            beats: beats, downbeats: downbeats, configuration: .init(),
            requireOpeningBar: true, checkCancellation: checkCancellation)
        let beatTimes = BeatThisAnalyzer.peaks(beats)
        let constantCandidate = grid.map(DeepBeatCandidate.init)
        // Development references measured an 8 ms early bias. Keep this correction in review evidence only.
        let refinedBeats = DeepRhythmTiming.refinedPeaks(beats).map { $0 + 0.008 }
        let refinedBars = DeepRhythmTiming.refinedPeaks(downbeats).map { $0 + 0.008 }
        let originalAdaptive = try DeepAdaptiveBeatCandidate.fit(
            beats: refinedBeats, bars: refinedBars,
            sampleRate: checkpoints.analysis.sampleRate, frameCount: checkpoints.analysis.frameCount,
            checkCancellation: checkCancellation)
        let fittedAdaptive = try originalAdaptive ?? DeepRhythmRecovery.fit(
            beats: refinedBeats, bars: refinedBars, barLogits: downbeats,
            sampleRate: checkpoints.analysis.sampleRate, frameCount: checkpoints.analysis.frameCount,
            checkCancellation: checkCancellation)
        let adaptive = grid?.openingPhaseCorrected == true ? nil : fittedAdaptive
        if originalAdaptive == nil, adaptive != nil {
            AnalysisMeasurement.current?.count("deepRhythmRecoveredCandidates", 1)
        }
        let tempo = grid == nil ? try BeatThisTempo.preferred(
            beats: beatTimes, configuration: .init(), checkCancellation: checkCancellation) : nil
        let phase = try tempo.flatMap { try guidedPhase($0, beatTimes) }
        let result = DeepBeatAnalysis(
            audio: .init(checkpoints.analysis), profile: checkpoints.profile,
            coveredFrames: checkpoints.analysis.frameCount, windowCount: checkpoints.starts.count,
            candidate: constantCandidate,
            tempoCandidateBPM: tempo, guidedPhase: phase,
            adaptiveCandidate: adaptive, learnedKey: try analyzeKey(),
            rhythmEvidence: try DeepRhythmEvidence.measure(
                beats: beats, bars: downbeats, times: beatTimes, constant: constantCandidate,
                adaptive: grid?.openingPhaseCorrected == true ? nil : originalAdaptive,
                checkCancellation: checkCancellation))
        try checkCancellation()
        try checkpoints.finish(result)
        return result
    }
}

extension AnalysisWorker {
    public func deepBeatAnalysis(
        url: URL, matching analysis: AudioAnalysis, root: URL,
        progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) async throws -> DeepBeatAnalysis {
        try await run { check in
            try withoutActuallyEscaping(check) { boundedCheck in
                try DeepBeatAnalyzer.analyze(
                    url: url, analysis: analysis, root: root,
                    progress: { done, total in
                        progress(done, total)
                        AnalysisWorkProgress.observer?(0.20 + 0.65 * Double(done) / Double(total))
                    }, checkCancellation: boundedCheck)
            }
        }
    }
}
