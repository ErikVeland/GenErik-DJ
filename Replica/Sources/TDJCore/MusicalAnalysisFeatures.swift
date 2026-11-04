import Foundation

public struct MusicalEnergyAnalysis: Codable, Equatable, Sendable {
    public let level: Int
    public let onsetsPerSecond: Double
    public let rhythmicity: Double
    public let spectralActivity: Double
    public let brightness: Double
    public let crestFactorDB: Double
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

    mutating func finish() {
        if count > 0 { flush() }
    }

    private mutating func flush() {
        let inverse = 1 / Double(count)
        frames.append(.init(rms: sqrt(powers[0] * inverse), bass: sqrt(powers[1] * inverse),
            middle: sqrt(powers[2] * inverse), high: sqrt(powers[3] * inverse), attackFrame: attackFrame, rise: rise))
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
    }

    static func analyze(frames: [MusicalPulseFrame], sampleRate: Double, framesPerBin: Int,
                        spectralActivity: Double, configuration: AnalysisConfiguration,
                        checkCancellation: @Sendable () throws -> Void) throws -> MusicalRhythmResult {
        try checkCancellation()
        guard sampleRate.isFinite, sampleRate > 0, framesPerBin > 0 else { return .init() }
        let whole=try analyzeWhole(frames:frames,sampleRate:sampleRate,framesPerBin:framesPerBin,
            spectralActivity:spectralActivity,configuration:configuration,checkCancellation:checkCancellation)
        guard whole.bpm == nil || whole.confidence < 0.72 else { return whole }
        let binsPerSecond=sampleRate/Double(framesPerBin)
        let window=max(1,Int((24*binsPerSecond).rounded()))
        let minimum=max(1,Int((12*binsPerSecond).rounded()))
        guard frames.count >= minimum else { return whole }
        var starts=Array(stride(from:0,to:frames.count-minimum+1,by:max(1,window/2)))
        starts.append(max(0,frames.count-window))
        starts.append(max(0,frames.count-minimum))
        for start in Set(starts).sorted() {
            try checkCancellation()
            let end=min(frames.count,start+window)
            let slice=frames[start..<end]
            let peak=slice.map(\.rms).max() ?? 0
            guard peak > 1e-7 else { continue }
            var rises=0.0
            for i in (start+1)..<end { rises += max(0,frames[i].rms-frames[i-1].rms) }
            let activity=min(1,4*rises/(peak*Double(end-start)))
            guard activity > 0.008 else { continue }
            let offset=Double(start*framesPerBin)
            let local=slice.map { value in
                MusicalPulseFrame(rms:value.rms,bass:value.bass,middle:value.middle,high:value.high,
                    attackFrame:value.attackFrame-offset,rise:value.rise)
            }
            var candidate=try analyzeWhole(frames:local,sampleRate:sampleRate,framesPerBin:framesPerBin,
                spectralActivity:activity,configuration:configuration,checkCancellation:checkCancellation)
            guard candidate.bpm != nil, candidate.confidence >= 0.72,
                  whole.bpm == nil || candidate.confidence > whole.confidence+0.08 else { continue }
            candidate.anchorSeconds=candidate.anchorSeconds.map { $0+offset/sampleRate }
            let extensionResult=try extendLateAnchor(frames:frames,binsPerSecond:binsPerSecond,
                anchor:candidate.anchorSeconds ?? offset/sampleRate,bpm:candidate.bpm!,checkCancellation:checkCancellation)
            candidate.anchorSeconds=extensionResult.anchor
            if let downbeat=candidate.downbeat { candidate.downbeat=(downbeat+extensionResult.beats)%4 }
            candidate.onsetsPerSecond *= Double(end-start)/Double(frames.count)
            if let map=candidate.adaptiveCandidate {
                let shifted=BeatGridMap(anchors:map.anchors.map { .init(beat:$0.beat+Double(extensionResult.beats),frame:$0.frame+offset) },
                    sampleRate:map.sampleRate,downbeatOffset:candidate.downbeat ?? map.downbeatOffset)
                candidate.adaptiveCandidate=(try? shifted.validate(frameCount:Int64(frames.count*framesPerBin))) != nil ? shifted:nil
            }
            return candidate
        }
        return whole
    }

    /// Extend a supported late beat train back to its first audible attack, using local contrast.
    private static func extendLateAnchor(frames: [MusicalPulseFrame], binsPerSecond: Double,
        anchor: Double, bpm: Double, checkCancellation: @Sendable () throws -> Void) throws -> (anchor: Double, beats: Int) {
        let period=60/bpm, radius=max(1,Int((0.025*binsPerSecond).rounded()))
        var earliest=anchor, shift=0, missed=0, beat=1
        while anchor-Double(beat)*period >= 0 {
            try checkCancellation()
            let center=Int(((anchor-Double(beat)*period)*binsPerSecond).rounded())
            let lower=max(0,center-radius), upper=min(frames.count-1,center+radius)
            guard lower <= upper else { break }
            let peak=(lower...upper).filter { frames[$0].rise > 1e-9 }
                .min { abs($0-center) < abs($1-center) }
            guard let peak else {
                missed += 1
                if missed >= 2 { break }
                beat += 1; continue
            }
            let beforeStart=max(0,lower-radius*2), afterEnd=min(frames.count,upper+radius*2+1)
            let before=frames[beforeStart..<lower].map(\.rms), after=frames[(upper+1)..<afterEnd].map(\.rms)
            let baseline=min(before.isEmpty ? frames[peak].rms:before.reduce(0,+)/Double(before.count),
                             after.isEmpty ? frames[peak].rms:after.reduce(0,+)/Double(after.count))
            if frames[peak].rms > max(1e-7,baseline*1.35) {
                earliest=Double(peak)/binsPerSecond; shift=beat; missed=0
            } else {
                missed += 1
                if missed >= 2 { break }
            }
            beat += 1
        }
        return (earliest,shift)
    }

    /// The whole-track path remains the fast path for a well-supported tempo.
    private static func analyzeWhole(frames: [MusicalPulseFrame], sampleRate: Double, framesPerBin: Int,
                        spectralActivity: Double, configuration: AnalysisConfiguration,
                        checkCancellation: @Sendable () throws -> Void) throws -> MusicalRhythmResult {
        var result = try consensus(frames: frames, sampleRate: sampleRate, framesPerBin: framesPerBin,
                                   spectralActivity: spectralActivity, configuration: configuration, checkCancellation: checkCancellation)
        let usedPeriodicity=result.bpm == nil
        if result.bpm == nil {
            guard frames.count > 400,spectralActivity > 0.008,
                  let periodic=try periodicity(frames:frames,binsPerSecond:sampleRate/Double(framesPerBin),
                    configuration:configuration,checkCancellation:checkCancellation) else { return result }
            result.bpm=periodic.bpm
            result.anchorSeconds=periodic.anchorSeconds
            result.confidence=periodic.confidence
        }
        if result.adaptiveCandidate == nil,let bpm=result.bpm,let supported=try supportedPulseTrain(frames:frames,
            binsPerSecond:sampleRate/Double(framesPerBin),bpm:bpm,configuration:configuration,
            checkCancellation:checkCancellation) {
            result.bpm=supported.bpm
            result.anchorSeconds=supported.anchorSeconds
            result.confidence=supported.confidence
            result.gridResidualMilliseconds=supported.residual*1000
        } else if usedPeriodicity,result.adaptiveCandidate == nil {
            result.confidence=min(result.confidence,0.69)
        }
        if let bpm=result.bpm,let anchor=result.anchorSeconds {
            let downbeat=try detectDownbeat(frames:frames,binsPerSecond:sampleRate/Double(framesPerBin),
                period:60/bpm,anchor:anchor,checkCancellation:checkCancellation)
            result.downbeat=downbeat.offset
            result.downbeatConfidence=downbeat.confidence
        }
        return result
    }

    /// Check tempo multiples against sustained bass attacks before accepting a dense-mix grid.
    private static func supportedPulseTrain(frames:[MusicalPulseFrame],binsPerSecond:Double,bpm:Double,
        configuration:AnalysisConfiguration,checkCancellation:@Sendable () throws -> Void) throws
        -> (bpm:Double,anchorSeconds:Double,confidence:Double,residual:Double)? {
        let radius=max(1,Int((0.0125*binsPerSecond).rounded(.down)))
        guard frames.count > radius*4 else { return nil }
        var sums=[Double](repeating:0,count:frames.count+1)
        for index in frames.indices {
            if index.isMultiple(of:4096) { try checkCancellation() }
            sums[index+1]=sums[index]+frames[index].bass*frames[index].bass
        }
        let envelope=frames.indices.map { index -> Double in
            let lower=max(0,index-radius),upper=min(frames.count,index+radius+1)
            return sqrt(max(0,(sums[upper]-sums[lower])/Double(upper-lower)))
        }
        let difference=max(1,Int((0.01*binsPerSecond).rounded()))
        var novelty=[Double](repeating:0,count:frames.count)
        for index in frames.indices { novelty[index]=max(0,envelope[index]-(index >= difference ? envelope[index-difference]:0)) }
        guard let peak=novelty.max(),peak > 1e-8 else { return nil }
        var onsets=[MusicalOnset]()
        for index in frames.indices where novelty[index] > peak*0.08
            && (index == 0 || novelty[index] >= novelty[index-1])
            && (index+1 == frames.count || novelty[index] > novelty[index+1]) {
            let event=MusicalOnset(seconds:Double(index+difference/2)/binsPerSecond,weight:novelty[index]/peak)
            if let previous=onsets.last,event.seconds-previous.seconds < 0.18 {
                if event.weight > previous.weight { onsets[onsets.count-1]=event }
            } else { onsets.append(event) }
        }
        guard onsets.count >= 24 else { return nil }
        let duration=Double(frames.count)/binsPerSecond
        var best:Fit?
        for tempo in [bpm,bpm*2,bpm/2] where tempo >= configuration.minimumBPM && tempo <= configuration.maximumBPM {
            try checkCancellation()
            guard let candidate=try fit(period:60/tempo,onsets:onsets,duration:duration,checkCancellation:checkCancellation),
                  candidate.score >= 0.4,candidate.matched >= 24 else { continue }
            if best == nil || candidate.score > best!.score+0.04 { best=candidate }
        }
        guard let best else { return nil }
        let anchor=best.phase+((best.first-best.phase)/best.period).rounded()*best.period
        return (60/best.period,max(0,anchor),min(1,best.score/0.75),best.residual)
    }

    /// Onset-strength autocorrelation with a broad log-tempo prior, refined at eight-beat lags.
    /// Returns nil when the envelope has no clear periodicity, so tonal or unaccented audio stays unknown.
    static func periodicity(frames: [MusicalPulseFrame], binsPerSecond: Double, configuration: AnalysisConfiguration,
                            checkCancellation: @Sendable () throws -> Void) throws -> (bpm: Double, anchorSeconds: Double, confidence: Double)? {
        let count = frames.count
        guard count > 400, binsPerSecond.isFinite, binsPerSecond > 0 else { return nil }
        let weights = [0.2, 0.4, 0.25, 0.15]
        var envelope = [Double](repeating: 0, count: count)
        for band in 0..<4 {
            let peak = max(frames.lazy.map { $0.value(band) }.max() ?? 0, 1e-12)
            for index in 1..<count {
                envelope[index] += weights[band] * max(0, frames[index].value(band) - frames[index - 1].value(band)) / peak
            }
        }
        // Remove the slow trend over about one second, keeping only rises above it.
        let window = max(4, Int(binsPerSecond))
        var running = 0.0, detrended = [Double](repeating: 0, count: count)
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
        var bestLag = 0, bestScore = 0.0
        for lag in (shortest + 1)...longest where values[lag] >= values[lag - 1] && values[lag] >= values[lag + 1] {
            let seconds = Double(lag) / binsPerSecond
            // Broad prior centred on 0.5 s (120 BPM), 1.4 octaves wide.
            let prior = exp(-0.5 * pow(log2(seconds / 0.5) / 1.4, 2))
            let score = values[lag] * prior
            if score > bestScore { bestScore = score; bestLag = lag }
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
            var peak = far, peakValue = autocorrelation(far)
            for lag in (far - 6)...(far + 6) { let value = autocorrelation(lag); if value > peakValue { peakValue = value; peak = lag } }
            let left = autocorrelation(peak - 1), right = autocorrelation(peak + 1)
            let curvature = left - 2 * peakValue + right
            let offset = curvature < 0 ? 0.5 * (left - right) / curvature : 0
            let refined = (Double(peak) + max(-0.5, min(0.5, offset))) / 8
            if abs(refined / period - 1) < 0.05 { period = refined }
        }
        let bpm = 60 * binsPerSecond / period
        guard bpm >= configuration.minimumBPM, bpm <= configuration.maximumBPM else { return nil }
        // Beat phase: the comb offset with the most onset energy.
        let steps = max(1, Int(period.rounded()))
        var bestPhase = 0, bestPhaseEnergy = -1.0
        for phase in 0..<steps {
            var energy = 0.0, position = Double(phase)
            while Int(position) < count { energy += detrended[Int(position)]; position += period }
            if energy > bestPhaseEnergy { bestPhaseEnergy = energy; bestPhase = phase }
        }
        let confidence = min(1, max(0, strength * 4))
        let threshold=(detrended.max() ?? 0)*0.08
        let tolerance=min(0.045*binsPerSecond,period*0.12)
        var byBeat=[Int:Int]()
        for index in detrended.indices where detrended[index] > max(1e-8,threshold) {
            if index.isMultiple(of:4096) { try checkCancellation() }
            let beat=Int(((Double(index)-Double(bestPhase))/period).rounded())
            guard abs(Double(index)-Double(bestPhase)-Double(beat)*period) <= tolerance else { continue }
            if byBeat[beat].map({ detrended[$0] >= detrended[index] }) != true { byBeat[beat]=index }
        }
        var run=[Int]()
        for beat in byBeat.keys.sorted() {
            let index=byBeat[beat]!
            if let previous=run.last, Double(index-previous) > period*2.25 { run=[] }
            run.append(index)
            if run.count >= 6 {
                return (bpm,Double(run[0])/binsPerSecond,confidence)
            }
        }
        return nil
    }

    private static func consensus(frames: [MusicalPulseFrame], sampleRate: Double, framesPerBin: Int,
                                  spectralActivity: Double, configuration: AnalysisConfiguration,
                                  checkCancellation: @Sendable () throws -> Void) throws -> MusicalRhythmResult {
        guard frames.count > 400, spectralActivity > 0.008,
              let maximum = frames.map(\.rms).max(), maximum > 1e-7 else { return .init() }
        let binsPerSecond = sampleRate / Double(framesPerBin)
        var onsets: [[MusicalOnset]] = []
        for band in 0..<4 {
            try checkCancellation()
            onsets.append(try extractOnsets(frames: frames, band: band, sampleRate: sampleRate,
                binsPerSecond: binsPerSecond, checkCancellation: checkCancellation))
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
                        let bucket = min(bucketCount - 1, max(0, Int(((bpm - configuration.minimumBPM) / step).rounded())))
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
                fits.append(try fit(period: 60 / candidate, onsets: onsets[band], duration: duration,
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
            if best == nil || score > best!.score + 0.005 {
                best = (bpm, fits, score)
            }
        }
        result.adaptiveCandidate = try AdaptiveRhythmAnalyzer.candidate(onsets: onsets[1], sampleRate: sampleRate,
            frameCount: Int64(frames.count * framesPerBin), downbeat: 0, referenceBPM: best?.bpm, checkCancellation: checkCancellation)
        guard let best, best.score > 0.58 else { return result }
        let order = [1, 2, 0, 3]
        guard let phaseFit = order.compactMap({ best.fits[$0] }).first(where: { $0.score > 0.72 && $0.matched >= 6 })
            ?? best.fits.compactMap({ $0 }).max(by: { $0.score < $1.score }) else { return result }
        let period = 60 / best.bpm
        let anchor = phaseFit.phase + ((phaseFit.first - phaseFit.phase) / phaseFit.period).rounded() * phaseFit.period
        result.bpm = best.bpm
        result.anchorSeconds = max(0, anchor)
        result.confidence = min(1, max(0, best.score))
        result.gridResidualMilliseconds = phaseFit.residual * 1000
        let downbeat = try detectDownbeat(frames: frames, binsPerSecond: binsPerSecond,
            period: period, anchor: max(0, anchor), checkCancellation: checkCancellation)
        result.downbeat = downbeat.offset
        result.downbeatConfidence = downbeat.confidence
        if let map = result.adaptiveCandidate {
            result.adaptiveCandidate = BeatGridMap(anchors: map.anchors, sampleRate: sampleRate, downbeatOffset: downbeat.offset ?? 0)
        }
        return result
    }

    private static func extractOnsets(frames: [MusicalPulseFrame], band: Int, sampleRate: Double,
                                      binsPerSecond: Double,
                                      checkCancellation: @Sendable () throws -> Void) throws -> [MusicalOnset] {
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
            guard value > 0.18,
                  index == 0 || value >= novelty[index - 1],
                  index + 1 == novelty.count || value > novelty[index + 1] else { continue }
            let start = max(0, index - 2)
            let attack = (start...index).max { frames[$0].rise < frames[$1].rise } ?? index
            let time = frames[attack].attackFrame / sampleRate
            let event = MusicalOnset(seconds: time, weight: sqrt(value))
            if let previous = events.last, time - previous.seconds < 0.07 {
                if event.weight > previous.weight { events[events.count - 1] = event }
            } else { events.append(event) }
        }
        return events
    }

    private static func fit(period initial: Double, onsets: [MusicalOnset], duration: Double,
                            checkCancellation: @Sendable () throws -> Void) throws -> Fit? {
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
                if distance <= tolerance {
                    phaseScores[index] += event.weight * (1 - pow(distance / tolerance, 2))
                }
            }
        }
        let strongest = phaseScores.indices.max { phaseScores[$0] < phaseScores[$1] } ?? 0
        var phase = Double(strongest) * period / Double(phaseBins)
        var offsetSum = 0.0, phaseWeight = 0.0
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
            let covariance = selected.reduce(0.0) { $0 + ($1.beat - meanBeat) * ($1.event.seconds - meanTime) * $1.event.weight }
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
        let score = (0.65 * matchedWeight / max(totalWeight, 1e-12) + 0.35 * occupancy) * precision * (0.7 + 0.3 * coverage)
        return .init(period: period, phase: phase, score: score, residual: residual, matched: selected.count, first: first)
    }

    private static func detectDownbeat(frames: [MusicalPulseFrame], binsPerSecond: Double, period: Double,
                                       anchor: Double, checkCancellation: @Sendable () throws -> Void) throws -> (offset: Int?, confidence: Double?) {
        let duration = Double(frames.count) / binsPerSecond
        let count = Int(floor((duration - anchor) / period))
        guard count >= 12 else { return (nil, nil) }
        var vectors: [[Double]] = []
        for beat in 0..<count {
            if beat.isMultiple(of: 256) { try checkCancellation() }
            let time = anchor + Double(beat) * period
            let start = max(0, Int(((time - 0.005) * binsPerSecond).rounded(.down)))
            let end = min(frames.count, Int(((time + min(0.12, period * 0.3)) * binsPerSecond).rounded(.up)))
            guard end > start else { continue }
            var powers = [Double](repeating: 0, count: 4)
            for index in start..<end {
                for band in 0..<4 { powers[band] += pow(frames[index].value(band), 2) }
            }
            let sum = powers[1] + powers[2] + powers[3]
            vectors.append(sum > 1e-14 ? [powers[1] / sum, powers[2] / sum, powers[3] / sum, sqrt(powers[0])] : [0, 0, 0, 0])
        }
        guard vectors.count == count else { return (nil, nil) }
        let magnitudes = vectors.map { $0[3] }.filter { $0 > 1e-7 }.sorted()
        guard magnitudes.count >= 12 else { return (nil, nil) }
        let median = magnitudes[magnitudes.count / 2]
        for index in vectors.indices { vectors[index][3] = min(2, vectors[index][3] / median) * 0.25 }
        func scores(parity: Int?) -> [Double] {
            var means = Array(repeating: [Double](repeating: 0, count: 4), count: 4)
            var counts = [Double](repeating: 0, count: 4)
            for beat in vectors.indices where vectors[beat][3] > 0.01 {
                if let parity, (beat / 4) % 2 != parity { continue }
                let position = beat % 4
                counts[position] += 1
                for feature in 0..<4 { means[position][feature] += vectors[beat][feature] }
            }
            guard counts.allSatisfy({ $0 >= 1 }) else { return [0, 0, 0, 0] }
            for position in 0..<4 {
                for feature in 0..<4 { means[position][feature] /= counts[position] }
            }
            return (0..<4).map { position in
                (0..<4).reduce(0.0) { total, feature in
                    let other = (0..<4).filter { $0 != position }.reduce(0.0) { $0 + means[$1][feature] } / 3
                    return total + pow(means[position][feature] - other, 2)
                }
            }
        }
        let total = scores(parity: nil)
        let ranked = total.indices.sorted { total[$0] > total[$1] }
        let best = ranked[0], second = ranked[1]
        guard total[best] > 0.004, total[best] > total[second] * 1.5 else { return (nil, nil) }
        for parity in 0..<2 {
            let split = scores(parity: parity)
            guard split.indices.max(by: { split[$0] < split[$1] }) == best else { return (nil, nil) }
        }
        return (best, min(1, max(0, 1 - total[second] / total[best])))
    }

    static func energy(frames: [MusicalPulseFrame], duration: Double, rhythm: MusicalRhythmResult,
                       spectralActivity: Double, brightness: Double) -> MusicalEnergyAnalysis? {
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
        let level = min(10, max(0, Int((10 * (0.5 * activity + 0.25 * rhythmStrength + 0.2 * flux + 0.05 * brightness)).rounded())))
        return .init(level: level, onsetsPerSecond: rate, rhythmicity: rhythmStrength,
            spectralActivity: spectralActivity, brightness: brightness, crestFactorDB: crest)
    }
}
