import AVFoundation
import Foundation
import whisper
#if canImport(TDJCore)
import TDJCore
#endif

final class VocalInferenceCancellation: @unchecked Sendable {
    private let lock=NSLock()
    private var cancelled=false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled=true; lock.unlock() }
    func check() throws { if isCancelled { throw CancellationError() } }
}

/// Offline preparation only. No text leaves this function or enters a saved arrangement.
enum VocalPhraseRecognizer {
    static var bundledModel: URL? {
#if SWIFT_PACKAGE
        Bundle.module.url(forResource:"vocal-model",withExtension:"bin",subdirectory:"VocalModelAssets")
#else
        nil
#endif
    }

    static func phrases(pcm: URL, analysis: AudioAnalysis, model: URL,
                        cancellation: VocalInferenceCancellation) throws -> [VocalPhrase] {
        try cancellation.check()
        let samples=try monoSamples(pcm:pcm,analysis:analysis,cancellation:cancellation)
        var contextParameters=whisper_context_default_params()
        contextParameters.use_gpu=false
        guard let context=whisper_init_from_file_with_params(model.path,contextParameters) else {
            throw CoreError.invalidAudio("The offline vocal model could not open. Reinstall the app to restore it.")
        }
        defer { whisper_free(context) }
        try cancellation.check()
        var parameters=whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        parameters.n_threads=2
        parameters.no_context=true
        parameters.language=nil
        parameters.print_progress=false
        parameters.print_realtime=false
        parameters.print_timestamps=false
        // Allow non-speech output instead of forcing lyric words over instrumental audio.
        parameters.suppress_nst=false
        let pointer=Unmanaged.passUnretained(cancellation).toOpaque()
        parameters.abort_callback_user_data=pointer
        parameters.abort_callback = { pointer in
            guard let pointer else { return true }
            return Unmanaged<VocalInferenceCancellation>.fromOpaque(pointer).takeUnretainedValue().isCancelled
        }
        parameters.encoder_begin_callback_user_data=pointer
        parameters.encoder_begin_callback = { _, _, pointer in
            guard let pointer else { return false }
            return !Unmanaged<VocalInferenceCancellation>.fromOpaque(pointer).takeUnretainedValue().isCancelled
        }
        let result=samples.withUnsafeBufferPointer { whisper_full(context,parameters,$0.baseAddress,Int32($0.count)) }
        try cancellation.check()
        guard result == 0 else { throw CoreError.invalidAudio("Offline vocal analysis failed. Reload the track to retry.") }
        var phrases=[VocalPhrase]()
        let endToken=whisper_token_eot(context), fileEnd=Double(analysis.frameCount)
        for segment in 0..<whisper_full_n_segments(context) {
            try cancellation.check()
            guard whisper_full_get_segment_no_speech_prob(context,segment) < 0.6,
                  let text=whisper_full_get_segment_text(context,segment) else { continue }
            var probabilities=[Double]()
            for index in 0..<whisper_full_n_tokens(context,segment) {
                let token=whisper_full_get_token_data(context,segment,index)
                if token.id < endToken, token.p.isFinite { probabilities.append(Double(token.p)) }
            }
            let confidence=probabilities.reduce(0,+)/Double(max(1,probabilities.count))
            let start=Double(whisper_full_get_segment_t0(context,segment))*analysis.sampleRate/100
            let end=min(fileEnd,Double(whisper_full_get_segment_t1(context,segment))*analysis.sampleRate/100)
            let value=String(cString:text).trimmingCharacters(in:.whitespacesAndNewlines)
            guard !value.hasPrefix("("), !value.hasPrefix("["), start >= 0, end > start else { continue }
            phrases.append(.init(start:start,end:end,text:value,confidence:confidence))
        }
        return phrases
    }

    static func monoSamples(pcm: URL, analysis: AudioAnalysis,
                                    cancellation: VocalInferenceCancellation) throws -> [Float] {
        let rate=analysis.sampleRate, frames=analysis.frameCount
        guard rate.isFinite, rate >= 8000, rate <= 384000, frames > 0,
              frames <= Int64(Int.max/8), Double(frames)/rate <= 2700 else {
            throw CoreError.invalidAudio("Offline vocal analysis supports tracks up to 45 minutes.")
        }
        let data=try Data(contentsOf:pcm,options:.alwaysMapped)
        guard data.count == Int(frames)*8,
              let inputFormat=AVAudioFormat(standardFormatWithSampleRate:rate,channels:1),
              let outputFormat=AVAudioFormat(standardFormatWithSampleRate:16000,channels:1),
              let converter=AVAudioConverter(from:inputFormat,to:outputFormat),
              let input=AVAudioPCMBuffer(pcmFormat:inputFormat,frameCapacity:8192),
              let output=AVAudioPCMBuffer(pcmFormat:outputFormat,frameCapacity:16000*30),
              let mono=input.floatChannelData?[0], let converted=output.floatChannelData?[0] else {
            throw CoreError.invalidAudio("Cannot prepare audio for offline vocal analysis.")
        }
        converter.sampleRateConverterQuality=AVAudioQuality.high.rawValue
        return try data.withUnsafeBytes { raw in
            let stereo=raw.bindMemory(to:Float.self)
            var position=0, samples=[Float]()
            samples.reserveCapacity(Int(Double(frames)/rate*16000)+16000)
            while true {
                try cancellation.check()
                var error: NSError?
                let status=converter.convert(to:output,error:&error) { requested, state in
                    guard position < Int(frames), !cancellation.isCancelled else { state.pointee = .endOfStream; return nil }
                    let count=min(Int(requested),Int(input.frameCapacity),Int(frames)-position)
                    for offset in 0..<count { mono[offset]=(stereo[(position+offset)*2]+stereo[(position+offset)*2+1])*0.5 }
                    input.frameLength=AVAudioFrameCount(count)
                    position += count
                    state.pointee = .haveData
                    return input
                }
                try cancellation.check()
                if let error { throw error }
                guard status != .error else { throw CoreError.invalidAudio("Cannot resample audio for offline vocal analysis.") }
                let chunk=UnsafeBufferPointer(start:converted,count:Int(output.frameLength))
                guard chunk.allSatisfy(\.isFinite) else { throw CoreError.invalidAudio("The vocal analysis source contains invalid samples.") }
                samples.append(contentsOf:chunk)
                if status == .endOfStream { return samples }
            }
        }
    }
}
