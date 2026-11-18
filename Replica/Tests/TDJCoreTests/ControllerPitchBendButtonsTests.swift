import Testing

@testable import TDJCore

@Test func controllerPitchBendButtonsFeedbackKeepsOpposingHoldsAndRejectsOtherGenerations() {
    var buttons = ControllerPitchBendButtons()
    #expect(!buttons.isPressed(.up, generation: 1))
    _ = buttons.update(.up, pressed: true, generation: 1)
    _ = buttons.update(.down, pressed: true, generation: 1)
    #expect(buttons.isPressed(.up, generation: 1) && buttons.isPressed(.down, generation: 1))
    #expect(!buttons.isPressed(.up, generation: 2) && !buttons.isPressed(.down, generation: 0))
    _ = buttons.update(.up, pressed: false, generation: 1)
    #expect(!buttons.isPressed(.up, generation: 1) && buttons.isPressed(.down, generation: 1))
}

@Test func controllerPitchBendButtonsCancelOpposingHoldsAndRestoreOnlyAfterFinalRelease() {
    var buttons = ControllerPitchBendButtons()
    #expect(buttons.update(.up, pressed: true, generation: 1) == 1.04)
    #expect(buttons.update(.up, pressed: true, generation: 1) == nil)
    #expect(buttons.update(.down, pressed: true, generation: 1) == 1)
    #expect(buttons.update(.up, pressed: false, generation: 1) == 0.96)
    #expect(buttons.update(.down, pressed: false, generation: 1) == 1)
    #expect(buttons.update(.down, pressed: false, generation: 1) == nil)
}

@Test func controllerPitchBendButtonsRetainTheOtherDirectionInEitherHoldOrder() {
    var buttons = ControllerPitchBendButtons()
    #expect(buttons.update(.down, pressed: true, generation: 1) == 0.96)
    #expect(buttons.update(.up, pressed: true, generation: 1) == 1)
    #expect(buttons.update(.down, pressed: false, generation: 1) == 1.04)
    #expect(buttons.update(.up, pressed: false, generation: 1) == 1)
}

@Test func controllerPitchBendButtonsIgnoreOrphansAndOldSourceHoldsAfterLoading() {
    var buttons = ControllerPitchBendButtons()
    #expect(buttons.update(.up, pressed: false, generation: 1) == nil)
    #expect(buttons.update(.up, pressed: true, generation: 1) == 1.04)
    #expect(buttons.update(.down, pressed: false, generation: 2) == nil)
    #expect(buttons.update(.up, pressed: false, generation: 2) == nil)
    #expect(buttons.update(.down, pressed: true, generation: 2) == 0.96)
    #expect(buttons.update(.up, pressed: true, generation: 3) == 1.04)
    #expect(buttons.update(.down, pressed: false, generation: 3) == nil)
    #expect(buttons.update(.up, pressed: true, generation: 0) == nil)
    #expect(buttons.update(.up, pressed: false, generation: 4) == nil)
}
