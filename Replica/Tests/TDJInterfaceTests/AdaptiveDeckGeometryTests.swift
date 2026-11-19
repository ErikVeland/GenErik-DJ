import Testing

@testable import TDJInterface

@Test func deckExpansionHasNoGeometryJumpAtTheFormerLayoutThreshold() {
    var previous = AdaptiveDeckGeometry(height: 44)
    for height in 45...700 {
        let current = AdaptiveDeckGeometry(height: Double(height))
        #expect(abs(current.headerHeight - previous.headerHeight) <= 1)
        #expect(abs(current.overviewHeight - previous.overviewHeight) <= 1)
        #expect(abs(current.waveformHeight - previous.waveformHeight) <= 1.00001)
        #expect(abs(current.transportWidth - previous.transportWidth) <= 1)
        previous = current
    }
}

@Test(arguments: [300.0, 619, 800, 1024]) func draggingToTheEndMatchesTheCollapsedLibraryHeight(height: Double) {
    let dragged = AdaptivePerformanceLayout.deckHeight(available: height, browserVisible: true, share: 1)
    let collapsed = AdaptivePerformanceLayout.deckHeight(available: height, browserVisible: false, share: 0.28)
    #expect(dragged == collapsed)
    #expect(height - collapsed == AdaptivePerformanceLayout.dividerHeight)
}

@Test(arguments: [300.0, 619, 800, 1024]) func explicitLibraryOpenUsesTheMinimumDeckStripHeight(height: Double) {
    let decks = AdaptivePerformanceLayout.deckHeight(available: height, browserVisible: true, share: 0)
    #expect(decks == AdaptivePerformanceLayout.minimumDeckHeight)
    #expect(height - decks - AdaptivePerformanceLayout.dividerHeight > 0)
}

@Test func fourDeckGridRequiresRoomForTwoFullRowsAndColumns() {
    let width = 2 * WideDeckLayout.minimumDeckWidth + WideDeckLayout.gap
    let height = 2 * WideDeckLayout.minimumDeckHeight + WideDeckLayout.gap
    #expect(WideDeckLayout.fits(width: width, height: height))
    #expect(!WideDeckLayout.fits(width: width - 1, height: height))
    #expect(!WideDeckLayout.fits(width: width, height: height - 1))
    #expect(!WideDeckLayout.fits(width: .infinity, height: height))
    #expect(!WideDeckLayout.fits(width: width, height: .nan))
}
