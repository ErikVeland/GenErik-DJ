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
    let live = try #require(core.snapshot())
    #expect(live[deck].phase == .playing)
    #expect(live[deck].lastStartOutputFrame == 1700)
    #expect(abs(live[deck].sourceFrame - 2040) < 0.001)
    #expect(live[referenceDeck].sourceFrame == before[referenceDeck].sourceFrame)
    #expect(live.masterBeat == before.masterBeat)
    _ = core.renderOffline(frames: 3304)
    try core.play(deck: deck, generation: target)
    core.processControlsWhileIdle()
    let paused = try #require(core.snapshot())
    _ = core.renderOffline(frames: 777)
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
func flexGridPairsWithThePlayingDeckAndRelaxesWhenAlone(beatLock: Bool) throws {
    let core = try SampleTransport(sampleRate: 8000)
    core.setBeatLockEnabled(beatLock)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.1, count: 256000), sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let map = BeatGridMap(
        anchors: [
            .init(beat: 0, frame: 0), .init(beat: 2, frame: 7900),
            .init(beat: 4, frame: 16100), .init(beat: 8, frame: 31700),
            .init(beat: 24, frame: 95800)
        ],
        sampleRate: 8000)
    let flex = try core.load(asset, deck: .c, grid: grid, adaptiveMap: map)
    let fixed = try core.load(asset, deck: .b, grid: grid)
    try core.play(deck: .c, generation: flex)
    _ = core.renderOffline(frames: 1933)
    let solo = try #require(core.snapshot())
    #expect(solo[.c].grooveSync == .solo)
    try core.play(deck: .b, generation: fixed)
    core.processControlsWhileIdle()
    #expect(core.snapshot()?[.b].phase == .playing)
    _ = core.renderOffline(frames: 20000)
    let paired = try #require(core.snapshot())
    #expect(paired[.b].phase == .playing)
    #expect(paired[.c].grooveSync != .solo)
    #expect(paired[.c].adaptiveMap == map)
    #expect(paired[.c].sourceFrame > solo[.c].sourceFrame)
    #expect(abs(paired[.c].speed - 1) <= 0.061)
    try core.play(deck: .b, generation: fixed)
    core.processControlsWhileIdle()
    let paused = try #require(core.snapshot())
    #expect(paused[.c].sourceFrame == paired[.c].sourceFrame)
    _ = core.renderOffline(frames: 8000)
    let relaxed = try #require(core.snapshot())
    #expect(relaxed[.c].grooveSync == .solo)
    #expect(abs(relaxed[.c].speed - 1) < 0.001)
    #expect(relaxed[.c].adaptiveMap == map)
    try core.play(deck: .b, generation: fixed)
    _ = core.renderOffline(frames: 8000)
    #expect(core.snapshot()?[.c].grooveSync != .solo)
}

@Test func flexGridUsesBoundsBesideAnIndependentDeckWithoutChangingItsTempo() throws {
    let core = try SampleTransport(sampleRate: 8000)
    core.setBeatLockEnabled(false)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.1, count: 256000), sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let map = BeatGridMap(
        anchors: [.init(beat: 0, frame: 0), .init(beat: 8, frame: 31600), .init(beat: 24, frame: 96400)],
        sampleRate: 8000)
    let flex = try core.load(asset, deck: .d, grid: grid, adaptiveMap: map)
    let independent = try core.load(
        asset, deck: .a, grid: BeatGrid(bpm: 90, anchorFrame: 0, sampleRate: 8000), synced: false)
    try core.play(deck: .d, generation: flex)
    _ = core.renderOffline(frames: 1900)
    try core.play(deck: .a, generation: independent)
    _ = core.renderOffline(frames: 12000)
    let mixed = try #require(core.snapshot())
    #expect(mixed.masterBPM == 120)
    #expect(mixed.a.speed == 1)
    #expect(mixed.a.sourceFrame == 12000)
    #expect(mixed[.d].grooveSync != .solo)
    #expect(abs(mixed[.d].speed - 1) <= 0.061)
    try core.setSync(false, deck: .d, generation: flex)
    _ = core.renderOffline(frames: 300)
    let independentFlex = try #require(core.snapshot())
    #expect(!independentFlex[.d].synced)
    #expect(independentFlex[.d].speed == mixed[.d].speed)
}
