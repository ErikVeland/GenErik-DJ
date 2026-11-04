import Foundation
import CoreGraphics

@main
enum FrontPerformanceChecks {
    static func main() {
        var checks = 0
        var failures = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL: \(message)") }
        }
        expect(FrontLibraryPresentation.resolve(count: 0, catalogueReady: false, catalogueRefreshing: true,
            projecting: false, requestReady: true, hasQuery: false, error: nil) == .loading,
            "an empty early projection cannot report an empty library during catalogue loading")
        expect(FrontLibraryPresentation.resolve(count: 0, catalogueReady: false, catalogueRefreshing: false,
            projecting: false, requestReady: true, hasQuery: false, error: nil) == .loading,
            "an unread catalogue cannot report an empty library")
        expect(FrontLibraryPresentation.resolve(count: 0, catalogueReady: true, catalogueRefreshing: true,
            projecting: false, requestReady: true, hasQuery: false, error: nil) == .loading,
            "refreshing an empty catalogue cannot show a completed empty state")
        expect(FrontLibraryPresentation.resolve(count: 0, catalogueReady: true, catalogueRefreshing: false,
            projecting: false, requestReady: false, hasQuery: false, error: nil) == .loading,
            "a changed request waits for its own projection")
        expect(FrontLibraryPresentation.resolve(count: 0, catalogueReady: true, catalogueRefreshing: false,
            projecting: false, requestReady: true, hasQuery: false, error: nil) == .empty,
            "a completed empty catalogue may report no songs")
        expect(FrontLibraryPresentation.resolve(count: 0, catalogueReady: true, catalogueRefreshing: false,
            projecting: false, requestReady: true, hasQuery: true, error: nil) == .noMatches,
            "a completed search distinguishes no matches")
        expect(FrontLibraryPresentation.resolve(count: 4, catalogueReady: false, catalogueRefreshing: true,
            projecting: true, requestReady: false, hasQuery: false, error: nil) == .content,
            "known songs remain visible while the catalogue refreshes")
        expect(FrontLibraryPresentation.resolve(count: 0, catalogueReady: false, catalogueRefreshing: false,
            projecting: false, requestReady: true, hasQuery: false, error: "Permission denied") == .failed("Permission denied"),
            "catalogue failure is not an empty library")
        expect(FrontDeckSwipePolicy.direction(horizontal: -80, vertical: 8, velocity: -100) == .next,
            "left swipe selects B")
        expect(FrontDeckSwipePolicy.direction(horizontal: 80, vertical: 8, velocity: 100) == .previous,
            "right swipe selects A")
        expect(FrontDeckSwipePolicy.direction(horizontal: 20, vertical: 3, velocity: 700) == .previous,
            "a deliberate short flick may switch")
        expect(FrontDeckSwipePolicy.direction(horizontal: 8, vertical: 0, velocity: 2000) == nil,
            "tap drift cannot become a deck switch")
        expect(FrontDeckSwipePolicy.direction(horizontal: 80, vertical: 100, velocity: 900) == nil,
            "vertical list scrolling cannot switch decks")
        expect(FrontDeckSwipePolicy.direction(horizontal: 70, vertical: 60, velocity: 900) == nil,
            "ambiguous diagonal gestures do not switch")
        expect(FrontDeckSwipePolicy.direction(horizontal: .nan, vertical: 0, velocity: 1000) == nil,
            "invalid input cannot switch")
        let bounds = CGRect(x: 0, y: 0, width: 375, height: 700)
        let blocked = [CGRect(x: 0, y: 604, width: 375, height: 52), CGRect(x: 0, y: 656, width: 375, height: 44)]
        expect(FrontDeckSwipePolicy.allowsStart(at: CGPoint(x: 160, y: 30), bounds: bounds, protected: blocked),
            "A/B selector accepts a deck swipe")
        expect(FrontDeckSwipePolicy.allowsStart(at: CGPoint(x: 160, y: 200), bounds: bounds, protected: blocked),
            "unclaimed space accepts a deck swipe")
        expect(!FrontDeckSwipePolicy.allowsStart(at: CGPoint(x: 160, y: 630), bounds: bounds, protected: blocked),
            "transport cannot start a deck swipe")
        expect(!FrontDeckSwipePolicy.allowsStart(at: CGPoint(x: 160, y: 675), bounds: bounds, protected: blocked),
            "crossfader cannot start a deck swipe")
        expect(!FrontDeckSwipePolicy.allowsStart(at: CGPoint(x: 380, y: 200), bounds: bounds, protected: blocked),
            "a touch outside the front workspace cannot switch decks")
        var selection = FrontDeckSelection(selected: "A")
        let aContact = selection.contactID
        selection.select("B")
        expect(selection.selected == "B", "A/B changes only the selected deck identity")
        expect(selection.contactID != aContact, "old deck contacts are retired")
        let bContact = selection.contactID
        selection.select("B")
        expect(selection.contactID == bContact, "reselecting the same deck preserves its contacts")
        selection.select("A")
        expect(selection.selected == "A" && selection.contactID != aContact, "returning to A cannot revive old contacts")
        let current = selection.contactID
        selection.interrupt()
        expect(selection.contactID != current && selection.selected == "A", "interruption retires input without switching decks")

        var panel = FrontBrowserPanelState()
        panel.configure(width: 375, height: 700)
        panel.apply(.browse)
        expect(panel.extent == 248, "Browse shares the 496-point body equally")
        panel.apply(.expand)
        expect(panel.extent == 432, "Expand keeps a 64-point deck overview")
        panel.beginDrag()
        panel.updateDrag(translation: -132)
        panel.endDrag(velocity: 0)
        expect(panel.extent == 300, "manual browser sizing is retained")
        let browserContact = panel.contactID
        panel.apply(.performance)
        expect(panel.extent == 0 && !panel.acceptsContentInput, "Performance hides browser input")
        expect(panel.contactID != browserContact, "hiding browser retires held loader contacts")
        panel.setPresented(true)
        expect(panel.extent == 300, "ordinary reopening restores manual browser space")
        let retainedBrowserContact = panel.contactID
        panel.beginDrag()
        panel.updateDrag(translation: -100)
        panel.apply(.expand)
        panel.updateDrag(translation: -400)
        panel.endDrag(velocity: -900)
        expect(panel.extent == 432 && !panel.isDragging, "shortcut rejects stale resize events")
        expect(panel.contactID == retainedBrowserContact, "visible browser resizing does not retire loader contacts")
        panel.beginDrag()
        panel.updateDrag(translation: -100)
        panel.cancelDrag()
        expect(panel.extent == 432, "cancel restores browser size")
        panel.configure(width: 375, height: 400)
        expect(panel.extent <= 196 && !panel.isDragging, "keyboard geometry clamps browser size")

        for (width, height) in [(320.0, 568.0), (375, 700), (430, 820), (599, 800)] {
            let base = FrontWorkspaceGeometry(width: width, height: height, browserExtent: 0)
            for extent in [0.0, 50, 220, 300, 10000] {
                let layout = FrontWorkspaceGeometry(width: width, height: height, browserExtent: extent)
                expect(layout.deck.width == width && layout.library.width == width, "one deck and browser use full phone width")
                expect(layout.selector == base.selector && layout.controls == base.controls && layout.crossfader == base.crossfader,
                    "browser motion retains selector, transport and mixer anchors")
                expect(layout.deck.maxY == layout.handle.minY && layout.handle.maxY == layout.library.minY,
                    "resize handle separates musical and browsing content")
                expect(layout.library.maxY == layout.controls.minY, "browser cannot cover selected-deck controls")
                expect(layout.controls.height >= 44 && layout.crossfader.height >= 44, "essential targets remain reachable")
                let rects = [layout.selector, layout.deck, layout.handle, layout.library, layout.controls, layout.crossfader]
                expect(rects.allSatisfy { CGRect(x: 0, y: 0, width: width, height: height).contains($0) },
                    "all front regions stay inside the viewport")
            }
        }
        let scaled = FrontWorkspaceGeometry(width: 375, height: 700, browserExtent: 10000,
            selectorHeight: 100, controlsHeight: 76)
        expect(scaled.selector.height == 100 && scaled.controls.height == 76, "larger text receives larger selector and control rows")
        expect(scaled.library.maxY == scaled.controls.minY && scaled.crossfader.maxY == 700,
            "larger rows preserve browser and mixer boundaries")
        for (width, height) in [(0.0, 0.0), (-1, -10), (.nan, .infinity), (320, 100)] {
            let layout = FrontWorkspaceGeometry(width: width, height: height, browserExtent: .nan)
            expect([layout.deck.width, layout.deck.height, layout.library.height, layout.maximumBrowserExtent].allSatisfy { $0.isFinite && $0 >= 0 },
                "invalid and constrained geometry stays finite and non-negative")
        }
        for width in [320.0, 375, 430, 599, 619, 834, 1112] {
            expect(BrowserPresentation.select(isPhone: false, windowWidth: width) == .standard, "iPad never uses the front workspace")
        }
        for width in [600.0, 619, 744, 834] {
            expect(BrowserPresentation.select(isPhone: true, windowWidth: width) == .standard, "inside windows retain the existing workspace")
        }
        print("\(checks) front performance checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
