import Testing

@testable import TDJCore

@Test(arguments: [DeckID.a, .b, .c, .d])
func syncToggleKeepsTheCurrentFrameAndRestoresStoppedSourceTempo(deck: DeckID) throws {
    let core = try SampleTransport(sampleRate: 8000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.1, count: 256000), sampleRate: 8000)
    let referenceDeck: DeckID = deck == .a ? .b : .a
    let reference = try core.load(
        asset, deck: referenceDeck, grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000))
    let target = try core.load(
        asset, deck: deck, grid: BeatGrid(bpm: 100, anchorFrame: 444, sampleRate: 8000), synced: false)
    try core.play(deck: referenceDeck, generation: reference)
    try core.play(deck: deck, generation: target)
    _ = core.renderOffline(frames: 1933)
    let before = try #require(core.snapshot())
    #expect(before[deck].phase == .playing)
    try core.setSync(true, deck: deck, generation: target)
    core.processControlsWhileIdle()
    let on = try #require(core.snapshot())
    #expect(on[deck].synced)
    #expect(on[deck].sourceFrame == before[deck].sourceFrame)
    #expect(on[referenceDeck].sourceFrame == before[referenceDeck].sourceFrame)
    #expect(on[referenceDeck].speed == before[referenceDeck].speed)
    #expect(abs(on[deck].speed - 1.2) < 0.0001)

    try core.setSync(false, deck: deck, generation: target)
    core.processControlsWhileIdle()
    let off = try #require(core.snapshot())
    #expect(!off[deck].synced)
    #expect(off[deck].sourceFrame == on[deck].sourceFrame)
    #expect(off[deck].speed == on[deck].speed)
    #expect(off[referenceDeck].sourceFrame == on[referenceDeck].sourceFrame)
    #expect(off[referenceDeck].speed == on[referenceDeck].speed)

    try core.setSync(true, deck: deck, generation: target)
    try core.play(deck: deck, generation: target)
    core.processControlsWhileIdle()
    let stopped = try #require(core.snapshot())
    #expect(stopped[deck].phase == .paused)
    let planned = try #require(
        SourceControl.sync(false, deck, target).preparationTargets(
            snapshot: stopped, deck: deck, frames: asset.frames).first)
    #expect(planned.position == stopped[deck].sourceFrame)
    #expect(planned.speed == 1)
    try core.setSync(false, deck: deck, generation: target)
    core.processControlsWhileIdle()
    let reset = try #require(core.snapshot())
    #expect(!reset[deck].synced)
    #expect(reset[deck].phase == .paused)
    #expect(reset[deck].sourceFrame == stopped[deck].sourceFrame)
    #expect(reset[deck].speed == 1)
    #expect(reset[referenceDeck].sourceFrame == stopped[referenceDeck].sourceFrame)
    #expect(reset[referenceDeck].speed == stopped[referenceDeck].speed)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}
