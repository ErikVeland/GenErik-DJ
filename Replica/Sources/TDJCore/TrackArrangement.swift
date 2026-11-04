import Foundation

public enum ArrangementRole: String, Codable, CaseIterable, Sendable {
    case intro, verse, preChorus, chorus, bridge, instrumental, outro, unknown
    public var label: String {
        switch self {
        case .preChorus: "PRE-CHORUS"
        case .unknown: "SECTION"
        default: rawValue.uppercased()
        }
    }
}
public enum ArrangementBehaviour: String, Codable, CaseIterable, Sendable {
    case sustaining, building, dropping, breakingDown, thinning
    public var label: String {
        switch self {
        case .breakingDown: "BREAKDOWN"
        case .dropping: "DROP"
        case .building: "BUILD"
        case .thinning: "THINNING OUT"
        case .sustaining: ""
        }
    }
}
public struct ArrangementSection: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var start: Double
    public var end: Double
    public var role: ArrangementRole
    public var behaviour: ArrangementBehaviour
    public var name: String
    public var boundaryConfidence: Double
    public var labelConfidence: Double
    public var locked: Bool
    public init(start: Double, end: Double, role: ArrangementRole = .unknown,
                behaviour: ArrangementBehaviour = .sustaining, name: String = "",
                boundaryConfidence: Double = 1, labelConfidence: Double = 0, locked: Bool = false) {
        self.start=start; self.end=end; self.role=role; self.behaviour=behaviour; self.name=name
        self.boundaryConfidence=boundaryConfidence; self.labelConfidence=labelConfidence; self.locked=locked
    }
    public var label: String {
        let primary = name.isEmpty ? role.label : name
        return primary + (behaviour == .sustaining || primary == behaviour.label ? "" : " · " + behaviour.label)
    }
    public var colourHex: UInt32 {
        switch role {
        case .intro: return 0x64CFB6
        case .verse: return 0x71ADFF
        case .preChorus: return 0xE9CC70
        case .chorus: return 0xF6AF69
        case .bridge: return 0xB69BE8
        case .outro: return 0x8DB3AA
        case .instrumental, .unknown: break
        }
        switch behaviour {
        case .building: return 0xE9CC70
        case .dropping: return 0xF6AF69
        case .breakingDown: return 0xB69BE8
        default: return 0x8592A5
        }
    }
}
public enum ArrangementLandmarkKind: String, Codable, CaseIterable, Sendable {
    case downbeat, mixIn, vocal, arrival, breakdown, mainReturn, mixOut, rhythmicEnd, musicalEnd, custom
    public var label: String {
        switch self {
        case .downbeat: "First reliable downbeat"
        case .mixIn: "Suggested mix-in"
        case .vocal: "Vocal entry"
        case .arrival: "Chorus or drop start"
        case .breakdown: "Breakdown start"
        case .mainReturn: "Main return"
        case .mixOut: "Suggested mix-out"
        case .rhythmicEnd: "Rhythmic ending"
        case .musicalEnd: "Musical ending"
        case .custom: "Custom landmark"
        }
    }
}
public enum ArrangementLandmarkState: String, Codable, Sendable { case suggested, accepted, dismissed }
public struct ArrangementLandmark: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var frame: Double
    public var end: Double?
    public var name: String
    public var kind: ArrangementLandmarkKind
    public var reason: String
    public var confidence: Double
    public var state: ArrangementLandmarkState
    public var locked: Bool
    public init(frame: Double, end: Double? = nil, name: String, kind: ArrangementLandmarkKind = .custom,
                reason: String = "", confidence: Double = 0.5, state: ArrangementLandmarkState = .suggested, locked: Bool = false) {
        self.frame=frame; self.end=end; self.name=name; self.kind=kind; self.reason=reason
        self.confidence=confidence; self.state=state; self.locked=locked
    }
}
public struct TrackArrangement: Codable, Equatable, Sendable {
    public var sections: [ArrangementSection]
    public var landmarks: [ArrangementLandmark]
    public var musicalEnd: Double
    public var rhythmicEnd: Double?
    public var endIsEstimated = true
    public init(sections: [ArrangementSection], landmarks: [ArrangementLandmark], musicalEnd: Double, rhythmicEnd: Double?) {
        self.sections=sections; self.landmarks=landmarks; self.musicalEnd=musicalEnd; self.rhythmicEnd=rhythmicEnd
    }
    public func isValid(fileEnd: Double) -> Bool {
        guard fileEnd.isFinite, fileEnd > 0, musicalEnd.isFinite, musicalEnd >= 0, musicalEnd <= fileEnd,
              rhythmicEnd.map({ $0.isFinite && $0 >= 0 && $0 <= musicalEnd }) ?? true,
              sections.count <= 2048, landmarks.count <= 4096,
              sections.allSatisfy({ $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end > $0.start && $0.end <= fileEnd }),
              landmarks.allSatisfy({ mark in mark.frame.isFinite && mark.frame >= 0 && mark.frame <= fileEnd &&
                  (mark.end.map { $0.isFinite && $0 > mark.frame && $0 <= fileEnd } ?? true) }) else { return false }
        let sorted=sections.sorted { $0.start < $1.start }
        return zip(sorted,sorted.dropFirst()).allSatisfy { $0.end <= $1.start }
    }
    public func section(at frame: Double) -> ArrangementSection? {
        sections.first { frame >= $0.start && frame < $0.end }
    }
    /// Manual preparation remains authoritative when automatic evidence changes.
    public mutating func retainCorrections(from previous: Self) {
        if previous.sections.contains(where: \.locked) { sections=previous.sections }
        for landmark in previous.landmarks where landmark.locked || landmark.state != .suggested {
            landmarks.removeAll { $0.id == landmark.id || ($0.kind == landmark.kind && (landmark.kind == .musicalEnd || landmark.kind == .rhythmicEnd || landmark.kind == .downbeat || abs($0.frame-landmark.frame) < 1)) }
            landmarks.append(landmark)
        }
        if let ending=landmarks.first(where: { $0.kind == .musicalEnd && $0.locked && $0.state != .dismissed }) {
            musicalEnd=ending.frame; endIsEstimated=false
        }
        if let ending=landmarks.first(where: { $0.kind == .rhythmicEnd && $0.locked && $0.state != .dismissed }) { rhythmicEnd=ending.frame }
        landmarks.sort { $0.frame < $1.frame }
    }
    /// Use local musical evidence when available. Cached loudness alone retains neutral labels.
    public static func prepare(analysis a: AudioAnalysis, features: [MusicalStructureFrame] = [], context: MusicalStructureContext = .init()) -> Self {
        if !features.isEmpty { return musicalPreparation(analysis:a,features:features,context:context) }
        let end=Double(a.frameCount)
        guard a.sampleRate > 0, end > 0, !a.waveform.isEmpty else {
            return .init(sections: [.init(start:0,end:end,name:"SECTION A")], landmarks: [], musicalEnd:end, rhythmicEnd:nil)
        }
        let binFrames=Double(max(1,a.waveformFramesPerBin))
        let peak=a.waveform.map { Double($0.rms) }.max() ?? 0
        let last=a.waveform.lastIndex { Double($0.rms) > max(0.0001,peak*0.015) }
        let musicalEnd=min(end,Double((last ?? (a.waveform.count-1))+1)*binFrames)
        let window=max(1,Int(2*a.sampleRate/binFrames))
        var boundaries=[0.0]
        if a.waveform.count > window*2 {
            var prefix=[0.0]
            for bin in a.waveform { prefix.append(prefix.last! + Double(bin.rms)) }
            for i in stride(from:window,to:a.waveform.count-window,by:window) {
                let before=(prefix[i]-prefix[i-window])/Double(window)
                let after=(prefix[i+window]-prefix[i])/Double(window)
                let frame=Double(i)*binFrames
                if abs(after-before) > max(0.02,peak*0.22),
                   frame-boundaries.last! >= 8*a.sampleRate, musicalEnd-frame >= 8*a.sampleRate {
                    boundaries.append(frame)
                }
            }
        }
        var sections=[ArrangementSection]()
        for (i,start) in boundaries.enumerated() {
            sections.append(.init(start:start,end:i+1 < boundaries.count ? boundaries[i+1] : end,
                name:"SECTION \(i+1)",boundaryConfidence:i == 0 ? 1:0.55))
        }
        var landmarks=[ArrangementLandmark(frame:musicalEnd,name:"Estimated musical end",kind:.musicalEnd,
            reason:"Last sustained audible content in the cached waveform",confidence:0.4)]
        if a.tempoConfidence >= 0.6, let anchor=a.beatAnchorFrame, anchor >= 0, anchor < musicalEnd {
            let offset=Double(a.detectedDownbeatOffset ?? 0)*a.sampleRate*60/max(1,a.bpm ?? 120)
            let frame=anchor+offset
            if frame < musicalEnd {
                landmarks.append(.init(frame:frame,name:"First grid downbeat",kind:.downbeat,
                    reason:"Beat-grid suggestion. Check against the audio.",confidence:a.tempoConfidence))
            }
        }
        return .init(sections:sections,landmarks:landmarks.sorted { $0.frame < $1.frame },musicalEnd:musicalEnd,rhythmicEnd:nil)
    }
}

public enum ArrangementWarning: Int, Sendable { case none, prepare, amber, red, urgent, ended }
public struct ArrangementStatus: Sendable {
    public var currentSection: String
    public var nextEvent: String
    public var endingText: String
    public var warning: ArrangementWarning
    public var barsRemaining: Int?
    public var musicSeconds: Double
    public var fileSeconds: Double
    public var pulse: Double
    public func pulseValue(reduceMotion: Bool, audible: Bool) -> Double { reduceMotion || !audible ? 0 : pulse }
}
extension TrackArrangement {
    public func status(frame: Double, continuingFrame: Double? = nil, fileEnd: Double, sampleRate: Double,
                       timing: BeatTiming?, reliableGrid: Bool, playing: Bool, rate: Double,
                       loop: Bool = false, slip: Bool = false, prepareBars: Int = 32) -> ArrangementStatus {
        let position=loop && slip ? (continuingFrame ?? frame) : frame
        let speed=abs(rate) > 0.0001 ? abs(rate):1, sr=max(1,sampleRate)
        let beat=timing?.beat(atFrame:position) ?? 0
        let beats=timing.map { max(0,$0.beat(atFrame:musicalEnd)-beat) }
        let bars=reliableGrid ? beats.map { Int(ceil($0/4)) } : nil
        let seconds=max(0,(musicalEnd-position)/sr/speed)
        let distance=bars.map(Double.init) ?? seconds/2
        var warning: ArrangementWarning = distance <= 0 ? .ended : distance <= 4 ? .urgent : distance <= 8 ? .red : distance <= 16 ? .amber : distance <= Double(prepareBars) ? .prepare : .none
        func countdown(_ target: Double) -> String {
            if reliableGrid, let timing {
                let bars=Int(ceil(max(0,timing.beat(atFrame:target)-beat)/4))
                return "\(bars) \(bars == 1 ? "BAR":"BARS")"
            }
            return "\(Int(ceil(max(0,(target-position)/sr/speed)))) SEC"
        }
        var ending=position >= musicalEnd ? (position < fileEnd ? "TAIL" : "MUSIC ENDED")
            : "\(endIsEstimated ? "ESTIMATED END" : "MUSIC ENDS") IN \(countdown(musicalEnd))"
        if let rhythmicEnd, position < rhythmicEnd, rhythmicEnd < musicalEnd {
            ending="DRUMS END IN \(countdown(rhythmicEnd))"
            let drumDistance = reliableGrid ? timing.map { max(0,$0.beat(atFrame:rhythmicEnd)-beat)/4 } : (rhythmicEnd-position)/sr/speed/2
            if let d=drumDistance, d <= 8 { warning=d <= 4 ? .urgent : .red }
        }
        var pulse=0.0
        if reliableGrid, playing, rate > 0, warning == .red || warning == .urgent, let timing {
            let localBPM=60*sr/max(1,timing.frame(atBeat:beat+1)-timing.frame(atBeat:beat))*speed
            var stride=1.0
            while localBPM/60/stride > 2 { stride *= 2 }
            pulse=(1-cos(2*Double.pi*beat/stride))/2
        }
        if loop && !slip { ending="LOOP ACTIVE · AFTER RELEASE \(countdown(musicalEnd))"; warning = .none; pulse=0 }
        if loop && slip { ending="SLIP · " + ending }
        if rate < 0 { ending="REVERSE"; warning = .none; pulse=0 }
        let nextLandmark=landmarks.filter { $0.state != .dismissed && $0.frame > position+1 && $0.kind != .musicalEnd }
            .min { $0.frame < $1.frame }
        let nextSection=sections.filter { $0.start > position+1 }.min { $0.start < $1.start }
        var event=""
        if let nextLandmark, nextSection == nil || nextLandmark.frame <= nextSection!.start {
            event="\(nextLandmark.name.uppercased()) IN \(countdown(nextLandmark.frame))"
        } else if let nextSection { event="\(nextSection.label) IN \(countdown(nextSection.start))" }
        return .init(currentSection:section(at:frame)?.label ?? "",nextEvent:event,endingText:ending,warning:warning,
            barsRemaining:bars,musicSeconds:seconds,fileSeconds:max(0,(fileEnd-position)/sr/speed),pulse:pulse)
    }
}
