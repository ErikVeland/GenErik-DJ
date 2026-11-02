import Foundation

/// The detail pane swipes off to the right, following the finger 1:1, so the song list widens and
/// shows its key and tempo columns. Swiping back or choosing a row brings it back. The category
/// column collapses to the left the same way.
struct BrowserLayoutState: Equatable {
    private(set) var detailHidden = false
    private(set) var categoriesHidden = false
    /// Positive while dragging the detail pane out (or negative while dragging it back in).
    private(set) var detailOffset: Double = 0
    private(set) var categoryOffset: Double = 0
    static let flickVelocity = 600.0

    init(categoriesHidden: Bool = false) { self.categoriesHidden = categoriesHidden }

    /// The list shows its own key and BPM columns and the Edit button once the detail pane is away.
    var listShowsTempoAndKey: Bool { detailHidden }

    mutating func dragDetail(translation: Double) {
        guard translation.isFinite else { return }
        detailOffset = detailHidden ? min(0, translation) : max(0, translation)
    }
    @discardableResult
    mutating func endDetail(translation: Double, velocity: Double, width: Double) -> Bool {
        defer { detailOffset = 0 }
        guard translation.isFinite, velocity.isFinite else { return detailHidden }
        let distance = detailHidden ? -translation : translation, speed = detailHidden ? -velocity : velocity
        if distance >= max(1, width) / 3 || (distance > 12 && speed >= Self.flickVelocity) { detailHidden.toggle() }
        return detailHidden
    }
    mutating func showDetail() { detailHidden = false; detailOffset = 0 }

    mutating func dragCategories(translation: Double) {
        guard translation.isFinite else { return }
        categoryOffset = categoriesHidden ? max(0, translation) : min(0, translation)
    }
    @discardableResult
    mutating func endCategories(translation: Double, velocity: Double, width: Double) -> Bool {
        defer { categoryOffset = 0 }
        guard translation.isFinite, velocity.isFinite else { return categoriesHidden }
        let distance = categoriesHidden ? translation : -translation, speed = categoriesHidden ? velocity : -velocity
        if distance >= max(1, width) / 3 || (distance > 12 && speed >= Self.flickVelocity) { categoriesHidden.toggle() }
        return categoriesHidden
    }
    mutating func showCategories() { categoriesHidden = false; categoryOffset = 0 }
}
