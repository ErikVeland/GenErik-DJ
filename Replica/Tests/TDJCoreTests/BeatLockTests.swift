import Foundation
import Testing

@testable import TDJCore

@Test(arguments: [DeckID.a, .b, .c, .d])
func beatLockAlignsOnlyTheFirstEntryAndKeepsTheSelectedFrame(deck: DeckID) throws {
    let core = try SampleTransport(sampleRate: 8000)
    core.setBeatLockEnabled(true)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.1, count: 256000), sampleRate: 8000)
    let referenceDeck: DeckID = deck == .a ? .b : .a
    let reference = try core.load(
        asset, deck: referenceDeck, grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000))
    let target = try core.load(
        asset, deck: deck, grid: BeatGrid(bpm: 100, anchorFrame: 0, sampleRate: 8000), sourceFrame: 1200)
    try core.play(deck: referenceDeck, generation: reference)
    _ = core.renderOffline(frames: 1700)
    let before = try #require(core.snapshot())
    try core.play(deck: deck, generation: target)
    core.processControlsWhileIdle()
    let queued = try #require(core.snapshot())
    #expect(queued[deck].phase == .queued)
    #expect(queued[deck].sourceFrame == 1200)
    #expect(queued[referenceDeck].sourceFrame == before[referenceDeck].sourceFrame)
    #expect(queued.masterBeat == before.masterBeat)
    try core.play(deck: deck, generation: target)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?[deck].phase == .paused)
    try core.play(deck: deck, generation: target)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?[deck].phase == .queued)
    _ = core.renderOffline(frames: 3304)
    let live = try #require(core.snapshot())
    #expect(live[deck].phase == .playing)
    #expect((5000...5001).contains(live[deck].lastStartOutputFrame))
    try core.play(deck: deck, generation: target)
    core.processControlsWhileIdle()
    let paused = try #require(core.snapshot())
    try core.play(deck: deck, generation: target)
    core.processControlsWhileIdle()
    let resumed = try #require(core.snapshot())
    #expect(resumed[deck].phase == .playing)
    #expect(resumed[deck].sourceFrame == paused[deck].sourceFrame)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test func beatLockOffStartsImmediatelyAndKeepsTempoMatch() throws {
    let core = try SampleTransport(sampleRate: 8000)
    core.setBeatLockEnabled(false)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.1, count: 256000), sampleRate: 8000)
    let a = try core.load(asset, deck: .a, grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000))
    let b = try core.load(asset, deck: .b, grid: BeatGrid(bpm: 100, anchorFrame: 200, sampleRate: 8000))
    try core.play(deck: .a, generation: a)
    _ = core.renderOffline(frames: 1933)
    try core.play(deck: .b, generation: b)
    core.processControlsWhileIdle()
    let state = try #require(core.snapshot())
    #expect(state.b.phase == .playing)
    #expect(state.b.synced)
    #expect(state.b.sourceFrame == 0)
    #expect(abs(state.b.speed - 1.2) < 0.0001)
}

@Test func beatLockPreferenceKeepsExplicitOffAndDefaultsOldFilesToOn() throws {
    let decoder = JSONDecoder()
    let old = try decoder.decode(MixerPreferences.self, from: Data(
        #"{"filterResonanceA":0,"filterResonanceB":0}"#.utf8))
    #expect((old.beatLock ?? true) == true)
    var changed = old
    changed.beatLock = false
    let saved = try decoder.decode(MixerPreferences.self, from: JSONEncoder().encode(changed))
    #expect(saved.beatLock == false)
}

@Test(arguments: [true, false])
func beatLockModesKeepAdaptiveSoloTimingWhenAnotherDeckStarts(enabled: Bool) throws {
    let core = try SampleTransport(sampleRate: 8000)
    core.setBeatLockEnabled(enabled)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.1, count: 256000), sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let map = BeatGridMap(
        anchors: [.init(beat: 0, frame: 0), .init(beat: 8, frame: 30800), .init(beat: 24, frame: 96500)],
        sampleRate: 8000)
    let a = try core.load(asset, deck: .a, grid: grid, adaptiveMap: map)
    let b = try core.load(asset, deck: .b, grid: grid)
    try core.play(deck: .a, generation: a)
    _ = core.renderOffline(frames: 3212)
    let solo = try #require(core.snapshot())
    #expect(solo.a.grooveSync == .solo)
    try core.play(deck: .b, generation: b)
    _ = core.renderOffline(frames: 36000)
    let paired = try #require(core.snapshot())
    #expect(paired.a.grooveSync == .solo)
    #expect(paired.b.phase == .playing)
    #expect(abs(paired.a.sourceFrame - solo.a.sourceFrame - 36000) < 0.001)
}
