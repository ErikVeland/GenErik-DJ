import Foundation

/// Source-frame timings and word fingerprints. Lyric text is not retained.
public struct VocalPhrase: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var words: [UInt64]
    public var confidence: Double
    public init(start: Double, end: Double, words: [UInt64], confidence: Double) {
        self.start=start; self.end=end; self.words=words; self.confidence=confidence
    }
    public init(start: Double, end: Double, text: String, confidence: Double) {
        let normal=text.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))
            .replacingOccurrences(of:"’",with:"'")
        let words=normal.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map { word in
            word.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        }
        self.init(start:start,end:end,words:words,confidence:confidence)
    }
}

extension TrackArrangement {
    mutating func prepareVocalForm(phrases input: [VocalPhrase], features: [MusicalStructureFrame],
                                  analysis: AudioAnalysis, context: MusicalStructureContext) {
        let rate=analysis.sampleRate, fileEnd=Double(analysis.frameCount)
        guard rate > 0, !input.isEmpty, input.count <= 4096 else { return }
        func voice(_ start: Double, _ end: Double, _ value: (MusicalStructureFrame) -> Double) -> Double {
            let frames=features.filter { $0.start < end && $0.end > start }
            let weights=frames.map { max(0,min(end,$0.end)-max(start,$0.start)) }
            return zip(frames,weights).reduce(0) { $0+value($1.0)*$1.1 }/max(1,weights.reduce(0,+))
        }
        let phrases=input.filter { p in
            p.start.isFinite && p.end.isFinite && p.start >= 0 && p.end <= fileEnd && p.end > p.start &&
            p.end-p.start <= 18*rate && p.confidence.isFinite && p.confidence >= 0.45 &&
            !p.words.isEmpty && p.words.count <= 160 && voice(p.start,p.end,{ $0.vocal ?? 0 }) >= 0.3
        }.sorted { $0.start < $1.start }
        guard phrases.count >= 2 else { return }
        struct Word { let value: UInt64; let phrase: Int; let offset: Int }
        var words=[Word]()
        for (index,phrase) in phrases.enumerated() {
            words += phrase.words.enumerated().map { Word(value:$0.element,phrase:index,offset:$0.offset) }
        }
        var grams=[[UInt64]:[Int]]()
        if words.count >= 5 {
            for i in 0...(words.count-5) {
                let slice=words[i..<(i+5)], first=words[i].phrase, last=words[i+4].phrase
                guard phrases[last].end-phrases[first].start <= 9*rate,
                      (first == last || (first..<last).allSatisfy({ phrases[$0+1].start-phrases[$0].end <= 2*rate })) else { continue }
                let key=slice.map(\.value)
                if Set(key).count >= 4 { grams[key,default:[]].append(i) }
            }
        }
        var matched=[Set<Int>](repeating:[],count:phrases.count)
        for occurrences in grams.values where occurrences.count > 1 {
            for i in occurrences where occurrences.contains(where: { abs(phrases[words[$0].phrase].start-phrases[words[i].phrase].start) >= 12*rate }) {
                for word in words[i..<(i+5)] { matched[word.phrase].insert(word.offset) }
            }
        }
        var repeated=phrases.indices.map { matched[$0].count >= 4 && Double(matched[$0].count)/Double(phrases[$0].words.count) >= 0.5 }
        // Small recognition differences must not turn the same line into a new verse.
        for i in phrases.indices where phrases[i].words.count >= 6 {
            let a=phrases[i].words, unique=Set(a)
            guard unique.count >= 4 else { continue }
            for j in phrases.indices where j > i && phrases[j].start-phrases[i].start >= 12*rate {
                let b=phrases[j].words
                guard b.count >= 6, Double(min(a.count,b.count))/Double(max(a.count,b.count)) >= 0.7,
                      Double(unique.intersection(b).count)/Double(max(unique.count,Set(b).count)) >= 0.7 else { continue }
                var row=[Int](repeating:0,count:b.count+1)
                for x in a {
                    var previous=0
                    for k in b.indices {
                        let saved=row[k+1]
                        row[k+1] = x == b[k] ? previous+1 : max(row[k],row[k+1])
                        previous=saved
                    }
                }
                if Double(row.last!)/Double(max(a.count,b.count)) >= 0.72 { repeated[i]=true; repeated[j]=true }
            }
        }
        struct Span { var start: Double; var end: Double; var indices: [Int] }
        var refrains=[Span]()
        for i in phrases.indices where repeated[i] {
            let p=phrases[i]
            if let last=refrains.last, p.start-last.end <= 8*rate,
               !phrases.indices.contains(where: { !repeated[$0] && phrases[$0].words.count >= 5 &&
                   phrases[$0].start >= last.end && phrases[$0].end <= p.start }) {
                refrains[refrains.count-1].end=max(last.end,p.end)
                refrains[refrains.count-1].indices.append(i)
            } else { refrains.append(.init(start:p.start,end:p.end,indices:[i])) }
        }
        refrains=refrains.filter { span in
            span.end-span.start >= 3*rate && span.indices.reduce(0) { $0+phrases[$1].words.count } >= 6
        }
        guard refrains.count >= 2 else { return }
        let oldVocalSpans=sections.filter { [.verse,.preChorus,.chorus,.bridge].contains($0.role) }
        for i in sections.indices where [.verse,.preChorus,.chorus,.bridge].contains(sections[i].role) {
            sections[i].role = .unknown
            sections[i].name="Vocal section"
            sections[i].labelConfidence=0.5
        }
        landmarks.removeAll { mark in
            [.arrival,.mainReturn].contains(mark.kind) && !mark.locked && mark.state == .suggested &&
            oldVocalSpans.contains { mark.frame >= $0.start && mark.frame < $0.end && $0.behaviour != .dropping }
        }
        for i in refrains.indices {
            for p in phrases where p.start >= refrains[i].end && p.start-refrains[i].end <= rate &&
                p.end-p.start <= 2.5*rate && p.words.count <= 3 {
                refrains[i].end=p.end
            }
        }
        let vocalStart=phrases.first!.start, vocalEnd=phrases.last!.end
        let rap=voice(vocalStart,vocalEnd,{ $0.rapping ?? 0 }), singing=voice(vocalStart,vocalEnd,{ $0.singing ?? 0 })
        let rapGenre=(context.genre ?? "").range(of:#"\b(?:hip.?hop|rap|grime)\b"#,options:[.regularExpression,.caseInsensitive]) != nil
        let spoken=rap > 0.12 && rap > singing*0.6 || rapGenre && singing < 0.5
        let refrainWords=refrains.map { $0.indices.flatMap { phrases[$0].words } }
        let vocabularies=refrainWords.map { Set($0) }
        let wordGrams=refrainWords.map { words -> Set<[UInt64]> in
            guard words.count >= 5 else { return [] }
            return Set((0...(words.count-5)).map { Array(words[$0..<($0+5)]) })
        }
        for (index,span) in refrains.enumerated() {
            let peers=refrains.indices.filter { other in
                if other == index { return true }
                let common=vocabularies[index].intersection(vocabularies[other]).count
                let union=vocabularies[index].union(vocabularies[other]).count
                return common >= 5 && Double(common)/Double(max(1,union)) >= 0.45 &&
                    !wordGrams[index].isDisjoint(with:wordGrams[other])
            }
            let duration=peers.reduce(0.0) { $0+refrains[$1].end-refrains[$1].start }
            let localRap=peers.reduce(0.0) { sum, peer in
                let p=refrains[peer]
                return sum+voice(p.start,p.end,{ $0.rapping ?? 0 })*(p.end-p.start)
            }/max(1,duration)
            let localSinging=peers.reduce(0.0) { sum, peer in
                let p=refrains[peer]
                return sum+voice(p.start,p.end,{ $0.singing ?? 0 })*(p.end-p.start)
            }/max(1,duration)
            let vocabulary=peers.map { vocabularies[$0].count }.max() ?? 0
            let localSpoken=localRap > 0.12 && localRap > localSinging*0.6 || rapGenre && localSinging < 0.5
            let chorus = !localSpoken && localSinging >= 0.3 && span.end-span.start >= 8*rate && vocabulary >= 12
            let role: ArrangementRole = chorus ? .chorus:.hook
            let opening=span.start < 3*rate && span.end-span.start < 8*rate
            replaceVocalSpan(start:span.start,end:span.end,role:role,name:opening ? "Opening hook":"",confidence:0.8)
        }
        var unique=[Span]()
        for i in phrases.indices where !refrains.contains(where: { phrases[i].start < $0.end && phrases[i].end > $0.start }) {
            let p=phrases[i]
            if let last=unique.last, p.start-last.end <= 6*rate,
               !refrains.contains(where: { $0.start >= last.end && $0.end <= p.start }) {
                unique[unique.count-1].end=p.end
                unique[unique.count-1].indices.append(i)
            } else { unique.append(.init(start:p.start,end:p.end,indices:[i])) }
        }
        unique=unique.filter { span in
            let tokens=span.indices.flatMap { phrases[$0].words }
            return span.end-span.start >= 10*rate && tokens.count >= 24 && Set(tokens).count >= 12
        }
        func signature(_ span: Span) -> [Double] {
            (0..<12).map { bin in voice(span.start,span.end,{ $0.chroma.count == 12 ? $0.chroma[bin]:0 }) }
        }
        let signatures=unique.map(signature)
        for (index,span) in unique.enumerated() {
            let similar=unique.indices.contains { other in
                other != index && zip(signatures[index],signatures[other]).reduce(0) { $0+abs($1.0-$1.1) } < 0.35
            }
            if spoken || similar {
                var start=span.start
                if let previous=refrains.last(where: { $0.end <= start }), start-previous.end <= 45*rate,
                   voice(previous.end,start,{ $0.vocal ?? 0 }) >= 0.55,
                   voice(previous.end,start,{ ($0.vocal ?? 0) >= 0.45 ? 1:0 }) >= 0.8 {
                    start=previous.end
                }
                replaceVocalSpan(start:start,end:span.end,role:.verse,name:"",confidence:0.7)
            }
        }
        if let last=refrains.last, last.end >= fileEnd*0.8, fileEnd-last.end <= 45*rate,
           fileEnd-last.end >= 4*rate, !unique.contains(where: { $0.start >= last.end }),
           !sections.contains(where: { $0.start >= last.end && $0.role == .outro }) {
            replaceVocalSpan(start:last.end,end:fileEnd,role:.outro,name:"",confidence:0.65)
        }
        for (i,span) in refrains.enumerated() {
            let role=section(at:span.start)?.role ?? .hook
            landmarks.append(.init(frame:span.start,name: i == 0 ? (role == .chorus ? "Chorus start":"Hook start") : (role == .chorus ? "Chorus return":"Hook return"),
                kind:i == 0 ? .arrival:.mainReturn,reason:"Repeated vocal words with local voice evidence. Boundaries follow the recognised phrases.",confidence:0.7))
        }
        var merged=[ArrangementSection]()
        for section in sections {
            if let previous=merged.last, abs(previous.end-section.start) < 1,
               previous.role == section.role, previous.name == section.name, previous.behaviour == section.behaviour {
                merged[merged.count-1].end=section.end
            } else { merged.append(section) }
        }
        sections=merged
        landmarks.sort { $0.frame < $1.frame }
    }

    private mutating func replaceVocalSpan(start: Double, end: Double, role: ArrangementRole, name: String, confidence: Double) {
        var retained=[ArrangementSection]()
        for section in sections {
            if section.end <= start || section.start >= end { retained.append(section); continue }
            if section.start < start { var before=section; before.end=start; retained.append(before) }
            if section.end > end { var after=section; after.start=end; retained.append(after) }
        }
        retained.append(.init(start:start,end:end,role:role,name:name,boundaryConfidence:0.7,labelConfidence:confidence))
        sections=retained.sorted { $0.start < $1.start }
        landmarks.removeAll { $0.frame >= start && $0.frame < end && [.arrival,.mainReturn,.breakdown].contains($0.kind) && !$0.locked && $0.state == .suggested }
    }
}
