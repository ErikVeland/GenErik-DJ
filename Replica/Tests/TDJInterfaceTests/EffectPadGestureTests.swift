import Foundation
import Testing
@testable import TDJInterface

private func padEvent(_ phase: SurfaceEvent.Phase, _ points: [SurfacePoint], ending: Set<Int> = []) -> SurfaceEvent {
    .init(phase:phase,points:points,ending:ending)
}

@Test func sharedEffectPadKeepsTheOriginalSlotAcrossTabChanges() throws {
    var session=EffectPadGestureSession()
    let first=SurfacePoint(id:1,x:0.2,y:0.3)
    #expect(session.handle(padEvent(.moved,[first]),selectedSlot:0) == nil)
    #expect(session.handle(padEvent(.began,[first]),selectedSlot:0)?.slot == 0)
    #expect(session.handle(padEvent(.moved,[.init(id:1,x:0.4,y:0.5)]),selectedSlot:2)?.slot == 0)
    #expect(session.handle(padEvent(.ended,[first],ending:[1]),selectedSlot:2)?.slot == 0)
    #expect(session.activeSlot == nil)
    #expect(session.handle(padEvent(.began,[first]),selectedSlot:2)?.slot == 2)
}

@Test func sharedEffectPadWaitsForAllContactsAndRetainsHardwareX() throws {
    var session=EffectPadGestureSession()
    let first=SurfacePoint(id:1,x:0.2,y:0.3), second=SurfacePoint(id:2,x:0.8,y:0.6)
    #expect(session.handle(padEvent(.began,[first]),selectedSlot:1)?.updateX == true)
    #expect(session.handle(padEvent(.moved,[.init(id:1,x:0.2,y:0.5)]),selectedSlot:2)?.updateX == false)
    #expect(session.handle(padEvent(.began,[first,second]),selectedSlot:2)?.slot == 1)
    #expect(session.handle(padEvent(.ended,[first,second],ending:[1]),selectedSlot:0)?.slot == 1)
    #expect(session.activeSlot == 1)
    #expect(session.handle(padEvent(.ended,[second],ending:[2]),selectedSlot:0)?.slot == 1)
    #expect(session.activeSlot == nil)
}

@Test func sharedEffectPadCancellationCannotLeakIntoTheNextSlot() throws {
    var session=EffectPadGestureSession()
    let point=SurfacePoint(id:1,x:0.5,y:0.5)
    _=session.handle(padEvent(.began,[point]),selectedSlot:2)
    #expect(session.cancel() == 2)
    #expect(session.cancel() == nil)
    #expect(session.handle(padEvent(.moved,[point]),selectedSlot:0) == nil)
    #expect(session.handle(padEvent(.began,[point]),selectedSlot:0)?.updateX == true)
    #expect(session.handle(padEvent(.cancelled,[point],ending:[1]),selectedSlot:1)?.slot == 0)
    #expect(session.activeSlot == nil)
}

@Test @MainActor func sharedEffectPadDoesNotReselectOrModifyTheNewTabDuringAHold() throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    model.selectedEffectSlots[.a]=2
    let point=SurfacePoint(id:1,x:0.2,y:0.7)
    model.effectTouch(padEvent(.began,[point]),slot:0,deck:.a,selectSlot:false)
    #expect(model.selectedEffectSlots[.a] == 2)
    #expect(model.effects[.a]?[0]?.enabled == true)
    #expect(model.effects[.a]?[2] == nil)
    model.effectTouch(padEvent(.cancelled,[point],ending:[1]),slot:0,deck:.a,selectSlot:false)
    #expect(model.effects[.a]?[0]?.enabled == false)
    #expect(model.selectedEffectSlots[.a] == 2)
}
