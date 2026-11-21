import TDJCore
import Testing

@testable import TDJInterface

@Test func libraryDeckBeatPulsesOnlyForThePlayingDeckAndItsOwnGrid() throws {
    let slow = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let fast = try BeatGrid(bpm: 160, anchorFrame: 0, sampleRate: 48_000)
    #expect(LibraryDeckBeat.pulse(phase: .playing, sourceFrame: 24_000, timing: BeatTiming(fixed: slow)) == 1)
    #expect(LibraryDeckBeat.pulse(phase: .playing, sourceFrame: 24_000, timing: BeatTiming(fixed: fast)) < 0.01)
    for phase: PlaybackPhase in [.empty, .ready, .queued, .paused, .ended] {
        #expect(LibraryDeckBeat.pulse(phase: phase, sourceFrame: 24_000, timing: BeatTiming(fixed: slow)) == 0)
    }
    #expect(LibraryDeckBeat.pulse(phase: .playing, sourceFrame: 24_000, timing: nil) == 0)
}

@Test func libraryDeckBeatUsesFlexGridFrameRatherThanFixedBPM() throws {
    let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let map = BeatGridMap(
        anchors: [.init(beat: 0, frame: 0), .init(beat: 1, frame: 30_000), .init(beat: 2, frame: 48_000)],
        sampleRate: 48_000)
    let flex = BeatTiming(fixed: fixed, adaptive: map)
    #expect(LibraryDeckBeat.pulse(phase: .playing, sourceFrame: 30_000, timing: flex) == 1)
    #expect(LibraryDeckBeat.pulse(phase: .playing, sourceFrame: 30_000, timing: BeatTiming(fixed: fixed)) < 0.10)
    #expect(LibraryDeckBeat.pulse(phase: .playing, sourceFrame: .nan, timing: flex) == 0)
}
