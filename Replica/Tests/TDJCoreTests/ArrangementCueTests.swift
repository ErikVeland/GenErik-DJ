import XCTest

import TDJCore

final class ArrangementCueTests: XCTestCase {
    private func timeline(
        _ arrangement: TrackArrangement, frame: Double = 0, reliable: Bool = true,
        timing: BeatTiming? = nil, rate: Double = 1, loopEnd: Double? = nil,
        continuingFrame: Double? = nil, slip: Bool = false
    ) throws -> ArrangementCueTimeline {
        arrangement.cueTimeline(
            frame: frame, continuingFrame: continuingFrame, fileEnd: 40_000, sampleRate: 1000,
            timing: try timing ?? BeatTiming(fixed: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 1000)),
            reliableGrid: reliable, rate: rate, loopEnd: loopEnd, slip: slip)
    }
    private func arrangement(_ marks: [ArrangementLandmark] = []) -> TrackArrangement {
        .init(sections: [], landmarks: marks, musicalEnd: 38_000, rhythmicEnd: nil)
    }
    func testPickupKeepsItsExactPositionAndBeatDistance() throws {
        let value = try timeline(
            arrangement([
                .init(frame: 1200, name: "Pickup", kind: .vocal, state: .accepted)
            ]))
        XCTAssertEqual(value.next?.frame, 1200)
        XCTAssertEqual(value.next?.beatsAway, 2.4)
        XCTAssertNil(value.next?.remainingBeatMarks)
        XCTAssertEqual(value.next?.distance, "3 beats")
        XCTAssertFalse(try XCTUnwrap(value.next).estimated)
    }
    func testMissingGridUsesSecondsAndNeverShowsBeatMarks() throws {
        let value = try timeline(arrangement([.init(frame: 1200, name: "Voice", kind: .vocal)]), reliable: false)
        XCTAssertNil(value.next?.beatsAway)
        XCTAssertNil(value.next?.remainingBeatMarks)
        XCTAssertEqual(value.next?.distance, "≈2 s")
    }
    func testAdaptiveTimingCountsActualBeatsAndRateOnlyChangesSeconds() throws {
        let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 1000)
        let map = BeatGridMap(
            anchors: [.init(beat: 0, frame: 0), .init(beat: 16, frame: 8000), .init(beat: 32, frame: 24000)],
            sampleRate: 1000)
        let value = try timeline(
            arrangement([.init(frame: 24000, name: "Return", kind: .mainReturn)]), frame: 8000,
            timing: BeatTiming(fixed: fixed, adaptive: map), rate: 2)
        XCTAssertEqual(value.next?.beatsAway, 16)
        XCTAssertEqual(value.next?.secondsAway, 8)
        XCTAssertEqual(value.next?.distance, "≈4 bars")
    }
    func testLoopHoldsFutureCueWithoutHidingItsSavedPosition() throws {
        let value = try timeline(
            arrangement([.init(frame: 6000, name: "Return", kind: .mainReturn)]), frame: 1500, loopEnd: 4000)
        XCTAssertEqual(value.next?.frame, 6000)
        XCTAssertEqual(value.next?.distance, "After loop")
        XCTAssertNil(value.next?.remainingBeatMarks)
        XCTAssertTrue(value.ending.heldByLoop)
    }
    func testSlipUsesAudiblePositionForCuesAndContinuingPositionForEnding() throws {
        let value = try timeline(
            arrangement([.init(frame: 6000, name: "Return", kind: .mainReturn)]), frame: 1500, loopEnd: 4000,
            continuingFrame: 34000, slip: true)
        XCTAssertEqual(value.next?.frame, 6000)
        XCTAssertTrue(try XCTUnwrap(value.next).heldByLoop)
        XCTAssertFalse(value.ending.heldByLoop)
        XCTAssertEqual(value.ending.beatsAway, 8)
        XCTAssertTrue(value.slip)
    }
    func testActiveRibbonSurvivesWhenItsStartIsBehindThePlayhead() throws {
        let value = try timeline(
            arrangement([
                .init(frame: 1000, end: 7000, name: "Verse vocal", kind: .vocal, state: .accepted),
                .init(frame: 9000, name: "Return", kind: .mainReturn),
            ]), frame: 4000)
        XCTAssertEqual(value.region?.kind, .vocal)
        XCTAssertEqual(value.region?.frame, 1000)
        XCTAssertEqual(value.region?.end, 7000)
        XCTAssertEqual(value.next?.frame, 9000)
        XCTAssertNil(
            try timeline(arrangement([.init(frame: 1000, end: 7000, name: "Vocal", kind: .vocal)]), frame: 7000).region)
    }
    func testDismissedCuesAndDownbeatSuggestionsDoNotCompeteForAttention() throws {
        let value = try timeline(
            arrangement([
                .init(frame: 100, name: "Beat", kind: .downbeat),
                .init(frame: 200, name: "Wrong vocal", kind: .vocal, state: .dismissed),
                .init(frame: 3000, name: "Break", kind: .breakdown),
            ]))
        XCTAssertEqual(value.next?.kind, .breakdown)
        XCTAssertTrue(try XCTUnwrap(value.next).estimated)
    }
    func testReverseHidesApproachingCueAndPauseKeepsFiniteDistance() throws {
        let value = arrangement([.init(frame: 2000, name: "Vocal", kind: .vocal)])
        XCTAssertNil(try timeline(value, rate: -1).next)
        XCTAssertTrue(try timeline(value, rate: -1).reverse)
        XCTAssertEqual(try timeline(value, rate: 0).next?.secondsAway, 2)
    }
    func testDrumEndingTakesPriorityAtTheSameBoundaryAndTailStaysExplicit() throws {
        var value = TrackArrangement(
            sections: [.init(start: 10000, end: 20000, role: .outro)], landmarks: [],
            musicalEnd: 20000, rhythmicEnd: 10000)
        XCTAssertEqual(try timeline(value).next?.kind, .drumsEnd)
        XCTAssertTrue(try timeline(value).ending.estimated)
        value.endIsEstimated = false
        XCTAssertFalse(try timeline(value, frame: 12000).ending.estimated)
        XCTAssertTrue(try timeline(value, frame: 20000).tail)
        XCTAssertTrue(try timeline(value, frame: 40000).ended)
    }
    func testSectionRolesDoNotInventVocalOrMixWindows() throws {
        let value = TrackArrangement(
            sections: [.init(start: 0, end: 8000, role: .verse), .init(start: 8000, end: 16000, role: .instrumental)],
            landmarks: [], musicalEnd: 16000, rhythmicEnd: nil)
        let result = try timeline(value)
        XCTAssertNil(result.region)
        XCTAssertEqual(result.next?.kind, .section)
        XCTAssertNil(result.next?.end)
    }
    func testAcceptedSectionWinsOverAnEstimatedLandmarkAtTheSamePosition() throws {
        let value = TrackArrangement(
            sections: [.init(start: 8000, end: 16000, role: .chorus, name: "My chorus", locked: true)],
            landmarks: [.init(frame: 8000, name: "Possible drop", kind: .arrival)],
            musicalEnd: 16000, rhythmicEnd: nil)
        let result = try timeline(value)
        XCTAssertEqual(result.next?.label, "My chorus")
        XCTAssertEqual(result.next?.estimated, false)
    }
    func testBeatMarksCountDownOnlyToAnAlignedEntry() throws {
        let value = arrangement([.init(frame: 6000, name: "Vocal", kind: .vocal, state: .accepted)])
        XCTAssertEqual(try timeline(value, frame: 4000).next?.remainingBeatMarks, 4)
        XCTAssertEqual(try timeline(value, frame: 4500).next?.remainingBeatMarks, 3)
        XCTAssertEqual(try timeline(value, frame: 5500).next?.remainingBeatMarks, 1)
        XCTAssertNil(try timeline(value, frame: 6000).next?.remainingBeatMarks)
    }
    func testBeatAlignmentUsesTheAdaptiveMap() throws {
        let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 1000)
        let map = BeatGridMap(
            anchors: [.init(beat: 0, frame: 0), .init(beat: 16, frame: 8000), .init(beat: 32, frame: 24000)],
            sampleRate: 1000)
        let timing = BeatTiming(fixed: fixed, adaptive: map)
        let aligned = try timeline(
            arrangement([.init(frame: 22000, name: "Entry", kind: .vocal)]), frame: 20000, timing: timing)
        let pickup = try timeline(
            arrangement([.init(frame: 22500, name: "Pickup", kind: .vocal)]), frame: 20000, timing: timing)
        XCTAssertEqual(aligned.next?.remainingBeatMarks, 2)
        XCTAssertNil(pickup.next?.remainingBeatMarks)
        XCTAssertEqual(pickup.next?.frame, 22500)
    }
    func testBeatAlignmentAllowsOnlySampleRounding() throws {
        let rounded = try timeline(arrangement([.init(frame: 6000.75, name: "Entry", kind: .vocal)]), frame: 4500)
        let between = try timeline(arrangement([.init(frame: 6001.25, name: "Pickup", kind: .vocal)]), frame: 4500)
        XCTAssertNotNil(rounded.next?.remainingBeatMarks)
        XCTAssertNil(between.next?.remainingBeatMarks)
    }
}
