import Testing

@testable import TDJCore

@Test func controllerJogBendConvertsRelativeCountsToBoundedRate() {
    #expect(ControllerJogBend.deltaCounts(fromNormalizedValue: 0.5) == 0)
    #expect(ControllerJogBend.deltaCounts(fromNormalizedValue: 0.625) == 1)
    #expect(ControllerJogBend.deltaCounts(fromNormalizedValue: 0.375) == -1)
    #expect(ControllerJogBend.deltaCounts(fromNormalizedValue: .nan) == 0)

    #expect(ControllerJogBend.accumulatedCounts(current: 3, delta: 2) == 4)
    #expect(ControllerJogBend.accumulatedCounts(current: -3, delta: -2) == -4)
    #expect(ControllerJogBend.accumulatedCounts(current: 2, delta: -2) == 0)
    #expect(ControllerJogBend.playbackRate(forCounts: 0) == 1)
    #expect(abs(ControllerJogBend.playbackRate(forCounts: 4) - 1.08) < 1e-12)
    #expect(abs(ControllerJogBend.playbackRate(forCounts: -4) - 0.92) < 1e-12)
    #expect(ControllerJogBend.playbackRate(forCounts: .infinity) == 1)
}
