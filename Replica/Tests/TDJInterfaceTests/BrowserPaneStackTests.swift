import Testing
import TDJCore
@testable import TDJInterface

@Test func choosingAGroupSlidesItsSongsInAndASwipeTracksTheFingerOneToOne() {
    var stack = BrowserPaneStack()
    stack.open(group: "ignored")
    #expect(stack.depth == 0)
    stack.select(.playlists)
    stack.open(group: "ios-playlist:1")
    #expect(stack.depth == 1 && stack.group == "ios-playlist:1")
    for translation in [0.0, 12.5, 140, 333] {
        stack.dragChanged(translation: translation)
        #expect(stack.dragOffset == translation)
    }
    stack.dragChanged(translation: -40)
    #expect(stack.dragOffset == 0)
}

@Test func releasingFarEnoughOrFlickingGoesBackAndShortSwipesSpringBack() {
    var stack = BrowserPaneStack()
    stack.select(.artists); stack.open(group: "artist")
    let short = stack.dragEnded(translation: 90, velocity: 100, width: 600)
    #expect(!short && stack.depth == 1 && stack.dragOffset == 0)
    let far = stack.dragEnded(translation: 220, velocity: 0, width: 600)
    #expect(far && stack.depth == 0 && stack.category == .artists)
    stack.open(group: "artist")
    let flick = stack.dragEnded(translation: 40, velocity: 900, width: 600)
    #expect(flick && stack.depth == 0)
    let atRoot = stack.dragEnded(translation: 400, velocity: 0, width: 600)
    #expect(!atRoot)
}

@Test func changingCategoryReturnsToItsRootPane() {
    var stack = BrowserPaneStack()
    stack.select(.albums); stack.open(group: "album")
    stack.select(.genre)
    #expect(stack.depth == 0 && stack.group == nil && stack.category == .genre)
}
