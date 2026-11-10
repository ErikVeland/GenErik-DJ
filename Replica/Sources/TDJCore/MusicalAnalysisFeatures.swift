import Foundation

public struct MusicalEnergyAnalysis: Codable, Equatable, Sendable {
    public let level: Int
    public let onsetsPerSecond: Double
    public let rhythmicity: Double
    public let spectralActivity: Double
    public let brightness: Double
    public let crestFactorDB: Double
}

struct MusicalHarmonicFrame: Sendable {
    let seconds: Double
    let chroma: [Double]
}

struct MusicalBarFrame: Codable, Sendable {
    let level: Double
    let attackBands: [Double]
    let chroma: [Double]
}

struct MusicalPulseFrame {
    let rms: Double
    let bass: Double
    let middle: Double
    let high: Double
    let attackFrame: Double
    let rise: Double

    func value(_ band: Int) -> Double {
        switch band {
        case 1: return bass
        case 2: return middle
        case 3: return high
        default: return rms
        }
    }
}

struct MusicalPulseAccumulator {
    let framesPerBin: Int
    let bassCoefficient: Double
    let middleCoefficient: Double
    var frames: [MusicalPulseFrame] = []
    private var bass = 0.0
    private var middle = 0.0
    private var previousMagnitude = 0.0
    private var powers = [Double](repeating: 0, count: 4)
    private var count = 0
    private var position = 0
    private var rise = 0.0
    private var attackFrame = 0.0

    init(sampleRate: Double) {
        framesPerBin = max(1, Int((sampleRate / 200).rounded()))
        bassCoefficient = 1 - exp(-2 * .pi * 180 / sampleRate)
        middleCoefficient = 1 - exp(-2 * .pi * 1500 / sampleRate)
    }

    mutating func consume(_ sample: Double) {
        bass += bassCoefficient * (sample - bass)
        middle += middleCoefficient * (sample - middle)
        let mid = middle - bass
        let high = sample - middle
        powers[0] += sample * sample
        powers[1] += bass * bass
        powers[2] += mid * mid
        powers[3] += high * high
        let magnitude = abs(sample)
        let difference = magnitude - previousMagnitude
        if difference > rise {
            rise = difference
            attackFrame = Double(position)
        }
        previousMagnitude = magnitude
        position += 1
        count += 1
        if count == framesPerBin { flush() }
    }

    mutating func finish() { if count > 0 { flush() } }

    private mutating func flush() {
        let inverse = 1 / Double(count)
        frames.append(
            .init(
                rms: sqrt(powers[0] * inverse), bass: sqrt(powers[1] * inverse), middle: sqrt(powers[2] * inverse),
                high: sqrt(powers[3] * inverse), attackFrame: attackFrame, rise: rise))
        for index in powers.indices { powers[index] = 0 }
        count = 0
        rise = 0
        attackFrame = Double(position)
    }
}

struct MusicalOnset {
    let seconds: Double
    let weight: Double
}

struct MusicalRhythmResult {
    var bpm: Double?
    var anchorSeconds: Double?
    var confidence = 0.0
    var downbeat: Int?
    var downbeatConfidence: Double?
    var onsetsPerSecond = 0.0
    var gridResidualMilliseconds: Double?
    var adaptiveCandidate: BeatGridMap?
}

enum MusicalRhythmAnalyzer {
    private struct Fit {
        var period: Double
        var phase: Double
        var score: Double
        var residual: Double
        var matched: Int
        var first: Double
        var occupancy: Double
        var coverage: Double
    }

    static func guidedPhase(
        frames: [MusicalPulseFrame], sampleRate: Double, framesPerBin: Double, bpm: Double, neuralBeats: [Double] = [],
        checkCancellation: @Sendable () throws -> Void
    ) throws -> GuidedBeatPhase? {
        try checkCancellation()
        guard bpm.isFinite, (60...200).contains(bpm), sampleRate.isFinite, sampleRate > 0,
            framesPerBin.isFinite, framesPerBin > 0, !frames.isEmpty else { return nil }
        let duration = Double(frames.count) * framesPerBin / sampleRate
        var fits: [Fit] = []
        for band in 0..<4 {
            let events = try extractOnsets(frames: frames, band: band, sampleRate: sampleRate,
                                          binsPerSecond: sampleRate / framesPerBin, checkCancellation: checkCancellation)
            if let fit = try fit(period: 60 / bpm, onsets: events, duration: duration,
                                 checkCancellation: checkCancellation), abs(60 / fit.period / bpm - 1) <= 0.005 {
                fits.append(fit)
            }
        }
        for fit in fits.sorted(by: { $0.residual < $1.residual }) {
            guard fit.matched >= 16, fit.residual <= 0.008, fit.occupancy >= 0.70, fit.coverage >= 0.90 else { continue }
            let support = fits.filter {
                abs(($0.phase - fit.phase).remainder(dividingBy: fit.period)) <= 0.045
                    && $0.occupancy >= 0.45 && $0.coverage >= 0.85
            }.count
            let errors = neuralBeats.map { abs(($0 - fit.phase).remainder(dividingBy: fit.period)) }.sorted()
            let neuralAgreement = errors.isEmpty ? nil : Double(errors.filter { $0 <= 0.04 }.count) / Double(errors.count)
            let neuralSupports = errors.count >= 32 && neuralAgreement! >= 0.55 && errors[errors.count / 2] <= 0.02
            guard support >= 3 || neuralSupports else { continue }
            let anchor = fit.phase + ceil(-fit.phase / fit.period) * fit.period
            return .init(bpm: 60 / fit.period, anchorSeconds: max(0, anchor),
                         residualMilliseconds: fit.residual * 1000, occupancy: fit.occupancy,
                         coverage: fit.coverage, supportingBands: support,
                         neuralAgreement: neuralSupports ? neuralAgreement : nil)
        }
        return nil
    }

    static func analyze(
        frames: [MusicalPulseFrame], sampleRate: Double, framesPerBin: Int, spectralActivity: Double,
        configuration: AnalysisConfiguration, harmonicFrames: [MusicalHarmonicFrame] = [],
        checkCancellation: @Sendable () throws -> Void
    ) throws -> MusicalRhythmResult {
        try checkCancellation()
        guard sampleRate.isFinite, sampleRate > 0, framesPerBin > 0 else { return .init() }
        func finishBar(_ input: MusicalRhythmResult) throws -> MusicalRhythmResult {
            var result = input
            if let bpm = result.bpm, let anchor = result.anchorSeconds {
                let bar = try detectDownbeat(
                    frames: frames, binsPerSecond: sampleRate / Double(framesPerBin), period: 60 / bpm, anchor: anchor,
                    harmonicFrames: harmonicFrames, checkCancellation: checkCancellation)
                result.downbeat = bar.offset
                result.downbeatConfidence = bar.confidence
            }
            if let map = result.adaptiveCandidate {
                let beats = try barFrames(
                    frames: frames, binsPerSecond: sampleRate / Double(framesPerBin), period: 1, anchor: 0,
                    harmonicFrames: harmonicFrames, adaptiveMap: map, checkCancellation: checkCancellation)
                let bar = try barStart(beats: beats, checkCancellation: checkCancellation)
                let firstBeat = Int(ceil(map.anchors.first?.beat ?? 0))
                let offset = bar.offset.map { (($0 + firstBeat) % 4 + 4) % 4 } ?? 0
                result.adaptiveCandidate = BeatGridMap(
                    anchors: map.anchors, sampleRate: map.sampleRate, downbeatOffset: offset)
            }
            return result
        }
        let whole = try analyzeWhole(
            frames: frames, sampleRate: sampleRate, framesPerBin: framesPerBin, spectralActivity: spectralActivity,
            configuration: configuration, checkCancellation: checkCancellation)
        guard whole.bpm == nil || whole.confidence < 0.72 else { return try finishBar(whole) }
        let binsPerSecond = sampleRate / Double(framesPerBin)
        let window = max(1, Int((24 * binsPerSecond).rounded()))
        let minimum = max(1, Int((12 * binsPerSecond).rounded()))
        guard frames.count >= minimum else { return try finishBar(whole) }
        var starts = Array(stride(from: 0, to: frames.count - minimum + 1, by: max(1, window / 2)))
        starts.append(max(0, frames.count - window))
        starts.append(max(0, frames.count - minimum))
        for start in Set(starts).sorted() {
            try checkCancellation()
            let end = min(frames.count, start + window)
            let slice = frames[start..<end]
            let peak = slice.map(\.rms).max() ?? 0
            guard peak > 1e-7 else { continue }
            var rises = 0.0
            for i in (start + 1)..<end { rises += max(0, frames[i].rms - frames[i - 1].rms) }
            let activity = min(1, 4 * rises / (peak * Double(end - start)))
            guard activity > 0.008 else { continue }
            let offset = Double(start * framesPerBin)
            let local = slice.map { value in
                MusicalPulseFrame(
                    rms: value.rms, bass: value.bass, middle: value.middle, high: value.high,
                    attackFrame: value.attackFrame - offset, rise: value.rise)
            }
            var candidate = try analyzeWhole(
                frames: local, sampleRate: sampleRate, framesPerBin: framesPerBin, spectralActivity: activity,
                configuration: configuration, checkCancellation: checkCancellation)
            guard candidate.bpm != nil, candidate.confidence >= 0.72,
                whole.bpm == nil || candidate.confidence > whole.confidence + 0.08
            else { continue }
            candidate.anchorSeconds = candidate.anchorSeconds.map { $0 + offset / sampleRate }
            let extensionResult = try extendLateAnchor(
                frames: frames, binsPerSecond: binsPerSecond, anchor: candidate.anchorSeconds ?? offset / sampleRate,
                bpm: candidate.bpm!, checkCancellation: checkCancellation)
            candidate.anchorSeconds = extensionResult.anchor
            if let downbeat = candidate.downbeat { candidate.downbeat = (downbeat + extensionResult.beats) % 4 }
            candidate.onsetsPerSecond *= Double(end - start) / Double(frames.count)
            // A local tempo estimate cannot describe tempo changes outside its window.
            // The whole-track map already uses absolute frames and its own beat origin.
            candidate.adaptiveCandidate = whole.adaptiveCandidate
            return try finishBar(candidate)
        }
        return try finishBar(whole)
    }

    /// Extend a supported late beat train back to its first audible attack, using local contrast.
    private static func extendLateAnchor(
        frames: [MusicalPulseFrame], binsPerSecond: Double, anchor: Double, bpm: Double,
        checkCancellation: @Sendable () throws -> Void
    ) throws -> (anchor: Double, beats: Int) {
        let period = 60 / bpm
        let radius = max(1, Int((0.025 * binsPerSecond).rounded()))
        var earliest = anchor
        var shift = 0
        var missed = 0
        var beat = 1
        while anchor - Double(beat) * period >= 0 {
            try checkCancellation()
            let center = Int(((anchor - Double(beat) * period) * binsPerSecond).rounded())
            let lower = max(0, center - radius)
            let upper = min(frames.count - 1, center + radius)
            guard lower <= upper else { break }
            let peak = (lower...upper).filter { frames[$0].rise > 1e-9 }.min { abs($0 - center) < abs($1 - center) }
            guard let peak else {
                missed += 1
                if missed >= 2 { break }
                beat += 1
                continue
            }
            let beforeStart = max(0, lower - radius * 2)
            let afterEnd = min(frames.count, upper + radius * 2 + 1)
            let before = frames[beforeStart..<lower].map(\.rms)
            let after = frames[(upper + 1)..<afterEnd].map(\.rms)
            let baseline = min(
                before.isEmpty ? frames[peak].rms : before.reduce(0, +) / Double(before.count),
                after.isEmpty ? frames[peak].rms : after.reduce(0, +) / Double(after.count))
            if frames[peak].rms > max(1e-7, baseline * 1.35) {
                earliest = Double(peak) / binsPerSecond
                shift = beat
                missed = 0
            } else {
                missed += 1
                if missed >= 2 { break }
            }
            beat += 1
        }
        return (earliest, shift)
    }

    /// The whole-track path remains the fast path for a well-supported tempo.
    private static func analyzeWhole(
        frames: [MusicalPulseFrame], sampleRate: Double, framesPerBin: Int, spectralActivity: Double,
        configuration: AnalysisConfiguration, checkCancellation: @Sendable () throws -> Void
    ) throws -> MusicalRhythmResult {
        var result = try consensus(
            frames: frames, sampleRate: sampleRate, framesPerBin: framesPerBin, spectralActivity: spectralActivity,
            configuration: configuration, checkCancellation: checkCancellation)
        let usedPeriodicity = result.bpm == nil
        if result.bpm == nil {
            guard frames.count > 400, spectralActivity > 0.008,
                let periodic = try periodicity(
                    frames: frames, binsPerSecond: sampleRate / Double(framesPerBin), configuration: configuration,
                    checkCancellation: checkCancellation)
            else { return result }
            result.bpm = periodic.bpm
            result.anchorSeconds = periodic.anchorSeconds
            result.confidence = periodic.confidence
        }
        if result.adaptiveCandidate == nil, let bpm = result.bpm,
            let supported = try supportedPulseTrain(
                frames: frames, binsPerSecond: sampleRate / Double(framesPerBin), bpm: bpm,
                configuration: configuration, checkCancellation: checkCancellation)
        {
            result.bpm = supported.bpm
            result.anchorSeconds = supported.anchorSeconds
            result.confidence = supported.confidence
            result.gridResidualMilliseconds = supported.residual * 1000
        } else if usedPeriodicity, result.adaptiveCandidate == nil {
            result.confidence = min(result.confidence, 0.69)
        }
        if let bpm = result.bpm, let anchor = result.anchorSeconds {
            let downbeat = try detectDownbeat(
                frames: frames, binsPerSecond: sampleRate / Double(framesPerBin), period: 60 / bpm, anchor: anchor,
                checkCancellation: checkCancellation)
            result.downbeat = downbeat.offset
            result.downbeatConfidence = downbeat.confidence
        }
        return result
    }

    /// Check tempo multiples against sustained bass attacks before accepting a dense-mix grid.
    private static func supportedPulseTrain(
        frames: [MusicalPulseFrame], binsPerSecond: Double, bpm: Double, configuration: AnalysisConfiguration,
        checkCancellation: @Sendable () throws -> Void
    ) throws -> (bpm: Double, anchorSeconds: Double, confidence: Double, residual: Double)? {
        let radius = max(1, Int((0.0125 * binsPerSecond).rounded(.down)))
        guard frames.count > radius * 4 else { return nil }
        var sums = [Double](repeating: 0, count: frames.count + 1)
        for index in frames.indices {
            if index.isMultiple(of: 4096) { try checkCancellation() }
            sums[index + 1] = sums[index] + frames[index].bass * frames[index].bass
        }
        let envelope = frames.indices.map { index -> Double in
            let lower = max(0, index - radius)
            let upper = min(frames.count, index + radius + 1)
            return sqrt(max(0, (sums[upper] - sums[lower]) / Double(upper - lower)))
        }
        let difference = max(1, Int((0.01 * binsPerSecond).rounded()))
        var novelty = [Double](repeating: 0, count: frames.count)
        for index in frames.indices {
            novelty[index] = max(0, envelope[index] - (index >= difference ? envelope[index - difference] : 0))
        }
        guard let peak = novelty.max(), peak > 1e-8 else { return nil }
        var onsets = [MusicalOnset]()
        for index in frames.indices
        where novelty[index] > peak * 0.08 && (index == 0 || novelty[index] >= novelty[index - 1])
            && (index + 1 == frames.count || novelty[index] > novelty[index + 1])
        {
            let event = MusicalOnset(
                seconds: Double(index + difference / 2) / binsPerSecond, weight: novelty[index] / peak)
            if let previous = onsets.last, event.seconds - previous.seconds < 0.18 {
                if event.weight > previous.weight { onsets[onsets.count - 1] = event }
            } else {
                onsets.append(event)
            }
        }
        guard onsets.count >= 24 else { return nil }
        let duration = Double(frames.count) / binsPerSecond
        var best: Fit?
        for tempo in [bpm, bpm * 2, bpm / 2]
        where tempo >= configuration.minimumBPM && tempo <= configuration.maximumBPM {
            try checkCancellation()
            guard
                let candidate = try fit(
                    period: 60 / tempo, onsets: onsets, duration: duration, checkCancellation: checkCancellation),
                candidate.score >= 0.4, candidate.matched >= 24
            else { continue }
            if best == nil || candidate.score > best!.score + 0.04 { best = candidate }
        }
        guard let best else { return nil }
        let anchor = best.phase + ((best.first - best.phase) / best.period).rounded() * best.period
        return (60 / best.period, max(0, anchor), min(1, best.score / 0.75), best.residual)
    }

    /// Onset-strength autocorrelation with a broad log-tempo prior, refined at eight-beat lags.
    /// Returns nil when the envelope has no clear periodicity, so tonal or unaccented audio stays unknown.
    static func periodicity(
        frames: [MusicalPulseFrame], binsPerSecond: Double, configuration: AnalysisConfiguration,
        checkCancellation: @Sendable () throws -> Void
    ) throws -> (bpm: Double, anchorSeconds: Double, confidence: Double)? {
        let count = frames.count
        guard count > 400, binsPerSecond.isFinite, binsPerSecond > 0 else { return nil }
        let weights = [0.2, 0.4, 0.25, 0.15]
        var envelope = [Double](repeating: 0, count: count)
        for band in 0..<4 {
            let peak = max(frames.lazy.map { $0.value(band) }.max() ?? 0, 1e-12)
            for index in 1..<count {
                envelope[index] +=
                    weights[band] * max(0, frames[index].value(band) - frames[index - 1].value(band)) / peak
            }
        }
        // Remove the slow trend over about one second, keeping only rises above it.
        let window = max(4, Int(binsPerSecond))
        var running = 0.0
        var detrended = [Double](repeating: 0, count: count)
        for index in 0..<count {
            running += envelope[index]
            if index >= window { running -= envelope[index - window] }
            detrended[index] = max(0, envelope[index] - running / Double(min(index + 1, window)))
        }
        try checkCancellation()
        func autocorrelation(_ lag: Int) -> Double {
            guard lag > 0, lag < count else { return 0 }
            var sum = 0.0
            for index in 0..<(count - lag) { sum += detrended[index] * detrended[index + lag] }
            return sum / Double(count - lag)
        }
        let zero = autocorrelation(0) + detrended.reduce(0) { $0 + $1 * $1 } / Double(count)
        guard zero > 1e-12 else { return nil }
        let shortest = max(2, Int(floor(binsPerSecond * 60 / configuration.maximumBPM)))
        let longest = min(count / 4, Int(ceil(binsPerSecond * 60 / configuration.minimumBPM)))
        guard longest > shortest + 2 else { return nil }
        var values = [Double](repeating: 0, count: longest + 2)
        for lag in shortest...(longest + 1) { values[lag] = autocorrelation(lag) }
        try checkCancellation()
        var bestLag = 0
        var bestScore = 0.0
        for lag in (shortest + 1)...longest where values[lag] >= values[lag - 1] && values[lag] >= values[lag + 1] {
            let seconds = Double(lag) / binsPerSecond
            // Broad prior centred on 0.5 s (120 BPM), 1.4 octaves wide.
            let prior = exp(-0.5 * pow(log2(seconds / 0.5) / 1.4, 2))
            let score = values[lag] * prior
            if score > bestScore {
                bestScore = score
                bestLag = lag
            }
        }
        guard bestLag > 0 else { return nil }
        let sorted = values[shortest...longest].sorted()
        let median = sorted[sorted.count / 2]
        let strength = values[bestLag] / zero
        guard values[bestLag] > median * 1.35, strength > 0.04 else { return nil }
        // Refine on the eighth multiple, where one bin is an eighth of the error.
        var period = Double(bestLag)
        let far = bestLag * 8
        if far + 2 < count / 2 {
            var peak = far
            var peakValue = autocorrelation(far)
            for lag in (far - 6)...(far + 6) {
                let value = autocorrelation(lag)
                if value > peakValue {
                    peakValue = value
                    peak = lag
                }
            }
            let left = autocorrelation(peak - 1)
            let right = autocorrelation(peak + 1)
            let curvature = left - 2 * peakValue + right
            let offset = curvature < 0 ? 0.5 * (left - right) / curvature : 0
            let refined = (Double(peak) + max(-0.5, min(0.5, offset))) / 8
            if abs(refined / period - 1) < 0.05 { period = refined }
        }
        let bpm = 60 * binsPerSecond / period
        guard bpm >= configuration.minimumBPM, bpm <= configuration.maximumBPM else { return nil }
        // Beat phase: the comb offset with the most onset energy.
        let steps = max(1, Int(period.rounded()))
        var bestPhase = 0
        var bestPhaseEnergy = -1.0
        for phase in 0..<steps {
            var energy = 0.0
            var position = Double(phase)
            while Int(position) < count {
                energy += detrended[Int(position)]
                position += period
            }
            if energy > bestPhaseEnergy {
                bestPhaseEnergy = energy
                bestPhase = phase
            }
        }
        let confidence = min(1, max(0, strength * 4))
        let threshold = (detrended.max() ?? 0) * 0.08
        let tolerance = min(0.045 * binsPerSecond, period * 0.12)
        var byBeat = [Int: Int]()
        for index in detrended.indices where detrended[index] > max(1e-8, threshold) {
            if index.isMultiple(of: 4096) { try checkCancellation() }
            let beat = Int(((Double(index) - Double(bestPhase)) / period).rounded())
            guard abs(Double(index) - Double(bestPhase) - Double(beat) * period) <= tolerance else { continue }
            if byBeat[beat].map({ detrended[$0] >= detrended[index] }) != true { byBeat[beat] = index }
        }
        var run = [Int]()
        for beat in byBeat.keys.sorted() {
            let index = byBeat[beat]!
            if let previous = run.last, Double(index - previous) > period * 2.25 { run = [] }
            run.append(index)
            if run.count >= 6 { return (bpm, Double(run[0]) / binsPerSecond, confidence) }
        }
        return nil
    }

    private static func consensus(
        frames: [MusicalPulseFrame], sampleRate: Double, framesPerBin: Int, spectralActivity: Double,
        configuration: AnalysisConfiguration, checkCancellation: @Sendable () throws -> Void
    ) throws -> MusicalRhythmResult {
        guard frames.count > 400, spectralActivity > 0.008, let maximum = frames.map(\.rms).max(), maximum > 1e-7 else {
            return .init()
        }
        let binsPerSecond = sampleRate / Double(framesPerBin)
        var onsets: [[MusicalOnset]] = []
        for band in 0..<4 {
            try checkCancellation()
            onsets.append(
                try extractOnsets(
                    frames: frames, band: band, sampleRate: sampleRate, binsPerSecond: binsPerSecond,
                    checkCancellation: checkCancellation))
        }
        let duration = Double(frames.count) / binsPerSecond
        var result = MusicalRhythmResult(onsetsPerSecond: Double(onsets[0].count) / max(duration, 1))
        guard onsets.contains(where: { $0.count >= 6 }) else { return result }
        let step = 0.2
        let bucketCount = Int(ceil((configuration.maximumBPM - configuration.minimumBPM) / step)) + 1
        var histogram = [Double](repeating: 0, count: bucketCount)
        var tempoSums = histogram
        let bandWeights = [0.25, 0.35, 0.25, 0.15]
        for band in 0..<4 where onsets[band].count >= 6 {
            var votes = [Double](repeating: 0, count: bucketCount)
            var sums = votes
            let events = onsets[band]
            for index in events.indices {
                if index.isMultiple(of: 256) { try checkCancellation() }
                for other in (index + 1)..<min(events.count, index + 13) {
                    let interval = events[other].seconds - events[index].seconds
                    if interval > 8 { break }
                    guard interval > 0 else { continue }
                    for beats in 1...8 {
                        let bpm = 60 * Double(beats) / interval
                        guard bpm >= configuration.minimumBPM, bpm <= configuration.maximumBPM else { continue }
                        let bucket = min(
                            bucketCount - 1, max(0, Int(((bpm - configuration.minimumBPM) / step).rounded())))
                        let weight = sqrt(events[index].weight * events[other].weight) / Double(beats)
                        votes[bucket] += weight
                        sums[bucket] += weight * bpm
                    }
                }
            }
            let normalization = max(votes.max() ?? 0, 1e-12)
            for index in votes.indices {
                histogram[index] += bandWeights[band] * votes[index] / normalization
                tempoSums[index] += bandWeights[band] * sums[index] / normalization
            }
        }
        let ranked = histogram.indices.sorted { histogram[$0] > histogram[$1] }
        var candidates: [Double] = []
        for index in ranked where histogram[index] > 0 {
            let bpm = tempoSums[index] / histogram[index]
            if candidates.allSatisfy({ abs($0 - bpm) > 1 }) { candidates.append(bpm) }
            if candidates.count == 16 { break }
        }
        var best: (bpm: Double, fits: [Fit?], score: Double)?
        for candidate in candidates {
            try checkCancellation()
            var fits: [Fit?] = []
            for band in 0..<4 {
                fits.append(
                    try fit(
                        period: 60 / candidate, onsets: onsets[band], duration: duration,
                        checkCancellation: checkCancellation))
            }
            let available = (0..<4).filter { onsets[$0].count >= 6 }
            let denominator = available.reduce(0.0) { $0 + bandWeights[$1] }
            guard denominator > 0 else { continue }
            let score = available.reduce(0.0) { $0 + bandWeights[$1] * (fits[$1]?.score ?? 0) } / denominator
            let validFits = fits.compactMap { $0 }.filter { $0.score > 0.6 }
            guard !validFits.isEmpty else { continue }
            let reference = validFits.max(by: { $0.matched < $1.matched })!
            let bpm = 60 / reference.period
            guard bpm >= configuration.minimumBPM, bpm <= configuration.maximumBPM else { continue }
            if best == nil || score > best!.score + 0.005 { best = (bpm, fits, score) }
        }
        result.adaptiveCandidate = try AdaptiveRhythmAnalyzer.candidate(
            onsets: onsets[1], sampleRate: sampleRate, frameCount: Int64(frames.count * framesPerBin), downbeat: 0,
            referenceBPM: best?.bpm, checkCancellation: checkCancellation)
        guard let best, best.score > 0.58 else { return result }
        let order = [1, 2, 0, 3]
        guard
            let phaseFit = order.compactMap({ best.fits[$0] }).first(where: { $0.score > 0.72 && $0.matched >= 6 })
                ?? best.fits.compactMap({ $0 }).max(by: { $0.score < $1.score })
        else { return result }
        let period = 60 / best.bpm
        let anchor = phaseFit.phase + ((phaseFit.first - phaseFit.phase) / phaseFit.period).rounded() * phaseFit.period
        result.bpm = best.bpm
        result.anchorSeconds = max(0, anchor)
        result.confidence = min(1, max(0, best.score))
        result.gridResidualMilliseconds = phaseFit.residual * 1000
        let downbeat = try detectDownbeat(
            frames: frames, binsPerSecond: binsPerSecond, period: period, anchor: max(0, anchor),
            checkCancellation: checkCancellation)
        result.downbeat = downbeat.offset
        result.downbeatConfidence = downbeat.confidence
        if let map = result.adaptiveCandidate {
            result.adaptiveCandidate = BeatGridMap(
                anchors: map.anchors, sampleRate: sampleRate, downbeatOffset: downbeat.offset ?? 0)
        }
        return result
    }

    private static func extractOnsets(
        frames: [MusicalPulseFrame], band: Int, sampleRate: Double, binsPerSecond: Double,
        checkCancellation: @Sendable () throws -> Void
    ) throws -> [MusicalOnset] {
        let values = frames.map { $0.value(band) }
        let maximum = values.max() ?? 0
        guard maximum > 1e-8 else { return [] }
        var novelty = [Double](repeating: 0, count: values.count)
        var average = 0.0
        let smoothing = 1 - exp(-1 / binsPerSecond)
        for index in values.indices {
            average += smoothing * (values[index] - average)
            let previous = index > 0 ? values[index - 1] : 0
            let difference = max(0, values[index] - previous)
            if difference > max(maximum * 0.015, previous * 0.12) {
                novelty[index] = min(12, difference / max(average, maximum * 0.03))
            }
        }
        var events: [MusicalOnset] = []
        for index in novelty.indices {
            if index.isMultiple(of: 4096) { try checkCancellation() }
            let value = novelty[index]
            guard value > 0.18, index == 0 || value >= novelty[index - 1],
                index + 1 == novelty.count || value > novelty[index + 1]
            else { continue }
            let start = max(0, index - 2)
            let attack = (start...index).max { frames[$0].rise < frames[$1].rise } ?? index
            let time = frames[attack].attackFrame / sampleRate
            let event = MusicalOnset(seconds: time, weight: sqrt(value))
            if let previous = events.last, time - previous.seconds < 0.07 {
                if event.weight > previous.weight { events[events.count - 1] = event }
            } else {
                events.append(event)
            }
        }
        return events
    }

    private static func fit(
        period initial: Double, onsets: [MusicalOnset], duration: Double, checkCancellation: @Sendable () throws -> Void
    ) throws -> Fit? {
        guard onsets.count >= 6, initial.isFinite, initial > 0 else { return nil }
        var period = initial
        let firstTime = onsets[0].seconds
        let local = onsets.filter { $0.seconds < firstTime + 24 }
        let tolerance = min(0.045, period * 0.12)
        let phaseBins = max(16, min(256, Int(ceil(period / 0.01))))
        var phaseScores = [Double](repeating: 0, count: phaseBins)
        for index in phaseScores.indices {
            let candidate = Double(index) * period / Double(phaseBins)
            for event in local {
                let distance = abs((event.seconds - candidate).remainder(dividingBy: period))
                if distance <= tolerance { phaseScores[index] += event.weight * (1 - pow(distance / tolerance, 2)) }
            }
        }
        let strongest = phaseScores.indices.max { phaseScores[$0] < phaseScores[$1] } ?? 0
        var phase = Double(strongest) * period / Double(phaseBins)
        var offsetSum = 0.0
        var phaseWeight = 0.0
        for event in local {
            let offset = (event.seconds - phase).remainder(dividingBy: period)
            if abs(offset) <= tolerance {
                offsetSum += offset * event.weight
                phaseWeight += event.weight
            }
        }
        if phaseWeight > 0 { phase += offsetSum / phaseWeight }
        var selected: [(beat: Double, event: MusicalOnset)] = []
        for iteration in 0..<6 {
            try checkCancellation()
            let horizon = iteration < 2 ? firstTime + 24 : (iteration < 4 ? firstTime + 96 : .infinity)
            let tolerance = min(0.045, period * 0.12)
            var byBeat: [Int: MusicalOnset] = [:]
            for event in onsets where event.seconds < horizon {
                let beat = Int(((event.seconds - phase) / period).rounded())
                let residual = abs(event.seconds - phase - Double(beat) * period)
                guard residual <= tolerance else { continue }
                if byBeat[beat].map({ $0.weight >= event.weight }) != true { byBeat[beat] = event }
            }
            selected = byBeat.map { (Double($0.key), $0.value) }
            guard selected.count >= 6 else { return nil }
            let weight = selected.reduce(0.0) { $0 + $1.event.weight }
            let meanBeat = selected.reduce(0.0) { $0 + $1.beat * $1.event.weight } / weight
            let meanTime = selected.reduce(0.0) { $0 + $1.event.seconds * $1.event.weight } / weight
            let variance = selected.reduce(0.0) { $0 + pow($1.beat - meanBeat, 2) * $1.event.weight }
            guard variance > 0 else { return nil }
            let covariance = selected.reduce(0.0) {
                $0 + ($1.beat - meanBeat) * ($1.event.seconds - meanTime) * $1.event.weight
            }
            let refined = covariance / variance
            guard refined > 0, abs(refined / initial - 1) < 0.04 else { return nil }
            period = refined
            phase = meanTime - meanBeat * period
        }
        let totalWeight = onsets.reduce(0.0) { $0 + $1.weight }
        let matchedWeight = selected.reduce(0.0) { $0 + $1.event.weight }
        let first = selected.map { $0.event.seconds }.min()!
        let last = selected.map { $0.event.seconds }.max()!
        let expectedBeats = max(1, (last - first) / period + 1)
        let occupancy = min(1, Double(selected.count) / expectedBeats)
        let coverage = min(1, (last - first + period) / max(duration, period))
        let residuals = selected.map { abs($0.event.seconds - phase - $0.beat * period) }.sorted()
        let residual = residuals[residuals.count / 2]
        let precision = exp(-pow(residual / 0.025, 2))
        let score =
            (0.65 * matchedWeight / max(totalWeight, 1e-12) + 0.35 * occupancy) * precision * (0.7 + 0.3 * coverage)
        return .init(
            period: period, phase: phase, score: score, residual: residual, matched: selected.count, first: first,
            occupancy: occupancy, coverage: coverage)
    }

    private static func detectDownbeat(
        frames: [MusicalPulseFrame], binsPerSecond: Double, period: Double, anchor: Double,
        harmonicFrames: [MusicalHarmonicFrame] = [], checkCancellation: @Sendable () throws -> Void
    ) throws -> (offset: Int?, confidence: Double?) {
        try barStart(
            beats: barFrames(
                frames: frames, binsPerSecond: binsPerSecond, period: period, anchor: anchor,
                harmonicFrames: harmonicFrames, checkCancellation: checkCancellation),
            checkCancellation: checkCancellation)
    }

    static func barFrames(
        frames: [MusicalPulseFrame], binsPerSecond: Double, period: Double, anchor: Double,
        harmonicFrames: [MusicalHarmonicFrame] = [], adaptiveMap: BeatGridMap? = nil,
        checkCancellation: @Sendable () throws -> Void
    ) throws -> [MusicalBarFrame] {
        let firstBeat = ceil(adaptiveMap?.anchors.first?.beat ?? 0)
        let count: Int
        if let map = adaptiveMap, let last = map.anchors.last {
            let end = min(last.frame, Double(frames.count) / binsPerSecond * map.sampleRate)
            count = Int(floor(map.beat(atFrame: end)) - firstBeat)
        } else {
            count = Int(floor((Double(frames.count) / binsPerSecond - anchor) / period))
        }
        guard count >= 16 else { return [] }
        var levels = [Double]()
        var bands = [[Double]]()
        for beat in 0..<count {
            if beat.isMultiple(of: 256) { try checkCancellation() }
            let time: Double
            let beatPeriod: Double
            if let map = adaptiveMap {
                time = map.frame(atBeat: firstBeat + Double(beat)) / map.sampleRate
                beatPeriod = map.frame(atBeat: firstBeat + Double(beat) + 1) / map.sampleRate - time
            } else {
                time = anchor + Double(beat) * period
                beatPeriod = period
            }
            let lower = max(0, Int((time * binsPerSecond).rounded(.down)))
            let upper = min(frames.count, Int(((time + beatPeriod * 0.7) * binsPerSecond).rounded(.up)))
            guard upper > lower else { return [] }
            var powers = [Double](repeating: 0, count: 4)
            var attacks = powers
            let attackEnd = min(upper, Int(((time + min(0.12, beatPeriod * 0.3)) * binsPerSecond).rounded(.up)))
            for i in lower..<upper {
                for band in 0..<4 {
                    let value = pow(frames[i].value(band), 2)
                    powers[band] += value
                    if i < attackEnd { attacks[band] += value }
                }
            }
            let total = max(1e-14, attacks[1] + attacks[2] + attacks[3])
            levels.append(sqrt(powers[0] / Double(upper - lower)))
            bands.append([attacks[1] / total, attacks[2] / total, attacks[3] / total])
        }
        var chroma = Array(repeating: [Double](repeating: 0, count: 12), count: count)
        var tonalCount = [Int](repeating: 0, count: count)
        for (index, frame) in harmonicFrames.enumerated() {
            if index.isMultiple(of: 256) { try checkCancellation() }
            let position = adaptiveMap.map { $0.beat(atFrame: frame.seconds * $0.sampleRate) - firstBeat }
                ?? ((frame.seconds - anchor) / period)
            let beat = Int(floor(position))
            guard beat >= 0, beat < count, frame.chroma.count == 12 else { continue }
            for pitch in 0..<12 { chroma[beat][pitch] += frame.chroma[pitch] }
            tonalCount[beat] += 1
        }
        for beat in 0..<count where tonalCount[beat] > 0 {
            for pitch in 0..<12 { chroma[beat][pitch] /= Double(tonalCount[beat]) }
        }
        return (0..<count).map { MusicalBarFrame(level: levels[$0], attackBands: bands[$0], chroma: chroma[$0]) }
    }

    static func barStart(beats: [MusicalBarFrame], checkCancellation: @Sendable () throws -> Void = {}) throws -> (
        offset: Int?, confidence: Double?
    ) {
        guard beats.count >= 16,
            beats.allSatisfy({
                $0.level.isFinite && $0.level >= 0 && $0.attackBands.count == 3 && $0.chroma.count == 12
            })
        else { return (nil, nil) }
        var count = beats.count
        var levels = beats.map(\.level)
        var bands = beats.map(\.attackBands)
        let active = levels.filter { $0 > 1e-7 }.sorted()
        guard active.count >= 16 else { return (nil, nil) }
        let median = active[active.count / 2]
        if let last = levels.lastIndex(where: { $0 > median * 0.1 }) {
            count = last + 1
            levels = Array(levels.prefix(count))
            bands = Array(bands.prefix(count))
        }
        guard count >= 16 else { return (nil, nil) }
        let vectors = (0..<count).map { [log1p(levels[$0] / median)] + bands[$0] }
        func mean(_ values: [[Double]]) -> [Double] {
            guard let first = values.first else { return [Double](repeating: 0, count: 4) }
            return first.indices.map { feature in values.reduce(0) { $0 + $1[feature] } / Double(values.count) }
        }
        func distance(_ a: [Double], _ b: [Double]) -> Double { sqrt(zip(a, b).reduce(0) { $0 + pow($1.0 - $1.1, 2) }) }
        func lagDistance(_ lag: Int, _ values: [[Double]]) -> Double {
            let indices = (lag..<values.count).filter { levels[$0] > median * 0.1 && levels[$0 - lag] > median * 0.1 }
            return indices.isEmpty
                ? 0 : indices.reduce(0) { $0 + distance(values[$1], values[$1 - lag]) } / Double(indices.count)
        }
        let lag4 = lagDistance(4, vectors)
        let lag3 = lagDistance(3, vectors)
        guard lag4 < 0.01 || lag3 >= lag4 * 0.65 else { return (nil, nil) }
        var votes = [Double](repeating: 0, count: 4)
        let prefix = Array(vectors.prefix(min(32, count)))
        let introMeans = (0..<4).map { offset in mean(stride(from: offset, to: prefix.count, by: 4).map { prefix[$0] })
        }
        let introMean = mean(introMeans)
        let introSpread = introMeans.reduce(0) { $0 + pow(distance($1, introMean), 2) } / 4
        if introSpread > 0.0005, lagDistance(4, prefix) < lagDistance(1, prefix) * 0.95, levels[0] > median * 0.4 {
            votes[0] += 0.8
        }
        for beat in 1..<min(4, count - 4) {
            let before = levels[..<beat].reduce(0, +) / Double(beat)
            let after = levels[beat..<(beat + 4)].reduce(0, +) / 4
            if after > max(median * 0.5, before * 3) {
                votes[beat % 4] += min(1.5, after / max(before, median * 0.05) * 0.15)
            }
        }
        let means = (0..<4).map { offset in
            mean(stride(from: offset, to: count, by: 4).filter { levels[$0] > median * 0.1 }.map { vectors[$0] })
        }
        let bassOrder = (0..<4).sorted { means[$0][1] > means[$1][1] }
        let bassMargin = means[bassOrder[0]][1] - means[bassOrder[1]][1]
        if bassMargin > 0.06 { votes[bassOrder[0]] += min(2.0, bassMargin * 8) }
        var novelty = [Double](repeating: 0, count: count)
        for beat in 4..<(count - 4) {
            if beat.isMultiple(of: 256) { try checkCancellation() }
            novelty[beat] = distance(mean(Array(vectors[(beat - 4)..<beat])), mean(Array(vectors[beat..<(beat + 4)])))
        }
        let ordered = novelty.sorted()
        let baseline = ordered[ordered.count / 2]
        for beat in 4..<(count - 4)
        where novelty[beat] > max(0.12, baseline * 2.5) && novelty[beat] >= novelty[beat - 1]
            && novelty[beat] > novelty[beat + 1]
        { votes[beat % 4] += min(1, novelty[beat]) * 0.6 }
        let chroma = Array(beats.prefix(count)).map(\.chroma)
        let tonalCount = chroma.map { $0.reduce(0, +) > 1e-12 ? 1 : 0 }
        var harmonicChange = [Double](repeating: 0, count: count)
        for beat in 1..<count where tonalCount[beat] > 0 && tonalCount[beat - 1] > 0 {
            let a = chroma[beat]
            let b = chroma[beat - 1]
            let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
            let norm = sqrt(a.reduce(0) { $0 + $1 * $1 } * b.reduce(0) { $0 + $1 * $1 })
            harmonicChange[beat] = max(0, 1 - dot / max(norm, 1e-12))
        }
        let harmonicSorted = harmonicChange.sorted()
        let harmonicMedian = harmonicSorted[harmonicSorted.count / 2]
        for beat in 1..<(count - 1)
        where harmonicChange[beat] > max(0.12, harmonicMedian * 2.5) && harmonicChange[beat] >= harmonicChange[beat - 1]
            && harmonicChange[beat] > harmonicChange[beat + 1]
        { votes[beat % 4] += harmonicChange[beat] }
        let ranked = (0..<4).sorted { votes[$0] > votes[$1] }
        let best = votes[ranked[0]]
        let second = votes[ranked[1]]
        guard best >= 0.3, best > second * 1.25 else { return (nil, nil) }
        let margin = (best - second) / max(best + second, 1e-12)
        return (ranked[0], min(1, 0.5 + margin * 0.5))
    }

    static func energy(
        frames: [MusicalPulseFrame], duration: Double, rhythm: MusicalRhythmResult, spectralActivity: Double,
        brightness: Double
    ) -> MusicalEnergyAnalysis? {
        guard !frames.isEmpty else { return nil }
        let power = frames.reduce(0.0) { $0 + $1.rms * $1.rms } / Double(frames.count)
        guard power > 1e-14, power.isFinite else { return nil }
        let sorted = frames.map(\.rms).sorted()
        let upper = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        let crest = max(0, 20 * log10(max(upper, 1e-12) / sqrt(power)))
        let rate = rhythm.onsetsPerSecond
        let activity = 1 - exp(-rate / 3)
        let rhythmStrength = rhythm.bpm == nil ? 0 : rhythm.confidence
        let flux = min(1, max(0, spectralActivity * 3))
        let level = min(
            10, max(0, Int((10 * (0.5 * activity + 0.25 * rhythmStrength + 0.2 * flux + 0.05 * brightness)).rounded())))
        return .init(
            level: level, onsetsPerSecond: rate, rhythmicity: rhythmStrength, spectralActivity: spectralActivity,
            brightness: brightness, crestFactorDB: crest)
    }
}
