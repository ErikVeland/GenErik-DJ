import AVFoundation
import CryptoKit
import Foundation

public struct AnalysisConfiguration: Sendable {
    public var id: String { "independent-dsp-0.3.2-late-rhythm-adaptive-candidate-multiband-consensus-tuned-hpcp-\(minimumBPM)-\(maximumBPM)" }
    public var minimumBPM: Double = 60
    public var maximumBPM: Double = 200
    public init() {}
}

public enum AudioAnalyzer {
    public static func analyze(url: URL, configuration: AnalysisConfiguration = .init(),
                               checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }) throws -> AudioAnalysis {
        guard configuration.minimumBPM.isFinite, configuration.maximumBPM.isFinite,
              configuration.minimumBPM > 0, (60 / configuration.minimumBPM).isFinite,
              configuration.maximumBPM >= configuration.minimumBPM, configuration.maximumBPM <= 1000 else {
            throw CoreError.invalidAudio("Invalid analysis tempo range.")
        }
        let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        try checkCancellation()
        let hash = try sha256(url: url, checkCancellation: checkCancellation)
        let decoded = try decode(url: url, waveformFramesPerBin: nil, analyzeMusic: true, checkCancellation: checkCancellation)
        try checkUnchanged(url: url, before: before)
        guard let pulses = decoded.pulses, let spectrum = decoded.spectrum else {
            throw CoreError.invalidAudio("Musical analysis features are unavailable.")
        }
        let rhythm = try MusicalRhythmAnalyzer.analyze(frames: pulses.frames, sampleRate: decoded.sampleRate,
            framesPerBin: pulses.framesPerBin, spectralActivity: spectrum.activity,
            configuration: configuration, checkCancellation: checkCancellation)
        try checkCancellation()
        let harmonic = spectrum.finish()
        let duration = Double(decoded.frameCount) / decoded.sampleRate
        let brightness = harmonic.timbre.count >= 6 ? harmonic.timbre[4] + harmonic.timbre[5] : 0
        let energy = MusicalRhythmAnalyzer.energy(frames: pulses.frames, duration: duration, rhythm: rhythm,
            spectralActivity: spectrum.activity, brightness: brightness)
        var analysis = AudioAnalysis(implementation: "Independent multiband consensus DSP v0.2.1. TDJ1 equivalence unverified.",
            configurationID: configuration.id, contentSHA256: hash, sampleRate: decoded.sampleRate,
            frameCount: decoded.frameCount, channelCount: decoded.channelCount, waveformFramesPerBin: decoded.binFrames,
            waveform: decoded.waveform, bpm: rhythm.bpm, beatAnchorFrame: rhythm.anchorSeconds.map { $0 * decoded.sampleRate },
            tempoConfidence: rhythm.confidence, key: harmonic.key, keyConfidence: harmonic.confidence,
            chroma: harmonic.chroma, timbre: harmonic.timbre)
        if let map = rhythm.adaptiveCandidate, (try? map.validate(frameCount: decoded.frameCount)) != nil {
            analysis.adaptiveCandidate = map
            analysis.adaptiveConfidence = rhythm.confidence
        }
        analysis.detectedDownbeatOffset = rhythm.downbeat
        analysis.downbeatConfidence = rhythm.downbeatConfidence
        analysis.musicalEnergy = energy
        analysis.cachedEnergyLevel = energy?.level
        analysis.tuningCents = harmonic.tuningCents
        analysis.keyStability = harmonic.stability
        analysis.gridResidualMilliseconds = rhythm.gridResidualMilliseconds
        try checkCancellation()
        return analysis
    }

    public static func waveformOnly(url: URL,
                                    checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }) throws -> AudioAnalysis {
        let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let hash = try sha256(url: url, checkCancellation: checkCancellation)
        let decoded = try decode(url: url, waveformFramesPerBin: nil, analyzeMusic: false, checkCancellation: checkCancellation)
        try checkUnchanged(url: url, before: before)
        var result = AudioAnalysis(implementation: "Waveform-only import; original TDJ preparation is retained separately.",
            configurationID: "tdj-preparation-waveform-1", contentSHA256: hash, sampleRate: decoded.sampleRate,
            frameCount: decoded.frameCount, channelCount: decoded.channelCount, waveformFramesPerBin: decoded.binFrames,
            waveform: decoded.waveform, bpm: nil, beatAnchorFrame: nil, tempoConfidence: 0,
            key: nil, keyConfidence: 0, chroma: [], timbre: [])
        result.musicalAnalysisDeferred = true
        try checkCancellation()
        return result
    }

    public static func rebuildWaveform(url: URL, matching expected: AudioAnalysis,
                                       checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }) throws -> AudioAnalysis {
        guard expected.waveformFramesPerBin > 0 else { throw CoreError.invalidAudio("Invalid waveform bin size.") }
        let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let hash = try sha256(url: url, checkCancellation: checkCancellation)
        guard hash == expected.contentSHA256 else { throw CoreError.invalidAudio("Waveform source differs from the analysed audio.") }
        let decoded = try decode(url: url, waveformFramesPerBin: expected.waveformFramesPerBin,
            analyzeMusic: false, checkCancellation: checkCancellation)
        try checkUnchanged(url: url, before: before)
        guard decoded.sampleRate == expected.sampleRate, decoded.frameCount == expected.frameCount,
              decoded.channelCount == expected.channelCount else {
            throw CoreError.invalidAudio("Waveform source format differs from the retained analysis.")
        }
        return expected.replacingWaveform(decoded.waveform)
    }

    public static func sha256(url: URL, checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            try checkCancellation()
            digest.update(data: data)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private struct DecodedAudio {
        let sampleRate: Double
        let channelCount: Int
        let frameCount: Int64
        let binFrames: Int
        let waveform: [WaveformBin]
        let pulses: MusicalPulseAccumulator?
        let spectrum: MusicalSpectrumAnalyzer?
    }

    private static func decode(url: URL, waveformFramesPerBin: Int?, analyzeMusic: Bool,
                               checkCancellation: @Sendable () throws -> Void) throws -> DecodedAudio {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let rate = file.processingFormat.sampleRate
        let channels = Int(file.processingFormat.channelCount)
        let declaredFrames = file.length
        guard rate.isFinite, rate > 0, declaredFrames > 0, channels > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 32768) else {
            throw CoreError.invalidAudio("The file contains no readable audio.")
        }
        let binFrames = waveformFramesPerBin ?? max(1, Int((rate / 100).rounded()))
        var waveform: [WaveformBin] = []
        var count = 0
        var low: Float = 0, high: Float = 0
        var power = 0.0
        var framesRead: Int64 = 0
        var pulses = analyzeMusic ? MusicalPulseAccumulator(sampleRate: rate) : nil
        let spectrum = analyzeMusic ? try MusicalSpectrumAnalyzer(sampleRate: rate) : nil
        var previousInput = 0.0, previousFiltered = 0.0
        let highPass = exp(-2 * .pi * 20 / rate)
        while framesRead < declaredFrames {
            try checkCancellation()
            let remaining = AVAudioFrameCount(min(Int64(buffer.frameCapacity), declaredFrames - framesRead))
            try file.read(into: buffer, frameCount: remaining)
            let length = Int(buffer.frameLength)
            guard length > 0, let data = buffer.floatChannelData else { break }
            var channelPower = [Double](repeating: 0, count: channels)
            var monoPower = 0.0
            for frame in 0..<length {
                var mono = 0.0
                for channel in 0..<channels {
                    let value = Double(data[channel][frame])
                    guard value.isFinite else { throw CoreError.invalidAudio("Audio contains non-finite samples.") }
                    channelPower[channel] += value * value
                    mono += value / Double(channels)
                }
                monoPower += mono * mono
            }
            let loudest = channelPower.indices.max { channelPower[$0] < channelPower[$1] } ?? 0
            let singleChannel = monoPower < channelPower[loudest] * 0.05
            for frame in 0..<length {
                var sample: Float = 0
                if singleChannel { sample = data[loudest][frame] }
                else { for channel in 0..<channels { sample += data[channel][frame] / Float(channels) } }
                low = min(low, sample)
                high = max(high, sample)
                power += Double(sample) * Double(sample)
                count += 1
                if analyzeMusic {
                    let input = Double(sample)
                    let filtered = input - previousInput + highPass * previousFiltered
                    previousInput = input
                    previousFiltered = filtered
                    pulses?.consume(filtered)
                    spectrum?.consume(filtered)
                }
                if count == binFrames {
                    waveform.append(.init(minimum: low, maximum: high, rms: Float(sqrt(power / Double(count)))))
                    count = 0
                    low = 0
                    high = 0
                    power = 0
                }
            }
            framesRead += Int64(length)
        }
        if count > 0 { waveform.append(.init(minimum: low, maximum: high, rms: Float(sqrt(power / Double(count))))) }
        guard framesRead > 0 else { throw CoreError.invalidAudio("No audio frames were decoded.") }
        pulses?.finish()
        return .init(sampleRate: rate, channelCount: channels, frameCount: framesRead,
            binFrames: binFrames, waveform: waveform, pulses: pulses, spectrum: spectrum)
    }

    private static func checkUnchanged(url: URL, before: URLResourceValues) throws {
        let after = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        guard before.fileSize == after.fileSize, before.contentModificationDate == after.contentModificationDate else {
            throw CoreError.invalidAudio("The source changed during analysis. Analyse the unchanged file again.")
        }
    }
}
