import Foundation
import Observation
import Testing
import TDJCore
@testable import TDJInterface

private final class MixerPaneChangeCounter: @unchecked Sendable {
    private let lock=NSLock()
    private var count=0
    func changed() { lock.lock();count+=1;lock.unlock() }
    var value: Int { lock.lock();defer { lock.unlock() };return count }
}

@Test @MainActor func mixerPaneSwitchCancelsBeforeBindingCommitAndPreservesTheParentGate() {
    let outer=TouchSurfaceInputGate(),input=MixerPaneInputSession()
    input.bindParent(outer);input.synchronize(selection:.equalizer,presented:true)
    var selected=MixerPanel.equalizer,eqCalls=0,filterCalls=0
    let eq=input.equalizer.register {
        #expect(selected == .equalizer)
        #expect(!input.equalizer.isEnabled)
        eqCalls+=1
    }
    input.select(.filter) {
        #expect(eqCalls == 1 && selected == .equalizer)
        selected = .filter
    }
    #expect(!input.equalizer.isEnabled && input.filter.isEnabled)
    let filter=input.filter.register { filterCalls+=1 }
    outer.setEnabled(false)
    #expect(filterCalls == 1 && eqCalls == 1)
    #expect(!input.filter.permits(.moved) && input.filter.permits(.cancelled))
    input.select(.equalizer) { selected = .equalizer }
    #expect(!input.equalizer.isEnabled && !input.filter.isEnabled)
    input.equalizer.unregister(eq);input.filter.unregister(filter);input.unbind()
}

@Test @MainActor func mixerPaneParentRebindingAndUnbindingCancelAndRemoveTheOldRegistration() {
    let old=TouchSurfaceInputGate(),next=TouchSurfaceInputGate(),input=MixerPaneInputSession()
    input.bindParent(old);input.synchronize(selection:.equalizer,presented:true)
    var calls=0
    let registration=input.equalizer.register { calls+=1 }
    input.bindParent(next)
    #expect(calls == 1 && input.equalizer.isEnabled)
    old.setEnabled(false)
    #expect(calls == 1 && input.equalizer.isEnabled)
    next.setEnabled(false)
    #expect(calls == 2 && !input.equalizer.isEnabled)
    next.setEnabled(true);input.synchronize(selection:.equalizer,presented:true)
    input.unbind()
    #expect(calls == 3 && !input.equalizer.isEnabled && !input.filter.isEnabled)
    next.setEnabled(false)
    #expect(calls == 3)
    input.equalizer.unregister(registration)
}

@Test @MainActor func mixerPaneRepeatedSwitchAndDrawerCyclesDoNotDuplicateCancellation() {
    let outer=TouchSurfaceInputGate(),input=MixerPaneInputSession()
    input.bindParent(outer);input.synchronize(selection:.equalizer,presented:true)
    var eqCalls=0,filterCalls=0
    let eq=input.equalizer.register { eqCalls+=1 }
    let filter=input.filter.register { filterCalls+=1 }
    // Registering on an initially inactive gate cancels once, matching ContactView semantics.
    #expect(eqCalls == 0 && filterCalls == 1)
    for cycle in 1...100 {
        input.select(.filter) {}
        #expect(eqCalls == cycle)
        input.select(.filter) {}
        #expect(eqCalls == cycle)
        outer.setEnabled(false)
        #expect(filterCalls == cycle+1)
        input.synchronize(selection:.filter,presented:true)
        #expect(!input.equalizer.isEnabled && !input.filter.isEnabled)
        input.synchronize(selection:.equalizer,presented:true)
        #expect(!input.equalizer.isEnabled && !input.filter.isEnabled)
        outer.setEnabled(true)
        #expect(input.equalizer.isEnabled && !input.filter.isEnabled)
    }
    input.equalizer.unregister(eq);input.filter.unregister(filter);input.unbind()
}

@Test @MainActor func mixerPaneSwitchRestoresTemporaryEQAndCancelsLockedFilterWithAxisReset() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    let outer=TouchSurfaceInputGate(),input=MixerPaneInputSession()
    input.bindParent(outer);input.synchronize(selection:.equalizer,presented:true)
    let fader=FaderGestureSession()
    model.setMixer(.low,value:1.5,deck:.a)
    let held=SurfaceEvent(phase:.began,points:[.init(id:0,x:0.2,y:0.25),.init(id:1,x:0.2,y:0.75)],ending:[])
    fader.handle(held,value:1.5,range:0...2,reset:1,axis:.vertical) { model.setMixer(.low,value:$0,deck:.a) }
    #expect(model.playbackSnapshot?.a.mixer.low == 0.5)
    let eq=input.equalizer.register {
        fader.handle(.init(phase:.cancelled,points:[],ending:[]),value:0.5,range:0...2,reset:1,axis:.vertical) {
            model.setMixer(.low,value:$0,deck:.a)
        }
    }
    input.select(.filter) { #expect(model.playbackSnapshot?.a.mixer.low == 1.5) }
    model.filterLocked=[.a,.b]
    model.filterTouch(x:0.4,y:0.3,deck:.b)
    let state=FilterPadContactState()
    var contact=MouseContactSession()
    let action:(SurfaceEvent)->Void={ event in
        let updateX=state.update(event)
        if event.phase == .cancelled { model.releaseFilter(deck:.a,cancelled:true) }
        else if let p=event.remaining.first { model.filterTouch(x:p.x,y:p.y,deck:.a,updateX:updateX) }
    }
    let point=SurfacePoint(id:0,x:0.25,y:0.75)
    contact.move(to:point,action:action)
    model.setMixer(.filterX,value:0.8,deck:.a)
    contact.move(to:.init(id:0,x:0.25,y:0.2),action:action)
    #expect(model.playbackSnapshot?.a.mixer.filterX == 0.8)
    let filter=input.filter.register { contact.cancel(action:action) }
    input.select(.equalizer) { #expect(model.playbackSnapshot?.a.mixer.filterEnabled == false) }
    #expect(model.filterLocked.contains(.a) && model.playbackSnapshot?.b.mixer.filterEnabled == true)
    // Reopening cannot turn the old held contact into a new filter gesture.
    input.select(.filter) {}
    contact.move(to:point,action:action)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == false)
    contact.end(at:point,action:action)
    contact.move(to:point,action:action)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == true)
    #expect(abs((model.playbackSnapshot?.a.mixer.filterX ?? 0)+0.5)<1e-9)
    outer.setEnabled(false)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == false)
    // The retained fader owner can begin and restore another temporary hold.
    outer.setEnabled(true);input.synchronize(selection:.equalizer,presented:true)
    model.setMixer(.low,value:1.25,deck:.a)
    fader.handle(held,value:1.25,range:0...2,reset:1,axis:.vertical) { model.setMixer(.low,value:$0,deck:.a) }
    input.unbind()
    #expect(model.playbackSnapshot?.a.mixer.low == 1.25)
    input.equalizer.unregister(eq);input.filter.unregister(filter)
    await model.finishForShutdown()
}

@Test @MainActor func hiddenMixerFilterDisplayDoesNotReadOrObserveTheLiveSweepAndReopensFresh() throws {
    let core=try SampleTransport(),display=PlaybackControlDisplay()
    display.update(core.snapshot())
    var cache=MixerPaneDisplayCache(MixerFilterDisplayValue(display[.a].mixer))
    let hiddenChanges=MixerPaneChangeCounter(),activeChanges=MixerPaneChangeCounter()
    var reads=0
    func read() -> MixerFilterDisplayValue { reads+=1;return .init(display[.a].mixer) }
    withObservationTracking { _=cache.value(active:false,read:read) } onChange: { hiddenChanges.changed() }
    for index in 1...50 {
        try core.setMixer(.filterY,value:Double(index)/50,deck:.a)
        core.processControlsWhileIdle();display.update(core.snapshot())
    }
    #expect(reads == 0 && hiddenChanges.value == 0)
    #expect(cache.value(active:false,read:read).y == 0)
    let fresh=cache.value(active:true,read:read)
    #expect(fresh.y == display[.a].mixer.filterY && fresh.y != cache.frozen.y && reads == 1)
    withObservationTracking { _=cache.value(active:true,read:read) } onChange: { activeChanges.changed() }
    try core.setMixer(.filterY,value:0.37,deck:.a)
    core.processControlsWhileIdle();display.update(core.snapshot())
    #expect(activeChanges.value == 1 && hiddenChanges.value == 0)
    cache.freeze(read())
    let frozen=cache.frozen
    try core.setMixer(.filterX,value:0.8,deck:.a)
    core.processControlsWhileIdle();display.update(core.snapshot())
    #expect(cache.value(active:false,read:read) == frozen)
    #expect(cache.value(active:true,read:read).x == 0.8)
}

@Test @MainActor func hiddenMixerEqualizerAndLockDisplayStayFrozenAndActivationReadsCurrentValues() throws {
    let core=try SampleTransport(),display=PlaybackControlDisplay()
    display.update(core.snapshot())
    var eq=MixerPaneDisplayCache(MixerEqualizerDisplayValue(display[.a].mixer))
    var locked=false,lockCache=MixerPaneDisplayCache(false),reads=0
    func readLock() -> Bool { reads+=1;return locked }
    eq.freeze(.init(display[.a].mixer));lockCache.freeze(readLock())
    let changes=MixerPaneChangeCounter()
    withObservationTracking {
        _=eq.value(active:false) { .init(display[.a].mixer) }
    } onChange: { changes.changed() }
    try core.setMixer(.low,value:1.4,deck:.a)
    try core.setMixer(.volume,value:0.75,deck:.a)
    core.processControlsWhileIdle();display.update(core.snapshot())
    locked=true
    #expect(eq.value(active:false) { .init(display[.a].mixer) }.low == 1)
    #expect(eq.value(active:true) { .init(display[.a].mixer) }.low == 1.4)
    #expect(eq.value(active:true) { .init(display[.a].mixer) }.volume == 0.75)
    #expect(changes.value == 0)
    #expect(!lockCache.value(active:false,read:readLock) && reads == 1)
    #expect(lockCache.value(active:true,read:readLock) && reads == 2)
}

@Test @MainActor func mixerPaneReconcilesRejectedBindingsAndIgnoresOldParentAfterUnbind() {
    let outer=TouchSurfaceInputGate(),input=MixerPaneInputSession()
    input.bindParent(outer);input.synchronize(selection:.filter,presented:true)
    let actual=MixerPanel.filter
    var cancelled=0
    let registration=input.filter.register { cancelled+=1 }
    input.select(.equalizer) {
        #expect(cancelled == 1)
        // A constant preview binding retains its original value.
    }
    input.synchronize(selection:actual,presented:true)
    #expect(input.filter.isEnabled && !input.equalizer.isEnabled)
    input.unbind()
    #expect(cancelled == 2)
    outer.setEnabled(false);outer.setEnabled(true)
    #expect(!input.filter.isEnabled && !input.equalizer.isEnabled && cancelled == 2)
    input.filter.unregister(registration)
}

@Test @MainActor func mixerPaneParentOpeningEnablesTheSelectedPaneWithoutChildResynchronization() {
    for selected in MixerPanel.allCases {
        let outer=TouchSurfaceInputGate(),input=MixerPaneInputSession()
        outer.setEnabled(false)
        input.bindParent(outer)
        input.synchronize(selection:selected,presented:true)
        #expect(!input.equalizer.isEnabled && !input.filter.isEnabled)
        outer.setEnabled(true)
        #expect(input.equalizer.isEnabled == (selected == .equalizer))
        #expect(input.filter.isEnabled == (selected == .filter))
        outer.setEnabled(false)
        #expect(!input.equalizer.isEnabled && !input.filter.isEnabled)
        input.unbind()
    }
}

@Test @MainActor func mixerPaneParentOpeningWhileHiddenKeepsBothPanesDisabled() {
    let outer=TouchSurfaceInputGate(),input=MixerPaneInputSession()
    outer.setEnabled(false);input.bindParent(outer)
    input.synchronize(selection:.filter,presented:false)
    outer.setEnabled(true)
    #expect(!input.equalizer.isEnabled && !input.filter.isEnabled)
    input.synchronize(selection:.filter,presented:true)
    #expect(input.filter.isEnabled && !input.equalizer.isEnabled)
    input.synchronize(selection:.filter,presented:false)
    outer.setEnabled(false);outer.setEnabled(true)
    #expect(!input.equalizer.isEnabled && !input.filter.isEnabled)
    input.unbind()
}

@Test @MainActor func gateEnabledObserversAllowRemovalDuringDeliveryAndKeepCancellationSemantics() {
    let gate=TouchSurfaceInputGate()
    var ids:[UUID]=[],initial=0,closed=0,cancellations=0
    for _ in 0..<2 {
        ids.append(gate.observeEnabled { enabled in
            if enabled { initial+=1 }
            else {
                closed+=1
                for id in ids { gate.removeEnabledObserver(id) }
            }
        })
    }
    let cancellation=gate.register { cancellations+=1 }
    #expect(initial == 2 && closed == 0 && cancellations == 0)
    gate.setEnabled(false)
    // The first callback removes both observer registrations, regardless of dictionary order.
    #expect(closed == 1 && cancellations == 1)
    gate.setEnabled(true);gate.setEnabled(false)
    #expect(initial == 2 && closed == 1 && cancellations == 2)
    var current:Bool?
    let immediate=gate.observeEnabled { current=$0 }
    #expect(current == false)
    gate.removeEnabledObserver(immediate);gate.unregister(cancellation)
}

@Test @MainActor func gateEnabledObserverLifecyclesAndWeakPaneOwnershipDoNotLeaveActiveCallbacks() {
    let outer=TouchSurfaceInputGate()
    var calls=0
    for cycle in 1...100 {
        let id=outer.observeEnabled { _ in calls+=1 }
        outer.setEnabled(false);outer.setEnabled(true)
        outer.removeEnabledObserver(id)
        #expect(calls == cycle*3)
        outer.setEnabled(false);outer.setEnabled(true)
        #expect(calls == cycle*3)
    }
    weak var released:MixerPaneInputSession?
    do {
        let input=MixerPaneInputSession()
        input.bindParent(outer);input.synchronize(selection:.equalizer,presented:true)
        released=input
        input.unbind()
    }
    #expect(released == nil)
    outer.setEnabled(false);outer.setEnabled(true)
    #expect(calls == 300)
}
