import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@Test @MainActor func gestureFilterReleaseLockCancellationAndRestart() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    model.filterTouch(x:0.75,y:0.2,deck:.a)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == true)
    model.releaseFilter(deck:.a)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == false)
    model.filterLocked.insert(.a)
    model.filterTouch(x:0.2,y:0.3,deck:.a); model.releaseFilter(deck:.a)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == true)
    model.releaseFilter(deck:.a,cancelled:true)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == false)
    await model.flushPreferenceWrites()
    let restarted=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    #expect(abs((restarted.playbackSnapshot?.a.mixer.filterY ?? 0)-0.7)<0.000001)
    #expect(restarted.playbackSnapshot?.b.mixer.filterY == 0)
}

@Test @MainActor func gestureTwoFingerLoopCancellationAndFreezeRelease() async throws {
    var base=URL(fileURLWithPath:#filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track=try #require(model.library.tracks.first)
    model.load(trackID:track.id,deck:.a); await model.flushWrites()
    model.viewport[.a]=96000
    let session=WaveformGestureSession()
    let p=SurfacePoint(id:1,x:0.25,y:0.5),q=SurfacePoint(id:2,x:0.75,y:0.5)
    session.handle(.init(phase:.began,points:[p],ending:[]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    session.handle(.init(phase:.began,points:[p,q],ending:[]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.loopEnabled == true)
    session.handle(.init(phase:.cancelled,points:[p,q],ending:[1,2]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.loopEnabled == false)
    model.frozen.insert(.a); model.performance.slicerQuantize=false
    session.handle(.init(phase:.began,points:[p],ending:[]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    session.handle(.init(phase:.began,points:[p,q],ending:[]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    session.handle(.init(phase:.ended,points:[p,q],ending:[2]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    session.handle(.init(phase:.ended,points:[p],ending:[1]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.phase == .paused)
    session.handle(.init(phase:.began,points:[p],ending:[]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.touchActive == true)
    model.toggleFreeze(deck:.a)
    let afterModeChange=model.playbackSnapshot?.a.sourceFrame
    session.handle(.init(phase:.moved,points:[.init(id:1,x:0.5,y:0.5)],ending:[]),model:model,deck:.a,span:96000)
    session.handle(.init(phase:.ended,points:[p],ending:[1]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.sourceFrame == afterModeChange)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    #expect(model.playbackSnapshot?.a.phase == .paused)
    model.frozen.remove(.a); model.viewport[.a]=96000
    session.handle(.init(phase:.began,points:[p],ending:[]),model:model,deck:.a,span:96000)
    let moved=SurfacePoint(id:1,x:0.5,y:0.5)
    session.handle(.init(phase:.moved,points:[moved],ending:[]),model:model,deck:.a,span:96000)
    session.handle(.init(phase:.ended,points:[moved],ending:[1]),model:model,deck:.a,span:96000)
    #expect(model.playbackSnapshot?.a.sourceFrame == 72000)
    #expect(model.playbackSnapshot?.a.phase == .paused)
    #expect(model.playbackSnapshot?.a.touchActive == false)
    let emptySlot=try #require((0..<8).first { model.performance.cues[track.id]?[$0] == nil })
    model.cue(slot:emptySlot,deck:.a)
    #expect(model.performance.cues[track.id]?[emptySlot] != nil)
    await model.flushPerformanceWrites()
    let restarted=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    #expect(restarted.performance.cues[track.id]?[emptySlot] == model.performance.cues[track.id]?[emptySlot])
    model.setLoop(start:72000,end:120000,deck:.a)
    model.jump(96000,deck:.a,quantized:false)
    model.performance.cues[track.id,default:[:]][1] = .init(frame:72000,loopEnd:120000)
    model.cue(slot:1,deck:.a)
    #expect(model.playbackSnapshot?.a.sourceFrame == 72000)
    #expect(model.playbackSnapshot?.a.phase == .playing)
}

@Test @MainActor func gesturePersistenceCoalescesOffMainActorAndKeepsNewestSnapshot() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    for index in 0..<500 {
        model.performance.cues["test-track",default:[:]][0] = .init(frame:Double(index))
        model.savePerformance()
    }
    await model.flushPerformanceWrites()
    let saved=try PerformancePreparation.load(from:root.appendingPathComponent("performance.json"))
    #expect(saved.cues["test-track"]?[0]?.frame == 499)
}

@Test @MainActor func effectSelectionPersistsWithoutAnXYGesture() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    var effect=EffectControl()
    effect.kind=4; effect.x=0.3; effect.y=0.8; effect.enabled=true; effect.locked=true
    model.setEffect(effect,slot:2,deck:.b,persist:true)
    await model.flushPerformanceWrites()
    let restarted=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    let restored=try #require(restarted.effects[.b]?[2])
    #expect(restored.kind == 4)
    #expect(restored.x == 0.3 && restored.y == 0.8)
    #expect(!restored.enabled && !restored.locked)
}

@Test @MainActor func effectPadsRetainIndependentContactsAndReleaseOwnership() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    let first=SurfacePoint(id:1,x:0.2,y:0.3), second=SurfacePoint(id:2,x:0.8,y:0.6)
    model.effectTouch(.init(phase:.began,points:[first],ending:[]),slot:0,deck:.a)
    model.effectTouch(.init(phase:.began,points:[second],ending:[]),slot:1,deck:.a)
    model.effectTouch(.init(phase:.began,points:[first],ending:[]),slot:0,deck:.b)
    model.effectTouch(.init(phase:.ended,points:[first],ending:[1]),slot:0,deck:.a)
    #expect(model.effects[.a]?[0]?.enabled == false)
    #expect(model.effects[.a]?[1]?.enabled == true)
    #expect(model.effects[.b]?[0]?.enabled == true)
    #expect(model.effects[.a]?[1]?.x == 0.8)
    #expect(model.effects[.a]?[1]?.y == 0.4)
    var locked=try #require(model.effects[.a]?[1]); locked.locked=true
    model.setEffect(locked,slot:1,deck:.a)
    model.effectTouch(.init(phase:.ended,points:[second],ending:[2]),slot:1,deck:.a)
    #expect(model.effects[.a]?[1]?.enabled == true)
    model.effectTouch(.init(phase:.cancelled,points:[second],ending:[2]),slot:1,deck:.a)
    #expect(model.effects[.a]?[1]?.enabled == false)
    #expect(model.effects[.b]?[0]?.enabled == true)
    await model.flushPerformanceWrites()
}

@Test @MainActor func twoFingerLoopDismissalWaitsForBothReleasesAndCancelsSafely() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    await model.importFiles([URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
        .deletingLastPathComponent().appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track=try #require(model.library.tracks.first)
    model.load(trackID:track.id,deck:.a); await model.flushWrites()
    model.viewport[.a]=96000
    let p=SurfacePoint(id:1,x:0.25,y:0.2),q=SurfacePoint(id:2,x:0.75,y:0.2)
    let downP=SurfacePoint(id:1,x:0.25,y:0.8),downQ=SurfacePoint(id:2,x:0.75,y:0.8)
    for cancel in [true,false] {
        model.setLoop(start:72000,end:120000,deck:.a)
        let session=WaveformGestureSession()
        session.handle(.init(phase:.began,points:[p,q],ending:[]),model:model,deck:.a,span:96000)
        session.handle(.init(phase:.moved,points:[downP,downQ],ending:[]),model:model,deck:.a,span:96000)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        if cancel {
            session.handle(.init(phase:.cancelled,points:[downP,downQ],ending:[1,2]),model:model,deck:.a,span:96000)
            #expect(model.playbackSnapshot?.a.loopEnabled == true)
            #expect(model.playbackSnapshot?.a.loopStart == 72000)
        } else {
            session.handle(.init(phase:.ended,points:[downP,downQ],ending:[1]),model:model,deck:.a,span:96000)
            #expect(model.playbackSnapshot?.a.loopEnabled == true)
            session.handle(.init(phase:.ended,points:[downQ],ending:[2]),model:model,deck:.a,span:96000)
            #expect(model.playbackSnapshot?.a.loopEnabled == false)
        }
    }
}

@Test @MainActor func temporaryFaderRestoresWhenBothContactsLiftTogether() {
    for cancellation in [false,true] {
        let session=FaderGestureSession()
        let p=SurfacePoint(id:1,x:0.2,y:0.5),q=SurfacePoint(id:2,x:0.9,y:0.5)
        var value=0.5
        func send(_ event: SurfaceEvent) {
            session.handle(event,value:value,range:0...1,reset:0.5) { value=$0 }
        }
        send(.init(phase:.began,points:[p],ending:[]))
        #expect(value == 0.2)
        send(.init(phase:.began,points:[p,q],ending:[]))
        #expect(value == 0.9)
        send(.init(phase:cancellation ? .cancelled : .ended,points:[p,q],ending:[1,2]))
        #expect(value == 0.2)
        send(.init(phase:.began,points:[.init(id:3,x:0.5,y:0.5)],ending:[]))
        #expect(value == 0.5)
    }
}

@Test @MainActor func tempoWheelWrapCentreRecontactAndExtraContactsDoNotJump() {
    let session=TempoWheelGestureSession()
    var bpm=120.0
    func point(_ degrees: Double,id: Int=1) -> SurfacePoint {
        let radians=degrees * .pi / 180
        return .init(id:id,x:0.5+cos(radians)*0.4,y:0.5+sin(radians)*0.4)
    }
    func send(_ phase: SurfaceEvent.Phase,_ points: [SurfacePoint],ending: Set<Int> = []) {
        session.handle(.init(phase:phase,points:points,ending:ending),width:168,height:168,bpm:bpm) { bpm=$0 }
    }
    send(.began,[point(179)])
    send(.moved,[point(-179)])
    #expect(abs(bpm-120.2)<0.000001)
    send(.moved,[.init(id:1,x:0.5,y:0.5)])
    send(.moved,[point(0)])
    #expect(abs(bpm-120.2)<0.000001)
    send(.began,[point(0),point(90,id:2)])
    send(.moved,[point(0),point(-90,id:2)])
    #expect(abs(bpm-120.2)<0.000001)
    send(.cancelled,[],ending:[1,2])
    send(.began,[point(90,id:3)])
    #expect(abs(bpm-120.2)<0.000001)
    send(.moved,[point(100,id:3)])
    #expect(abs(bpm-121.2)<0.000001)
}
