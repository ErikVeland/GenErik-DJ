import Foundation
import CoreGraphics

enum BrowserListTab: String, CaseIterable {
    case songs = "Songs", suggestions = "Suggestions", prep = "Prep list"
}

/// Lists retain their full width. Sources and details appear as exclusive drawers.
struct BrowserLayoutState: Equatable {
    private(set) var tab = BrowserListTab.songs
    private(set) var detailHidden = true
    private(set) var categoriesHidden = false
    /// Positive while dragging the detail pane out (or negative while dragging it back in).
    private(set) var detailOffset: Double = 0
    private(set) var categoryOffset: Double = 0
    static let flickVelocity = 600.0

    init(categoriesHidden: Bool = false) { self.categoriesHidden = categoriesHidden }

    mutating func selectTab(_ tab: BrowserListTab) {
        self.tab = tab
        hideDrawers()
    }

    mutating func hideDrawers() {
        detailHidden = true; categoriesHidden = true
        detailOffset = 0; categoryOffset = 0
    }

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
        if distance >= max(1, width) / 3 || (distance > 12 && speed >= Self.flickVelocity) {
            if detailHidden { showDetail() } else { detailHidden = true }
        }
        return detailHidden
    }
    mutating func showDetail() {
        hideDrawers(); detailHidden = false
    }

    mutating func dragCategories(translation: Double) {
        guard translation.isFinite else { return }
        categoryOffset = categoriesHidden ? max(0, translation) : min(0, translation)
    }
    @discardableResult
    mutating func endCategories(translation: Double, velocity: Double, width: Double) -> Bool {
        defer { categoryOffset = 0 }
        guard translation.isFinite, velocity.isFinite else { return categoriesHidden }
        let distance = categoriesHidden ? translation : -translation, speed = categoriesHidden ? velocity : -velocity
        if distance >= max(1, width) / 3 || (distance > 12 && speed >= Self.flickVelocity) {
            if categoriesHidden { showCategories() } else { categoriesHidden = true }
        }
        return categoriesHidden
    }
    mutating func showCategories() {
        hideDrawers(); categoriesHidden = false
    }
}

struct BrowserContentGeometry {
    let listArea: CGRect
    let drawerWidth: Double

    init(width: Double, height: Double) {
        let width = width.isFinite ? max(0, width) : 0
        let height = height.isFinite ? max(0, height) : 0
        listArea = CGRect(x: 0, y: 0, width: width, height: height)
        drawerWidth = min(400, width)
    }
}
