import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@Test @MainActor func extraGridContactCannotCommitAnUnrelatedPhaseShift() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    let fixture=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).deletingLastPathComponent()
        .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    await model.importFiles([fixture])
    let track=try #require(model.library.tracks.first)
    model.load(trackID:track.id,deck:.a); await model.flushWrites()
    let grid=try #require(model.grid(.a))
    model.editing.insert(.a); model.viewport[.a]=96000
    let session=WaveformGestureSession()
    let first=SurfacePoint(id:1,x:0.25,y:0.5),moved=SurfacePoint(id:1,x:0.3,y:0.5)
    let second=SurfacePoint(id:2,x:0.75,y:0.5)
    session.handle(.init(phase:.began,points:[first],ending:[]),model:model,deck:.a,span:96000)
    session.handle(.init(phase:.moved,points:[moved],ending:[]),model:model,deck:.a,span:96000)
    #expect(model.gridDraft[.a] != nil)
    session.handle(.init(phase:.began,points:[moved,second],ending:[]),model:model,deck:.a,span:96000)
    session.handle(.init(phase:.moved,points:[moved,second],ending:[]),model:model,deck:.a,span:96000)
    session.handle(.init(phase:.ended,points:[moved,second],ending:[1,2]),model:model,deck:.a,span:96000)
    await model.flushWrites()
    #expect(model.gridDraft[.a] == nil)
    #expect(model.grid(.a) == grid)
    #expect(model.viewport[.a] == 96000)
    model.editing.remove(.a)
    model.pressPlay(deck:.a); await model.flushTransportRequests()
    _=model.playback.core.renderOffline(frames:100)
    model.refreshPlayback()
    let playing=try #require(model.playbackSnapshot?.a)
    model.previewing.insert(.a); model.viewport[.a]=150000
    model.returnToPlayhead(deck:.a)
    #expect(!model.previewing.contains(.a))
    #expect(model.viewport[.a] == playing.sourceFrame)
    #expect(model.playbackSnapshot?.a.sourceFrame == playing.sourceFrame)
    #expect(model.playbackSnapshot?.a.phase == playing.phase)
    model.frozen.insert(.a); model.viewport[.a]=0; model.performance.slicerQuantize=false
    let slices=WaveformGestureSession(),span=track.analysis.sampleRate*8
    let blank=SurfacePoint(id:2,x:0.05,y:0.5),valid=SurfacePoint(id:1,x:0.75,y:0.5)
    slices.handle(.init(phase:.began,points:[blank],ending:[]),model:model,deck:.a,span:span)
    slices.handle(.init(phase:.ended,points:[blank],ending:[2]),model:model,deck:.a,span:span)
    #expect(model.playbackSnapshot?.a.sourceFrame == playing.sourceFrame)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    slices.handle(.init(phase:.began,points:[valid],ending:[]),model:model,deck:.a,span:span)
    let heldFrame=model.playbackSnapshot?.a.sourceFrame
    #expect(model.playbackSnapshot?.a.touchActive == true)
    slices.handle(.init(phase:.began,points:[valid,blank],ending:[]),model:model,deck:.a,span:span)
    #expect(model.playbackSnapshot?.a.sourceFrame == heldFrame)
    slices.handle(.init(phase:.ended,points:[valid,blank],ending:[1]),model:model,deck:.a,span:span)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    slices.handle(.init(phase:.ended,points:[blank],ending:[2]),model:model,deck:.a,span:span)
    #expect(model.playbackSnapshot?.a.sourceFrame == heldFrame)
    await model.flushWaveforms()
    await model.finishForShutdown()
}

@Test @MainActor func gridPinchChangesOnlyScaleAndRetainsContactOwnership() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    let fixture=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).deletingLastPathComponent()
        .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    await model.importFiles([fixture])
    let track=try #require(model.library.tracks.first)
    model.load(trackID:track.id,deck:.a); await model.flushWrites()
    model.pressPlay(deck:.a); await model.flushTransportRequests()
    _=model.playback.core.renderOffline(frames:128); model.refreshPlayback()
    let original=try #require(model.playback.core.snapshot())
    let grid=try #require(model.grid(.a))
    model.editing.insert(.a); model.viewport[.a]=96000
    let session=WaveformGestureSession()
    var span=96000.0,zooms:[Double]=[]
    func point(_ id:Int,_ x:Double) -> SurfacePoint { .init(id:id,x:x,y:0.5) }
    func send(_ phase:SurfaceEvent.Phase,_ points:[SurfacePoint],_ ending:Set<Int>=[]) {
        session.handle(.init(phase:phase,points:points,ending:ending),model:model,deck:.a,span:span) {
            span=$0; zooms.append($0)
        }
    }
    send(.began,[point(1,0.25)])
    send(.moved,[point(1,0.3)])
    #expect(model.gridDraft[.a] != nil)
    send(.began,[point(1,0.3),point(2,0.75)])
    send(.moved,[point(2,0.75),point(1,0.3)])
    #expect(zooms.isEmpty && model.gridDraft[.a] == nil && model.viewport[.a] == 96000)
    send(.moved,[point(2,0.9),point(1,0.1)])
    #expect(abs(span-54000)<0.000001)
    send(.moved,[point(1,0.3875),point(2,0.6125)])
    // Re-rendered spans do not replace the original pinch baseline.
    #expect(abs(span-192000)<0.000001)
    let count=zooms.count
    send(.ended,[point(1,0.3875),point(2,0.6125)],[2])
    send(.moved,[point(1,0.9)])
    send(.ended,[point(1,0.9)],[1])
    #expect(zooms.count == count && model.gridDraft[.a] == nil)
    // A third contact ends zoom ownership until every contact has lifted.
    send(.began,[point(3,0.25),point(4,0.75)])
    send(.began,[point(3,0.25),point(4,0.75),point(5,0.5)])
    send(.ended,[point(3,0.25),point(4,0.75),point(5,0.5)],[5])
    send(.moved,[point(3,0.1),point(4,0.9)])
    send(.ended,[point(3,0.1),point(4,0.9)],[3,4])
    #expect(zooms.count == count)
    send(.began,[point(6,0.25),point(7,0.75)])
    send(.moved,[point(6,0.1),point(7,0.9)])
    let cancelledSpan=span
    send(.cancelled,[point(6,0.1),point(7,0.9)],[6,7])
    #expect(span == cancelledSpan && model.gridDraft[.a] == nil)
    send(.began,[point(8,0.25),point(9,0.75)])
    let beforeModeChange=zooms.count
    model.editing.remove(.a)
    send(.moved,[point(8,0.1),point(9,0.9)])
    send(.ended,[point(8,0.1),point(9,0.9)],[8,9])
    #expect(zooms.count == beforeModeChange)
    await model.flushWrites()
    #expect(model.grid(.a) == grid && model.gridDraft[.a] == nil)
    #expect(model.viewport[.a] == 96000)
    #expect(model.playback.core.snapshot() == original)
    await model.flushWaveforms(); await model.finishForShutdown()
}

@Test func gridZoomUsesTheExistingStripeScaleBounds() {
    #expect(WaveformZoom.seconds(frameSpan:1,sampleRate:48000,duration:240) == 1)
    #expect(WaveformZoom.seconds(frameSpan:48000*999,sampleRate:48000,duration:240) == 240)
    #expect(WaveformZoom.seconds(frameSpan:48000*8,sampleRate:48000,duration:240) == 8)
    #expect(WaveformZoom.seconds(frameSpan:1,sampleRate:48000,duration:0.5) == 0.5)
}
