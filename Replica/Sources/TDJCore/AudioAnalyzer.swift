import AVFoundation
import CryptoKit
import Foundation

public struct AnalysisConfiguration: Sendable {
    static let mixOpeningSuffix = "-mix-opening-1"

    public var id: String {
        "beat-this-small0-grid-1-tuned-hpcp-\(minimumBPM)-\(maximumBPM)"
    }
    public var minimumBPM: Double = 60
    public var maximumBPM: Double = 200
    public init() {}

    func id(for duration: Double) -> String {
        NativeAnalysisPlan.isMix(duration: duration) ? id + Self.mixOpeningSuffix : id
    }
}

public struct BeatGridDetection: Codable, Sendable {
    public let grid: BeatGrid
    public let tempoConfidence: Double
    public let downbeatConfidence: Double?
}

public enum AudioAnalyzer {
    /// Read the prepared stereo cache without changing the saved source analysis or imported preparation.
    public static func detectBeatGrid(
        pcm: URL, matching analysis: AudioAnalysis,
        checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }
    ) throws -> BeatGridDetection? {
        try checkCancellation()
        let before = try pcm.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        guard analysis.sampleRate.isFinite, analysis.sampleRate > 0, analysis.frameCount > 0,
            analysis.frameCount <= Int64.max / 8, before.fileSize.map({ Int64($0) == analysis.frameCount * 8 }) == true
        else {
            throw CoreError.invalidAudio(
                "The prepared audio cache does not match the track. Reload the track and try again.")
        }
        let handle = try FileHandle(forReadingFrom: pcm)
        defer { try? handle.close() }
        var pulses = MusicalPulseAccumulator(sampleRate: analysis.sampleRate)
        let spectrum = try MusicalSpectrumAnalyzer(sampleRate: analysis.sampleRate)
        var previous = 0.0
        var filtered = 0.0
        var framesRead: Int64 = 0
        let highPass = exp(-2 * .pi * 20 / analysis.sampleRate)
        while framesRead < analysis.frameCount {
            try checkCancellation()
            let requested = Int(min(32768, analysis.frameCount - framesRead)) * 8
            guard let data = try handle.read(upToCount: requested), data.count == requested else {
                throw CoreError.invalidAudio("The prepared audio cache is incomplete. Reload the track and try again.")
            }
            try data.withUnsafeBytes { bytes in
                let samples = bytes.bindMemory(to: Float.self)
                var leftPower = 0.0
                var rightPower = 0.0
                var monoPower = 0.0
                for index in stride(from: 0, to: samples.count, by: 2) {
                    let left = Double(samples[index])
                    let right = Double(samples[index + 1])
                    guard left.isFinite, right.isFinite else {
                        throw CoreError.invalidAudio("Audio contains non-finite samples.")
                    }
                    leftPower += left * left
                    rightPower += right * right
                    monoPower += pow((left + right) * 0.5, 2)
                }
                let singleChannel = monoPower < max(leftPower, rightPower) * 0.05
                for index in stride(from: 0, to: samples.count, by: 2) {
                    let value =
                        singleChannel
                        ? samples[index + (leftPower >= rightPower ? 0 : 1)]
                        : samples[index] * 0.5 + samples[index + 1] * 0.5
                    let input = Double(value)
                    filtered = input - previous + highPass * filtered
                    previous = input
                    pulses.consume(filtered)
                    spectrum.consume(filtered)
                }
            }
            framesRead += Int64(requested / 8)
        }
        pulses.finish()
        try checkUnchanged(url: pcm, before: before)
        let activity = spectrum.activity
        let rhythm = try MusicalRhythmAnalyzer.analyze(
            frames: pulses.frames, sampleRate: analysis.sampleRate, framesPerBin: pulses.framesPerBin,
            spectralActivity: activity, configuration: .init(), harmonicFrames: spectrum.harmonicFrames,
            checkCancellation: checkCancellation)
        guard let bpm = rhythm.bpm, let anchor = rhythm.anchorSeconds, rhythm.confidence >= 0.72 else { return nil }
        return BeatGridDetection(
            grid: try BeatGrid(
                bpm: bpm, anchorFrame: anchor * analysis.sampleRate, sampleRate: analysis.sampleRate,
                downbeatOffset: rhythm.downbeat ?? 0), tempoConfidence: rhythm.confidence,
            downbeatConfidence: rhythm.downbeatConfidence)
    }

    public static func analyze(
        url: URL, configuration: AnalysisConfiguration = .init(),
        checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }
    ) throws -> AudioAnalysis {
        guard configuration.minimumBPM.isFinite, configuration.maximumBPM.isFinite, configuration.minimumBPM > 0,
            (60 / configuration.minimumBPM).isFinite, configuration.maximumBPM >= configuration.minimumBPM,
            configuration.maximumBPM <= 1000
        else { throw CoreError.invalidAudio("Invalid analysis tempo range.") }
        let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        AnalysisMeasurement.current?.update { $0.sourceSizeBytes = before.fileSize }
        try checkCancellation()
        let hash = try sha256(url: url, checkCancellation: checkCancellation)
        let decoded = try decode(
            url: url, waveformFramesPerBin: nil, analyzeMusic: true, checkCancellation: checkCancellation)
        try checkUnchanged(url: url, before: before)
        guard let pulses = decoded.pulses, let spectrum = decoded.spectrum else {
            throw CoreError.invalidAudio("Musical analysis features are unavailable.")
        }
        var rhythm = try AnalysisMeasurement.measure("dspRhythm") {
            try MusicalRhythmAnalyzer.analyze(
                frames: pulses.frames, sampleRate: decoded.sampleRate, framesPerBin: pulses.framesPerBin,
                spectralActivity: spectrum.activity, configuration: configuration,
                harmonicFrames: spectrum.harmonicFrames,
                checkCancellation: checkCancellation)
        }
        let duration = Double(decoded.frameCount) / decoded.sampleRate
        let configurationID = configuration.id(for: duration)
        AnalysisMeasurement.current?.update { $0.requestedConfigurationID = configurationID }
        let beatFrames = BeatThisAnalyzer.sourceFrameLimit(decoded.frameCount, sampleRate: decoded.sampleRate)
        let requiresOpeningBar = beatFrames < decoded.frameCount
        let fitted: BeatThisGrid?
        if duration >= 11 * 60 / configuration.maximumBPM {
            fitted = try BeatThisAnalyzer.analyze(
                url: url, sourceFrames: beatFrames, configuration: configuration, requireOpeningBar: requiresOpeningBar,
                checkCancellation: checkCancellation)
        } else {
            fitted = nil
        }
        try checkUnchanged(url: url, before: before)
        if let fitted {
            if let map = rhythm.adaptiveCandidate {
                let firstFrame = fitted.firstBar * decoded.sampleRate
                let bar = map.beat(atFrame: firstFrame) - Double(map.downbeatOffset)
                if abs(bar - (bar / 4).rounded() * 4) > 0.15
                    || rhythm.bpm.map({ abs($0 / fitted.bpm - 1) > 0.01 }) != false
                {
                    rhythm.adaptiveCandidate = nil
                }
            }
            rhythm.bpm = fitted.bpm
            rhythm.anchorSeconds = fitted.firstBar
            rhythm.confidence = fitted.beatAgreement
            rhythm.downbeat = 0
            rhythm.downbeatConfidence = fitted.barAgreement
            rhythm.gridResidualMilliseconds = fitted.residualMilliseconds
        } else if requiresOpeningBar {
            rhythm.downbeat = nil
            rhythm.downbeatConfidence = nil
        }
        try checkCancellation()
        let harmonic = AnalysisMeasurement.measure("keyFinalization") { spectrum.finish() }
        let brightness = harmonic.timbre.count >= 6 ? harmonic.timbre[4] + harmonic.timbre[5] : 0
        let energy = MusicalRhythmAnalyzer.energy(
            frames: pulses.frames, duration: duration, rhythm: rhythm, spectralActivity: spectrum.activity,
            brightness: brightness)
        var analysis = AudioAnalysis(
            implementation: fitted == nil
                ? "Beat This small0 with DSP grid fallback"
                : requiresOpeningBar ? "Beat This small0 opening grid" : "Beat This small0 fitted grid",
            configurationID: configurationID, contentSHA256: hash, sampleRate: decoded.sampleRate,
            frameCount: decoded.frameCount, channelCount: decoded.channelCount, waveformFramesPerBin: decoded.binFrames,
            waveform: decoded.waveform, bpm: rhythm.bpm,
            beatAnchorFrame: rhythm.anchorSeconds.map { $0 * decoded.sampleRate }, tempoConfidence: rhythm.confidence,
            key: harmonic.key, keyConfidence: harmonic.confidence, chroma: harmonic.chroma, timbre: harmonic.timbre)
        if let map = rhythm.adaptiveCandidate, (try? map.validate(frameCount: decoded.frameCount)) != nil {
            analysis.adaptiveCandidate = map
            analysis.adaptiveConfidence = rhythm.confidence
        }
        analysis.beatModelVersion = "BeatThis/small0-6074be2c-mel1-fit1"
        analysis.detectedDownbeatOffset = rhythm.downbeat
        analysis.downbeatConfidence = rhythm.downbeatConfidence
        analysis.barAnalysisVersion = BarStartAnalysis.version
        analysis.musicalEnergy = energy
        analysis.cachedEnergyLevel = energy?.level
        analysis.tuningCents = harmonic.tuningCents
        analysis.keyStability = harmonic.stability
        analysis.gridResidualMilliseconds = rhythm.gridResidualMilliseconds
        try checkCancellation()
        AnalysisMeasurement.current?.capture(analysis)
        return analysis
    }

    public static func waveformOnly(
        url: URL, checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }
    ) throws -> AudioAnalysis {
        let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        AnalysisMeasurement.current?.update { $0.sourceSizeBytes = before.fileSize }
        let hash = try sha256(url: url, checkCancellation: checkCancellation)
        let decoded = try decode(
            url: url, waveformFramesPerBin: nil, analyzeMusic: false, checkCancellation: checkCancellation)
        try checkUnchanged(url: url, before: before)
        var result = AudioAnalysis(
            implementation: "Waveform-only import; original TDJ preparation is retained separately.",
            configurationID: "tdj-preparation-waveform-1", contentSHA256: hash, sampleRate: decoded.sampleRate,
            frameCount: decoded.frameCount, channelCount: decoded.channelCount, waveformFramesPerBin: decoded.binFrames,
            waveform: decoded.waveform, bpm: nil, beatAnchorFrame: nil, tempoConfidence: 0, key: nil, keyConfidence: 0,
            chroma: [], timbre: [])
        result.musicalAnalysisDeferred = true
        try checkCancellation()
        AnalysisMeasurement.current?.capture(result)
        return result
    }

    public static func rebuildWaveform(
        url: URL, matching expected: AudioAnalysis,
        checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }
    ) throws -> AudioAnalysis {
        guard expected.waveformFramesPerBin > 0 else { throw CoreError.invalidAudio("Invalid waveform bin size.") }
        let before = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let hash = try sha256(url: url, checkCancellation: checkCancellation)
        guard hash == expected.contentSHA256 else {
            throw CoreError.invalidAudio("Waveform source differs from the analysed audio.")
        }
        let decoded = try decode(
            url: url, waveformFramesPerBin: expected.waveformFramesPerBin, analyzeMusic: false,
            checkCancellation: checkCancellation)
        try checkUnchanged(url: url, before: before)
        guard decoded.sampleRate == expected.sampleRate, decoded.frameCount == expected.frameCount,
            decoded.channelCount == expected.channelCount
        else { throw CoreError.invalidAudio("Waveform source format differs from the retained analysis.") }
        return expected.replacingWaveform(decoded.waveform)
    }

    public static func sha256(
        url: URL, checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }
    ) throws -> String {
        let span = AnalysisMeasurement.begin("sourceHash")
        let measurement = AnalysisMeasurement.current
        var bytes: Int64 = 0
        defer {
            span?.finish()
            measurement?.count("hashBytesRead", bytes)
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        // Release Foundation read buffers after each chunk, including during long-mix hashing.
        while try autoreleasepool(invoking: {
            guard let data = try handle.read(upToCount: 1_048_576), !data.isEmpty else { return false }
            bytes += Int64(data.count)
            try checkCancellation()
            digest.update(data: data)
            return true
        }) {}
        let hash = digest.finalize().map { String(format: "%02x", $0) }.joined()
        measurement?.update {
            $0.contentSHA256 = hash
            $0.sourceHashComputed = true
        }
        return hash
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

    private static func decode(
        url: URL, waveformFramesPerBin: Int?, analyzeMusic: Bool, checkCancellation: @Sendable () throws -> Void
    ) throws -> DecodedAudio {
        let span = AnalysisMeasurement.begin(analyzeMusic ? "decodeAndFeatures" : "decodeWaveform")
        defer { span?.finish() }
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let rate = file.processingFormat.sampleRate
        let channels = Int(file.processingFormat.channelCount)
        let declaredFrames = file.length
        guard rate.isFinite, rate > 0, declaredFrames > 0, channels > 0,
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 32768)
        else { throw CoreError.invalidAudio("The file contains no readable audio.") }
        let binFrames = waveformFramesPerBin ?? max(1, Int((rate / 100).rounded()))
        var waveform: [WaveformBin] = []
        var count = 0
        var low: Float = 0
        var high: Float = 0
        var power = 0.0
        var framesRead: Int64 = 0
        var pulses = analyzeMusic ? MusicalPulseAccumulator(sampleRate: rate) : nil
        let spectrum = analyzeMusic ? try MusicalSpectrumAnalyzer(sampleRate: rate) : nil
        var previousInput = 0.0
        var previousFiltered = 0.0
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
                if singleChannel {
                    sample = data[loudest][frame]
                } else {
                    for channel in 0..<channels { sample += data[channel][frame] / Float(channels) }
                }
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
        return .init(
            sampleRate: rate, channelCount: channels, frameCount: framesRead, binFrames: binFrames, waveform: waveform,
            pulses: pulses, spectrum: spectrum)
    }

    private static func checkUnchanged(url: URL, before: URLResourceValues) throws {
        let span = AnalysisMeasurement.begin("sourceStatVerification")
        defer { span?.finish() }
        let after = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        guard before.fileSize == after.fileSize, before.contentModificationDate == after.contentModificationDate else {
            throw CoreError.invalidAudio("The source changed during analysis. Analyse the unchanged file again.")
        }
    }
}
