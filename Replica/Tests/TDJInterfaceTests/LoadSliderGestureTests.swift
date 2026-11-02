import Testing
@testable import TDJInterface

@Test func loadSliderCancellationReleaseAndSecondContactStayIsolated() {
    var session = LoadSliderGestureSession()
    func event(_ phase: SurfaceEvent.Phase, _ y: Double, ending: Set<Int> = []) -> SurfaceEvent {
        .init(phase:phase,points:[.init(id:1,x:0.5,y:y)],ending:ending)
    }
    #expect(session.handle(event(.began,0.5),height:100) == nil)
    #expect(session.handle(event(.moved,0),height:100) == nil)
    #expect(session.offset == -18)
    #expect(session.handle(event(.cancelled,0,ending:[1]),height:100) == nil)
    #expect(session.offset == 0)
    _ = session.handle(event(.began,0.5),height:100)
    #expect(session.handle(event(.ended,0,ending:[1]),height:100) == .a)
    #expect(session.offset == 0)
    _ = session.handle(event(.began,0.5),height:100)
    #expect(session.handle(event(.ended,1,ending:[1]),height:100) == .b)
    _ = session.handle(event(.began,0.5),height:100)
    let second = SurfacePoint(id:2,x:0.5,y:0.9)
    #expect(session.handle(.init(phase:.began,points:[.init(id:1,x:0.5,y:0.5),second],ending:[]),height:100) == nil)
    #expect(session.offset == 0)
    #expect(session.handle(.init(phase:.ended,points:[.init(id:1,x:0.5,y:0.5),second],ending:[1]),height:100) == nil)
    #expect(session.handle(.init(phase:.ended,points:[second],ending:[2]),height:100) == nil)
    #expect(session.offset == 0)
}

@Test(arguments: [-18.0, 18.0])
func loadSliderCommitsAtTheVisibleEndpoint(distance: Double) {
    var session = LoadSliderGestureSession()
    _ = session.handle(.init(phase: .began, points: [.init(id: 1, x: 0.5, y: 0.5)], ending: []), height: 100)
    let destination = session.handle(.init(phase: .ended,
        points: [.init(id: 1, x: 0.5, y: 0.5 + distance / 100)], ending: [1]), height: 100)
    #expect(destination == (distance < 0 ? .a : .b))
    #expect(session.offset == 0)
}
