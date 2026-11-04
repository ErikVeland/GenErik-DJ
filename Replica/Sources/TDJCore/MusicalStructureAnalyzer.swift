import Accelerate
import AVFoundation
import Foundation
import SoundAnalysis

public struct MusicalStructureContext: Codable, Equatable, Sendable {
    public var title: String
    public var genre: String?
    public init(title: String = "", genre: String? = nil) { self.title=title; self.genre=genre }
    var prefersRhythmicEdges: Bool {
        func matches(_ text: String, _ pattern: String) -> Bool {
            text.range(of:pattern,options:[.regularExpression,.caseInsensitive]) != nil
        }
        if matches(title,#"\ba\s?cap+p?ella\b"#) { return false }
        let version=matches(title,#"\bextended\s+(?:mix|edit|remix|version)\b|12(?:[\s-]*(?:["”″']|inch)|_\s*(?:mix|version|scratch))|\b(?:club|dub)\s+(?:mix|remix|version)\b"#)
        let dance=matches(genre ?? "",#"\b(?:house|disco|techno|trance|dance|electronic|garage|jungle|breakbeat|breaks)\b|drum.{0,5}bass"#)
        return version || dance
    }
}

/// One second of local evidence. Frames use the source audio timeline.
public struct MusicalStructureFrame: Sendable, Equatable {
    public var start: Double
    public var end: Double
    public var rms: Double
    public var bass: Double
    public var rhythm: Double
    public var bands: [Double]
    public var chroma: [Double]
    public var vocal: Double?
    public var rapping: Double?
    public var singing: Double?
    public init(start: Double, end: Double, rms: Double, bass: Double, rhythm: Double,
                bands: [Double], chroma: [Double], vocal: Double? = nil, rapping: Double? = nil, singing: Double? = nil) {
        self.start=start; self.end=end; self.rms=rms; self.bass=bass; self.rhythm=rhythm
        self.bands=bands; self.chroma=chroma; self.vocal=vocal; self.rapping=rapping; self.singing=singing
    }
}

/// Runs on cached PCM at utility priority. Playback never calls this analyser.
public enum MusicalStructureAnalyzer {
    public static let version = 6

    public static func analyze(pcm url: URL, analysis: AudioAnalysis,
                               checkCancellation: () throws -> Void = { try Task.checkCancellation() }) throws -> [MusicalStructureFrame] {
        try checkCancellation()
        let rate=analysis.sampleRate
        guard rate.isFinite, rate >= 8000, rate <= 384000, analysis.frameCount > 0,
              analysis.frameCount <= Int64(Int.max / 8) else { throw CoreError.invalidAudio("The structure source format is invalid.") }
        let data=try Data(contentsOf:url,options:.alwaysMapped)
        guard data.count == Int(analysis.frameCount)*8 else { throw CoreError.invalidAudio("The structure source is incomplete.") }
        let fft=try StructureSpectrum(sampleRate:rate)
        let format=AVAudioFormat(standardFormatWithSampleRate:rate,channels:1)!
        let observer=VocalResults()
        let request=try SNClassifySoundRequest(classifierIdentifier:.version1)
        let vocalNames=Set(["singing","speech","rapping","choir"])
        observer.names=vocalNames.intersection(request.knownClassifications)
        guard !observer.names.isEmpty else { throw CoreError.invalidAudio("The vocal classifier is unavailable.") }
        request.overlapFactor=0
        let classifier=SNAudioStreamAnalyzer(format:format)
        try classifier.add(request,withObserver:observer)
        defer { classifier.removeAllRequests() }
        let second=max(1,Int(rate.rounded()))
        let capacity=AVAudioFrameCount(second)
        guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:capacity), let mono=buffer.floatChannelData?[0] else {
            throw CoreError.invalidAudio("Cannot allocate the structure analysis buffer.")
        }
        var result=[MusicalStructureFrame]()
        var low=0.0, smooth=0.0, previousEnvelope=0.0
        let coefficient=1-exp(-2 * Double.pi * 180/rate)
        let envelopeSize=max(1,Int(rate*0.02))
        try data.withUnsafeBytes { raw in
            let samples=raw.bindMemory(to:Float.self)
            for start in stride(from:0,to:Int(analysis.frameCount),by:second) {
                try checkCancellation()
                let count=min(second,Int(analysis.frameCount)-start)
                var power=0.0, bassPower=0.0, envelopePower=0.0, attacks=0
                for offset in 0..<count {
                    let x=Double(samples[(start+offset)*2]+samples[(start+offset)*2+1])*0.5
                    guard x.isFinite else { throw CoreError.invalidAudio("The structure source contains invalid samples.") }
                    mono[offset]=Float(x)
                    power += x*x
                    low += coefficient*(x-low)
                    bassPower += low*low
                    envelopePower += low*low
                    if (offset+1).isMultiple(of:envelopeSize) {
                        let envelope=sqrt(envelopePower/Double(envelopeSize))
                        if envelope > max(0.005,previousEnvelope*1.35), envelope > smooth*1.15 { attacks += 1 }
                        smooth=smooth*0.8+envelope*0.2
                        previousEnvelope=envelope; envelopePower=0
                    }
                }
                buffer.frameLength=AVAudioFrameCount(count)
                classifier.analyze(buffer,atAudioFramePosition:AVAudioFramePosition(start))
                let spectrum=fft.features(mono:mono,count:count)
                let rms=sqrt(power/Double(count))
                result.append(.init(start:Double(start),end:Double(start+count),rms:rms,
                    bass:sqrt(bassPower/max(power,1e-12)),rhythm:min(1,Double(attacks)/max(1,Double(count)/rate)/3),
                    bands:spectrum.bands,chroma:spectrum.chroma))
            }
        }
        classifier.completeAnalysis()
        try checkCancellation()
        let vocals=try observer.snapshot(checkCancellation:checkCancellation)
        for index in result.indices {
            let start=result[index].start/rate, end=result[index].end/rate
            let overlaps=vocals.filter { $0.start < end && $0.end > start }
            if !overlaps.isEmpty {
                let duration=overlaps.reduce(0.0) { $0+max(0,min(end,$1.end)-max(start,$1.start)) }
                result[index].vocal=overlaps.reduce(0.0) { $0+$1.confidence*max(0,min(end,$1.end)-max(start,$1.start)) }/max(1e-9,duration)
                result[index].rapping=overlaps.reduce(0.0) { $0+$1.rapping*max(0,min(end,$1.end)-max(start,$1.start)) }/max(1e-9,duration)
                result[index].singing=overlaps.reduce(0.0) { $0+$1.singing*max(0,min(end,$1.end)-max(start,$1.start)) }/max(1e-9,duration)
            }
        }
        return result
    }
}

private final class VocalResults: NSObject, SNResultsObserving {
    struct Window { var start: Double; var end: Double; var confidence: Double; var rapping: Double; var singing: Double }
    var names=Set<String>()
    private let lock=NSCondition()
    private var windows=[Window]()
    private var failure: Error?
    private var completed=false
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result=result as? SNClassificationResult else { return }
        let confidence=result.classifications.filter { names.contains($0.identifier) }.map(\.confidence).max() ?? 0
        let rapping=result.classification(forIdentifier:"rapping")?.confidence ?? 0
        let singing=max(result.classification(forIdentifier:"singing")?.confidence ?? 0, result.classification(forIdentifier:"choir")?.confidence ?? 0)
        lock.lock(); defer { lock.unlock() }
        windows.append(.init(start:result.timeRange.start.seconds,end:CMTimeRangeGetEnd(result.timeRange).seconds,
            confidence:confidence,rapping:rapping,singing:singing))
    }
    func request(_ request: SNRequest, didFailWithError error: Error) {
        lock.lock(); defer { lock.unlock() }; failure=error; completed=true; lock.broadcast()
    }
    func requestDidComplete(_ request: SNRequest) {
        lock.lock(); defer { lock.unlock() }; completed=true; lock.broadcast()
    }
    func snapshot(checkCancellation: () throws -> Void) throws -> [Window] {
        lock.lock(); defer { lock.unlock() }
        let deadline=Date().addingTimeInterval(30)
        while !completed {
            try checkCancellation()
            guard Date() < deadline else { throw CoreError.invalidAudio("The vocal classifier timed out.") }
            _=lock.wait(until:Date().addingTimeInterval(0.1))
        }
        if let failure { throw failure }
        return windows
    }
}

private final class StructureSpectrum {
    private let size=8192
    private let setup: FFTSetupD
    private let rate: Double
    private var real=[Double](repeating:0,count:8192)
    private var imaginary=[Double](repeating:0,count:8192)
    private let window=(0..<8192).map { 0.5-0.5*cos(2 * Double.pi * Double($0)/8191) }
    init(sampleRate: Double) throws {
        rate=sampleRate
        guard let value=vDSP_create_fftsetupD(13,FFTRadix(kFFTRadix2)) else {
            throw CoreError.invalidAudio("Cannot allocate the structure transform.")
        }
        setup=value
    }
    deinit { vDSP_destroy_fftsetupD(setup) }
    func features(mono: UnsafeMutablePointer<Float>, count: Int) -> (bands:[Double],chroma:[Double]) {
        let offset=max(0,(count-size)/2)
        for i in 0..<size { real[i]=i+offset < count ? Double(mono[i+offset])*window[i]:0; imaginary[i]=0 }
        real.withUnsafeMutableBufferPointer { r in
            imaginary.withUnsafeMutableBufferPointer { i in
                var split=DSPDoubleSplitComplex(realp:r.baseAddress!,imagp:i.baseAddress!)
                vDSP_fft_zipD(setup,&split,1,13,FFTDirection(FFT_FORWARD))
            }
        }
        let magnitudes=(0..<(size/2)).map { hypot(real[$0],imaginary[$0]) }
        let peak=magnitudes.max() ?? 0
        var bands=[Double](repeating:0,count:6), chroma=[Double](repeating:0,count:12)
        for bin in 1..<(size/2-1) {
            let frequency=Double(bin)*rate/Double(size), magnitude=magnitudes[bin]
            let band=[150.0,400,1000,2500,6000].firstIndex { frequency < $0 } ?? 5
            bands[band] += magnitude
            if frequency >= 65, frequency <= 4000, magnitude > peak*0.05,
               magnitude > magnitudes[bin-1], magnitude >= magnitudes[bin+1] {
                let pitch=Int((69+12*log2(frequency/440)).rounded())
                chroma[(pitch%12+12)%12] += magnitude
            }
        }
        let total=bands.reduce(0,+), tones=chroma.reduce(0,+)
        return (bands.map { $0/max(1e-12,total) },chroma.map { $0/max(1e-12,tones) })
    }
}

extension TrackArrangement {
    static func musicalPreparation(analysis a: AudioAnalysis, features input: [MusicalStructureFrame], context: MusicalStructureContext) -> Self {
        let fileEnd=Double(a.frameCount), rate=a.sampleRate
        let frames=input.filter { $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end > $0.start && $0.end <= fileEnd &&
            $0.rms.isFinite && $0.bass.isFinite && $0.rhythm.isFinite && $0.bands.count == 6 && $0.chroma.count == 12 &&
            $0.bands.allSatisfy(\.isFinite) && $0.chroma.allSatisfy(\.isFinite) && ($0.vocal.map { $0.isFinite && (0...1).contains($0) } ?? true) }
        guard rate > 0, frames.count >= 8, frames.count == input.count,
              zip(frames,frames.dropFirst()).allSatisfy({ $0.end <= $1.start }) else { return prepare(analysis:a) }
        let peak=frames.map(\.rms).max() ?? 0
        guard peak > 0.0001 else { return prepare(analysis:a) }
        let audible=frames.filter { $0.rms > max(0.0001,peak*0.015) }
        let musicalEnd=audible.last?.end ?? fileEnd
        let grid=(a.tempoConfidence >= 0.6 ? a.bpm.flatMap { try? BeatGrid(bpm:$0,anchorFrame:a.beatAnchorFrame ?? 0,sampleRate:rate,downbeatOffset:a.detectedDownbeatOffset ?? 0) }:nil)
        let timing=grid.map { BeatTiming(fixed:$0,adaptive:a.adaptiveCandidate) }
        func aligned(_ frame: Double) -> Double {
            guard let timing else { return frame }
            let beat=timing.beat(atFrame:frame), offset=Double(timing.downbeatOffset)
            let target=timing.frame(atBeat:((beat-offset)/4).rounded()*4+offset)
            return abs(target-frame) <= rate*2 ? min(fileEnd,max(0,target)):frame
        }
        func mean(_ slice: ArraySlice<MusicalStructureFrame>) -> MusicalStructureFrame {
            let n=Double(max(1,slice.count))
            var bands=[Double](repeating:0,count:6), chroma=[Double](repeating:0,count:12)
            for frame in slice {
                for i in 0..<6 { bands[i] += frame.bands[i]/n }
                for i in 0..<12 { chroma[i] += frame.chroma[i]/n }
            }
            let vocals=slice.compactMap(\.vocal)
            return .init(start:slice.first?.start ?? 0,end:slice.last?.end ?? 0,
                rms:slice.reduce(0) { $0+$1.rms }/n,bass:slice.reduce(0) { $0+$1.bass }/n,
                rhythm:slice.reduce(0) { $0+$1.rhythm }/n,bands:bands,chroma:chroma,
                vocal:vocals.isEmpty ? nil:vocals.reduce(0,+)/Double(vocals.count))
        }
        func distance(_ lhs: [Double], _ rhs: [Double]) -> Double { zip(lhs,rhs).reduce(0) { $0+abs($1.0-$1.1) }/2 }
        var novelty=[Double](repeating:0,count:frames.count)
        for i in 4..<(frames.count-3) {
            let before=mean(frames[(i-4)..<i]), after=mean(frames[i..<min(frames.count,i+4)])
            novelty[i]=abs(after.rms-before.rms)/max(peak*0.2,before.rms,after.rms)*0.5
                + distance(before.bands,after.bands)*0.7 + distance(before.chroma,after.chroma)*0.5
                + abs(after.bass-before.bass)*0.4 + abs(after.rhythm-before.rhythm)*0.4
                + abs((after.vocal ?? 0)-(before.vocal ?? 0))*0.35
        }
        var candidates=[Int]()
        for i in 4..<(frames.count-4) where novelty[i] >= 0.22 {
            if novelty[i] >= novelty[(i-2)...(i+2)].max()! { candidates.append(i) }
        }
        candidates.sort { novelty[$0] == novelty[$1] ? $0 < $1:novelty[$0] > novelty[$1] }
        var boundaries=[0.0]
        for index in candidates {
            let boundary=aligned(frames[index].start)
            if boundary >= rate*8, musicalEnd-boundary >= rate*6,
               boundaries.allSatisfy({ abs($0-boundary) >= rate*8 }) { boundaries.append(boundary) }
        }
        boundaries.sort()
        var sections=[ArrangementSection](), summaries=[MusicalStructureFrame](), rises=[Double]()
        var signatures=[[MusicalStructureFrame]]()
        for (i,start) in boundaries.enumerated() {
            let end=i+1 < boundaries.count ? boundaries[i+1]:fileEnd
            let slice=frames.filter { $0.start >= start && $0.start < min(end,musicalEnd) }
            let summary=mean(slice[...])
            summaries.append(summary)
            // Keep passage order. Equal averages can hide different musical sequences.
            signatures.append(slice.count >= 8 ? (0..<8).map { part in
                mean(slice[(part*slice.count/8)..<((part+1)*slice.count/8)])
            } : [])
            let quarter=max(1,slice.count/4)
            let first=mean(slice.prefix(quarter)), last=mean(slice.suffix(quarter))
            rises.append((last.rms-first.rms)/max(peak*0.1,first.rms))
            sections.append(.init(start:start,end:end,role:.instrumental,boundaryConfidence:i == 0 ? 1:0.65,labelConfidence:0.5))
        }
        let maximum=summaries.map(\.rms).max() ?? peak
        let vocalSections=summaries.indices.filter { (summaries[$0].vocal ?? 0) >= 0.45 }
        let vocalDuration=vocalSections.reduce(0.0) { $0+sections[$1].end-sections[$1].start }
        func hasVocalContrast(_ index: Int) -> Bool {
            let contrasting=vocalSections.filter {
                distance(summaries[index].chroma,summaries[$0].chroma) >= 0.25 ||
                distance(summaries[index].bands,summaries[$0].bands) >= 0.25
            }.reduce(0.0) { $0+sections[$1].end-sections[$1].start }
            // A brief change does not distinguish a hook from the track's backing loop.
            return contrasting >= max(rate*8,vocalDuration*0.25)
        }
        func repeatsInOrder(_ i: Int, _ j: Int) -> Bool {
            let first=sections[i].end-sections[i].start, second=sections[j].end-sections[j].start
            guard min(first,second)/max(first,second) >= 0.75,
                  signatures[i].count == 8, signatures[j].count == 8 else { return false }
            let distances=zip(signatures[i],signatures[j]).map {
                max(distance($0.chroma,$1.chroma),distance($0.bands,$1.bands))
            }
            return distances.reduce(0,+)/8 < 0.18 && distances.filter { $0 < 0.18 }.count >= 6
        }
        let contrasted=Set(vocalSections.filter { hasVocalContrast($0) })
        var refrain=Set<Int>()
        for i in vocalSections where summaries[i].rms >= maximum*0.72 && contrasted.contains(i) {
            for j in vocalSections where abs(j-i) >= 2 && summaries[j].rms >= maximum*0.72 && contrasted.contains(j) {
                if distance(summaries[i].chroma,summaries[j].chroma) < 0.18 && distance(summaries[i].bands,summaries[j].bands) < 0.18 && repeatsInOrder(i,j) {
                    refrain.insert(i); refrain.insert(j)
                }
            }
        }
        for i in sections.indices {
            let s=summaries[i], previous=i > 0 ? summaries[i-1]:s
            if refrain.contains(i) { sections[i].role = .chorus }
            else if (s.vocal ?? 0) >= 0.45 {
                if refrain.isEmpty {
                    sections[i].role = .unknown
                    sections[i].name = "Vocal section"
                } else { sections[i].role = .verse }
            }
            else if i == 0 && sections.count > 1 && s.rms < maximum*0.7 { sections[i].role = .intro }
            else if i == sections.count-1 && sections.count > 1 && s.rms < maximum*0.7 { sections[i].role = .outro }
            if rises[i] > 0.65 && s.bass < 0.4 {
                sections[i].behaviour = .building
                if sections[i].role == .verse, refrain.contains(i+1) { sections[i].role = .preChorus }
            } else if i > 0 && s.rms > previous.rms*1.35 && s.bass > previous.bass*1.3 && s.rhythm >= 0.2 {
                sections[i].behaviour = .dropping
            } else if i > 0 && s.rms < previous.rms*0.65 && s.bass < previous.bass*0.7 {
                sections[i].behaviour = .breakingDown
            } else if i > 0 && s.rms < previous.rms*0.75 { sections[i].behaviour = .thinning }
            if sections[i].role == .verse, !refrain.isEmpty, i > (refrain.min() ?? i), i < (refrain.max() ?? i),
               !summaries.indices.contains(where: { $0 != i && distance(s.chroma,summaries[$0].chroma) < 0.18 }) { sections[i].role = .bridge }
            if sections[i].role == .instrumental && sections[i].behaviour != .sustaining { sections[i].name=sections[i].behaviour.label }
        }
        var marks=[ArrangementLandmark]()
        var wasVocal=false
        for i in frames.indices {
            let vocal=(frames[i].vocal ?? 0) >= 0.65
            if vocal && !wasVocal, i+1 < frames.count, (frames[i+1].vocal ?? 0) >= 0.65 {
                marks.append(.init(frame:frames[i].start,name:"Vocal entry",kind:.vocal,
                    reason:"On-device sound classifier detects sustained voice. Check the pickup against the audio.",confidence:frames[i].vocal ?? 0))
            }
            wasVocal=vocal
        }
        var seenChorus=false
        for section in sections {
            if section.role == .chorus || section.behaviour == .dropping {
                let returned=section.role == .chorus && seenChorus
                marks.append(.init(frame:section.start,name:returned ? "Main return":"Chorus or drop start",kind:returned ? .mainReturn:.arrival,
                    reason:"Ordered passage repetition with contrasting vocal passages, or a rhythmic bass arrival. Song form is estimated.",confidence:0.55))
                if section.role == .chorus { seenChorus=true }
            } else if section.behaviour == .breakingDown {
                marks.append(.init(frame:section.start,name:"Breakdown start",kind:.breakdown,
                    reason:"Sustained reduction in bass, rhythm and level.",confidence:0.6))
            }
        }
        let peakBass=frames.map { $0.rms*$0.bass }.max() ?? 0
        let rhythmic=frames.filter { $0.rms*$0.bass > max(0.003,peakBass*0.12) && $0.rhythm >= 0.15 }
        let rhythmicEnd=rhythmic.count >= 4 ? rhythmic.last?.end:nil
        if let rhythmicEnd, musicalEnd-rhythmicEnd >= rate*3 {
            marks.append(.init(frame:rhythmicEnd,name:"Estimated rhythmic ending",kind:.rhythmicEnd,
                reason:"Last sustained bass attacks before the remaining audible tail.",confidence:0.55))
        }
        let mixEnd=rhythmicEnd ?? musicalEnd
        var spans=[(start:Double,end:Double,voiceKnown:Bool)]()
        var run: (start:Double,end:Double,voiceKnown:Bool)?
        for frame in frames {
            let suitable=frame.end <= mixEnd && frame.rms > peak*0.08 && frame.rhythm >= 0.2 && frame.bass >= 0.12 && (frame.vocal ?? 0) < 0.25
            if suitable {
                if run == nil { run=(frame.start,frame.end,frame.vocal != nil) }
                else { run!.end=frame.end; run!.voiceKnown = run!.voiceKnown && frame.vocal != nil }
            } else if let saved=run { if saved.end-saved.start >= rate*8 { spans.append(saved) }; run=nil }
        }
        if let run, run.end-run.start >= rate*8 { spans.append(run) }
        if let first=spans.first, first.start < musicalEnd*0.4 {
            let start=max(first.start,aligned(first.start)), end=min(first.end,aligned(first.end))
            if end > start {
                marks.append(.init(frame:start,end:end,name:"Suggested mix-in",kind:.mixIn,
                    reason:first.voiceKnown ? "Steady bass rhythm with low detected vocal activity. Finish before the next section.":"Steady bass rhythm. Vocal content is unverified.",confidence:first.voiceKnown ? 0.65:0.4))
            }
        }
        if let last=spans.last, last.end > musicalEnd*0.6 {
            let start=max(last.start,aligned(last.start)), end=min(last.end,aligned(last.end))
            if end > start {
                marks.append(.init(frame:start,end:end,name:"Suggested mix-out",kind:.mixOut,
                    reason:last.voiceKnown ? "Steady bass rhythm with low detected vocal activity. Finish before the rhythmic ending.":"Steady bass rhythm before the ending. Vocal content is unverified.",confidence:last.voiceKnown ? 0.65:0.4))
            }
        }
        marks.append(.init(frame:musicalEnd,name:"Estimated musical end",kind:.musicalEnd,
            reason:"Last sustained audible content in local audio.",confidence:0.5))
        if let timing {
            let frame=timing.frame(atBeat:Double(timing.downbeatOffset))
            if frame >= 0, frame < musicalEnd { marks.append(.init(frame:frame,name:"First grid downbeat",kind:.downbeat,reason:"Beat-grid suggestion. Check against the audio.",confidence:a.tempoConfidence)) }
        }
        var result=Self(sections:sections,landmarks:marks.sorted { $0.frame < $1.frame },musicalEnd:musicalEnd,
            rhythmicEnd:rhythmicEnd.flatMap { musicalEnd-$0 >= rate*3 ? $0:nil })
        if context.prefersRhythmicEdges, let timing {
            let origin=timing.beat(atFrame:0)
            let minimum=timing.frame(atBeat:origin+32)-timing.frame(atBeat:origin)
            result.prepareRhythmicEdges(frames:frames,rate:rate,fileEnd:fileEnd,minimum:minimum,aligned:aligned)
        }
        return result
    }

    private mutating func prepareRhythmicEdges(frames: [MusicalStructureFrame], rate: Double, fileEnd: Double,
                                              minimum: Double, aligned: (Double) -> Double) {
        guard minimum.isFinite, minimum > 0, frames.count >= 8 else { return }
        let peak=frames.map(\.rms).max() ?? 0
        let audible=frames.indices.filter { frames[$0].rms > peak*0.05 }
        guard let first=audible.first, let last=audible.last, last-first >= 4 else { return }
        let good=frames.map { f in
            f.vocal.map { $0 <= 0.25 } == true && f.rhythm >= 0.55 && f.bass >= 0.12 && f.rms > peak*0.05
        }
        // A sustained change ends the passage. A single fill does not create a new section.
        var front=(first..<(last-3)).first { i in good[i..<(i+4)].filter { $0 }.count < 2 } ?? last
        var back=stride(from:last,through:first+3,by:-1).first { i in good[(i-3)...i].filter { $0 }.count < 2 }.map { $0+1 } ?? first
        while front < last && good[front] { front += 1 }
        while back > first && good[back-1] { back -= 1 }
        func supported(_ range: Range<Int>) -> Bool {
            !range.isEmpty && Double(good[range].filter { $0 }.count)/Double(range.count) >= 0.75
        }
        let proposedIntroEnd=aligned(frames[front].start)
        // Retain the established transition if the sustained-change window reports it slightly late.
        let introEnd=sections.map(\.start).filter { $0 > 0 && $0 <= proposedIntroEnd && proposedIntroEnd-$0 <= rate*3 }.max() ?? proposedIntroEnd
        if frames[first].start <= rate*8, frames[front].start-frames[first].start >= minimum,
           introEnd <= musicalEnd*0.4, supported(first..<front) {
            replaceEdge(start:0,end:introEnd,role:.intro,name:"Rhythmic intro")
        }
        if back <= last {
            let outroStart=aligned(frames[back].start)
            if frames[last].end-frames[back].start >= minimum, outroStart >= musicalEnd*0.6,
               supported(back..<(last+1)) {
                replaceEdge(start:outroStart,end:fileEnd,role:.outro,name:"Rhythmic outro")
            }
        }
    }

    private mutating func replaceEdge(start: Double, end: Double, role: ArrangementRole, name: String) {
        guard end > start else { return }
        var retained=[ArrangementSection]()
        for section in sections {
            if section.end <= start || section.start >= end { retained.append(section); continue }
            if section.start < start { var before=section; before.end=start; retained.append(before) }
            if section.end > end { var after=section; after.start=end; retained.append(after) }
        }
        retained.append(.init(start:start,end:end,role:role,name:name,boundaryConfidence:0.65,labelConfidence:0.65))
        sections=retained.sorted { $0.start < $1.start }
        landmarks.removeAll { $0.frame > start && $0.frame < end && [.arrival,.mainReturn,.breakdown].contains($0.kind) && !$0.locked && $0.state == .suggested }
    }
}
