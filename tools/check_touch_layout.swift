import Foundation
import CoreGraphics

@main
enum TouchLayoutChecks {
    static func main() {
        var checks = 0
        var failures = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL: \(message)") }
        }
        let viewports: [(Double, Double)] = [
            (1112, 774), (834, 1052), (1024, 708), (768, 964),
            (880, 619), (619, 880), (744, 1073), (1133, 684),
        ]
        for (width, height) in viewports {
            let baseline = PerformanceDockGeometry(width: width, height: height)
            let targets = baseline.aButtons + baseline.bButtons + [baseline.crossfader]
            expect(baseline.fits, "supported viewport \(width)x\(height)")
            expect(baseline.aButtons.count == 4 && baseline.bButtons.count == 4, "both four-button stacks")
            expect(baseline.crossfader.minY == baseline.aButtons[3].maxY, "crossfader starts at A Play boundary")
            expect(baseline.crossfader.maxY == baseline.bButtons[0].minY, "crossfader fills gap to B FX boundary")
            for (index, target) in targets.enumerated() {
                expect(target.width >= 44 && target.height >= 44, "usable target \(index)")
                expect(CGRect(x: 0, y: 0, width: width, height: height).contains(target), "target inside window")
                expect(!baseline.workArea.intersects(target), "work area cannot cover dock")
                for other in targets.dropFirst(index + 1) {
                    expect(!target.intersects(other), "dock targets do not intersect")
                }
            }
            for visible in [false, true] {
                for share in [0.0, 0.1, 0.25, 0.5, 0.72, 0.95, 1.0] {
                    let layout = PerformanceWorkspaceGeometry(width: width, height: height,
                        browserVisible: visible, deckShare: share)
                    expect(layout.dock.aButtons == baseline.aButtons, "A anchors through resize")
                    expect(layout.dock.bButtons == baseline.bButtons, "B anchors through resize")
                    expect(layout.dock.crossfader == baseline.crossfader, "fader anchor through resize")
                    expect(layout.deckArea.maxX <= baseline.workArea.maxX, "deck width reserves dock")
                    expect(layout.libraryArea.maxX <= baseline.workArea.maxX, "library width reserves dock")
                    expect(layout.deckArea.maxY <= layout.libraryArea.minY, "library does not cover decks")
                    expect(layout.libraryArea.maxY <= height, "library stays inside workspace")
                }
            }
        }
        for (width, height) in [(80.0, 300.0), (300, 500), (0, 0), (-20, -10), (.nan, .infinity)] {
            let geometry = PerformanceDockGeometry(width: width, height: height)
            expect(!geometry.fits, "unsupported viewport is explicit")
            let rectangles = geometry.aButtons + geometry.bButtons + [geometry.crossfader, geometry.workArea]
            expect(rectangles.allSatisfy { [$0.minX, $0.minY, $0.width, $0.height].allSatisfy { $0.isFinite && $0 >= 0 } },
                "unsupported and invalid geometry remains finite and non-negative")
        }
        print("\(checks) anchor and workspace checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
