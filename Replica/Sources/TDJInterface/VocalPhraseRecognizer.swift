import AVFoundation
import Foundation
import whisper

#if canImport(TDJCore)
    import TDJCore
#endif

final class VocalInferenceCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var progress: AnalysisWorkProgress.Step?

    func setProgress(_ step: AnalysisWorkProgress.Step?) {
        lock.withLock { progress = step }
    }

    func reportProgress(_ percent: Int32) {
        lock.withLock { progress?.advance(Int64(percent), of: 100) }
    }
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
    func check() throws { if isCancelled { throw CancellationError() } }
}

struct VocalPhrasePreparation: Sendable {
    var arrangement: TrackArrangement
    var phrases: [VocalPhrase]
    var attemptedWindows: [VocalRecognitionWindow]
    var usedFocusedResult: Bool
}

/// Offline preparation only. No text leaves this function or enters a saved arrangement.
enum VocalPhraseRecognizer {
    static var bundledModel: URL? {
        #if SWIFT_PACKAGE
            Bundle.module.url(forResource: "vocal-model", withExtension: "bin", subdirectory: "VocalModelAssets")
        #else
            nil
        #endif
    }

    static func phrases(pcm: URL, analysis: AudioAnalysis, model: URL, cancellation: VocalInferenceCancellation) throws
        -> [VocalPhrase]
    {
        try cancellation.check()
        let samples = try monoSamples(pcm: pcm, analysis: analysis, cancellation: cancellation, progressRange: 0.84...0.87)
        var contextParameters = whisper_context_default_params()
        contextParameters.use_gpu = false
        guard let context = whisper_init_from_file_with_params(model.path, contextParameters) else {
            throw CoreError.invalidAudio("The offline vocal model could not open. Reinstall the app to restore it.")
        }
        defer { whisper_free(context) }
        try cancellation.check()
        return try samples.withUnsafeBufferPointer {
            try decode(
                $0, sourceOffset: 0, ownedStart: 0, ownedEnd: Double(analysis.frameCount), analysis: analysis,
                context: context, cancellation: cancellation, progressRange: 0.87...0.96)
        }
    }

    static func refine(
        pcm: URL, analysis: AudioAnalysis, features: [MusicalStructureFrame], context: MusicalStructureContext,
        initial: [VocalPhrase], model: URL, cancellation: VocalInferenceCancellation
    ) throws -> VocalPhrasePreparation {
        try cancellation.check()
        let baseline = TrackArrangement.prepare(
            analysis: analysis, features: features, context: context, vocalPhrases: initial)
        func hasVocalForm(_ value: TrackArrangement) -> Bool {
            value.sections.contains { [.verse, .chorus, .hook].contains($0.role) }
        }
        let unchanged = VocalPhrasePreparation(
            arrangement: baseline, phrases: initial, attemptedWindows: [], usedFocusedResult: false)
        guard !hasVocalForm(baseline) else { return unchanged }
        let windows = VocalRecognitionWindow.plan(
            features: features, sampleRate: analysis.sampleRate, frameCount: analysis.frameCount)
        guard !windows.isEmpty else { return unchanged }
        let samples = try monoSamples(pcm: pcm, analysis: analysis, cancellation: cancellation, progressRange: 0.96...0.97)
        var parameters = whisper_context_default_params()
        parameters.use_gpu = false
        guard let inference = whisper_init_from_file_with_params(model.path, parameters) else {
            throw CoreError.invalidAudio("The offline vocal model could not open. Reinstall the app to restore it.")
        }
        defer { whisper_free(inference) }
        var phrases = [VocalPhrase]()
        let share = 0.02 / Double(windows.count)
        for (index, window) in windows.sorted(by: { $0.vocalScore > $1.vocalScore }).enumerated() {
            try cancellation.check()
            let start = max(0, min(samples.count, Int((window.start / analysis.sampleRate * 16000).rounded())))
            let end = max(start, min(samples.count, Int((window.end / analysis.sampleRate * 16000).rounded())))
            guard end > start else { continue }
            let offset = Double(start) / 16000 * analysis.sampleRate
            let startProgress = 0.97 + Double(index) * share
            phrases += try samples.withUnsafeBufferPointer { buffer in
                let region = UnsafeBufferPointer(start: buffer.baseAddress!.advanced(by: start), count: end - start)
                return try decode(
                    region, sourceOffset: offset, ownedStart: window.coreStart, ownedEnd: window.coreEnd,
                    analysis: analysis, context: inference, cancellation: cancellation, musicWindow: true,
                    progressRange: startProgress...(startProgress + share))
            }
        }
        try cancellation.check()
        phrases.sort { $0.start < $1.start }
        let refined = TrackArrangement.prepare(
            analysis: analysis, features: features, context: context, vocalPhrases: phrases)
        let useRefined = hasVocalForm(refined) && refined.isValid(fileEnd: Double(analysis.frameCount))
        return .init(
            arrangement: useRefined ? refined : baseline, phrases: useRefined ? phrases : initial,
            attemptedWindows: windows, usedFocusedResult: useRefined)
    }

    private static func decode(
        _ samples: UnsafeBufferPointer<Float>, sourceOffset: Double, ownedStart: Double, ownedEnd: Double,
        analysis: AudioAnalysis, context: OpaquePointer, cancellation: VocalInferenceCancellation,
        musicWindow: Bool = false, progressRange: ClosedRange<Double>
    ) throws -> [VocalPhrase] {
        try cancellation.check()
        var parameters = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        parameters.n_threads = 2
        parameters.no_context = true
        parameters.language = nil
        parameters.print_progress = false
        parameters.print_realtime = false
        parameters.print_timestamps = false
        // Allow non-speech output instead of forcing lyric words over instrumental audio.
        parameters.suppress_nst = false
        let pointer = Unmanaged.passUnretained(cancellation).toOpaque()
        parameters.abort_callback_user_data = pointer
        parameters.abort_callback = { pointer in
            guard let pointer else { return true }
            return Unmanaged<VocalInferenceCancellation>.fromOpaque(pointer).takeUnretainedValue().isCancelled
        }
        parameters.encoder_begin_callback_user_data = pointer
        parameters.encoder_begin_callback = { _, _, pointer in
            guard let pointer else { return false }
            return !Unmanaged<VocalInferenceCancellation>.fromOpaque(pointer).takeUnretainedValue().isCancelled
        }
        if AnalysisWorkProgress.observer != nil {
            cancellation.setProgress(AnalysisWorkProgress.Step(progressRange))
            parameters.progress_callback_user_data = pointer
            parameters.progress_callback = { _, _, percent, pointer in
                guard let pointer else { return }
                Unmanaged<VocalInferenceCancellation>.fromOpaque(pointer).takeUnretainedValue().reportProgress(percent)
            }
        }
        defer { cancellation.setProgress(nil) }
        let result = whisper_full(context, parameters, samples.baseAddress, Int32(samples.count))
        try cancellation.check()
        guard result == 0 else {
            throw CoreError.invalidAudio("Offline vocal analysis failed. Reload the track to retry.")
        }
        var phrases = [VocalPhrase]()
        let endToken = whisper_token_eot(context)
        let fileEnd = Double(analysis.frameCount)
        for segment in 0..<whisper_full_n_segments(context) {
            try cancellation.check()
            guard let text = whisper_full_get_segment_text(context, segment) else { continue }
            let noSpeech = whisper_full_get_segment_no_speech_prob(context, segment)
            var probabilities = [Double]()
            for index in 0..<whisper_full_n_tokens(context, segment) {
                let token = whisper_full_get_token_data(context, segment, index)
                if token.id < endToken, token.p.isFinite { probabilities.append(Double(token.p)) }
            }
            let confidence = probabilities.reduce(0, +) / Double(max(1, probabilities.count))
            // Strong sung words can coexist with a high speech-silence score.
            guard noSpeech < 0.6 || (musicWindow && confidence >= 0.6) else { continue }
            let rawStart =
                sourceOffset + Double(whisper_full_get_segment_t0(context, segment)) * analysis.sampleRate / 100
            let rawEnd = min(
                fileEnd,
                sourceOffset + Double(whisper_full_get_segment_t1(context, segment)) * analysis.sampleRate / 100)
            let midpoint = (rawStart + rawEnd) / 2
            guard midpoint >= ownedStart, midpoint < ownedEnd else { continue }
            let start = max(ownedStart, rawStart)
            let end = min(ownedEnd, rawEnd)
            let value = String(cString: text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.hasPrefix("("), !value.hasPrefix("["), start >= 0, end > start else { continue }
            phrases.append(.init(start: start, end: end, text: value, confidence: confidence, windowed: musicWindow))
        }
        return phrases
    }

    static func monoSamples(pcm: URL, analysis: AudioAnalysis, cancellation: VocalInferenceCancellation,
        progressRange: ClosedRange<Double>
    ) throws
        -> [Float]
    {
        let rate = analysis.sampleRate
        let frames = analysis.frameCount
        guard rate.isFinite, rate >= 8000, rate <= 384000, frames > 0, frames <= Int64(Int.max / 8),
            Double(frames) / rate <= 2700
        else { throw CoreError.invalidAudio("Offline vocal analysis supports tracks up to 45 minutes.") }
        let data = try Data(contentsOf: pcm, options: .alwaysMapped)
        guard data.count == Int(frames) * 8,
            let inputFormat = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
            let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1),
            let converter = AVAudioConverter(from: inputFormat, to: outputFormat),
            let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 8192),
            let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 16000 * 30),
            let mono = input.floatChannelData?[0], let converted = output.floatChannelData?[0]
        else { throw CoreError.invalidAudio("Cannot prepare audio for offline vocal analysis.") }
        converter.sampleRateConverterQuality = AVAudioQuality.high.rawValue
        return try data.withUnsafeBytes { raw in
            let stereo = raw.bindMemory(to: Float.self)
            var position = 0
            var samples = [Float]()
            var progress = AnalysisWorkProgress.Step(progressRange)
            samples.reserveCapacity(Int(Double(frames) / rate * 16000) + 16000)
            while true {
                try cancellation.check()
                var error: NSError?
                let status = converter.convert(to: output, error: &error) { requested, state in
                    guard position < Int(frames), !cancellation.isCancelled else {
                        state.pointee = .endOfStream
                        return nil
                    }
                    let count = min(Int(requested), Int(input.frameCapacity), Int(frames) - position)
                    for offset in 0..<count {
                        mono[offset] = (stereo[(position + offset) * 2] + stereo[(position + offset) * 2 + 1]) * 0.5
                    }
                    input.frameLength = AVAudioFrameCount(count)
                    position += count
                    state.pointee = .haveData
                    return input
                }
                try cancellation.check()
                if let error { throw error }
                guard status != .error else {
                    throw CoreError.invalidAudio("Cannot resample audio for offline vocal analysis.")
                }
                let chunk = UnsafeBufferPointer(start: converted, count: Int(output.frameLength))
                guard chunk.allSatisfy(\.isFinite) else {
                    throw CoreError.invalidAudio("The vocal analysis source contains invalid samples.")
                }
                samples.append(contentsOf: chunk)
                progress.advance(Int64(position), of: frames)
                if status == .endOfStream { return samples }
            }
        }
    }
}
