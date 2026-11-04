import CoreGraphics
import Foundation

@main enum SectionWorkspaceChecks {
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
        let compact = PanelHandleMetrics(expanded: false)
        let accessible = PanelHandleMetrics(expanded: true)
        expect(
            compact.extent == 12 && accessible.extent == 44,
            "quiet handles are the default alternative to expanded accessibility handles")
        let load = UUID()
        var editor = SectionEditorPanelState()
        editor.configure(height: 420, portrait: false, handleExtent: compact.extent)
        expect(!editor.isPresented && editor.session == nil && editor.extent == 0, "section editor starts closed")
        editor.open(trackID: "one", loadID: load)
        let session = editor.session!
        expect(
            editor.extent == 260 && session.matches(trackID: "one", loadID: load),
            "opening captures the exact loaded track")
        editor.beginDrag()
        editor.updateDrag(translation: 31)
        editor.endDrag(velocity: 0)
        expect(editor.extent == 291, "editor retains an arbitrary direct size")
        editor.setPresented(false)
        editor.setPresented(true)
        expect(
            editor.extent == 291 && editor.session?.id == session.id, "hide and reopen preserve size and draft identity"
        )
        editor.beginDrag()
        editor.updateDrag(translation: -1000)
        expect(
            editor.isPresented && editor.extent == 0 && editor.session?.id == session.id,
            "zero-height preview does not remove the editor")
        editor.cancelDrag()
        expect(editor.extent == 291 && editor.isPresented, "cancel restores editor size and presentation")
        editor.configure(height: 200, portrait: false, handleExtent: 12)
        expect(editor.extent == 136 && editor.session?.id == session.id, "compact deck clips the same editor session")
        editor.configure(height: 420, portrait: false, handleExtent: 12)
        expect(editor.extent == 291, "restoring deck space restores the chosen editor size")
        editor.configure(height: 600, portrait: true, handleExtent: 12)
        expect(
            editor.extent == 260 && editor.session?.id == session.id,
            "orientation has separate size memory without replacing the draft")
        editor.beginDrag()
        editor.updateDrag(translation: 81)
        editor.endDrag(velocity: 0)
        editor.configure(height: 420, portrait: false, handleExtent: 12)
        expect(editor.extent == 291, "landscape size is remembered")
        editor.configure(height: 600, portrait: true, handleExtent: 12)
        expect(editor.extent == 341, "portrait size is remembered")
        expect(!session.matches(trackID: "two", loadID: load), "different track cannot receive a stale save")
        expect(!session.matches(trackID: "one", loadID: UUID()), "reloading the same track cannot receive a stale save")
        editor.validate(trackID: "one", loadID: UUID())
        expect(editor.session == nil && !editor.isPresented, "changed load identity discards the old edit")
        editor.open(trackID: "two", loadID: load)
        editor.discard()
        expect(editor.session == nil && editor.extent == 0, "Cancel discards rather than hides the draft")
        editor.open(trackID: "two", loadID: load)
        editor.validate(trackID: nil, loadID: nil)
        expect(editor.session == nil && !editor.isPresented, "unloading closes the editor without a stale apply")

        let panels = DeckPanelPresentation()
        panels.configure(width: 1004, portrait: false, handleExtent: 12)
        expect(
            !panels.extraVisible && !panels.effectsVisible && !panels.mixerVisible,
            "empty decks have no open action tray")
        panels.toggle(.extra)
        expect(!panels.extraVisible, "empty deck cannot open a blank action tray")
        panels.setTrackAvailable(true)
        panels.toggle(.extra)
        expect(panels.extraVisible, "loaded deck can open its action controls")
        panels.setTrackAvailable(false)
        expect(
            !panels.extraVisible && panels.geometry(width: 1004, height: 240).extraWidth == 0,
            "unloading reclaims the action tray width")
        let small = DeckPanelsGeometry(width: 1004, height: 240, effects: 200, mixer: 0, extra: 0, handleExtent: 12)
        let large = DeckPanelsGeometry(width: 1004, height: 180, effects: 200, mixer: 0, extra: 0, handleExtent: 44)
        let viewport = TouchSurfaceViewport(
            size: CGSize(width: 1112, height: 834), orientation: 3, interruption: UUID())
        var held = TouchContactGeometry(policy: .retainContactSpace)
        expect(
            held.begin(id: 1, frame: small.waveform, viewport: viewport), "musical contact captures compact geometry")
        let finger = CGPoint(x: small.waveform.midX, y: small.waveform.midY)
        expect(
            !held.requiresCancellation(frame: large.waveform, viewport: viewport),
            "changing handle size does not cancel a held musical contact")
        expect(
            held.point(id: 1, location: finger, frame: large.waveform) == SurfacePoint(id: 1, x: 0.5, y: 0.5),
            "held musical value survives changing handle policy")
        for extent in [compact.extent, accessible.extent] {
            for (width, height) in [(1112.0, 774.0), (834, 1052), (768, 964)] {
                let dock = PerformanceDockGeometry(width: width, height: height)
                let maximum = AdaptivePerformanceLayout.maximumLibraryExtent(available: height, handleExtent: extent)
                for library in [0.0, maximum / 2, maximum] {
                    let work = PerformanceWorkspaceGeometry(
                        width: width, height: height, libraryExtent: library, handleExtent: extent)
                    let split = DeckSplitGeometry(
                        width: work.deckArea.width, height: work.deckArea.height, share: 0.8, handleExtent: extent)
                    expect(
                        work.dock.workArea.width == dock.workArea.width
                            && work.dock.workArea.height == work.deckArea.height,
                        "both handle sizes keep side controls aligned with the decks")
                    expect(
                        split.a.height >= 0 && split.b.height >= 0
                            && split.handle.height == min(extent, work.deckArea.height),
                        "deck geometry fits while the browser expands")
                    expect(
                        work.libraryArea.minY - work.deckArea.maxY == extent,
                        "library reserves only the selected grab thickness")
                    let panels = DeckPanelsGeometry(
                        width: work.deckArea.width, height: 240, effects: 200, mixer: 200, extra: 0,
                        handleExtent: extent)
                    expect(
                        panels.effectsHandle.width == extent && panels.mixerHandle.width == extent,
                        "side grab geometry matches the visual policy")
                    expect(
                        panels.waveform.minX == panels.effectsHandle.maxX
                            && panels.waveform.maxX == panels.mixerHandle.minX, "quiet grabs never cover musical input")
                }
            }
        }
        print("\(checks) section editor and quiet workspace checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
