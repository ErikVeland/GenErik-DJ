import Foundation

enum BeatThisOpeningBar {
    static func correct(_ grid: BeatThisGrid, beats: [Double], barLogits: [Float]) -> BeatThisGrid? {
        guard grid.beatAgreement >= 0.95, grid.residualMilliseconds <= 20,
            beats.count >= 32, let start = beats.first else { return nil }
        let period = 60 / grid.bpm
        var beatIndex = 0
        var scores: [[Double]] = []
        for bar in 0..<4 {
            var values: [Double] = []
            for beat in 0..<4 {
                let time = start + Double(bar * 4 + beat) * period
                while beatIndex + 1 < beats.count, abs(beats[beatIndex + 1] - time) < abs(beats[beatIndex] - time) {
                    beatIndex += 1
                }
                guard abs(beats[beatIndex] - time) <= 0.04 else { return nil }
                let index = Int((time * 50).rounded())
                guard index >= 3, index + 3 < barLogits.count else { return nil }
                values.append(Double(barLogits[(index - 3)...(index + 3)].max()!))
            }
            scores.append(values)
        }
        let winners = scores.map { values in values.indices.max { values[$0] < values[$1] }! }
        guard let phase = winners.first, winners.allSatisfy({ $0 == phase }) else { return nil }
        let margins = scores.map { values -> Double in
            let ranked = values.sorted()
            return ranked[3] - ranked[2]
        }
        guard scores.allSatisfy({ $0[phase] >= 3 }), margins.allSatisfy({ $0 >= 0.25 }),
            margins.reduce(0, +) / 4 >= 2 else { return nil }
        let opening = start + Double(phase) * period
        let offset = (opening - grid.firstBar) / period
        let shift = Int(offset.rounded())
        guard abs(offset - Double(shift)) <= 0.15, ((shift % 4) + 4) % 4 == 2 else { return nil }
        let anchor = grid.firstBar + Double(shift) * period
        guard anchor >= 0 else { return nil }
        // The opening agrees, but later bar evidence conflicts. Keep confidence below the strong-evidence threshold.
        return .init(bpm: grid.bpm, firstBar: anchor, beatAgreement: grid.beatAgreement,
                     barAgreement: min(0.69, grid.barAgreement), residualMilliseconds: grid.residualMilliseconds,
                     openingPhaseCorrected: true)
    }
}
