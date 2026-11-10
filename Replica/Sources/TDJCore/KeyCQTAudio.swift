import AVFoundation
import Accelerate
import Foundation

public protocol KeyFeatureAudio {
    var frameCount: Int { get }
    func fill(_ frames: Range<Int>, into values: UnsafeMutablePointer<Float>) throws
}

/// The pinned MusicalKeyCNN frontend uses sparse, complex constant-Q filters.
public final class KeyCQTAudio: KeyFeatureAudio {
    private struct Filter: Decodable {
        let indices: [Int]
        let real: [Float]
        let imaginary: [Float]
    }
    private struct Group: Decodable {
        let sampleRate: Int
        let hop: Int
        let fftSize: Int
        let firstBand: Int
        let filters: [Filter]
    }
    private struct Bank: Decodable { let format: String; let groups: [Group] }
    private let banks: [RateBank]
    private var nextFrame = 0
    public let frameCount: Int

    private let check: @Sendable () throws -> Void

    public init(url: URL, filtersURL: URL, checkCancellation: @escaping @Sendable () throws -> Void = { try Task.checkCancellation() }) throws {
        check = checkCancellation
        let bank = try JSONDecoder().decode(Bank.self, from: Data(contentsOf: filtersURL))
        guard bank.format == "generik.key-cqt/v1", bank.groups.count == 5 else {
            throw CoreError.invalidAudio("The constant-Q filter bank is invalid.")
        }
        var covered = Set<Int>()
        for group in bank.groups {
            guard [44100, 22050, 11025].contains(group.sampleRate), group.hop * 5 == group.sampleRate,
                (1024...32768).contains(group.fftSize), group.fftSize.nonzeroBitCount == 1,
                group.firstBand >= 0, group.firstBand + group.filters.count <= 105 else {
                throw CoreError.invalidAudio("The constant-Q filter dimensions are invalid.")
            }
            for (index, filter) in group.filters.enumerated() {
                guard covered.insert(group.firstBand + index).inserted, !filter.indices.isEmpty,
                    filter.indices.count == filter.real.count, filter.indices.count == filter.imaginary.count,
                    filter.indices.allSatisfy({ (0...group.fftSize / 2).contains($0) }),
                    filter.real.allSatisfy(\.isFinite), filter.imaginary.allSatisfy(\.isFinite) else {
                    throw CoreError.invalidAudio("The constant-Q filter coefficients are invalid.")
                }
            }
        }
        guard covered.count == 105 else { throw CoreError.invalidAudio("The key filters have missing bands.") }
        let groups = bank.groups
        let rates = Array(Set(groups.map(\.sampleRate))).sorted(by: >)
        let source = try CQTSource(url: url, consumers: rates.count, checkCancellation: checkCancellation)
        banks = try rates.enumerated().map { index, rate in
            try RateBank(groups: groups.filter { $0.sampleRate == rate }, source: source,
                         consumer: index, checkCancellation: checkCancellation)
        }
        frameCount = max(0, Int((Double(source.frameCount) * 44100 / source.format.sampleRate).rounded()) / 8820 - 1)
        guard frameCount >= 8 else { throw CoreError.invalidAudio("The key model needs at least two seconds of audio.") }
    }

    public func fill(_ frames: Range<Int>, into values: UnsafeMutablePointer<Float>) throws {
        guard frames.lowerBound >= nextFrame, frames.upperBound <= frameCount else {
            throw CoreError.invalidAudio("The key feature range is invalid or precedes saved input.")
        }
        // Advance every rate together, including gaps left by saved feature windows.
        for frame in nextFrame..<frames.upperBound {
            try check()
            for bank in banks {
                try bank.fill(frame: frame, into: frame >= frames.lowerBound
                    ? values.advanced(by: (frame - frames.lowerBound) * 105) : nil)
            }
            nextFrame = frame + 1
        }
    }

    private final class RateBank {
        let reader: CQTReader
        let hop: Int
        let spectra: [Spectrum]
        var samples: [Float]
        init(groups: [Group], source: CQTSource, consumer: Int,
             checkCancellation: @escaping @Sendable () throws -> Void) throws {
            reader = try CQTReader(source: source, consumer: consumer, rate: Double(groups[0].sampleRate),
                                   checkCancellation: checkCancellation)
            hop = groups[0].hop
            spectra = try groups.map(Spectrum.init)
            samples = .init(repeating: 0, count: groups.map(\.fftSize).max()!)
        }
        func fill(frame: Int, into values: UnsafeMutablePointer<Float>?) throws {
            try reader.fill(start: frame * hop - samples.count / 2, into: &samples)
            guard let values else { return }
            for spectrum in spectra { try spectrum.fill(samples, into: values) }
        }
    }

    private final class Spectrum {
        let group: Group
        let fft: FFTSetup
        let power: vDSP_Length
        var real: [Float]
        var imaginary: [Float]
        init(_ group: Group) throws {
            self.group = group
            power = vDSP_Length(group.fftSize.trailingZeroBitCount)
            guard let fft = vDSP_create_fftsetup(power, FFTRadix(kFFTRadix2)) else {
                throw CoreError.invalidAudio("Cannot prepare the key spectrum.")
            }
            self.fft = fft
            real = .init(repeating: 0, count: group.fftSize)
            imaginary = real
        }
        deinit { vDSP_destroy_fftsetup(fft) }
        func fill(_ samples: [Float], into values: UnsafeMutablePointer<Float>) throws {
            let offset = (samples.count - real.count) / 2
            for i in real.indices { real[i] = samples[offset + i] }
            vDSP_vclr(&imaginary, 1, vDSP_Length(imaginary.count))
            real.withUnsafeMutableBufferPointer { re in
                imaginary.withUnsafeMutableBufferPointer { im in
                    var split = DSPSplitComplex(realp: re.baseAddress!, imagp: im.baseAddress!)
                    vDSP_fft_zip(fft, &split, 1, power, FFTDirection(FFT_FORWARD))
                }
            }
            for (band, filter) in group.filters.enumerated() {
                var re: Float = 0
                var im: Float = 0
                for index in filter.indices.indices {
                    let bin = filter.indices[index]
                    re += filter.real[index] * real[bin] - filter.imaginary[index] * imaginary[bin]
                    im += filter.real[index] * imaginary[bin] + filter.imaginary[index] * real[bin]
                }
                let value = log1p(hypot(re, im))
                guard value.isFinite else { throw CoreError.invalidAudio("The key spectrum is not finite.") }
                values[group.firstBand + band] = value
            }
        }
    }
}

private final class CQTSource {
    let file: AVAudioFile
    let format: AVAudioFormat
    let frameCount: Int64
    private let buffer: AVAudioPCMBuffer
    private let check: @Sendable () throws -> Void
    private var positions: [Int64]
    private var samples: [[Float]]
    private var first: Int64 = 0

    init(url: URL, consumers: Int, checkCancellation: @escaping @Sendable () throws -> Void) throws {
        file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        format = file.processingFormat
        frameCount = file.length
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else {
            throw CoreError.invalidAudio("Cannot prepare shared key audio.")
        }
        self.buffer = buffer
        check = checkCancellation
        positions = .init(repeating: 0, count: consumers)
        samples = .init(repeating: [], count: Int(format.channelCount))
    }

    func read(consumer: Int, requested: AVAudioFrameCount, into output: AVAudioPCMBuffer) throws -> Bool {
        try check()
        let position = positions[consumer]
        let count = Int(min(Int64(min(requested, output.frameCapacity)), frameCount - position))
        guard count > 0 else { output.frameLength = 0; return false }
        let discard = Int(positions.min()! - first)
        if discard > 0 {
            for channel in samples.indices { samples[channel].removeFirst(discard) }
            first += Int64(discard)
        }
        while first + Int64(samples[0].count) < position + Int64(count) {
            try check()
            try file.read(into: buffer, frameCount: AVAudioFrameCount(min(8192, frameCount - file.framePosition)))
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else {
                throw CoreError.invalidAudio("The key audio ended before its recorded length.")
            }
            for channel in samples.indices {
                samples[channel].append(contentsOf: UnsafeBufferPointer(start: channels[channel], count: Int(buffer.frameLength)))
            }
            guard samples[0].count <= max(131072, Int(format.sampleRate)) else {
                throw CoreError.invalidAudio("The key audio readers exceeded their buffer limit.")
            }
            AnalysisMeasurement.current?.count("keySourceDecodedFrames", Int64(buffer.frameLength))
            AnalysisMeasurement.current?.update {
                $0.counters["keySourcePeakBufferedFrames"] = max($0.counters["keySourcePeakBufferedFrames", default: 0], Int64(samples[0].count))
            }
        }
        guard let channels = output.floatChannelData else {
            throw CoreError.invalidAudio("The key audio buffer has no channels.")
        }
        let offset = Int(position - first)
        for channel in samples.indices {
            samples[channel].withUnsafeBufferPointer { source in
                channels[channel].update(from: source.baseAddress!.advanced(by: offset), count: count)
            }
        }
        output.frameLength = AVAudioFrameCount(count)
        positions[consumer] += Int64(count)
        return true
    }
}

private final class CQTReader {
    private let source: CQTSource
    private let consumer: Int
    private let input: AVAudioPCMBuffer
    private let output: AVAudioPCMBuffer
    private let converter: AVAudioConverter?
    private var samples: [Float] = []
    private var sampleStart = 0
    private var inputError: (any Error)?
    let sampleCount: Int

    private let check: @Sendable () throws -> Void

    init(source: CQTSource, consumer: Int, rate: Double, checkCancellation: @escaping @Sendable () throws -> Void) throws {
        check = checkCancellation
        self.source = source; self.consumer = consumer
        let format = source.format
        let count = (Double(source.frameCount) * rate / format.sampleRate).rounded()
        guard count >= 2, count <= rate * 24 * 3600,
            let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate,
                                       channels: format.channelCount, interleaved: false),
            let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192),
            let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 8192) else {
            throw CoreError.invalidAudio("Cannot prepare constant-Q audio.")
        }
        self.input = input; self.output = output; sampleCount = Int(count)
        if format.sampleRate == rate { converter = nil }
        else {
            guard let converter = AVAudioConverter(from: format, to: target) else {
                throw CoreError.invalidAudio("Cannot convert the key sample rate.")
            }
            converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
            self.converter = converter
        }
    }

    func fill(start: Int, into values: inout [Float]) throws {
        let first = max(0, start)
        let discard = min(samples.count, max(0, first - sampleStart))
        samples.removeFirst(discard); sampleStart += discard
        let end = min(sampleCount, start + values.count)
        while sampleStart + samples.count < end {
            try check()
            let trim = min(samples.count, max(0, first - sampleStart))
            samples.removeFirst(trim); sampleStart += trim
            guard let buffer = try read(), let channels = buffer.floatChannelData else { break }
            let channelCount = Int(buffer.format.channelCount)
            for frame in 0..<Int(buffer.frameLength) {
                let mono = (0..<channelCount).reduce(Float(0)) { $0 + channels[$1][frame] } / Float(channelCount)
                guard mono.isFinite else { throw CoreError.invalidAudio("The key audio contains a non-finite sample.") }
                samples.append(mono)
            }
        }
        for index in values.indices {
            let position = start + index
            let offset = position - sampleStart
            values[index] = position >= 0 && position < sampleCount && samples.indices.contains(offset) ? samples[offset] : 0
        }
    }

    private func readInput(_ requested: AVAudioFrameCount) throws -> Bool {
        try source.read(consumer: consumer, requested: requested, into: input)
    }
    private func read() throws -> AVAudioPCMBuffer? {
        guard let converter else { return try readInput(input.frameCapacity) ? input : nil }
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { [self] requested, status in
            do {
                let hasData = try readInput(requested)
                status.pointee = hasData ? .haveData : .endOfStream
                return hasData ? input : nil
            } catch { inputError = error; status.pointee = .endOfStream; return nil }
        }
        if let inputError { throw inputError }
        if status == .error { throw error ?? CoreError.invalidAudio("Cannot resample the key audio.") }
        return output.frameLength > 0 ? output : nil
    }
}
