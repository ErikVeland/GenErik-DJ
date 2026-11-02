import Foundation

/// The caller must establish identity and field mappings before it constructs this value.
public struct NormalizedTraktorPreparation: Codable, Equatable, Sendable {
    public let collectionSHA256:String
    public let entryIndex:Int
    public let contentSHA256:String
    public let sampleRate:Double
    public let frameCount:Int64
    public let grid:BeatGrid?
    public let key:MusicalKey?
    public let cues:[Int:PerformanceCue]
    public init(collectionSHA256:String,entryIndex:Int,contentSHA256:String,sampleRate:Double,frameCount:Int64,
                grid:BeatGrid?,key:MusicalKey?,cues:[Int:PerformanceCue]) {
        self.collectionSHA256=collectionSHA256;self.entryIndex=entryIndex;self.contentSHA256=contentSHA256
        self.sampleRate=sampleRate;self.frameCount=frameCount;self.grid=grid;self.key=key;self.cues=cues
    }
}

/// Retain this history even if all imported cues are later deleted.
public struct TraktorPreparationImportHistory: Codable, Equatable, Sendable {
    public var previouslyImportedSlots:Set<Int>
    public var protectedEmptySlots:Set<Int>
    public init(previouslyImportedSlots:Set<Int> = [],protectedEmptySlots:Set<Int>) {
        self.previouslyImportedSlots=previouslyImportedSlots;self.protectedEmptySlots=protectedEmptySlots
    }
}

public struct TraktorPreparationMergePlan: Sendable {
    public let reference:NormalizedTraktorPreparation
    public let preparation:Preparation
    public let cues:[Int:PerformanceCue]
    public let history:TraktorPreparationImportHistory
    private let expectedPreparation:Preparation
    private let expectedCues:[Int:PerformanceCue]
    private let expectedHistory:TraktorPreparationImportHistory

    /// Build a proposal only. Persistence needs a journal and a final check against current edits.
    public init(reference:NormalizedTraktorPreparation,track:Track,existingCues:[Int:PerformanceCue],
                history:TraktorPreparationImportHistory) throws {
        func digest(_ value:String) -> Bool { value.count==64 && value.allSatisfy(\.isHexDigit) }
        let count=Double(reference.frameCount)
        guard digest(reference.collectionSHA256),digest(reference.contentSHA256),reference.entryIndex>=0,
              reference.contentSHA256==track.id,reference.sampleRate==track.analysis.sampleRate,
              reference.frameCount==track.analysis.frameCount,reference.sampleRate.isFinite,reference.sampleRate>0,
              reference.frameCount>0,
              history.previouslyImportedSlots.allSatisfy({ (0..<8).contains($0) }),
              history.protectedEmptySlots.allSatisfy({ (0..<8).contains($0) }),
              reference.grid.map({ $0.sampleRate==reference.sampleRate && $0.anchorFrame>=0 && $0.anchorFrame<count }) ?? true,
              reference.cues.allSatisfy({ slot,cue in
                  (0..<8).contains(slot) && cue.frame.isFinite && cue.frame>=0 && cue.frame<count &&
                  (cue.loopEnd.map { $0.isFinite && $0>cue.frame && $0<=count } ?? true) &&
                  (cue.category == .loop ? cue.loopEnd != nil : cue.loopEnd == nil)
              }) else { throw CoreError.invalidWorkspace("The preparation reference does not match this track or contains unsupported positions.") }
        self.reference=reference;expectedPreparation=track.preparation;expectedCues=existingCues;expectedHistory=history
        var preparation=track.preparation
        if !preparation.gridIsManual,let grid=reference.grid {
            preparation.grid=grid
            // Protect imported preparation from later automatic reanalysis.
            preparation.gridIsManual=true
        }
        preparation.importKey(reference.key, authority: .traktor)
        var cues=existingCues,updatedHistory=history
        for (slot,cue) in reference.cues {
            guard cues[slot] == nil,!history.protectedEmptySlots.contains(slot),
                  !history.previouslyImportedSlots.contains(slot) else { continue }
            cues[slot]=cue;updatedHistory.previouslyImportedSlots.insert(slot)
        }
        self.preparation=preparation;self.cues=cues;self.history=updatedHistory
    }

    /// Check inside the storage transaction. A false result requires a new proposal.
    public func matchesCurrent(track:Track,cues:[Int:PerformanceCue],history:TraktorPreparationImportHistory) -> Bool {
        reference.contentSHA256==track.id && reference.sampleRate==track.analysis.sampleRate &&
        reference.frameCount==track.analysis.frameCount && track.preparation==expectedPreparation && cues==expectedCues && history==expectedHistory
    }
}
