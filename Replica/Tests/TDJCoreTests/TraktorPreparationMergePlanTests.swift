import Foundation
import Testing
@testable import TDJCore

private func importPlanTrack() throws -> Track {
    let analysis=AudioAnalysis(implementation:"Synthetic",configurationID:"synthetic",contentSHA256:String(repeating:"a",count:64),
        sampleRate:48000,frameCount:480000,channelCount:2,waveformFramesPerBin:512,waveform:[],bpm:120,beatAnchorFrame:0,
        tempoConfidence:0.5,key:nil,keyConfidence:0,chroma:[],timbre:[])
    return try Track(title:"Synthetic",mediaFilename:"synthetic.wav",analysis:analysis)
}
private func importPlanReference(_ track:Track,hash:String=String(repeating:"b",count:64),
                                 id:String?=nil,rate:Double?=nil,frames:Int64?=nil,cues:[Int:PerformanceCue]=[0:.init(frame:24000)]) throws -> NormalizedTraktorPreparation {
    .init(collectionSHA256:hash,entryIndex:0,contentSHA256:id ?? track.id,sampleRate:rate ?? track.analysis.sampleRate,
        frameCount:frames ?? track.analysis.frameCount,grid:try BeatGrid(bpm:128,anchorFrame:12000,sampleRate:48000),
        key:.init(tonic:3,mode:.minor),cues:cues)
}

@Test func traktorMergePlanProposesPreparedValuesWithoutChangingAnalysisOrTheSourceTrack() throws {
    let track=try importPlanTrack(),before=try JSONEncoder().encode(importPlanTrack())
    let plan=try TraktorPreparationMergePlan(reference:importPlanReference(track),track:track,existingCues:[:],history:.init(protectedEmptySlots:[]))
    #expect(plan.preparation.grid?.bpm == 128 && plan.preparation.gridIsManual)
    #expect(plan.preparation.correctedKey == MusicalKey(tonic:3,mode:.minor))
    #expect(plan.cues[0]?.frame == 24000 && plan.history.previouslyImportedSlots == [0])
    #expect(plan.matchesCurrent(track:track,cues:[:],history:.init(protectedEmptySlots:[])))
    let decoded=try JSONDecoder().decode(Track.self,from:before)
    #expect(track == decoded && track.analysis.bpm == 120)
}

@Test func traktorMergePlanProtectsManualPreparationOccupiedCuesAndKnownDeletions() throws {
    var track=try importPlanTrack()
    track.preparation=Preparation(grid:try BeatGrid(bpm:123,anchorFrame:100,sampleRate:48000),correctedKey:.init(tonic:7,mode:.major),gridIsManual:true)
    let existing:[Int:PerformanceCue]=[0:.init(frame:10)],history=TraktorPreparationImportHistory(previouslyImportedSlots:[2],protectedEmptySlots:[1])
    let reference=try importPlanReference(track,cues:[0:.init(frame:20),1:.init(frame:30),2:.init(frame:40),3:.init(frame:50)])
    let plan=try TraktorPreparationMergePlan(reference:reference,track:track,existingCues:existing,history:history)
    #expect(plan.preparation == track.preparation && plan.cues[0]?.frame == 10)
    #expect(plan.cues[1] == nil && plan.cues[2] == nil && plan.cues[3]?.frame == 50)
    #expect(plan.history.previouslyImportedSlots == [2,3] && plan.history.protectedEmptySlots == [1])
}

@Test func traktorMergePlanIsIdempotentAndRetainsDeletionHistoryAcrossRestartAndNewExports() throws {
    var track=try importPlanTrack()
    let reference=try importPlanReference(track)
    let first=try TraktorPreparationMergePlan(reference:reference,track:track,existingCues:[:],history:.init(protectedEmptySlots:[]))
    track.preparation=first.preparation
    let history=try JSONDecoder().decode(TraktorPreparationImportHistory.self,from:JSONEncoder().encode(first.history))
    let repeated=try TraktorPreparationMergePlan(reference:reference,track:track,existingCues:first.cues,history:history)
    #expect(repeated.preparation == first.preparation && repeated.cues == first.cues && repeated.history == history)
    let changedExport=try importPlanReference(track,hash:String(repeating:"c",count:64),cues:[0:.init(frame:40000)])
    let deleted=try TraktorPreparationMergePlan(reference:changedExport,track:track,existingCues:[:],history:history)
    #expect(deleted.cues.isEmpty && deleted.history.previouslyImportedSlots == [0])
}

@Test(arguments:["identity","rate","frames","sourceDigest"])
func traktorMergePlanRejectsUnboundOrChangedSources(_ mismatch:String) throws {
    let track=try importPlanTrack()
    let reference=try importPlanReference(track,hash:mismatch == "sourceDigest" ? "opaque" : String(repeating:"b",count:64),
        id:mismatch == "identity" ? String(repeating:"d",count:64):nil,rate:mismatch == "rate" ? 44100:nil,frames:mismatch == "frames" ? 479999:nil)
    #expect(throws:CoreError.self) { try TraktorPreparationMergePlan(reference:reference,track:track,existingCues:[:],history:.init(protectedEmptySlots:[])) }
}

@Test(arguments:["slot","negative","end","nan","infiniteEnd","backwardLoop","mismatchedType"])
func traktorMergePlanRejectsUnsupportedCuePositions(_ invalid:String) throws {
    let track=try importPlanTrack()
    let cue:PerformanceCue
    switch invalid {
    case "negative":cue = .init(frame:-1)
    case "end":cue = .init(frame:480000)
    case "nan":cue = .init(frame:.nan)
    case "infiniteEnd":cue = .init(frame:1,loopEnd:.infinity)
    case "backwardLoop":cue = .init(frame:20,loopEnd:10)
    case "mismatchedType":cue = .init(frame:1,loopEnd:10,kind:.cue)
    default:cue = .init(frame:1)
    }
    let reference=try importPlanReference(track,cues:[invalid == "slot" ? 8:0:cue])
    #expect(throws:CoreError.self) { try TraktorPreparationMergePlan(reference:reference,track:track,existingCues:[:],history:.init(protectedEmptySlots:[])) }
}

@Test func traktorMergePlanDetectsEditsBeforeCommitIncludingDeliberatelyEmptyCues() throws {
    var track=try importPlanTrack()
    let existing:[Int:PerformanceCue]=[1:.init(frame:100)]
    let plan=try TraktorPreparationMergePlan(reference:importPlanReference(track),track:track,existingCues:existing,history:.init(protectedEmptySlots:[]))
    #expect(plan.matchesCurrent(track:track,cues:existing,history:.init(protectedEmptySlots:[])))
    #expect(!plan.matchesCurrent(track:track,cues:[:],history:.init(protectedEmptySlots:[])))
    #expect(!plan.matchesCurrent(track:track,cues:existing,history:.init(protectedEmptySlots:[0])))
    track.preparation.gridIsManual=true
    #expect(!plan.matchesCurrent(track:track,cues:existing,history:.init(protectedEmptySlots:[])))
}
