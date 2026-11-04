import CoreGraphics
import Foundation

@main enum BrowserLayoutChecks {
    static func main() {
        var checks = 0
        var failures = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition {
                failures += 1
                print("FAIL: \(message)")
            }
        }
        for width in [320.0, 375, 430, 599, 600, 619, 744, 834, 1112] {
            expect(
                BrowserPresentation.select(isPhone: false, windowWidth: width) == .standard,
                "iPad keeps its existing layout at every window width")
        }
        for (width, front) in [
            (320.0, true), (375, true), (430, true), (599, true), (600, false), (619, false), (744, false),
            (834, false), (1112, false),
        ] {
            expect(
                (BrowserPresentation.select(isPhone: true, windowWidth: width) == .frontPhone) == front,
                "only a compact phone window receives the front-screen design")
        }
        for width in [0.0, -1, .nan, .infinity] {
            expect(
                BrowserPresentation.select(isPhone: true, windowWidth: width) == .standard,
                "unknown geometry cannot opt into the front-screen design")
        }
        var standard = StandardBrowserLayoutState(categoriesHidden: true)
        expect(!standard.detailHidden, "existing wide browser opens its detail column")
        standard.showCategories()
        expect(!standard.categoriesHidden && !standard.detailHidden, "wide browser retains independent side columns")
        _ = standard.endDetail(translation: 150, velocity: 0, width: 400)
        expect(standard.detailHidden && !standard.categoriesHidden, "closing wide details leaves categories visible")
        standard.showDetail()
        expect(!standard.detailHidden && !standard.categoriesHidden, "restoring wide details retains categories")
        var state = BrowserLayoutState(categoriesHidden: true)
        expect(state.detailHidden, "opening Songs gives the list all available width")
        state.showDetail()
        state.showCategories()
        expect(state.detailHidden && !state.categoriesHidden, "Sources replaces Details")
        state.showDetail()
        expect(state.categoriesHidden && !state.detailHidden, "Details replaces Sources")
        for tab in BrowserListTab.allCases {
            state.showDetail()
            state.selectTab(tab)
            expect(state.tab == tab, "requested list is selected")
            expect(state.detailHidden && state.categoriesHidden, "switching lists closes drawers")
            expect(state.detailOffset == 0 && state.categoryOffset == 0, "switching lists clears stale drags")
        }
        state.showDetail()
        state.dragDetail(translation: 90)
        expect(state.detailOffset == 90, "Details follows the closing drag")
        expect(!state.endDetail(translation: 90, velocity: 50, width: 400), "short slow drag keeps Details")
        expect(state.endDetail(translation: 150, velocity: 0, width: 400), "long drag hides Details")
        state.showCategories()
        expect(!state.endDetail(translation: -40, velocity: -900, width: 400), "opening flick reveals Details")
        expect(state.categoriesHidden, "opening Details by gesture closes Sources")
        expect(!state.endCategories(translation: 20, velocity: 900, width: 180), "opening flick reveals Sources")
        expect(state.detailHidden, "opening Sources by gesture closes Details")
        expect(state.endCategories(translation: -90, velocity: 0, width: 180), "long drag hides Sources")
        state.showDetail()
        _ = state.endDetail(translation: .nan, velocity: 900, width: 400)
        expect(!state.detailHidden && state.detailOffset == 0, "invalid drag cannot dismiss Details")
        for (width, height) in [(834.0, 1052.0), (768, 964), (1112, 774), (619, 880)] {
            let dock = PerformanceDockGeometry(width: width, height: height)
            for extent in [180.0, 320, 600, 800] {
                let workspace = PerformanceWorkspaceGeometry(width: width, height: height, libraryExtent: extent)
                let browser = BrowserContentGeometry(
                    width: workspace.libraryArea.width, height: workspace.libraryArea.height)
                expect(
                    browser.listArea.minX == 0 && browser.listArea.width == width - 96,
                    "songs and suggestions have no reserved side columns")
                expect(browser.drawerWidth <= browser.listArea.width, "drawer fits inside browser")
                expect(browser.listArea.maxY <= workspace.libraryArea.height, "list fits inside library")
                expect(
                    workspace.dock.aButtons == dock.aButtons && workspace.dock.bButtons == dock.bButtons
                        && workspace.dock.crossfader == dock.crossfader, "library keeps performance anchors")
                let globalList = browser.listArea.offsetBy(
                    dx: workspace.libraryArea.minX, dy: workspace.libraryArea.minY)
                expect(
                    !(dock.aButtons + dock.bButtons + [dock.crossfader]).contains { $0.intersects(globalList) },
                    "browser content cannot cover a performance control")
            }
        }
        for (width, height) in [(0.0, 0.0), (-1, -2), (.nan, .infinity)] {
            let browser = BrowserContentGeometry(width: width, height: height)
            expect(
                [browser.listArea.width, browser.listArea.height, browser.drawerWidth].allSatisfy {
                    $0.isFinite && $0 >= 0
                }, "invalid dimensions remain finite and non-negative")
        }
        print("\(checks) browser navigation and geometry checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
