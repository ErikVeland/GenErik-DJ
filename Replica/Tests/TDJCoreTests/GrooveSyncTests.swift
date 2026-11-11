import Foundation
import Testing

@testable import TDJCore

@Suite struct GrooveSyncTests {
    private func rig() throws -> (SampleTransport, UInt64, UInt64) {
        let core = try SampleTransport(sampleRate: 8000)
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.1, count: 320_000), sampleRate: 8000)
        let map = BeatGridMap(
            anchors: (0...32).map { beat in
                let offset = [0.0, 0.28, 0.5, 0.78][beat % 4]
                return .init(beat: Double(beat), frame: (Double(beat / 4) + offset) * 16_160)
            }, sampleRate: 8000)
        try core.setMasterBPM(120)
        let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
        let a = try core.load(asset, deck: .a, grid: grid, adaptiveMap: map)
        let b = try core.load(asset, deck: .b, grid: grid)
        core.processControlsWhileIdle()
        return (core, a, b)
    }

    @Test func displayDistinguishesSoloGrooveFromAcquisitionAndBarAlignment() throws {
        let (core, a, b) = try rig()
        try core.submit(.play(.a, a))
        _ = core.renderOffline(frames: 8000)
        let solo = try #require(core.snapshot())
        #expect(solo.a.grooveSync == .solo && solo.a.synced)
        #expect(!solo.syncNeedsAlignment(.a))
        try core.submit(.play(.b, b))
        core.processControlsWhileIdle()
        let acquiring = try #require(core.snapshot())
        #expect(acquiring.a.sourceFrame == solo.a.sourceFrame)
        #expect(acquiring.a.grooveSync == .acquiring)
        #expect(acquiring.syncNeedsAlignment(.a))
        let remaining = Int(ceil((try #require(acquiring.b.targetBeat) - acquiring.masterBeat) * 4000))
        _ = core.renderOffline(frames: remaining + 1)
        let aligned = try #require(core.snapshot())
        #expect(aligned.a.grooveSync == .aligned)
        #expect(!aligned.syncNeedsAlignment(.a))
        _ = core.renderOffline(frames: 4000)
        let human = try #require(core.snapshot())
        #expect(abs(try #require(human.syncPhaseError(.a))) > 0.05)
        #expect(!human.syncNeedsAlignment(.a))
    }

    @Test func streamPreparationReservesAutomaticCorrectionAboveTheNominalRate() throws {
        let core = try SampleTransport(sampleRate: 8000)
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 320_000), sampleRate: 8000)
        _ = try core.load(
            asset, deck: .a, grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000),
            adaptiveMap: BeatGridMap(
                anchors: [.init(beat: 0, frame: 0), .init(beat: 8, frame: 32_000)], sampleRate: 8000))
        core.processControlsWhileIdle()
        let state = try #require(core.snapshot())
        let targets = SourceControl.tempo(120).preparationTargets(snapshot: state, deck: .a, frames: 160_000)
        #expect(!targets.isEmpty && targets.allSatisfy { $0.speed >= 1.06 })
    }

    @Test func incomingBarPreparationMatchesTheNativeStartWithAPickup() throws {
        let core = try SampleTransport(sampleRate: 8000)
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 320_000), sampleRate: 8000)
        let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
        let a = try core.load(asset, deck: .a, grid: grid)
        let map = BeatGridMap(
            anchors: [.init(beat: 0, frame: 0), .init(beat: 8, frame: 32_000)], sampleRate: 8000, downbeatOffset: 2)
        let b = try core.load(asset, deck: .b, grid: grid, adaptiveMap: map)
        try core.submit(.play(.a, a))
        _ = core.renderOffline(frames: 1000)
        let state = try #require(core.snapshot())
        #expect(state.b.sourceFrame == 0)
        let targets = SourceControl.play(.b, b).preparationTargets(snapshot: state, deck: .b, frames: asset.frames)
        #expect(targets.first?.position == 0)
        try core.submit(.play(.b, b))
        core.processControlsWhileIdle()
        #expect(core.snapshot()?.b.sourceFrame == targets.first?.position)
        #expect(core.snapshot()?.b.phase == .queued)
        #expect(core.snapshot()?.b.targetBeat == 2)
        _ = core.renderOffline(frames: 15_001)
        #expect(abs((core.snapshot()?.b.sourceFrame ?? 0) - 8001) < 2)
        #expect(core.snapshot()?.b.grooveSync == .aligned)
    }

    @Test func snapshotsWithoutGrooveStateRemainReadable() throws {
        let (core, _, _) = try rig()
        let old = try #require(core.snapshot()?.a)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        object.removeValue(forKey: "grooveSync")
        let reopened = try JSONDecoder().decode(
            DeckPlaybackSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(reopened.grooveSync == nil && reopened.grid == old.grid && reopened.generation == old.generation)
    }
}
