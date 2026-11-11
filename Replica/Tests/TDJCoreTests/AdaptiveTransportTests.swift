import CTDJTransport
import Testing

@testable import TDJCore

@Suite struct AdaptiveTransportTests {
    let map = BeatGridMap(
        anchors: [.init(beat: 0, frame: 0), .init(beat: 4, frame: 96_000), .init(beat: 8, frame: 211_200)],
        sampleRate: 48_000)
    @Test func nativeLookupAndValidation() throws {
        let native = map.native
        #expect(tdj_beatgrid_validate(native, 480_000))
        #expect(tdj_beatgrid_frame(native, 6) == 153_600)
        #expect(tdj_beatgrid_beat(native, 153_600) == 6)
        #expect(tdj_beatgrid_frame(native, -1) == -24_000)
        var bad = native
        bad.count = 257
        #expect(!tdj_beatgrid_validate(bad, 480_000))
    }
    @Test func publicationIsIsolatedProtectedAndGenerationBound() throws {
        let core = try SampleTransport()
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 960_000), sampleRate: 48_000)
        let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
        let a = try core.load(asset, deck: .a, grid: fixed, synced: false)
        _ = try core.load(asset, deck: .b, grid: fixed)
        core.processControlsWhileIdle()
        _ = core.acknowledgements()
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
        try core.play(deck: .a, generation: a)
        core.processControlsWhileIdle()
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
    @Test func soloSyncPreservesAdaptiveTimingAndFixedFallbackRemainsExact() throws {
        let core = try SampleTransport()
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 960_000), sampleRate: 48_000)
        let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
        let a = try core.load(asset, deck: .a, grid: fixed, adaptiveMap: map)
        try core.play(deck: .a, generation: a)
        _ = core.renderOffline(frames: 192_000)
        #expect(abs((core.snapshot()?.a.sourceFrame ?? 0) - 192_000) < 2)
        #expect(abs((core.snapshot()?.a.speed ?? 0) - 1) < 1e-9)
        #expect(core.snapshot()?.a.grooveSync == .solo)
        try core.play(deck: .a, generation: a)
        core.processControlsWhileIdle()
        let position = core.snapshot()?.a.sourceFrame
        try core.updateAdaptiveMap(nil, deck: .a, generation: a)
        core.processControlsWhileIdle()
        #expect(core.snapshot()?.a.sourceFrame == position)
        #expect(core.snapshot()?.a.adaptiveMap == nil)
        #expect(core.snapshot()?.a.grid == fixed)
    }
}

extension AdaptiveTransportTests {
    @Test(arguments: ["tempo", "keylock", "sync", "load"]) func keylockLimitsCoverEverySegment(action: String) throws {
        let core = try SampleTransport()
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 1_920_000), sampleRate: 48_000)
        let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
        let slow = BeatGridMap(
            anchors: [.init(beat: 0, frame: 0), .init(beat: 4, frame: 96_000), .init(beat: 8, frame: 672_000)],
            sampleRate: 48_000)
        if action != "tempo" {
            try core.setMasterBPM(240)
            core.processControlsWhileIdle()
            _ = core.acknowledgements()
        }
        let a = try core.load(
            asset, deck: .a, grid: fixed, synced: action != "sync", keylock: action != "keylock", adaptiveMap: slow)
        core.processControlsWhileIdle()
        if action == "load" {
            #expect(core.acknowledgements().contains { $0.error == .keylockRate })
            return
        }
        _ = core.acknowledgements()
        switch action {
        case "tempo": try core.setMasterBPM(240)
        case "sync": try core.setSync(true, deck: .a, generation: a)
        default: try core.setKeylock(true, deck: .a, generation: a)
        }
        core.processControlsWhileIdle()
        #expect(core.acknowledgements().contains { $0.error == .keylockRate })
    }
}

extension AdaptiveTransportTests {
    @Test func enablingSyncPreparesTheWholeMapFromAnUnsyncedSnapshot() throws {
        let core = try SampleTransport()
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 960_000), sampleRate: 48_000)
        let a = try core.load(
            asset, deck: .a, grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000), synced: false,
            adaptiveMap: map)
        core.processControlsWhileIdle()
        let state = try #require(core.snapshot())
        for control in [SourceControl.restoreSync(.a, a), .sync(true, .a, a)] {
            let targets = control.preparationTargets(snapshot: state, deck: .a, frames: asset.frames)
            #expect(targets.allSatisfy { $0.speed >= 1.2 })
            #expect(!targets.isEmpty)
        }
    }
}

extension AdaptiveTransportTests {
    @Test func adaptiveFluxReturnsToItsOwnContinuingTempoSegment() throws {
        let core = try SampleTransport()
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 960_000), sampleRate: 48_000)
        let a = try core.load(
            asset, deck: .a, grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000), adaptiveMap: map)
        try core.perform(.flux, deck: .a, generation: a)
        try core.perform(.loop, deck: .a, generation: a, value: 0, end: 96_000)
        try core.play(deck: .a, generation: a)
        _ = core.renderOffline(frames: 192_000)
        let looping = try #require(core.snapshot()?.a)
        #expect(looping.sourceFrame < 96_000)
        #expect(abs(looping.continuingFrame - 211_200) < 2)
        try core.perform(.loop, deck: .a, generation: a, enabled: false)
        core.processControlsWhileIdle()
        #expect(abs((core.snapshot()?.a.sourceFrame ?? 0) - 211_200) < 2)
        #expect(core.snapshot()?.a.adaptiveMap == map)
    }
    @Test func queuedDecksUseTheirOwnTempoMapAfterTheSharedBoundary() throws {
        let core = try SampleTransport()
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 960_000), sampleRate: 48_000)
        let fixed = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
        let other = BeatGridMap(
            anchors: [.init(beat: 0, frame: 0), .init(beat: 4, frame: 115_200), .init(beat: 8, frame: 211_200)],
            sampleRate: 48_000)
        let a = try core.load(asset, deck: .a, grid: fixed, adaptiveMap: map)
        let b = try core.load(asset, deck: .b, grid: fixed, adaptiveMap: other)
        try core.play(deck: .a, generation: a)
        _ = core.renderOffline(frames: 48_000)
        try core.play(deck: .b, generation: b)
        _ = core.renderOffline(frames: 48_000)
        #expect(core.snapshot()?.b.phase == .queued)
        #expect(core.snapshot()?.b.sourceFrame == 0)
        _ = core.renderOffline(frames: 1)
        let state = try #require(core.snapshot())
        #expect(state.b.phase == .playing)
        #expect(state.b.lastStartOutputFrame == 96_000)
        #expect(abs(state.a.sourceFrame - 96_001) < 2)
        #expect(abs(state.b.sourceFrame - 1) < 0.00001)
        #expect(state.b.grooveSync == .limited)
        #expect(state.a.adaptiveMap == map)
        #expect(state.b.adaptiveMap == other)
    }
}
