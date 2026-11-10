import AVFoundation
import Accelerate
import Foundation
import TDJCore

/// The pinned MusicalKeyCNN frontend uses sparse, complex constant-Q filters.
final class KeyCQTAudio: KeyFeatureAudio {
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
    private let groups: [Group]
    private let readers: [CQTReader]
    let frameCount: Int

    init(url: URL, filtersURL: URL) throws {
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
        groups = bank.groups
        readers = try groups.map { try CQTReader(url: url, rate: Double($0.sampleRate)) }
        frameCount = max(0, readers[0].sampleCount / groups[0].hop - 1)
        guard frameCount >= 8 else { throw CoreError.invalidAudio("The key model needs at least two seconds of audio.") }
    }

    func fill(_ frames: Range<Int>, into values: UnsafeMutablePointer<Float>) throws {
        guard frames.lowerBound >= 0, frames.upperBound <= frameCount else {
            throw CoreError.invalidAudio("The key feature range is invalid.")
        }
        for (group, reader) in zip(groups, readers) {
            let size = group.fftSize
            let power = vDSP_Length(size.trailingZeroBitCount)
            guard let fft = vDSP_create_fftsetup(power, FFTRadix(kFFTRadix2)) else {
                throw CoreError.invalidAudio("Cannot prepare the key spectrum.")
            }
            defer { vDSP_destroy_fftsetup(fft) }
            var real = [Float](repeating: 0, count: size)
            var imaginary = real
            for frame in frames {
                try Task.checkCancellation()
                let start = frame * group.hop - size / 2
                try reader.fill(start: start, into: &real)
                vDSP_vclr(&imaginary, 1, vDSP_Length(size))
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
                    values[(frame - frames.lowerBound) * 105 + group.firstBand + band] = value
                }
            }
        }
    }
}

private final class CQTReader {
    private let file: AVAudioFile
    private let input: AVAudioPCMBuffer
    private let output: AVAudioPCMBuffer
    private let converter: AVAudioConverter?
    private var samples: [Float] = []
    private var sampleStart = 0
    private var inputError: (any Error)?
    let sampleCount: Int

    init(url: URL, rate: Double) throws {
        file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        let count = (Double(file.length) * rate / format.sampleRate).rounded()
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
            try Task.checkCancellation()
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
        let remaining = min(Int64(min(requested, input.frameCapacity)), file.length - file.framePosition)
        guard remaining > 0 else { return false }
        try file.read(into: input, frameCount: AVAudioFrameCount(remaining))
        return input.frameLength > 0
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
