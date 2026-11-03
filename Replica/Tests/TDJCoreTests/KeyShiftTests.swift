import Testing
@testable import TDJCore

@Test func keyShiftMapsTheTransposeStretchRangeAndRejectsInvalidValues() {
    #expect(KeyShift.semitones(for:0) == -60)
    #expect(KeyShift.semitones(for:0.25) == -30)
    #expect(KeyShift.semitones(for:0.5) == 0)
    #expect(KeyShift.semitones(for:0.75) == 6)
    #expect(KeyShift.semitones(for:1) == 12)
    for semitones in [-12.0,-6,0,1,6,12] {
        let position=KeyShift.position(for:semitones)
        #expect(position.flatMap { KeyShift.semitones(for:$0) } == semitones)
    }
    #expect(KeyShift.semitones(for:-0.1) == nil)
    #expect(KeyShift.semitones(for:.nan) == nil)
    #expect(KeyShift.position(for:-60.1) == nil)
    #expect(KeyShift.position(for:12.1) == nil)
    #expect(KeyShift.position(for:.infinity) == nil)
}

@Test func keyShiftMatchesTheShortestSameModePathAndRejectsModeChanges() {
    let c=MusicalKey(tonic:0,mode:.major)
    #expect(KeyShift.matchOffset(from:c,to:MusicalKey(tonic:5,mode:.major)) == 5)
    #expect(KeyShift.matchOffset(from:c,to:MusicalKey(tonic:7,mode:.major)) == -5)
    #expect(KeyShift.matchOffset(from:c,to:MusicalKey(tonic:6,mode:.major)) == 6)
    #expect(KeyShift.matchOffset(from:c,to:c) == 0)
    #expect(KeyShift.matchOffset(from:c,to:MusicalKey(tonic:9,mode:.minor)) == nil)
}
