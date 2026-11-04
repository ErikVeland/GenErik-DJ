import Foundation

enum TouchPanelEdge {
    case bottom, leading, trailing
    var horizontal: Bool { self != .bottom }
    func translation(horizontal: Double, vertical: Double) -> Double {
        switch self {
        case .bottom: -vertical
        case .leading: horizontal
        case .trailing: -horizontal
        }
    }
}

struct TouchPanelState {
    let minimumExtent: Double
    private(set) var extent: Double
    private(set) var rememberedExtent: Double
    private var dragOrigin: Double?
    private var memoryAtDragStart = 0.0
    private var translation = 0.0
    var isDragging: Bool { dragOrigin != nil }

    init(minimumExtent: Double, initialExtent: Double) {
        let minimum = minimumExtent.isFinite ? max(1, minimumExtent) : 1
        let initial = initialExtent.isFinite ? max(0, initialExtent) : 0
        self.minimumExtent = minimum
        extent = initial
        rememberedExtent = initial >= minimum ? initial : 0
    }

    mutating func beginDrag() {
        guard dragOrigin == nil else { return }
        dragOrigin = extent
        memoryAtDragStart = rememberedExtent
        translation = 0
    }

    mutating func updateDrag(translation: Double, maximumExtent: Double, layoutOffset: Double = 0) {
        guard let origin = dragOrigin, translation.isFinite, maximumExtent.isFinite, layoutOffset.isFinite else { return }
        self.translation = translation
        extent = min(max(0, maximumExtent), max(0, origin + translation + layoutOffset))
    }

    mutating func endDrag(velocity: Double, maximumExtent: Double) {
        guard dragOrigin != nil else { return }
        guard velocity.isFinite, maximumExtent.isFinite else { cancelDrag(); return }
        let maximum = max(0, maximumExtent)
        if translation >= 12 && velocity >= 600 {
            extent = min(maximum, max(minimumExtent, rememberedExtent > 0 ? rememberedExtent : maximum))
        } else if translation <= -12 && velocity <= -600 {
            extent = 0
        } else {
            let minimum = min(minimumExtent, maximum)
            extent = extent < minimum / 2 ? 0 : min(maximum, max(minimum, extent))
        }
        if extent > 0 { rememberedExtent = extent }
        dragOrigin = nil
    }

    mutating func cancelDrag() {
        guard let origin = dragOrigin else { return }
        extent = origin
        rememberedExtent = memoryAtDragStart
        dragOrigin = nil
    }

    mutating func setPresented(_ presented: Bool, maximumExtent: Double) {
        guard maximumExtent.isFinite else { return }
        cancelDrag()
        let maximum = max(0, maximumExtent)
        if presented {
            if extent > 0 { extent = min(maximum, max(minimumExtent, extent)) }
            else { extent = min(maximum, max(minimumExtent, rememberedExtent > 0 ? rememberedExtent : maximum)) }
        } else {
            if extent >= min(minimumExtent, maximum), extent > 0 { rememberedExtent = extent }
            extent = 0
        }
    }

    mutating func expand(maximumExtent: Double) {
        guard maximumExtent.isFinite else { return }
        cancelDrag()
        extent = max(0, maximumExtent)
        if extent > 0 { rememberedExtent = extent }
    }
}

struct LibraryPanelState {
    enum Orientation { case portrait, landscape }
    private var portrait = TouchPanelState(minimumExtent: 132, initialExtent: 0)
    private var landscape = TouchPanelState(minimumExtent: 132, initialExtent: 0)
    private(set) var orientation = Orientation.landscape
    private(set) var maximumExtent = 0.0
    private var panel: TouchPanelState {
        get { orientation == .portrait ? portrait : landscape }
        set { if orientation == .portrait { portrait = newValue } else { landscape = newValue } }
    }
    var extent: Double { panel.extent }
    var isDragging: Bool { panel.isDragging }
    var acceptsContentInput: Bool { extent > 0 && extent >= min(panel.minimumExtent, maximumExtent) }

    mutating func updateViewport(width: Double, height: Double, presented: Bool) {
        let dragging = isDragging
        panel.cancelDrag()
        let visible = dragging ? extent > 0 : presented
        orientation = width < height ? .portrait : .landscape
        maximumExtent = AdaptivePerformanceLayout.maximumLibraryExtent(available: height)
        panel.setPresented(visible, maximumExtent: maximumExtent)
    }

    mutating func setPresented(_ presented: Bool) {
        panel.setPresented(presented, maximumExtent: maximumExtent)
    }

    mutating func present(fullyExpanded: Bool) {
        if fullyExpanded { panel.expand(maximumExtent: maximumExtent) }
        else { setPresented(true) }
    }

    mutating func adjust(by delta: Double) {
        guard delta.isFinite else { return }
        if extent == 0, delta > 0 { setPresented(true) }
        else if extent <= min(132, maximumExtent), delta < 0 { setPresented(false) }
        else {
            beginDrag()
            updateDrag(translation: delta)
            endDrag(velocity: 0)
        }
    }

    mutating func beginDrag() { panel.beginDrag() }
    mutating func updateDrag(translation: Double) { panel.updateDrag(translation: translation, maximumExtent: maximumExtent) }
    mutating func endDrag(velocity: Double) { panel.endDrag(velocity: velocity, maximumExtent: maximumExtent) }
    mutating func cancelDrag() { panel.cancelDrag() }
}
