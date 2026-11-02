import Testing
import CTDJTransport
@testable import TDJCore

@Suite struct AdaptiveTransportTests {
    let map = BeatGridMap(anchors: [.init(beat: 0, frame: 0), .init(beat: 4, frame: 96_000), .init(beat: 8, frame: 211_200)], sampleRate: 48_000)
    @Test func nativeLookupAndValidation() throws {
        let native = map.native
        #expect(tdj_beatgrid_validate(native, 480_000))
        #expect(tdj_beatgrid_frame(native, 6) == 153_600)
        #expect(tdj_beatgrid_beat(native, 153_600) == 6)
        #expect(tdj_beatgrid_frame(native, -1) == -24_000)
        var bad = native; bad.count = 257
        #expect(!tdj_beatgrid_validate(bad, 480_000))
    }
    @Test func publicationIsIsolatedProtectedAndGenerationBound() throws {
        let core = try SampleTransport()
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 960_000), sampleRate: 48_000)
        let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
        let a = try core.load(asset, deck: .a, grid: fixed, synced: false)
        _ = try core.load(asset, deck: .b, grid: fixed)
        core.processControlsWhileIdle(); _ = core.acknowledgements()
        try core.updateAdaptiveMap(map, deck: .a, generation: a)
        core.processControlsWhileIdle()
        #expect(core.acknowledgements().allSatisfy { $0.error == nil })
        #expect(core.snapshot()?.a.adaptiveMap == map)
        #expect(core.snapshot()?.b.adaptiveMap == nil)
        try core.play(deck: .a, generation: a)
        _ = core.renderOffline(frames: 1000)
        #expect(core.snapshot()?.a.sourceFrame == 1000)
        try core.updateAdaptiveMap(nil, deck: .a, generation: a)
        core.processControlsWhileIdle()
        #expect(core.acknowledgements().contains { $0.error == .protectedDeck })
        #expect(core.snapshot()?.a.adaptiveMap == map)
        try core.play(deck: .a, generation: a); core.processControlsWhileIdle()
        let next = try core.load(asset, deck: .a, grid: fixed)
        core.processControlsWhileIdle()
        try core.updateAdaptiveMap(map, deck: .a, generation: a)
        core.processControlsWhileIdle()
        #expect(core.acknowledgements().contains { $0.error == .stale })
        #expect(core.snapshot()?.a.generation == next)
        #expect(core.snapshot()?.a.adaptiveMap == nil)
    }
}

extension AdaptiveTransportTests {
    @Test func syncFollowsLocalTempoAndFixedFallbackRemainsExact() throws {
        let core = try SampleTransport()
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 960_000), sampleRate: 48_000)
        let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
        let a = try core.load(asset, deck: .a, grid: fixed, adaptiveMap: map)
        try core.play(deck: .a, generation: a)
        _ = core.renderOffline(frames: 192_000)
        #expect(abs((core.snapshot()?.a.sourceFrame ?? 0) - 211_200) < 2)
        #expect(abs((core.snapshot()?.a.speed ?? 0) - 1.2) < 1e-9)
        try core.play(deck: .a, generation: a); core.processControlsWhileIdle()
        let position = core.snapshot()?.a.sourceFrame
        try core.updateAdaptiveMap(nil, deck: .a, generation: a)
        core.processControlsWhileIdle()
        #expect(core.snapshot()?.a.sourceFrame == position)
        #expect(core.snapshot()?.a.adaptiveMap == nil)
        #expect(core.snapshot()?.a.grid == fixed)
    }
}
