import Testing
@testable import TDJInterface

@Test func songsPaneFollowsTheFingerOneToOneAndNeverMovesUp() {
    for translation in [0.0,1,37.5,119,400] { #expect(PaneDismissGesture.offset(translation:translation) == translation) }
    #expect(PaneDismissGesture.offset(translation:-50) == 0)
    #expect(PaneDismissGesture.offset(translation:.nan) == 0)
}

@Test func songsPaneClosesOnAPullOrAFlickDownAndSpringsBackOtherwise() {
    #expect(PaneDismissGesture.dismisses(translation:120,velocity:0))
    #expect(PaneDismissGesture.dismisses(translation:30,velocity:900))
    #expect(!PaneDismissGesture.dismisses(translation:80,velocity:100))
    #expect(!PaneDismissGesture.dismisses(translation:5,velocity:2000))
    #expect(!PaneDismissGesture.dismisses(translation:60,velocity:-900))
    #expect(!PaneDismissGesture.dismisses(translation:.infinity,velocity:0))
}
