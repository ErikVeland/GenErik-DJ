import Accelerate
import CoreML
import Foundation
import TDJCore

final class SpleeterVocalMask {
    static let sampleRate = 44_100
    static let hop = 1024
    static let context = 64
    static let outputFrames = (512 - 2 * context) * hop
    static let inputFrames = (512 - 1) * hop + 4096

    private let fft: FFTSetup
    private let model: MLModel
    private let magnitude: MLMultiArray
    private let window: [Float] = (0..<4096).map { 0.5 - 0.5 * cos(2 * .pi * Float($0) / 4096) }
    private var real = [Float](repeating: 0, count: 4096)
    private var imaginary = [Float](repeating: 0, count: 4096)

    init() throws {
        let url = Bundle.module.resourceURL?.appendingPathComponent("LiveStemModelAssets/Spleeter.mlmodelc")
        guard let url else { throw TransportError.invalid }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndGPU
        model = try MLModel(contentsOf: url, configuration: configuration)
        magnitude = try MLMultiArray(shape: [1, 2, 512, 1536], dataType: .float32)
        guard let fft = vDSP_create_fftsetup(12, FFTRadix(kFFTRadix2)) else { throw TransportError.allocation }
        self.fft = fft
    }

    deinit { vDSP_destroy_fftsetup(fft) }

    private func transform(_ direction: Int) {
        let setup = fft
        real.withUnsafeMutableBufferPointer { r in
            imaginary.withUnsafeMutableBufferPointer { i in
                var split = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
                vDSP_fft_zip(setup, &split, 1, 12, FFTDirection(direction))
            }
        }
    }

    private func spectrum(_ input: [Float], _ offset: Int) {
        for i in 0..<4096 {
            real[i] = input[offset + 2 * i] * window[i]
            imaginary[i] = 0
        }
        transform(FFT_FORWARD)
    }

    func vocals(in input: [Float]) throws -> [Float] {
        let values = magnitude.dataPointer.assumingMemoryBound(to: Float.self)
        for channel in 0..<2 {
            for frame in 0..<512 {
                if frame.isMultiple(of: 16) { try Task.checkCancellation() }
                spectrum(input, frame * Self.hop * 2 + channel)
                let base = (channel * 512 + frame) * 1536
                for bin in 0..<1536 { values[base + bin] = hypotf(real[bin], imaginary[bin]) }
            }
        }
        let features = try MLDictionaryFeatureProvider(dictionary: ["magnitude": MLFeatureValue(multiArray: magnitude)])
        let result = try model.prediction(from: features)
        guard let mask = result.featureValue(for: "vocal_mask")?.multiArrayValue,
            mask.dataType == .float32, mask.shape.map(\.intValue) == [1, 2, 512, 1536]
        else { throw TransportError.invalid }
        try Task.checkCancellation()
        let weights = mask.dataPointer.assumingMemoryBound(to: Float.self)
        let strides = mask.strides.map(\.intValue)
        let start = Self.context * Self.hop
        let end = start + Self.outputFrames
        var output = [Float](repeating: 0, count: 2 * Self.outputFrames)
        for channel in 0..<2 {
            for frame in (Self.context - 3)..<(512 - Self.context) {
                if frame.isMultiple(of: 16) { try Task.checkCancellation() }
                let offset = frame * Self.hop
                spectrum(input, 2 * offset + channel)
                let base = channel * strides[1] + frame * strides[2]
                for bin in 0..<2049 {
                    let weight = bin < 1536 ? weights[base + bin * strides[3]] : 0
                    guard weight.isFinite else { throw TransportError.invalid }
                    real[bin] *= weight
                    imaginary[bin] *= weight
                    if bin > 0 && bin < 2048 {
                        real[4096 - bin] *= weight
                        imaginary[4096 - bin] *= weight
                    }
                }
                transform(FFT_INVERSE)
                // Four Hann windows at a quarter-window hop sum to 1.5 after squaring.
                for i in max(0, start - offset)..<min(4096, end - offset) {
                    output[2 * (offset + i - start) + channel] += real[i] * window[i] / 6144
                }
            }
        }
        return output
    }
}
