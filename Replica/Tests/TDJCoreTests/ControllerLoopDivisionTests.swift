import TDJCore
import Testing

@Test func controllerPlayerLoopDivisionRestoresTheOriginalAfterSeveralDivisions() {
    var division = ControllerLoopDivision()
    #expect(division.divide(generation: 1, start: 100, end: 900) == 500)
    #expect(division.divide(generation: 1, start: 100, end: 500) == 300)
    #expect(division.restore(generation: 1, start: 100, end: 300) == 900)
    #expect(division.divide(generation: 1, start: 100, end: 900) == 500)
    #expect(division.restore(generation: 1, start: 100, end: 500) == 900)
}

@Test func controllerPlayerLoopDivisionRejectsStaleTracksAndReplacedLoops() {
    var division = ControllerLoopDivision()
    #expect(division.divide(generation: 1, start: 100, end: 900) == 500)
    #expect(division.restore(generation: 2, start: 100, end: 500) == nil)
    #expect(division.restore(generation: 1, start: 101, end: 500) == nil)
    #expect(division.restore(generation: 1, start: 100, end: 400) == nil)
    #expect(division.divide(generation: 2, start: 200, end: 600) == 400)
    #expect(division.restore(generation: 2, start: 200, end: 400) == 600)
}

@Test func controllerPlayerLoopDivisionBoundsInvalidAndOneFrameLoops() {
    var division = ControllerLoopDivision()
    #expect(division.divide(generation: 0, start: 0, end: 100) == nil)
    #expect(division.divide(generation: 1, start: -1, end: 100) == nil)
    #expect(division.divide(generation: 1, start: .nan, end: 100) == nil)
    #expect(division.divide(generation: 1, start: 0, end: .infinity) == nil)
    #expect(division.divide(generation: 1, start: 100, end: 101) == nil)
    #expect(division.divide(generation: 1, start: 100, end: 102) == 101)
    #expect(division.restore(generation: 1, start: 100, end: 101) == 102)
}
