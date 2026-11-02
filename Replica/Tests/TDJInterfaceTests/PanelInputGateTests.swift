import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@Test @MainActor func panelInputGateCancelsSynchronouslyAndAllowsRegistryRemovalDuringClose() {
    let gate=TouchSurfaceInputGate()
    var calls=0
    var registration: UUID?
    registration=gate.register {
        #expect(!gate.isEnabled)
        #expect(!gate.permits(.began) && !gate.permits(.moved) && !gate.permits(.ended))
        #expect(gate.permits(.cancelled))
        calls+=1
        gate.unregister(registration)
    }
    gate.setEnabled(false)
    #expect(calls == 1)
    gate.setEnabled(false)
    #expect(calls == 1)
    let second=gate.register { calls+=1 }
    #expect(calls == 2)
    gate.setEnabled(true)
    #expect(calls == 2 && gate.permits(.began))
    gate.setEnabled(false)
    #expect(calls == 3)
    gate.unregister(second)
}

@Test @MainActor func panelInputGateCloseRestoresTemporaryEQAndReleasesOnlyTouchedFilterAndFX() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    let gate=TouchSurfaceInputGate()
    var fx=MouseContactSession(),filter=MouseContactSession()
    let eq=FaderGestureSession()
    let point=SurfacePoint(id:0,x:0.25,y:0.75)
    let filterAction:(SurfaceEvent)->Void={ event in
        if event.phase == .cancelled { model.releaseFilter(deck:.a,cancelled:true) }
        else if let point=event.remaining.first { model.filterTouch(x:point.x,y:point.y,deck:.a) }
    }
    let fxAction:(SurfaceEvent)->Void={ model.effectTouch($0,slot:0,deck:.a) }
    var untouched=EffectControl()
    untouched.enabled=true; untouched.locked=true
    model.setEffect(untouched,slot:2,deck:.a)
    model.filterLocked=[.a,.b]
    model.filterTouch(x:0.5,y:0.5,deck:.b)
    fx.move(to:point,action:fxAction)
    filter.move(to:point,action:filterAction)
    model.setMixer(.low,value:1.5,deck:.a)
    eq.handle(.init(phase:.began,points:[.init(id:1,x:0.1,y:0.25),.init(id:2,x:0.1,y:0.75)],ending:[]),
              value:1.5,range:0...2,reset:1,axis:.vertical) { model.setMixer(.low,value:$0,deck:.a) }
    #expect(model.playbackSnapshot?.a.mixer.low == 0.5)
    #expect(model.effects[.a]?[0]?.enabled == true)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == true)
    let registrations=[
        gate.register { fx.cancel(action:fxAction) },
        gate.register { filter.cancel(action:filterAction) },
        gate.register {
            eq.handle(.init(phase:.cancelled,points:[],ending:[]),value:0.5,range:0...2,reset:1,axis:.vertical) {
                model.setMixer(.low,value:$0,deck:.a)
            }
        }
    ]
    gate.setEnabled(false)
    #expect(model.playbackSnapshot?.a.mixer.low == 1.5)
    #expect(model.effects[.a]?[0]?.enabled == false)
    #expect(model.effects[.a]?[2]?.enabled == true && model.effects[.a]?[2]?.locked == true)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == false)
    #expect(model.playbackSnapshot?.b.mixer.filterEnabled == true)
    gate.setEnabled(true)
    fx.move(to:.init(id:0,x:0.9,y:0.2),action:fxAction)
    #expect(model.effects[.a]?[0]?.enabled == false)
    fx.end(at:point,action:fxAction)
    fx.move(to:point,action:fxAction)
    #expect(model.effects[.a]?[0]?.enabled == true)
    gate.setEnabled(false)
    for id in registrations { gate.unregister(id) }
    await model.finishForShutdown()
}

@Test @MainActor func panelInputGateDoesNotCancelAnotherDeckOrAnUnregisteredSurface() {
    let a=TouchSurfaceInputGate(),b=TouchSurfaceInputGate()
    var callsA=0,callsB=0,removedCalls=0
    let first=a.register { callsA+=1 },second=b.register { callsB+=1 }
    let removed=a.register { removedCalls+=1 }
    a.unregister(removed)
    a.setEnabled(false)
    #expect(callsA == 1 && callsB == 0 && removedCalls == 0)
    #expect(b.permits(.moved))
    b.setEnabled(false)
    #expect(callsB == 1)
    a.unregister(first); b.unregister(second)
}

@Test @MainActor func panelInputGateCancellationUsesTheRefreshedHandlerWithoutEndingItsContactEarly() {
    let gate=TouchSurfaceInputGate(),relay=SurfaceEventActionRelay()
    var contact=MouseContactSession()
    var old:[SurfaceEvent.Phase]=[],current:[SurfaceEvent.Phase]=[]
    let point=SurfacePoint(id:0,x:0.25,y:0.5)
    relay.update { old.append($0.phase) }
    contact.move(to:point,action:relay.send)
    let registration=gate.register { contact.cancel(action:relay.send) }
    relay.update { current.append($0.phase) }
    #expect(current.isEmpty)
    contact.move(to:.init(id:0,x:0.4,y:0.5),action:relay.send)
    #expect(old == [.began,.moved] && current == [.moved])
    gate.setEnabled(false)
    #expect(old == [.began,.moved] && current == [.moved,.cancelled])
    contact.end(at:point,action:relay.send)
    #expect(current == [.moved,.cancelled])
    gate.unregister(registration)
}

@Test func panelNativeOwnedEventsIgnoreOldContactsAfterReopenAndRetainTheGenuineFinalRelease() throws {
    let old=SurfacePoint(id:0,x:0.25,y:0.5),current=SurfacePoint(id:1,x:0.75,y:0.5)
    let began=try #require(SurfaceEvent.owned(phase:.began,points:[old],changed:[0]))
    #expect(began.points == [old])
    let cancelled=try #require(SurfaceEvent.owned(phase:.cancelled,points:[old],changed:[0],ending:[0]))
    #expect(cancelled.remaining.isEmpty)
    for phase in [SurfaceEvent.Phase.moved,.ended,.cancelled] {
        #expect(SurfaceEvent.owned(phase:phase,points:[],changed:[0],ending:[0]) == nil)
        #expect(SurfaceEvent.owned(phase:phase,points:[current],changed:[0],ending:[0]) == nil)
    }
    #expect(SurfaceEvent.owned(phase:.began,points:[current],changed:[1])?.remaining == [current])
    let ended=try #require(SurfaceEvent.owned(phase:.ended,points:[current],changed:[1],ending:[0,1]))
    #expect(ended.points == [current])
    #expect(ended.ending == [1] && ended.remaining.isEmpty)
}
