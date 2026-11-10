import Foundation

struct BeatThisGrid {
    let bpm: Double
    let firstBar: Double
    let beatAgreement: Double
    let barAgreement: Double
    let residualMilliseconds: Double
    var openingPhaseCorrected = false

    private struct Candidate {
        let period: Double
        let phase: Double
        let score: Double
    }

    static func fit(
        beats: [Double], bars: [Double], configuration: AnalysisConfiguration, requireOpeningBar: Bool = false,
        checkCancellation: @Sendable () throws -> Void
    ) throws -> Self? {
        guard beats.count >= 12, bars.count >= 4 else { return nil }
        let beatSteps = zip(beats.dropFirst(), beats).map(-)
        let barSteps = zip(bars.dropFirst(), bars).map(-)
        let periods = (60 / configuration.maximumBPM)...(60 / configuration.minimumBPM)
        var histogram: [Int: Int] = [:]
        for interval in beatSteps + barSteps.map({ $0 / 4 }) where periods.contains(interval) {
            histogram[Int((interval / 0.02).rounded()), default: 0] += 1
        }
        let modes = histogram.keys.sorted {
            let left = histogram[$0, default: 0]
            let right = histogram[$1, default: 0]
            return left == right ? $0 < $1 : left > right
        }.prefix(6)

        func evaluate(_ period: Double) -> Candidate {
            let barLength = 4 * period
            let bins = max(8, Int((barLength / 0.03).rounded()))
            let binWidth = barLength / Double(bins)
            var votes = [Double](repeating: 0, count: bins)
            for bar in bars {
                let bin = Int((bar.truncatingRemainder(dividingBy: barLength) / binWidth).rounded()) % bins
                votes[bin] += 1
            }
            let spread = (-6...6).map { likelihood(Double($0) * binWidth, width: 0.055) }
            let phaseBin = votes.indices.max { a, b in
                func support(_ bin: Int) -> Double {
                    spread.indices.reduce(0) { $0 + spread[$1] * votes[(bin + $1 - 6 + bins) % bins] }
                }
                return support(a) < support(b)
            } ?? 0
            let phase = Double(phaseBin) * binWidth
            let beatPhase = beats.reduce(0) { $0 + likelihood(residual($1, phase, period), width: 0.05) }
            let barPhase = bars.reduce(0) { $0 + likelihood(residual($1, phase, barLength), width: 0.055) }
            let beatSpacing = beatSteps.reduce(0) { $0 + likelihood($1 - period, width: 0.055) }
            let barSpacing = barSteps.reduce(0) { $0 + likelihood($1 - barLength, width: 0.085) }
            // Consecutive beat and bar support distinguish a tempo from its double.
            let score = beatPhase / Double(beats.count) + barPhase / Double(bars.count)
                + beatSpacing / Double(beatSteps.count) + barSpacing / Double(barSteps.count)
            return .init(period: period, phase: phase, score: score)
        }

        var best: Candidate?
        for mode in modes {
            let center = Double(mode) * 0.02
            let lower = max(periods.lowerBound, center - 0.025)
            let upper = min(periods.upperBound, center + 0.025)
            for offset in 0...Int(((upper - lower) / 0.0005).rounded(.down)) {
                try checkCancellation()
                let candidate = evaluate(lower + Double(offset) * 0.0005)
                if best.map({ $0.score < candidate.score }) ?? true { best = candidate }
            }
        }
        guard var winner = best else { return nil }
        let coarsePeriod = winner.period
        for offset in -12...12 {
            try checkCancellation()
            let period = coarsePeriod + Double(offset) * 0.00008
            guard periods.contains(period) else { continue }
            let candidate = evaluate(period)
            if candidate.score > winner.score { winner = candidate }
        }

        let barLength = winner.period * 4
        let inliers = bars.filter { abs(residual($0, winner.phase, barLength)) < 0.06 }
        guard inliers.count >= 4 else { return nil }
        let barIndices = inliers.map { (($0 - winner.phase) / barLength).rounded() }
        let count = Double(inliers.count)
        let meanIndex = barIndices.reduce(0, +) / count
        let meanTime = inliers.reduce(0, +) / count
        let variance = barIndices.reduce(0) { $0 + ($1 - meanIndex) * ($1 - meanIndex) }
        guard variance > 0 else { return nil }
        let fittedBarLength = zip(barIndices, inliers).reduce(0) {
            $0 + ($1.0 - meanIndex) * ($1.1 - meanTime)
        } / variance
        guard periods.contains(fittedBarLength / 4) else { return nil }
        let intercept = meanTime - meanIndex * fittedBarLength
        let phase = intercept - (intercept / fittedBarLength).rounded(.down) * fittedBarLength
        let beatErrors = beats.map { abs(residual($0, phase, fittedBarLength / 4)) }.sorted()
        let beatAgreement = Double(beatErrors.filter { $0 < 0.055 }.count) / Double(beats.count)
        let barAgreement = Double(bars.filter { abs(residual($0, phase, fittedBarLength)) < 0.06 }.count)
            / Double(bars.count)
        guard beatAgreement >= 0.72, barAgreement >= 0.55 else { return nil }
        var firstBar = phase
        if requireOpeningBar {
            // Opening attacks can wobble without moving to another beat or bar.
            // Keep the full-track agreement and residual limits unchanged.
            let openingTolerance = min(0.15, fittedBarLength / 4 * 0.2)
            guard barAgreement >= 0.72,
                let opening = bars.indices.dropLast(3).first(where: { index in
                    let step = (bars[index + 3] - bars[index]) / 3
                    return periods.contains(step / 4) && (1...2).allSatisfy {
                        abs(bars[index + $0] - bars[index] - Double($0) * step) < 0.06
                    }
                }),
                (0...3).allSatisfy({ abs(residual(bars[opening + $0], phase, fittedBarLength)) < openingTolerance }),
                abs((bars[opening + 3] - bars[opening]) - 3 * fittedBarLength) < 2 * openingTolerance
            else { return nil }
            let observed = bars[opening]
            firstBar = max(0, observed - residual(observed, phase, fittedBarLength))
        }
        return .init(
            bpm: 240 / fittedBarLength, firstBar: firstBar, beatAgreement: beatAgreement,
            barAgreement: barAgreement, residualMilliseconds: beatErrors[beatErrors.count / 2] * 1000)
    }

    private static func residual(_ time: Double, _ phase: Double, _ period: Double) -> Double {
        (time - phase) - ((time - phase) / period).rounded() * period
    }

    private static func likelihood(_ error: Double, width: Double) -> Double {
        let normalized = error / width
        return exp(-0.5 * normalized * normalized)
    }
}
