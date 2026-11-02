import Testing
@testable import TDJInterface

@Test func detailPaneFollowsTheFingerOffAndBackAndWidensTheList() {
    var layout = BrowserLayoutState()
    #expect(!layout.listShowsTempoAndKey)
    for translation in [0.0, 40, 133.5] { layout.dragDetail(translation: translation); #expect(layout.detailOffset == translation) }
    layout.dragDetail(translation: -30)
    #expect(layout.detailOffset == 0)
    let short = layout.endDetail(translation: 90, velocity: 50, width: 400)
    #expect(!short && layout.detailOffset == 0)
    let away = layout.endDetail(translation: 150, velocity: 0, width: 400)
    #expect(away && layout.listShowsTempoAndKey)
    layout.dragDetail(translation: -80)
    #expect(layout.detailOffset == -80)
    let back = layout.endDetail(translation: -40, velocity: -900, width: 400)
    #expect(!back && !layout.listShowsTempoAndKey)
    _ = layout.endDetail(translation: 300, velocity: 0, width: 400)
    layout.showDetail()
    #expect(!layout.detailHidden)
}

@Test func categoryColumnCollapsesLeftAndReturns() {
    var layout = BrowserLayoutState()
    layout.dragCategories(translation: -50)
    #expect(layout.categoryOffset == -50)
    let hidden = layout.endCategories(translation: -90, velocity: 0, width: 180)
    #expect(hidden && layout.categoriesHidden)
    let shown = layout.endCategories(translation: 20, velocity: 900, width: 180)
    #expect(!shown)
}
