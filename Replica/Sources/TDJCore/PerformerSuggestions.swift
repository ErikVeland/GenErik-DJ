import Foundation

/// Performer instructions, 25 October 2026: key, ±8% tempo range, similar energy, previous pairing.
/// Ordered criteria are never combined into a weighted score.
public enum PerformerSuggestions {
    public static let tempoTolerance = 0.08
    private static let worker=AnalysisWorker()
    public static func rankAsync(library: LibrarySnapshot, context: SuggestionContext,
                                 referenceOverride: Track? = nil) async throws -> [Suggestion] {
        try await worker.run { check in try rank(library:library,context:context,referenceOverride:referenceOverride,checkCancellation:check) }
    }

    package static func rankAsync(librarySource: BackgroundOwnedValue<LibrarySnapshot>, context: SuggestionContext,
                                  referenceOverride: Track? = nil) async throws -> [Suggestion] {
        try await worker.run { check in
            let library = librarySource.withValue { $0 }
            return try rank(library: library, context: context, referenceOverride: referenceOverride, checkCancellation: check)
        }
    }

    /// Independent estimate, not a recovered NI energy model. Ten bands avoid false precision.
    /// Uses loudness, spectral brightness and onset activity already available from local analysis.
    public static func energyLevel(_ analysis: AudioAnalysis) -> Int? {
        if analysis.musicalAnalysisDeferred == true { return nil }
        if let energy = analysis.musicalEnergy { return (0...10).contains(energy.level) ? energy.level : nil }
        let bins=analysis.waveform
        if bins.isEmpty { return analysis.cachedEnergyLevel.flatMap { (0...10).contains($0) ? $0 : nil } }
        let power=bins.reduce(0.0) { $0+Double($1.rms)*Double($1.rms) }/Double(bins.count)
        guard power.isFinite, power>1e-12 else { return nil }
        let loudness=min(1,max(0,(10*log10(power)+48)/48))
        let brightness=analysis.timbre.count >= 6 ? min(1,max(0,analysis.timbre[4]+analysis.timbre[5])) : 0
        var onsets=0
        for index in 1..<bins.count where bins[index].rms > 0.0001 && bins[index].rms > bins[index-1].rms*1.5 { onsets += 1 }
        let activity=min(1,Double(onsets)/max(1,analysis.duration)/8)
        return min(10,max(0,Int((10*(0.6*loudness+0.2*brightness+0.2*activity)).rounded())))
    }

    /// Exact key, then relative major/minor or adjacent fifths, then other keys, then unavailable key.
    public static func keyTier(reference: MusicalKey?, candidate: MusicalKey?) -> Int {
        guard let reference else { return 0 }
        guard let candidate else { return 3 }
        if reference == candidate { return 0 }
        let distance=(candidate.tonic-reference.tonic+12)%12
        if reference.mode == candidate.mode && (distance == 5 || distance == 7) { return 1 }
        if reference.mode == .major && candidate.mode == .minor && distance == 9 { return 1 }
        if reference.mode == .minor && candidate.mode == .major && distance == 3 { return 1 }
        return 2
    }

    public static func rank(library: LibrarySnapshot, context: SuggestionContext,
                            referenceOverride: Track? = nil,
                            checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }) throws -> [Suggestion] {
        guard context.libraryRevision == library.revision,
              let storedReference=library.tracks.first(where: { $0.id == context.referenceTrackID }),
              referenceOverride.map({ $0.id == storedReference.id }) ?? true else { throw CoreError.staleContext }
        let reference=referenceOverride ?? storedReference.resolvingTraktorPreparation()
        let tempo=context.usePerformanceBPM ? context.performanceBPM : reference.bpm
        let energy=energyLevel(reference.analysis)
        var paired=Set<String>()
        for event in library.events where event.kind == .transition {
            if event.fromTrackID == reference.id, let other=event.toTrackID { paired.insert(other) }
            if event.toTrackID == reference.id, let other=event.fromTrackID { paired.insert(other) }
        }
        struct Candidate {
            let track: Track
            let order: Int
            let priorities: [Int]
            let tempoMatch: Bool?
            let keyMatch: Bool?
        }
        var candidates: [Candidate]=[]
        for (index,storedTrack) in library.tracks.enumerated() {
            try checkCancellation()
            let track=storedTrack.resolvingTraktorPreparation()
            guard track.id != reference.id, !context.loadedTrackIDs.contains(track.id) else { continue }
            let key=keyTier(reference:reference.key,candidate:track.key)
            var tempoTier=0
            var tempoMatch: Bool?
            if let tempo,tempo.isFinite,tempo>0 {
                if let bpm=track.bpm,bpm.isFinite,bpm>0 {
                    let distance=abs(bpm-tempo)/tempo
                    tempoMatch=distance <= tempoTolerance+1e-12
                    // All candidates in the requested range share the same tempo priority.
                    tempoTier=tempoMatch == true ? 0 : 1+Int(min(10000,floor((distance-tempoTolerance)*100)))
                } else { tempoTier=Int.max }
            }
            let energyTier: Int
            if let energy { energyTier=energyLevel(track.analysis).map { abs($0-energy) } ?? 11 }
            else { energyTier=0 }
            candidates.append(.init(track:track,order:index,priorities:[key,tempoTier,energyTier,paired.contains(track.id) ? 0 : 1],
                tempoMatch:tempoMatch,keyMatch:reference.key == nil || track.key == nil ? nil : key<=1))
        }
        candidates.sort {
            if $0.priorities != $1.priorities { return $0.priorities.lexicographicallyPrecedes($1.priorities) }
            return $0.order<$1.order
        }
        return candidates.enumerated().map { rank,candidate in
            .init(id:candidate.track.id,score:1/Double(rank+1),tempoCompatible:candidate.tempoMatch,keyCompatible:candidate.keyMatch)
        }
    }
}
