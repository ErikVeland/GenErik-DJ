import CoreGraphics
import Foundation

/// Selection owns input identity, not playback or loaded-track state.
struct FrontDeckSelection<Deck: Equatable> {
    private(set) var selected: Deck
    private(set) var contactID = UUID()

    init(selected: Deck) { self.selected = selected }

    mutating func select(_ deck: Deck) {
        guard deck != selected else { return }
        selected = deck
        interrupt()
    }

    mutating func interrupt() { contactID = UUID() }
}

struct FrontWorkspaceGeometry {
    let selector: CGRect
    let deck: CGRect
    let handle: CGRect
    let library: CGRect
    let controls: CGRect
    let maximumBrowserExtent: Double
    let bodyHeight: Double

    init(width: Double, height: Double, browserExtent: Double, selectorHeight: Double = 44, controlsHeight: Double = 44)
    {
        let width = width.isFinite ? max(0, width) : 0
        let height = height.isFinite ? max(0, height) : 0
        let selectorHeight = min(selectorHeight.isFinite ? max(44, selectorHeight) : 44, height)
        let controlsHeight = min(
            controlsHeight.isFinite ? max(44, controlsHeight) : 44, max(0, height - selectorHeight))
        let handleHeight = min(44, max(0, height - selectorHeight - controlsHeight))
        let body = max(0, height - selectorHeight - controlsHeight - handleHeight)
        bodyHeight = body
        maximumBrowserExtent = max(0, body - (body >= 284 ? 64 : 0))
        let extent = browserExtent.isFinite ? min(maximumBrowserExtent, max(0, browserExtent)) : 0
        selector = CGRect(x: 0, y: 0, width: width, height: selectorHeight)
        deck = CGRect(x: 0, y: selector.maxY, width: width, height: body - extent)
        handle = CGRect(x: 0, y: deck.maxY, width: width, height: handleHeight)
        library = CGRect(x: 0, y: handle.maxY, width: width, height: extent)
        controls = CGRect(x: 0, y: library.maxY, width: width, height: controlsHeight)
    }
}

struct FrontBrowserPanelState {
    private var panel = TouchPanelState(minimumExtent: 220, initialExtent: 0)
    private(set) var contactID = UUID()
    private(set) var maximumExtent = 0.0
    private var bodyHeight = 0.0
    var extent: Double { panel.extent }
    var isDragging: Bool { panel.isDragging }
    var acceptsContentInput: Bool { extent > 0 && extent >= min(panel.minimumExtent, maximumExtent) }

    mutating func configure(width: Double, height: Double, selectorHeight: Double = 44, controlsHeight: Double = 44) {
        panel.cancelDrag()
        contactID = UUID()
        let geometry = FrontWorkspaceGeometry(
            width: width, height: height, browserExtent: extent, selectorHeight: selectorHeight,
            controlsHeight: controlsHeight)
        maximumExtent = geometry.maximumBrowserExtent
        bodyHeight = geometry.bodyHeight
        panel.setPresented(extent > 0, maximumExtent: maximumExtent)
    }

    mutating func apply(_ shortcut: LibraryWorkspaceShortcut) {
        switch shortcut {
        case .performance: setPresented(false)
        case .browse: panel.expand(maximumExtent: min(maximumExtent, max(220, bodyHeight / 2)))
        case .expand: panel.expand(maximumExtent: maximumExtent)
        }
    }

    mutating func setPresented(_ presented: Bool) {
        panel.setPresented(presented, maximumExtent: maximumExtent)
        if !presented { contactID = UUID() }
    }
    mutating func beginDrag() { panel.beginDrag() }
    mutating func updateDrag(translation: Double) {
        panel.updateDrag(translation: translation, maximumExtent: maximumExtent)
    }
    mutating func endDrag(velocity: Double) {
        panel.endDrag(velocity: velocity, maximumExtent: maximumExtent)
        if extent == 0 { contactID = UUID() }
    }
    mutating func cancelDrag() { panel.cancelDrag() }
    mutating func interrupt() {
        panel.cancelDrag()
        contactID = UUID()
    }
    mutating func adjust(by amount: Double) {
        guard amount.isFinite else { return }
        if extent == 0 && amount > 0 {
            setPresented(true)
        } else {
            beginDrag()
            updateDrag(translation: amount)
            endDrag(velocity: 0)
        }
    }
}
