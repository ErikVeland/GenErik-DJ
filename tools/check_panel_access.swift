import CoreGraphics
import Foundation

@main enum PanelAccessChecks {
    @MainActor static func main() {
        var checks = 0
        var failures = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition {
                failures += 1
                print("FAIL: \(message)")
            }
        }
        let compact = AdaptiveDeckGeometry(height: 44, compactControls: true)
        expect(
            compact.headerHeight > 0 && compact.footerHeight > 0,
            "compact deck retains its artwork and bottom time anchors")
        let expanded = AdaptiveDeckGeometry(height: 336, compactControls: true)
        expect(expanded.waveformHeight >= 264, "normal deck gives at least 264 points to the detailed waveform")
        for height in [44.0, 60, 104, 172, 336, 700] {
            let layout = AdaptiveDeckGeometry(height: height)
            expect(
                layout.headerHeight > 0 && layout.footerHeight > 0, "both corner bands remain present while resizing")
            expect(
                abs(layout.headerHeight + layout.footerHeight + layout.waveformHeight - height) < 0.001,
                "corner bands leave every remaining point to the waveform")
        }
        for height in [720.0, 964] {
            let library = AdaptivePerformanceLayout.maximumLibraryExtent(available: height, handleExtent: 12)
            let workspace = PerformanceWorkspaceGeometry(
                width: 1112, height: height, libraryExtent: library, handleExtent: 12)
            let split = DeckSplitGeometry(
                width: workspace.deckArea.width, height: workspace.deckArea.height, share: 0.5, handleExtent: 12)
            expect(
                split.a.height == 0 && split.b.height == 0 && split.handle.height == 0,
                "maximised browser collapses both decks and their divider")
            expect(library >= 132, "maximised browser remains usable")
        }
        let deck = DeckPanelPresentation()
        deck.configure(width: 1004, portrait: false, handleExtent: 12)
        expect(!deck.controlsEnabled, "empty deck disables the Controls entry")
        deck.setTrackAvailable(true)
        expect(deck.controlsEnabled, "loaded deck enables the Controls entry")
        expect(!deck.extraVisible, "loaded deck actions start collapsed above the preview strip")
        if deck.extraVisible { deck.toggleControls() }
        let full = deck.geometry(width: 1004, height: 240)
        expect(full.waveformWidth == full.mainWidth, "expanded waveforms use the space below the cover")
        deck.toggleEffects()
        expect(
            deck.geometry(width: 1004, height: 240).effectsContent.width == 454,
            "FX opens at half the available panel budget")
        deck.toggleMixer()
        expect(
            deck.geometry(width: 1004, height: 240).mixerContent.width == 454,
            "EQ opens at a substantial width beside FX")
        var cancellations = 0
        let fx = deck.effectsInput.register { cancellations += 1 }
        let eq = deck.mixerInput.register { cancellations += 1 }
        deck.toggleControls()
        let withControls = deck.geometry(width: 1004, height: 240)
        expect(
            deck.extraVisible && withControls.extraWidth == 0,
            "Controls opens even when FX and EQ have filled the panel budget")
        expect(
            withControls.effectsContent.width >= 200 && withControls.mixerContent.width >= 200,
            "opening Controls retains usable FX and EQ")
        expect(
            cancellations == 0 && deck.effectsInput.isEnabled && deck.mixerInput.isEnabled,
            "making room for Controls retains held FX and EQ")
        let before = withControls.mixerHandle.minX
        deck.begin(.mixer)
        deck.update(.mixer, translation: -16)
        expect(
            deck.geometry(width: 1004, height: 240).mixerHandle.minX == before + 16,
            "constrained EQ grab follows the finger without a dead zone")
        deck.cancel(.mixer)
        expect(
            deck.geometry(width: 1004, height: 240).mixerHandle.minX == before,
            "cancel restores the constrained EQ boundary")
        deck.toggleControls()
        expect(
            !deck.extraVisible && deck.geometry(width: 1004, height: 240).mixerContent.width == 454,
            "hiding Controls restores the chosen panel space")
        deck.begin(.effects)
        deck.update(.effects, translation: -64)
        deck.end(.effects, velocity: 0)
        deck.toggleEffects()
        deck.toggleEffects()
        expect(
            deck.geometry(width: 1004, height: 240).effectsContent.width == 390,
            "explicitly resized FX width survives reopening")
        deck.configure(width: 1204, portrait: false, handleExtent: 12)
        expect(
            deck.geometry(width: 1204, height: 240).effectsContent.width == 390,
            "full-screen expansion retains the user's chosen FX size")
        expect(
            deck.geometry(width: 1204, height: 240).mixerContent.width == 554,
            "untouched EQ defaults grow with the available workspace")
        deck.effectsInput.unregister(fx)
        deck.mixerInput.unregister(eq)
        deck.setTrackAvailable(false)
        expect(!deck.controlsEnabled && !deck.extraVisible, "unloading still closes empty Controls")
        var split = DeckSplitState()
        split.updateViewport(width: 1112, height: 774)
        split.beginDrag(height: 720, handleExtent: 12)
        split.updateDrag(translation: -1000)
        split.endDrag(height: 720, handleExtent: 12)
        split.ensureHeight(upper: true, minimum: 312, height: 720, handleExtent: 12)
        expect(
            split.geometry(width: 1004, height: 720, handleExtent: 12).a.height >= 312,
            "FX can request usable height for a compact upper deck")
        split.ensureHeight(upper: true, minimum: 600, height: 720, handleExtent: 12)
        split.ensureHeight(upper: false, minimum: 368, height: 720, handleExtent: 12)
        expect(
            split.geometry(width: 1004, height: 720, handleExtent: 12).b.height >= 368,
            "lower deck can make room for FX with hotcue pads")
        for width in [1004.0, 726] {
            let panels = DeckPanelPresentation()
            panels.setTrackAvailable(true)
            panels.configure(width: width, portrait: width < 800, handleExtent: 12)
            if panels.extraVisible { panels.toggleControls() }
            panels.toggleEffects()
            panels.toggleMixer()
            panels.toggleControls()
            let g = panels.geometry(width: width, height: 240)
            expect(panels.extraVisible && g.extraWidth == 0, "Controls remains reachable in both iPad orientations")
            expect(
                g.effectsContent.width >= 200 && g.mixerContent.width >= 200,
                "paired panes retain usable minimums with Controls")
        }
        print("\(checks) performance access checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
