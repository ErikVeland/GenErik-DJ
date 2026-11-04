import Foundation
import CoreGraphics

@main
enum BrowserColumnChecks {
    static func main() {
        var checks = 0, failures = 0
        func expect(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL: \(message)") }
        }
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.000001 }
        var state = BrowserColumnSizingState()
        state.configure(width: 1016, portrait: false, leading: .categories)
        state.setPresented(.detail, true)
        expect(state.geometry().detail.width == 320, "detail starts at a usable width")
        state.begin(.detail)
        state.update(.detail, translation: 61)
        expect(state.geometry().detail.width == 381, "detail boundary follows direct opening travel")
        state.end(.detail, velocity: 0)
        state.begin(.detail); state.update(.detail, translation: -1000)
        expect(state.geometry().detail.width == 0 && state.isPresented(.detail), "zero-width resize preview retains the held loader presentation")
        state.cancel(.detail)
        expect(state.geometry().detail.width == 381, "zero-width preview cancellation restores the detail size")
        state.setPresented(.detail, false)
        state.setPresented(.detail, true)
        expect(state.geometry().detail.width == 381, "detail reopening restores the chosen width")
        state.setPresented(.categories, true)
        expect(state.geometry().leading.width == 180, "category opening restores its default width")
        let detail = state.geometry().detail
        state.begin(.categories); state.update(.categories, translation: 31)
        expect(state.geometry().leading.width == 211 && state.geometry().detail == detail, "left resize leaves the right column width and edge stable")
        state.end(.categories, velocity: 0)
        state.setPresented(.categories, false); state.setPresented(.categories, true)
        expect(state.geometry().leading.width == 211, "categories remember their width")
        state.begin(.categories); state.update(.categories, translation: -500); state.cancel(.categories)
        expect(state.geometry().leading.width == 211, "cancel restores the preceding width")
        let detailCommand = state.presentationID(for: .detail)
        state.setPresented(.categories, false)
        expect(state.presentationID(for: .detail) == detailCommand, "unrelated column commands do not invalidate a detail grab")
        state.configure(width: 738, portrait: true, leading: .categories)
        expect(state.geometry().detail.width == 320, "portrait starts with its own detail width")
        state.begin(.detail); state.update(.detail, translation: -40); state.end(.detail, velocity: 0)
        state.configure(width: 1016, portrait: false, leading: .categories)
        expect(state.geometry().detail.width == 381, "landscape width survives rotation")
        state.configure(width: 738, portrait: true, leading: .categories)
        expect(state.geometry().detail.width == 280, "portrait width is independently remembered")
        state.setPresented(.categories, true)
        expect(state.geometry().leading.width == 180 && state.isPresented(.detail), "drawer size storage does not change unrelated presentation")
        state.setPresented(.categories, false); state.setPresented(.detail, true)
        state.begin(.categories); state.update(.categories, translation: 100)
        state.cancel(.categories)
        expect(!state.isPresented(.categories) && state.geometry().detail.width == 280, "cancel of an opening preserves the detail width")
        state.configure(width: 1016, portrait: false, leading: .playlists)
        state.setPresented(.detail, false)
        state.setPresented(.playlists, true)
        state.begin(.playlists); state.update(.playlists, translation: 49); state.end(.playlists, velocity: 0)
        expect(state.geometry().leading.width == 289, "playlist column can resize directly")
        state.configure(width: 1016, portrait: false, leading: .categories)
        state.setPresented(.categories, true)
        expect(state.geometry().leading.width == 211, "playlist resizing does not overwrite categories")
        state.configure(width: 1016, portrait: false, leading: .playlists)
        expect(state.geometry().leading.width == 289, "playlist navigation restores its own width")
        state.configure(width: 1016, portrait: false, leading: nil)
        expect(state.geometry().leading.width == 0 && state.geometry().leadingHandle.width == 0, "search temporarily frees the left column without changing its memory")
        state.configure(width: 1016, portrait: false, leading: .playlists)
        expect(state.geometry().leading.width == 289, "clearing search restores the playlist width")
        state.begin(.playlists); state.update(.playlists, translation: .nan)
        expect(state.geometry().leading.width == 289, "invalid travel is ignored")
        state.end(.playlists, velocity: .nan)
        expect(state.geometry().leading.width == 289 && !state.isDragging, "invalid release restores the saved size")
        state.begin(.playlists); state.update(.playlists, translation: -25); state.end(.playlists, velocity: -800)
        expect(!state.isPresented(.playlists), "closing flick retains a reveal handle")
        state.begin(.playlists); state.update(.playlists, translation: 20); state.end(.playlists, velocity: 800)
        expect(state.geometry().leading.width == 289, "opening flick restores the remembered width")

        for width in [1016.0, 738, 928, 672, 784, 523] {
            for left in [0.0, 80, 180, 300, 1000] {
                for right in [0.0, 100, 260, 400, 1000] {
                    let g = BrowserColumnsGeometry(width: width, leading: left, detail: right)
                    expect(g.list.width == width, "song list retains the full browser width beneath exclusive drawers")
                    expect(g.leadingHandle.width == 44 && g.detailHandle.width == 44, "both columns have dedicated 44-point grabs")
                    expect(g.leading.maxX == g.leadingHandle.minX && near(g.detailHandle.maxX, g.detail.minX), "dedicated grab strips stay outside drawer controls")
                    expect(near(g.detail.maxX, width), "detail stays attached to the browser edge")
                }
            }
        }
        var contact = LoadSliderContactGeometry()
        let original = CGRect(x: 850, y: 300, width: 104, height: 178)
        expect(contact.begin(frame: original), "loader captures its global frame")
        expect(!contact.begin(frame: CGRect(x: 100, y: 120, width: 80, height: 90)), "duplicate begin cannot replace the held loader frame")
        let start = contact.point(at: CGPoint(x: 902, y: 389))!
        expect(start.x == 0.5 && start.y == 0.5 && contact.height == 178, "loader normalization retains its original frame after an unrelated begin")
        var loader = LoadSliderGestureSession()
        expect(loader.handle(.init(phase: .began, points: [start], ending: []), height: 178, maximumTravel: TallLoadSliderMetrics.maximumTravel) == nil, "loader begin does not load a deck")
        for direction in [-1.0, 1.0] {
            loader = LoadSliderGestureSession()
            _ = loader.handle(.init(phase: .began, points: [start], ending: []), height: 178, maximumTravel: TallLoadSliderMetrics.maximumTravel)
            let stationary = contact.point(at: CGPoint(x: 902, y: 389))!
            expect(loader.handle(.init(phase: .moved, points: [stationary], ending: []), height: 178, maximumTravel: TallLoadSliderMetrics.maximumTravel) == nil && loader.offset == 0, "column or library motion cannot arm a stationary loader finger")
            let point = contact.point(at: CGPoint(x: 902, y: 389 + direction * TallLoadSliderMetrics.maximumTravel))!
            expect(loader.handle(.init(phase: .ended, points: [point], ending: [1]), height: 178, maximumTravel: TallLoadSliderMetrics.maximumTravel) == (direction < 0 ? .a : .b), "both loader directions keep their original contact space")
        }
        contact.cancel()
        expect(contact.point(at: CGPoint(x: 902, y: 389)) == nil, "cancelled loader rejects a stale release")
        expect(!contact.begin(frame: .zero), "hidden loader rejects new contact")
        for y in [0.1, 0.9] {
            expect(contact.begin(frame: original), "next loader gesture captures a new frame")
            loader = LoadSliderGestureSession()
            let point = contact.point(at: CGPoint(x: 902, y: 300 + y * 178))!
            _ = loader.handle(.init(phase: .began, points: [point], ending: []), height: contact.height,
                maximumTravel: TallLoadSliderMetrics.maximumTravel, edgeTapThreshold: 0.22)
            expect(loader.handle(.init(phase: .ended, points: [point], ending: [1]), height: contact.height,
                maximumTravel: TallLoadSliderMetrics.maximumTravel, edgeTapThreshold: 0.22) == (y < 0.5 ? .a : .b), "both end taps retain their loader direction")
            contact.cancel()
        }
        print("\(checks) browser column and loader checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
