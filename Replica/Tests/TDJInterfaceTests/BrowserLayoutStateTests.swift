import Testing
@testable import TDJInterface

@Test func browserColumnsRetainDirectSizesAndCancelPreviews() {
    var state = BrowserLayoutState(categoriesHidden: true)
    state.configure(width: 1016, portrait: false, leading: .categories)
    state.begin(.detail)
    state.update(.detail, translation: 55)
    state.end(.detail, velocity: 0)
    #expect(state.geometry().detail.width == 375)
    state.setPresented(.detail, false)
    state.showDetail()
    #expect(state.geometry().detail.width == 375)
    state.begin(.detail)
    state.update(.detail, translation: -200)
    state.cancel(.detail)
    #expect(state.geometry().detail.width == 375)
}

@Test func browserColumnOpeningMakesRoomWithoutLosingTheOtherSize() {
    var state = BrowserLayoutState(categoriesHidden: true)
    state.configure(width: 738, portrait: true, leading: .categories)
    state.begin(.categories)
    state.update(.categories, translation: 170)
    #expect(!state.isPresented(.detail))
    state.cancel(.categories)
    #expect(state.geometry().detail.width == 320)
    #expect(!state.isPresented(.categories))
    state.setPresented(.categories, true)
    #expect(state.geometry().leading.width == 180)
    state.showDetail()
    #expect(!state.isPresented(.categories))
    #expect(state.geometry().detail.width == 320)
}
