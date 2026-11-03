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

@Test(arguments: [-1.0, 1.0])
func tallLoadSliderFollowsTheFingerUntilItsEndpoint(direction: Double) {
    var session = LoadSliderGestureSession()
    func event(_ phase: SurfaceEvent.Phase, distance: Double) -> SurfaceEvent {
        .init(phase: phase, points: [.init(id: 1, x: 0.5, y: 0.5 + distance / 178)],
              ending: phase == .ended ? [1] : [])
    }
    _ = session.handle(event(.began, distance: 0), height: 178, maximumTravel: 53)
    #expect(session.handle(event(.moved, distance: direction * 32), height: 178, maximumTravel: 53) == nil)
    #expect(session.offset == direction * 32)
    #expect(session.handle(event(.ended, distance: direction * 32), height: 178, maximumTravel: 53) == nil)
    #expect(session.offset == 0)
    _ = session.handle(event(.began, distance: 0), height: 178, maximumTravel: 53)
    #expect(session.handle(event(.moved, distance: direction * 60), height: 178, maximumTravel: 53) == nil)
    #expect(session.offset == direction * 53)
    #expect(session.handle(event(.ended, distance: direction * 53), height: 178, maximumTravel: 53)
        == (direction < 0 ? .a : .b))
}

@Test(arguments: [-1.0, 1.0])
func tallLoaderReachesBothDecksWithoutEnteringLabelAreas(direction: Double) {
    let travel = TallLoadSliderMetrics.maximumTravel
    #expect(travel >= 16)
    #expect(travel + TallLoadSliderMetrics.handleHeight / 2 <= TallLoadSliderMetrics.railHeight / 2)
    var session = LoadSliderGestureSession()
    let height = TallLoadSliderMetrics.height + 8
    _ = session.handle(.init(phase: .began, points: [.init(id: 1, x: 0.5, y: 0.5)], ending: []),
                       height: height, maximumTravel: travel)
    let point = SurfacePoint(id: 1, x: 0.5, y: 0.5 + direction * travel / height)
    #expect(session.handle(.init(phase: .moved, points: [point], ending: []),
                           height: height, maximumTravel: travel) == nil)
    #expect(session.armedDeck == (direction < 0 ? .a : .b))
    #expect(session.handle(.init(phase: .ended, points: [point], ending: [1]),
                           height: height, maximumTravel: travel) == (direction < 0 ? .a : .b))
}
