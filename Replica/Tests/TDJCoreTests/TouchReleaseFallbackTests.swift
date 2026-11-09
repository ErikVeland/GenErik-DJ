import TDJCore
import Testing

@Test(arguments: [false, true])
func shortClipReleaseClearsHoldAndKeepsSync(park: Bool) throws {
    let core = try SampleTransport()
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    let clip = try PCMAsset(interleavedStereo: Array(repeating: 0.4, count: 9600), sampleRate: 48000)
    let generation = try core.load(clip, deck: .a, grid: grid, synced: true)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 128)
    try core.perform(.touch, deck: .a, generation: generation, value: 128, touchRate: 0, followsPosition: true)
    _ = core.renderOffline(frames: 12000)
    try #require(core.snapshot()?.a.touchActive == true)
    _ = core.acknowledgements()
    let release: SourceControl = park ? .parkTouchRelease(deck: .a, generation: generation)
        : .performance(.touch, .a, generation, value: 0, end: 0, enabled: false, quantum: 0)
    try core.submit(release)
    core.processControlsWhileIdle()
    let released = try #require(core.snapshot())
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(!released.a.touchActive && released.a.synced)
    #expect(released.a.sourceFrame == 0)
    if park {
        #expect(released.a.phase == .paused)
    } else {
        #expect(released.a.phase == .queued)
        #expect(released.a.targetBeat == 1)
        let audio = core.renderOffline(frames: 24000 - Int(released.outputFrame) + 512)
        #expect(core.snapshot()?.a.phase == .playing)
        #expect(audio.left.suffix(256).allSatisfy { $0 > 0.01 })
    }
}
