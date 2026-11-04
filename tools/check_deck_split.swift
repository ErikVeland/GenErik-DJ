import Foundation
import CoreGraphics

@main
enum DeckSplitChecks {
    @MainActor static func main() {
        var checks = 0, failures = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL: \(message)") }
        }
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.000001 }
        var split = DeckSplitState()
        split.updateViewport(width: 1112, height: 774)
        let initial = split.geometry(width: 1004, height: 700)
        expect(initial.a.height == initial.b.height, "first split gives both decks equal space")
        split.beginDrag(height: 700)
        split.updateDrag(translation: 83)
        let preview = split.geometry(width: 1004, height: 700)
        expect(near(preview.a.height, initial.a.height + 83), "divider follows finger one point per point")
        split.updateDrag(translation: 100)
        expect(near(split.geometry(width: 1004, height: 700).a.height, initial.a.height + 100), "updates use touch-down rather than accumulated travel")
        split.endDrag(height: 700)
        let settled = split.geometry(width: 1004, height: 700)
        expect(near(settled.a.height, initial.a.height + 100), "release keeps the exact chosen size")
        expect(!split.isDragging, "release ends resize ownership")
        let ratio = settled.a.height / (settled.a.height + settled.b.height)
        expect(near(split.geometry(width: 1004, height: 400).a.height, (400 - 44) * ratio), "library resize retains preferred deck proportion")
        _ = split.geometry(width: 1004, height: 148)
        expect(split.geometry(width: 1004, height: 700).a == settled.a, "library maximum does not overwrite preferred balance")
        split.beginDrag(height: 148)
        split.updateDrag(translation: 40)
        split.endDrag(height: 148)
        expect(split.geometry(width: 1004, height: 700).a == settled.a, "no-room grab cannot erase preferred balance")
        split.beginDrag(height: 700)
        split.updateDrag(translation: -200)
        split.cancelDrag()
        expect(split.geometry(width: 1004, height: 700).a == settled.a, "cancel restores the preceding size")
        split.updateDrag(translation: 150)
        expect(split.geometry(width: 1004, height: 700).a == settled.a, "stale resize cannot alter settled size")
        split.updateViewport(width: 834, height: 1052)
        expect(split.geometry(width: 726, height: 900).a.height == 428, "portrait starts with its own equal split")
        split.adjust(by: -90, height: 900)
        let portrait = split.geometry(width: 726, height: 900)
        expect(near(portrait.a.height, 338), "accessible adjustment uses direct point travel")
        split.updateViewport(width: 1112, height: 774)
        expect(split.geometry(width: 1004, height: 700).a == settled.a, "landscape restores its independent size")
        split.beginDrag(height: 700)
        split.updateDrag(translation: 40)
        split.updateViewport(width: 834, height: 1052)
        expect(!split.isDragging && split.geometry(width: 726, height: 900).a == portrait.a, "rotation cancels old preview and restores orientation memory")
        split.updateViewport(width: 1112, height: 774)
        expect(split.geometry(width: 1004, height: 700).a == settled.a, "rotation did not save an unfinished drag")
        split.beginDrag(height: 700)
        split.updateDrag(translation: 20)
        expect(near(split.geometry(width: 1004, height: 600).a.height, settled.a.height + 20), "library motion during a grab retains its absolute finger origin")
        split.endDrag(height: 600)
        let afterLibrary = split.geometry(width: 1004, height: 600)
        expect(near(afterLibrary.a.height, settled.a.height + 20), "release uses the current available height")
        split.beginDrag(height: 600)
        split.updateDrag(translation: -25)
        split.endDrag(height: 148)
        expect(split.geometry(width: 1004, height: 600).a == afterLibrary.a, "library reaching maximum cancels rather than saving a forced equal split")
        split.balance()
        expect(split.geometry(width: 1004, height: 500).a.height == 228, "balance action returns to equal decks")
        split.beginDrag(height: 500)
        split.updateDrag(translation: .nan)
        expect(split.geometry(width: 1004, height: 500).a.height == 228, "non-finite movement is ignored")
        split.endDrag(height: .infinity)
        expect(!split.isDragging && split.geometry(width: 1004, height: 500).a.height == 228, "invalid release restores the last balance")

        let viewport = TouchSurfaceViewport(size: CGSize(width: 1112, height: 834), orientation: 3, interruption: UUID())
        for (width, height) in [(1112.0, 774.0), (834, 1052), (880, 619), (619, 880)] {
            let dock = PerformanceDockGeometry(width: width, height: height)
            for library in [0.0, 200, AdaptivePerformanceLayout.maximumLibraryExtent(available: height)] {
                let workspace = PerformanceWorkspaceGeometry(width: width, height: height, libraryExtent: library)
                for share in [0.0, 0.1, 0.5, 0.9, 1.0] {
                    let layout = DeckSplitGeometry(width: workspace.deckArea.width - 12, height: workspace.deckArea.height, share: share)
                    expect(layout.a.height >= 52 && layout.b.height >= 52, "both compact deck targets remain reachable")
                    expect(layout.handle.height == 44, "divider has a dedicated 44-point lane")
                    expect(layout.a.maxY == layout.handle.minY && layout.handle.maxY == layout.b.minY, "grab lane never overlays a deck")
                    expect(near(layout.b.maxY, workspace.deckArea.height), "split fills the available deck region")
                    expect(workspace.dock.aButtons == dock.aButtons && workspace.dock.bButtons == dock.bButtons && workspace.dock.crossfader == dock.crossfader, "both divider extremes retain every dock anchor")
                    for (id, original, resized) in [(1, CGRect(x: 58, y: 80, width: 450, height: 220), layout.a), (2, CGRect(x: 58, y: 420, width: 450, height: 220), layout.b)] {
                        var contact = TouchContactGeometry(policy: .retainContactSpace)
                        expect(contact.begin(id: id, frame: original, viewport: viewport), "deck contact is admitted")
                        let finger = CGPoint(x: original.midX, y: original.midY)
                        let before = contact.point(id: id, location: finger, frame: original)
                        expect(!contact.requiresCancellation(frame: resized, viewport: viewport), "deck resize cannot cancel a held contact")
                        expect(contact.point(id: id, location: finger, frame: resized) == before, "held value survives A height and B origin changes")
                    }
                }
            }
        }
        for height in [0.0, 20, 44, 100, .nan, .infinity, -10] {
            let layout = DeckSplitGeometry(width: .nan, height: height, share: .nan)
            expect([layout.a, layout.handle, layout.b].allSatisfy { [$0.minX, $0.minY, $0.width, $0.height].allSatisfy { $0.isFinite && $0 >= 0 } }, "invalid and unsupported geometry remains finite")
        }
        print("\(checks) deck divider checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
