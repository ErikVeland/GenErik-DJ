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
    #expect(cap <= 24)
    #expect(cap <= (lower - 2 * AdaptiveDeckGeometry.inset) * 0.35)
}

@Test(arguments: [22.0, 44], [21.0, 34]) func duoKeepsLiftedControlsClearOfTheBottomInset(
    handleExtent: Double, safeInset: Double
) {
    let fullHeight = 669.0
    let safeBottom = fullHeight - safeInset
    let bottom = InnerPhoneBottomLayout(height: fullHeight, safeInset: safeInset, handleExtent: handleExtent)
    let closed = PerformanceWorkspaceGeometry(width: 951, height: bottom.height, libraryExtent: 0, handleExtent: handleExtent)
    let open = PerformanceWorkspaceGeometry(width: 951, height: bottom.height, libraryExtent: 160, handleExtent: handleExtent)

    #expect(bottom.height > safeBottom)
    #expect(bottom.height <= fullHeight - 12)
    #expect(closed.deckArea.maxY <= safeBottom)
    #expect(closed.deckArea.maxY + handleExtent - bottom.handleLift(deckHeight: closed.deckArea.height) == safeBottom)
    #expect(bottom.dockHeight(deckHeight: closed.deckArea.height) + max(44, handleExtent) == safeBottom)
    #expect(bottom.handleLift(deckHeight: open.deckArea.height) == 0)
    #expect(bottom.dockHeight(deckHeight: open.deckArea.height) == Double(open.deckArea.height))
    #expect(open.libraryArea.maxY - bottom.reclaimedHeight == safeBottom)
}

@Test(arguments: [264.0, 380, 560]) func duoDockWrapsControlsWithoutReducingTouchTargets(height: Double) {
    let dock = PerformanceDockGeometry(width: 951, height: height, deckBoundary: height / 2, wrapsControls: true)
    #expect(dock.fits)
    #expect(dock.crossfader.height >= 88)
    for buttons in [dock.aButtons, dock.bButtons] {
        #expect(buttons[0].minY == buttons[1].minY)
        #expect(buttons[2].minY == buttons[3].minY)
        #expect(buttons[0].maxX == buttons[1].minX)
        #expect(buttons.allSatisfy { $0.width >= 44 && $0.height >= 44 && $0.maxY <= dock.workArea.height })
    }
    let standard = PerformanceDockGeometry(width: 951, height: height)
    #expect(standard.aButtons[0].maxY == standard.aButtons[1].minY)
    #expect(standard.aButtons[0].width == 80)
}
