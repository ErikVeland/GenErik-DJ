import Foundation
import TDJCore

/// Browser panes slide like the original: choosing a playlist, artist, album or genre slides its
/// songs in from the right; a rightward swipe tracks the finger 1:1 and returns on release.
struct BrowserPaneStack: Equatable {
    private(set) var category: CollectionCategory = .songs
    private(set) var group: String?
    /// Horizontal offset of the top pane in points while a back swipe is held.
    private(set) var dragOffset: Double = 0
    static let flickVelocity = 600.0

    /// Category root is pane 0; an opened group is pane 1.
    var depth: Int { group == nil ? 0 : 1 }

    mutating func select(_ category: CollectionCategory) {
        self.category = category
        group = nil
        dragOffset = 0
    }
    mutating func open(group id: String) {
        guard category != .songs else { return }
        group = id
        dragOffset = 0
    }
    mutating func back() {
        group = nil
        dragOffset = 0
    }

    mutating func dragChanged(translation: Double) {
        guard depth > 0, translation.isFinite else {
            dragOffset = 0
            return
        }
        dragOffset = max(0, translation)
    }
    /// Returns true when the swipe went back a pane.
    @discardableResult mutating func dragEnded(translation: Double, velocity: Double, width: Double) -> Bool {
        defer { dragOffset = 0 }
        guard depth > 0, translation.isFinite, velocity.isFinite else { return false }
        let returns = translation >= max(1, width) / 3 || (translation > 12 && velocity >= Self.flickVelocity)
        if returns { group = nil }
        return returns
    }
}
