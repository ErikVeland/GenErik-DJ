import AVFoundation
import Accelerate
import Foundation

/// Read mono audio at the model rate and retain only the samples for the current model window.
final class BeatThisAudio {
    static let rate = 22050.0
    static let hop = 441
    static let bands = 128
    private static let fftSize = 1024
    private static let binCount = fftSize / 2 + 1
    private static let hann = (0..<fftSize).map { Float(0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(fftSize))) }

    private let file: AVAudioFile
    private let input: AVAudioPCMBuffer
    private let output: AVAudioPCMBuffer
    private let converter: AVAudioConverter?
    private let filters: [Float]
    private let fft: FFTSetup
    private let sourceFrames: Int64
    private let sampleCount: Int
    private var samples: [Float] = []
    private var sampleStart = 0
    private var inputError: (any Error)?
    private var real = [Float](repeating: 0, count: fftSize)
    private var imaginary = [Float](repeating: 0, count: fftSize)
    private var magnitude = [Float](repeating: 0, count: binCount)
    private var mel = [Float](repeating: 0, count: bands)
    var frameCount: Int { sampleCount / Self.hop + 1 }

    init(url: URL, sourceFrames: Int64) throws {
        file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        let count = (Double(sourceFrames) * Self.rate / format.sampleRate).rounded()
        guard count >= 2, count < Double(Int.max / 2),
            let target = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: Self.rate, channels: format.channelCount,
                interleaved: false),
            let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192),
            let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 8192),
            let filterURL = Bundle.module.url(
                forResource: "mel-filters", withExtension: "f32", subdirectory: "BeatThisAssets")
        else { throw CoreError.invalidAudio("Cannot prepare audio for beat analysis.") }
        self.input = input
        self.output = output
        self.sourceFrames = sourceFrames
        sampleCount = Int(count)
        if format.sampleRate == Self.rate {
            converter = nil
        } else {
            guard let resampler = AVAudioConverter(from: format, to: target) else {
                throw CoreError.invalidAudio("Cannot convert the sample rate for beat analysis.")
            }
            resampler.sampleRateConverterQuality = AVAudioQuality.max.rawValue
            converter = resampler
        }
        let weights = try Data(contentsOf: filterURL)
        guard weights.count == Self.bands * Self.binCount * MemoryLayout<Float>.stride,
            let fft = vDSP_create_fftsetup(10, FFTRadix(kFFTRadix2))
        else { throw CoreError.invalidAudio("Cannot load beat analysis filters.") }
        self.fft = fft
        filters = weights.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    deinit { vDSP_destroy_fftsetup(fft) }

    func fill(
        _ frames: Range<Int>, into values: UnsafeMutablePointer<Float>,
        checkCancellation: @Sendable () throws -> Void
    ) throws {
        let firstFrame = max(0, frames.lowerBound)
        let endFrame = min(frameCount, frames.upperBound)
        guard firstFrame < endFrame else { return }
        let firstSample = max(0, firstFrame * Self.hop - Self.fftSize / 2)
        let endSample = min(sampleCount, (endFrame - 1) * Self.hop + Self.fftSize / 2)
        let discard = min(samples.count, firstSample - sampleStart)
        samples.removeFirst(discard)
        sampleStart += discard
        while sampleStart + samples.count < endSample {
            try checkCancellation()
            guard let buffer = try read(), let channels = buffer.floatChannelData else { break }
            let count = Int(buffer.format.channelCount)
            let trim = min(samples.count, max(0, firstSample - sampleStart))
            samples.removeFirst(trim)
            sampleStart += trim
            for index in 0..<Int(buffer.frameLength) {
                var mono: Float = 0
                for channel in 0..<count { mono += channels[channel][index] }
                samples.append(mono / Float(count))
            }
        }
        for frame in firstFrame..<endFrame {
            if frame.isMultiple(of: 32) { try checkCancellation() }
            for index in 0..<Self.fftSize {
                let source = frame * Self.hop + index - Self.fftSize / 2
                let folded = abs(source) % (2 * (sampleCount - 1))
                let reflected = min(folded, 2 * (sampleCount - 1) - folded)
                let offset = reflected - sampleStart
                real[index] = (samples.indices.contains(offset) ? samples[offset] : 0) * Self.hann[index]
            }
            vDSP_vclr(&imaginary, 1, vDSP_Length(Self.fftSize))
            real.withUnsafeMutableBufferPointer { re in
                imaginary.withUnsafeMutableBufferPointer { im in
                    var split = DSPSplitComplex(realp: re.baseAddress!, imagp: im.baseAddress!)
                    vDSP_fft_zip(fft, &split, 1, 10, FFTDirection(FFT_FORWARD))
                    vDSP_zvabs(&split, 1, &magnitude, 1, vDSP_Length(Self.binCount))
                }
            }
            vDSP_mmul(
                filters, 1, magnitude, 1, &mel, 1, vDSP_Length(Self.bands), 1, vDSP_Length(Self.binCount))
            let row = values.advanced(by: (frame - frames.lowerBound) * Self.bands)
            for band in 0..<Self.bands { row[band] = log1p(mel[band] * 31.25) }
        }
    }

    private func readInput(upTo requested: AVAudioFrameCount) throws -> Bool {
        let remaining = min(Int64(min(requested, input.frameCapacity)), sourceFrames - file.framePosition)
        guard remaining > 0 else { return false }
        try file.read(into: input, frameCount: AVAudioFrameCount(remaining))
        return input.frameLength > 0
    }

    private func read() throws -> AVAudioPCMBuffer? {
        guard let converter else {
            return try readInput(upTo: input.frameCapacity) ? input : nil
        }
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { [self] requested, status in
            do {
                let hasData = try readInput(upTo: requested)
                status.pointee = hasData ? .haveData : .endOfStream
                return hasData ? input : nil
            } catch {
                inputError = error
                status.pointee = .endOfStream
                return nil
            }
        }
        if let inputError { throw inputError }
        if status == .error { throw error ?? CoreError.invalidAudio("Cannot resample audio for beat analysis.") }
        return output.frameLength > 0 ? output : nil
    }
}
