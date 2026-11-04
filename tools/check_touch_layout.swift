import CoreGraphics
import Foundation

@main enum TouchLayoutChecks {
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
        let viewports: [(Double, Double)] = [
            (1112, 774), (834, 1052), (1024, 708), (768, 964), (880, 619), (619, 880), (744, 1073), (1133, 684),
        ]
        for (width, height) in viewports {
            let baseline = PerformanceDockGeometry(width: width, height: height)
            let targets = baseline.aButtons + baseline.bButtons + [baseline.crossfader]
            expect(baseline.fits, "supported viewport \(width)x\(height)")
            expect(baseline.aButtons.count == 4 && baseline.bButtons.count == 4, "both four-button stacks")
            expect(baseline.aButtons[0].minY == 0, "side buttons start at the top edge")
            expect(baseline.bButtons[3].maxY == height, "side buttons finish at the bottom edge")
            expect(baseline.crossfader.midY == height / 2, "crossfader is centred between equal decks")
            expect(baseline.crossfader.minY == baseline.aButtons[3].maxY, "crossfader starts at A Play boundary")
            expect(baseline.crossfader.maxY == baseline.bButtons[0].minY, "crossfader fills gap to B FX boundary")
            for (index, target) in targets.enumerated() {
                expect(target.width >= 44 && target.height >= 44, "usable target \(index)")
                expect(CGRect(x: 0, y: 0, width: width, height: height).contains(target), "target inside window")
                expect(!baseline.workArea.intersects(target), "work area cannot cover dock")
                for other in targets.dropFirst(index + 1) {
                    expect(
                        !target.intersects(other),
                        "dock targets \(target) and \(other) do not intersect at \(width)x\(height)")
                }
            }
            for visible in [false, true] {
                for share in [0.0, 0.1, 0.25, 0.5, 0.72, 0.95, 1.0] {
                    let layout = PerformanceWorkspaceGeometry(
                        width: width, height: height, browserVisible: visible, deckShare: share)
                    expect(layout.dock.aButtons[0].minY == 0, "upper controls retain the top edge")
                    expect(layout.dock.workArea.height == layout.deckArea.height, "side controls follow the visible deck area")
                    expect(layout.dock.workArea.width == baseline.workArea.width, "side controls retain their horizontal position")
                    expect(layout.deckArea.maxX <= baseline.workArea.maxX, "deck width reserves dock")
                    expect(layout.libraryArea.maxX <= baseline.workArea.maxX, "library width reserves dock")
                    expect(layout.deckArea.maxY <= layout.libraryArea.minY, "library does not cover decks")
                    expect(layout.libraryArea.maxY <= height, "library stays inside workspace")
                }
            }
        }
        for (width, height) in [(80.0, 300.0), (300, 400), (0, 0), (-20, -10), (.nan, .infinity)] {
            let geometry = PerformanceDockGeometry(width: width, height: height)
            expect(!geometry.fits, "unsupported viewport is explicit")
            let rectangles = geometry.aButtons + geometry.bButtons + [geometry.crossfader, geometry.workArea]
            expect(
                rectangles.allSatisfy {
                    [$0.minX, $0.minY, $0.width, $0.height].allSatisfy { $0.isFinite && $0 >= 0 }
                }, "unsupported and invalid geometry remains finite and non-negative")
        }
        print("\(checks) anchor and workspace checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
