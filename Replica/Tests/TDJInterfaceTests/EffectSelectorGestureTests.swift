import Testing

@testable import TDJInterface

@Test func effectSelectorUsesOwnerReleaseAndResetsOnEmptyCancellation() {
    var session = EffectSelectorGestureSession()
    let owner = SurfacePoint(id: 1, x: 0.5, y: 0.5)
    let other = SurfacePoint(id: 2, x: 0.5, y: 4.2)
    _ = session.handle(.init(phase: .began, points: [owner], ending: []), at: 10, count: 5)
    _ = session.handle(
        .init(phase: .moved, points: [.init(id: 1, x: 0.5, y: 2.2), other], ending: []), at: 10.4, count: 5)
    #expect(session.opened)
    let selection = session.handle(
        .init(phase: .ended, points: [.init(id: 1, x: 0.5, y: 2.2), other], ending: [1]), at: 10.5, count: 5)
    #expect(selection == 1)
    #expect(!session.opened)
    let ignored = session.handle(.init(phase: .ended, points: [other], ending: [2]), at: 10.6, count: 5)
    #expect(ignored == nil)
    #expect(!session.opened)
    _ = session.handle(.init(phase: .began, points: [owner], ending: []), at: 20, count: 5)
    _ = session.handle(.init(phase: .ended, points: [owner], ending: [1]), at: 20.1, count: 5)
    #expect(session.opened)
    _ = session.handle(.init(phase: .cancelled, points: [], ending: []), at: 20.2, count: 5)
    #expect(!session.opened)
}

@Test func inactiveEffectTabSelectsBeforeOpeningItsMenu() {
    var session = EffectSelectorGestureSession()
    let point = SurfacePoint(id: 1, x: 0.5, y: 0.5)
    _ = session.handle(.init(phase: .began, points: [point], ending: []), at: 1, count: 8, tapOpensMenu: false)
    _ = session.handle(.init(phase: .ended, points: [point], ending: [1]), at: 1.1, count: 8, tapOpensMenu: true)
    #expect(!session.opened)
    _ = session.handle(.init(phase: .began, points: [point], ending: []), at: 2, count: 8, tapOpensMenu: true)
    _ = session.handle(.init(phase: .ended, points: [point], ending: [1]), at: 2.1, count: 8)
    #expect(session.opened)
}

@Test func deselectedEffectMenuIgnoresItsOldContactUntilRelease() {
    var session = EffectSelectorGestureSession()
    let point = SurfacePoint(id: 1, x: 0.5, y: 0.5)
    _ = session.handle(.init(phase: .began, points: [point], ending: []), at: 1, count: 8)
    session.dismiss()
    #expect(session.isTracking)
    #expect(!session.opened)
    _ = session.handle(.init(phase: .moved, points: [.init(id: 1, x: 0.5, y: 3)], ending: []), at: 2, count: 8)
    #expect(!session.opened)
    _ = session.handle(.init(phase: .ended, points: [point], ending: [1]), at: 2.1, count: 8)
    #expect(!session.isTracking)
    _ = session.handle(.init(phase: .began, points: [point], ending: []), at: 3, count: 8)
    _ = session.handle(.init(phase: .ended, points: [point], ending: [1]), at: 3.1, count: 8)
    #expect(session.opened)
}
