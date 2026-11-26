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

@Test(arguments: [50.0, 76, 150, 200]) func duoPreviewStripsShareTheShorterDeckLimit(lower: Double) {
    let upper = 310.0
    let cap = AdaptiveDeckGeometry.pairedPreviewHeight(upper: upper, lower: lower)
    let taller = AdaptiveDeckGeometry(
        height: upper - 2 * AdaptiveDeckGeometry.inset, hotcues: true, previewStripHeight: cap)
    let shorter = AdaptiveDeckGeometry(height: lower - 2 * AdaptiveDeckGeometry.inset, previewStripHeight: cap)
    #expect(taller.footerHeight == shorter.footerHeight)
    #expect(cap <= 36)
    #expect(cap <= (lower - 2 * AdaptiveDeckGeometry.inset) * 0.35)
}

@Test(arguments: [0.0, 160, 310]) func duoInnerDecksAndLibraryMeetWithoutAHandleRow(libraryExtent: Double) {
    let height = 669.0
    let layout = PerformanceWorkspaceGeometry(width: 951, height: height, libraryExtent: libraryExtent, handleExtent: 0)
    #expect(layout.deckArea.maxY == layout.libraryArea.minY)
    #expect(Double(layout.libraryArea.maxY) == height)
    #expect(Double(layout.deckArea.height) == height - libraryExtent)
}

@Test(arguments: [380.0, 440, 669]) func duoDockStacksControlsAlongTheEdge(height: Double) {
    let dock = PerformanceDockGeometry(width: 951, height: height, deckBoundary: height / 2, edgeAligned: true)
    #expect(dock.fits == (height >= 440))
    #expect(dock.crossfader.height >= 88)
    #expect(dock.crossfader.maxX == 951)
    for buttons in [dock.aButtons, dock.bButtons] {
        #expect(buttons.allSatisfy { $0.width == 96 && $0.height >= 44 && $0.minX == dock.crossfader.minX })
        for index in 1..<buttons.count {
            #expect(abs(buttons[index].minY - buttons[index - 1].maxY) < 0.000001)
        }
    }
    #expect(dock.aButtons[0].minY == 0)
    #expect(abs(Double(dock.bButtons.last!.maxY) - dock.contentHeight) < 0.000001)
    let standard = PerformanceDockGeometry(width: 951, height: height)
    #expect(standard.aButtons[0].width == 80)
}

@Test(arguments: [320.0, 466, 678], [44.0, 78])
func duoFrontControlRowMeetsTheDisplayEdges(width: Double, controlsHeight: Double) {
    let height = 570.0
    for browserExtent in [0.0, 175, 600] {
        let layout = FrontWorkspaceGeometry(
            width: width, height: height, browserExtent: browserExtent, controlsHeight: controlsHeight)
        #expect(layout.controls.minX == 0)
        #expect(Double(layout.controls.maxX) == width)
        #expect(Double(layout.controls.maxY) == height)
        #expect(Double(layout.controls.height) == controlsHeight)
        #expect(layout.handle.minX == layout.controls.minX)
        #expect(layout.handle.maxX == layout.controls.maxX)
        #expect(layout.library.maxY == layout.controls.minY)
    }
}
