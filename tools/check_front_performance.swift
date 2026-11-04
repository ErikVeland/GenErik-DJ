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
