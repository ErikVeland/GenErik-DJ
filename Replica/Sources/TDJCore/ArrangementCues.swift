import Foundation

/**
 * Describes musical context without prescribing a performance action.
 */
public enum ArrangementCueKind: Equatable, Sendable {
    case section, build, drop, breakdown, vocal, mixIn, mixOut, drumsEnd, musicEnd

    fileprivate var priority: Int {
        switch self {
        case .musicEnd, .drumsEnd: 5
        case .vocal: 4
        case .drop: 3
        case .breakdown: 2
        case .mixIn, .mixOut: 1
        case .section, .build: 0
        }
    }
}

/**
 * Keeps a cue on its saved source position, including pickups and estimated boundaries.
 */
public struct ArrangementCue: Sendable {
    public var kind: ArrangementCueKind
    public var label: String
    public var frame: Double
    public var end: Double?
    public var estimated: Bool
    public var beatsAway: Double?
    public var beatAligned: Bool
    public var secondsAway: Double
    public var heldByLoop: Bool

    public var distance: String {
        if heldByLoop { return "After loop" }
        let prefix = estimated ? "≈" : ""
        if let beatsAway {
            if beatsAway <= 4 {
                let beats = Int(ceil(max(0, beatsAway)))
                return "\(prefix)\(beats) \(beats == 1 ? "beat" : "beats")"
            }
            return "\(prefix)\(Int(ceil(beatsAway / 4))) bars"
        }
        return "\(prefix)\(Int(ceil(max(0, secondsAway)))) s"
    }

    public var emphasis: Double {
        if heldByLoop { return 0.3 }
        let distance = beatsAway.map { $0 / 4 } ?? secondsAway / 2
        return distance <= 4 ? 0.9 : distance <= 8 ? 0.65 : 0.35
    }

    public var remainingBeatMarks: Int? {
        guard !heldByLoop, beatAligned, let beatsAway, beatsAway > 0, beatsAway <= 4 else { return nil }
        return Int(ceil(beatsAway))
    }
}

/**
 * Selects one upcoming cue and one active region from prepared structure.
 */
public struct ArrangementCueTimeline: Sendable {
    public var currentLabel: String
    public var currentKind: ArrangementCueKind
    public var next: ArrangementCue?
    public var region: ArrangementCue?
    public var ending: ArrangementCue
    public var reverse: Bool
    public var tail: Bool
    public var ended: Bool
    public var slip: Bool
}

extension TrackArrangement {
    /**
     * Reads transport position only. This policy does not schedule analysis or change playback.
     */
    public func cueTimeline(
        frame: Double, continuingFrame: Double? = nil, fileEnd: Double, sampleRate: Double,
        timing: BeatTiming?, reliableGrid: Bool, rate: Double, loopEnd: Double? = nil, slip: Bool = false
    ) -> ArrangementCueTimeline {
        let current = section(at: frame)
        let grid = reliableGrid ? timing : nil
        let speed = abs(rate) > 0.0001 ? abs(rate) : 1
        func cue(
            kind: ArrangementCueKind, label: String, at target: Double, end: Double? = nil,
            estimated: Bool, position: Double? = nil
        ) -> ArrangementCue {
            let position = position ?? frame
            return ArrangementCue(
                kind: kind, label: label, frame: target, end: end, estimated: estimated,
                beatsAway: grid.map { max(0, $0.beat(atFrame: target) - $0.beat(atFrame: position)) },
                beatAligned: grid.map {
                    abs($0.frame(atBeat: $0.beat(atFrame: target).rounded()) - target) <= 1
                } ?? false,
                secondsAway: max(0, target - position) / max(1, sampleRate) / speed,
                heldByLoop: loopEnd.map { target >= $0 } ?? false)
        }
        let endPosition = slip ? continuingFrame ?? frame : frame
        let drumsFirst = rhythmicEnd.map { $0 > endPosition && $0 < musicalEnd } ?? false
        let endFrame = drumsFirst ? rhythmicEnd! : musicalEnd
        let endKind: ArrangementCueKind = drumsFirst ? .drumsEnd : .musicEnd
        let acceptedEnd = landmarks.contains {
            $0.kind == (drumsFirst ? .rhythmicEnd : .musicalEnd) && $0.state != .dismissed
                && ($0.locked || $0.state == .accepted) && abs($0.frame - endFrame) < 1
        }
        var ending = cue(
            kind: endKind, label: drumsFirst ? "Drums end" : "Music end", at: endFrame,
            estimated: drumsFirst ? !acceptedEnd : endIsEstimated, position: endPosition)
        if slip { ending.heldByLoop = false }

        var next: ArrangementCue?
        var region: ArrangementCue?
        func consider(_ candidate: ArrangementCue) {
            guard candidate.frame > frame + 1, rate >= 0 else { return }
            guard let previous = next else {
                next = candidate
                return
            }
            if candidate.frame < previous.frame - 1 {
                next = candidate
            } else if abs(candidate.frame - previous.frame) <= 1 {
                if previous.estimated && !candidate.estimated
                    || previous.estimated == candidate.estimated && candidate.kind.priority > previous.kind.priority
                {
                    next = candidate
                }
            }
        }
        for section in sections where section.start > frame + 1 {
            guard section.role != .unknown || section.behaviour != .sustaining || !section.name.isEmpty else {
                continue
            }
            consider(
                cue(
                    kind: section.cueKind, label: section.cueLabel, at: section.start,
                    estimated: !section.locked))
        }
        for landmark in landmarks where landmark.state != .dismissed && landmark.kind != .downbeat {
            let candidate = cue(
                kind: landmark.kind.cueKind, label: landmark.cueLabel, at: landmark.frame, end: landmark.end,
                estimated: !landmark.locked && landmark.state != .accepted)
            consider(candidate)
            if let end = landmark.end, landmark.frame <= frame, end > frame,
                region == nil || landmark.kind == .vocal
            {
                region = candidate
            }
        }
        if let rhythmicEnd, rhythmicEnd > frame, rhythmicEnd < musicalEnd {
            consider(
                cue(
                    kind: .drumsEnd, label: "Drums end", at: rhythmicEnd,
                    estimated: !landmarks.contains {
                        $0.kind == .rhythmicEnd && $0.state != .dismissed && ($0.locked || $0.state == .accepted)
                    }))
        }
        consider(cue(kind: .musicEnd, label: "Music end", at: musicalEnd, estimated: endIsEstimated))
        return ArrangementCueTimeline(
            currentLabel: current?.cueLabel ?? "", currentKind: current?.cueKind ?? .section,
            next: next, region: region, ending: ending, reverse: rate < 0,
            tail: endPosition >= musicalEnd && endPosition < fileEnd, ended: endPosition >= fileEnd, slip: slip)
    }
}

extension ArrangementSection {
    var cueKind: ArrangementCueKind {
        switch behaviour {
        case .building: .build
        case .dropping: .drop
        case .breakingDown: .breakdown
        default: .section
        }
    }
    var cueLabel: String {
        if !name.isEmpty { return name }
        switch behaviour {
        case .building: return "Build"
        case .dropping: return "Drop"
        case .breakingDown: return "Breakdown"
        default:
            return role == .unknown ? "Section" : role == .preChorus ? "Pre-chorus" : role.rawValue.capitalized
        }
    }
}

extension ArrangementLandmarkKind {
    var cueKind: ArrangementCueKind {
        switch self {
        case .vocal: .vocal
        case .arrival, .mainReturn: .drop
        case .breakdown: .breakdown
        case .mixIn: .mixIn
        case .mixOut: .mixOut
        case .rhythmicEnd: .drumsEnd
        case .musicalEnd: .musicEnd
        default: .section
        }
    }
}

extension ArrangementLandmark {
    var cueLabel: String {
        switch kind {
        case .vocal: "Vocal"
        case .arrival: "Drop / chorus"
        case .mainReturn: "Main return"
        case .breakdown: "Breakdown"
        case .mixIn: "Mix in"
        case .mixOut: "Mix out"
        case .rhythmicEnd: "Drums end"
        case .musicalEnd: "Music end"
        default: name
        }
    }
}
