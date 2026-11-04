import Testing

@testable import TDJInterface

@Test @MainActor func verticalEQFaderUsesHeightAndKeepsItsUnityReset() {
    let session = FaderGestureSession()
    var value = 1.0
    for (x, y, expected) in [(0.1, 0.0, 2.0), (0.9, 1.0, 0.0), (0.9, 0.49, 1.0)] {
        session.handle(
            .init(phase: .began, points: [.init(id: 1, x: x, y: y)], ending: []), value: value, range: 0...2, reset: 1,
            axis: .vertical
        ) { value = $0 }
        #expect(value == expected)
        session.handle(
            .init(phase: .ended, points: [], ending: [1]), value: value, range: 0...2, reset: 1, axis: .vertical
        ) { value = $0 }
    }
}

@Test @MainActor func verticalFaderRestoresTheTemporarySecondFingerValueOnCancellation() {
    let session = FaderGestureSession()
    var value = 1.5
    let first = SurfacePoint(id: 1, x: 0.8, y: 0.25)
    let second = SurfacePoint(id: 2, x: 0.1, y: 0.75)
    session.handle(
        .init(phase: .began, points: [first, second], ending: []), value: value, range: 0...2, reset: 1, axis: .vertical
    ) { value = $0 }
    #expect(value == 0.5)
    session.handle(
        .init(phase: .cancelled, points: [], ending: []), value: value, range: 0...2, reset: 1, axis: .vertical
    ) { value = $0 }
    #expect(value == 1.5)
}

@Test @MainActor func faderThumbCentresReachTheDrawnEndpointsWithoutAValueJump() {
    for (axis, x, y, expected) in [
        (FaderAxis.vertical, 0.2, 0.06, 1.0), (.vertical, 0.8, 0.94, 0), (.horizontal, 0.06, 0.2, 0),
        (.horizontal, 0.94, 0.8, 1),
    ] {
        let session = FaderGestureSession()
        var value = expected
        session.handle(
            .init(phase: .began, points: [.init(id: 1, x: x, y: y)], ending: []), value: value, range: 0...1,
            reset: nil, axis: axis, insetFraction: 0.06
        ) { value = $0 }
        #expect(abs(value - expected) < 0.000001)
    }
}
