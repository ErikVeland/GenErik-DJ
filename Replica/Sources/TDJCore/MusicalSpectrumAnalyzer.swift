import Accelerate
import Foundation

struct MusicalHarmonicResult {
    var key: MusicalKey?
    var confidence: Double
    var chroma: [Double]
    var timbre: [Double]
    var tuningCents: Double?
    var stability: Double?
}

final class MusicalSpectrumAnalyzer {
    private let size: Int
    private let logSize: vDSP_Length
    private let setup: FFTSetupD
    private let sampleRate: Double
    private var ring: [Double]
    private var real: [Double]
    private var imaginary: [Double]
    private var magnitudes: [Double]
    private var previous: [Double]
    private var prefix: [Double]
    private var window: [Double]
    private var samples = 0
    private var previousSum = 0.0
    private var bands = [Double](repeating: 0, count: 6)
    private var centroid = 0.0
    private var activeFrames = 0.0
    private var fluxSum = 0.0
    private var pitchProfile = [Double](repeating: 0, count: 120)
    private var sectionProfile = [Double](repeating: 0, count: 120)
    private var sections: [[Double]] = []
    private var sectionFrames = 0
    private var tonalFrames = 0
    private var tuningX = 0.0
    private var tuningY = 0.0

    private(set) var harmonicFrames: [MusicalHarmonicFrame] = []

    var activity: Double { fluxSum / max(activeFrames, 1) }

    init(sampleRate: Double) throws {
        self.sampleRate = sampleRate
        var exponent = 11
        while exponent < 15 && Double(1 << exponent) < sampleRate / 6 { exponent += 1 }
        size = 1 << exponent
        logSize = vDSP_Length(exponent)
        guard let setup = vDSP_create_fftsetupD(logSize, FFTRadix(kFFTRadix2)) else {
            throw CoreError.invalidAudio("Cannot allocate the spectral analysis transform.")
        }
        self.setup = setup
        ring = .init(repeating: 0, count: size)
        real = ring
        imaginary = ring
        magnitudes = .init(repeating: 0, count: size / 2)
        previous = magnitudes
        prefix = .init(repeating: 0, count: size / 2 + 1)
        let windowSize = size
        window = (0..<windowSize).map { 0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(windowSize - 1)) }
    }

    deinit { vDSP_destroy_fftsetupD(setup) }

    func consume(_ sample: Double) {
        ring[samples % size] = sample
        samples += 1
        if samples >= size && (samples - size).isMultiple(of: size / 4) { transform() }
    }

    private func transform() {
        let sampleCount = samples
        let transformSize = size
        let rate = sampleRate
        ring.withUnsafeBufferPointer { ring in
            window.withUnsafeBufferPointer { window in
                real.withUnsafeMutableBufferPointer { reals in
                    imaginary.withUnsafeMutableBufferPointer { imaginaries in
                        for index in 0..<transformSize {
                            reals[index] = ring[(sampleCount + index) % transformSize] * window[index]
                            imaginaries[index] = 0
                        }
                        var split = DSPDoubleSplitComplex(realp: reals.baseAddress!, imagp: imaginaries.baseAddress!)
                        vDSP_fft_zipD(setup, &split, 1, logSize, FFTDirection(FFT_FORWARD))
                    }
                }
            }
        }
        var sum = 0.0
        var weightedFrequency = 0.0
        var flux = 0.0
        let thresholds = [150.0, 400, 1000, 2500, 6000]
        real.withUnsafeBufferPointer { reals in
            imaginary.withUnsafeBufferPointer { imaginaries in
                magnitudes.withUnsafeMutableBufferPointer { magnitudes in
                    previous.withUnsafeMutableBufferPointer { previous in
                        prefix.withUnsafeMutableBufferPointer { prefix in
                            bands.withUnsafeMutableBufferPointer { bands in
                                prefix[0] = 0
                                for bin in 0..<(transformSize / 2) {
                                    let magnitude = hypot(reals[bin], imaginaries[bin])
                                    magnitudes[bin] = magnitude
                                    prefix[bin + 1] = prefix[bin] + magnitude
                                    if bin == 0 { continue }
                                    let frequency = Double(bin) * rate / Double(transformSize)
                                    flux += max(0, magnitude - previous[bin])
                                    previous[bin] = magnitude
                                    sum += magnitude
                                    weightedFrequency += frequency * magnitude
                                    let band = thresholds.firstIndex { frequency < $0 } ?? 5
                                    bands[band] += magnitude
                                }
                            }
                        }
                    }
                }
            }
        }
        guard sum > 1e-8 else {
            previousSum = 0
            return
        }
        if activeFrames > 0 { fluxSum += min(1, flux / max(sum, previousSum, 1e-12)) }
        previousSum = sum
        centroid += weightedFrequency / sum / (sampleRate / 2)
        activeFrames += 1

        let magnitudeValues = magnitudes
        let cumulative = prefix
        let strongest = magnitudeValues.max() ?? 0
        struct Peak {
            var frequency: Double
            var magnitude: Double
            var bin: Int
        }
        var peaks: [Peak] = []
        for bin in 2..<(size / 2 - 1) {
            let frequency = Double(bin) * sampleRate / Double(size)
            guard frequency >= 35, frequency <= min(5000, sampleRate * 0.45), magnitudeValues[bin] > strongest * 0.004,
                magnitudeValues[bin] >= magnitudeValues[bin - 1], magnitudeValues[bin] > magnitudeValues[bin + 1]
            else { continue }
            let left = log(max(magnitudeValues[bin - 1], 1e-20))
            let center = log(max(magnitudeValues[bin], 1e-20))
            let right = log(max(magnitudeValues[bin + 1], 1e-20))
            let curvature = left - 2 * center + right
            let offset = abs(curvature) > 1e-12 ? min(0.5, max(-0.5, 0.5 * (left - right) / curvature)) : 0
            peaks.append(
                .init(
                    frequency: (Double(bin) + offset) * sampleRate / Double(size), magnitude: magnitudeValues[bin], bin: bin)
            )
        }
        peaks.sort { $0.magnitude > $1.magnitude }
        if peaks.count > 60 { peaks.removeLast(peaks.count - 60) }
        let captured = peaks.reduce(0.0) { $0 + magnitudeValues[$1.bin - 1] + magnitudeValues[$1.bin] + magnitudeValues[$1.bin + 1] }
        guard captured / sum > 0.45 else { return }
        peaks.sort { $0.frequency < $1.frequency }
        var frameProfile = [Double](repeating: 0, count: 120)
        for (index, peak) in peaks.enumerated() {
            let low = max(1, Int(Double(peak.bin) / 1.3))
            let high = min(size / 2, Int(Double(peak.bin) * 1.3) + 1)
            let envelope = (cumulative[high] - cumulative[low]) / Double(high - low)
            var weight = sqrt(peak.magnitude / max(envelope, strongest * 0.001))
            for lower in peaks[..<index] where lower.magnitude > peak.magnitude * 0.4 {
                let ratio = peak.frequency / lower.frequency
                if ratio >= 1.95, ratio <= 8.05, abs(12 * log2(ratio / ratio.rounded())) < 0.12 {
                    weight *= 0.15
                    break
                }
            }
            let midi = 69 + 12 * log2(peak.frequency / 440)
            let position = (midi.truncatingRemainder(dividingBy: 12) + 12).truncatingRemainder(dividingBy: 12) * 10
            let first = Int(floor(position)) % 120
            let fraction = position - floor(position)
            frameProfile[first] += weight * (1 - fraction)
            frameProfile[(first + 1) % 120] += weight * fraction
            tuningX += weight * cos(2 * .pi * midi)
            tuningY += weight * sin(2 * .pi * midi)
        }
        let total = frameProfile.reduce(0, +)
        guard total > 0 else { return }
        var chroma = [Double](repeating: 0, count: 12)
        for index in 0..<120 { chroma[Int((Double(index) / 10).rounded()) % 12] += frameProfile[index] / total }
        harmonicFrames.append(.init(seconds: Double(samples - size / 2) / sampleRate, chroma: chroma))
        for index in 0..<120 {
            let value = frameProfile[index] / total
            pitchProfile[index] += value
            sectionProfile[index] += value
        }
        tonalFrames += 1
        sectionFrames += 1
        if Double(sectionFrames * size / 4) / sampleRate >= 8 {
            sections.append(sectionProfile)
            sectionProfile = .init(repeating: 0, count: 120)
            sectionFrames = 0
        }
    }

    func finish() -> MusicalHarmonicResult {
        let bandTotal = bands.reduce(0, +)
        let timbre = bands.map { $0 / max(bandTotal, 1e-12) } + [centroid / max(activeFrames, 1)]
        let tuning = tonalFrames > 0 ? atan2(tuningY, tuningX) / (2 * .pi) : 0
        func collapse(_ profile: [Double]) -> [Double] {
            var result = [Double](repeating: 0, count: 12)
            for index in profile.indices {
                let corrected = Double(index) / 10 - tuning
                let pitch = ((Int(corrected.rounded()) % 12) + 12) % 12
                result[pitch] += profile[index]
            }
            let total = result.reduce(0, +)
            return result.map { $0 / max(total, 1e-12) }
        }
        let chroma = collapse(pitchProfile)
        let active = chroma.filter { $0 > 0.055 }.count
        guard tonalFrames >= 6, active >= 3 else {
            return .init(
                key: nil, confidence: 0, chroma: chroma, timbre: timbre,
                tuningCents: tonalFrames > 0 ? tuning * 100 : nil, stability: nil)
        }
        let ranking = MusicalKeyEstimator.rank(chroma)
        var localProfiles = sections
        if sectionFrames >= 6 { localProfiles.append(sectionProfile) }
        let localKeys = localProfiles.map { MusicalKeyEstimator.rank(collapse($0))[0].key }
        let decision = MusicalKeyEstimator.select(ranking: ranking, localKeys: localKeys)
        return .init(
            key: decision.key, confidence: decision.confidence, chroma: chroma, timbre: timbre, tuningCents: tuning * 100,
            stability: decision.stability)
    }
}

enum MusicalKeyEstimator {
    struct Candidate {
        let key: MusicalKey
        let score: Double
    }

    static func select(ranking: [Candidate], localKeys: [MusicalKey]) -> (
        key: MusicalKey?, confidence: Double, stability: Double
    ) {
        guard ranking.count >= 2 else { return (nil, 0, 0) }
        let best = ranking[0]
        let margin = best.score - ranking[1].score
        let stability = localKeys.isEmpty ? 0 : Double(localKeys.filter { $0 == best.key }.count) / Double(localKeys.count)
        let confidence = min(1, max(0, margin / 0.2)) * (0.5 + 0.5 * stability)
        let wholeTrack = best.score > 0.45 && margin > 0.02
        let repeatedSections = best.score > 0.4 && margin > 0.04 && localKeys.count >= 3 && stability > 0.5
        return (wholeTrack || repeatedSections ? best.key : nil, confidence, stability)
    }

    static func rank(_ chroma: [Double]) -> [Candidate] {
        let profiles = [
            (
                [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88],
                [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
            ),
            (
                [1.0, 0, 0.15, 0, 0.8, 0.2, 0, 0.7, 0, 0.15, 0, 0.1],
                [1.0, 0, 0.15, 0.8, 0, 0.2, 0, 0.7, 0.15, 0, 0.1, 0.15]
            ),
        ]
        func correlation(_ profile: [Double], tonic: Int) -> Double {
            let meanProfile = profile.reduce(0, +) / 12
            let meanChroma = chroma.reduce(0, +) / 12
            var covariance = 0.0
            var profilePower = 0.0
            var chromaPower = 0.0
            for index in 0..<12 {
                let a = profile[index] - meanProfile
                let b = chroma[(index + tonic) % 12] - meanChroma
                covariance += a * b
                profilePower += a * a
                chromaPower += b * b
            }
            return covariance / max(sqrt(profilePower * chromaPower), 1e-12)
        }
        var candidates: [Candidate] = []
        for tonic in 0..<12 {
            for mode in [MusicalKey.Mode.major, .minor] {
                let scores = profiles.map { correlation(mode == .major ? $0.0 : $0.1, tonic: tonic) }
                let score = 0.7 * scores[0] + 0.3 * scores[1]
                candidates.append(.init(key: .init(tonic: tonic, mode: mode), score: score))
            }
        }
        return candidates.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.key.tonic != $1.key.tonic { return $0.key.tonic < $1.key.tonic }
            return $0.key.mode.rawValue < $1.key.mode.rawValue
        }
    }
}
