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

@Test(arguments: [300.0, 619, 800, 1024])
func draggingToTheEndMatchesTheCollapsedLibraryHeight(height: Double) {
    let dragged = AdaptivePerformanceLayout.deckHeight(available: height, browserVisible: true, share: 1)
    let collapsed = AdaptivePerformanceLayout.deckHeight(available: height, browserVisible: false, share: 0.28)
    #expect(dragged == collapsed)
    #expect(height - collapsed == AdaptivePerformanceLayout.dividerHeight)
}
