import Foundation
import CoreGraphics

struct DeckSplitGeometry {
    static let handleHeight = 44.0
    static let minimumDeckHeight = 52.0
    let a: CGRect
    let handle: CGRect
    let b: CGRect

    init(width: Double, height: Double, share: Double, proposedAHeight: Double? = nil, handleExtent: Double = 44) {
        let width = width.isFinite ? max(0, width) : 0
        let height = height.isFinite ? max(0, height) : 0
        let lane = min(handleExtent, height)
        let usable = height - lane
        let minimum = min(Self.minimumDeckHeight, usable / 2)
        let share = share.isFinite ? min(1, max(0, share)) : 0.5
        let proposed = proposedAHeight.flatMap { $0.isFinite ? $0 : nil } ?? usable * share
        let aHeight = min(usable - minimum, max(minimum, proposed))
        a = CGRect(x: 0, y: 0, width: width, height: aHeight)
        handle = CGRect(x: 0, y: aHeight, width: width, height: lane)
        b = CGRect(x: 0, y: aHeight + lane, width: width, height: usable - aHeight)
    }
}

struct DeckSplitState {
    private var portraitShare = 0.5
    private var landscapeShare = 0.5
    private var portrait = false
    private var viewport = CGSize.zero
    private var dragOrigin: Double?
    private var translation = 0.0
    var isDragging: Bool { dragOrigin != nil }
    private var share: Double {
        get { portrait ? portraitShare : landscapeShare }
        set { if portrait { portraitShare = newValue } else { landscapeShare = newValue } }
    }

    func geometry(width: Double, height: Double, handleExtent: Double = 44) -> DeckSplitGeometry {
        .init(width: width, height: height, share: share, proposedAHeight: dragOrigin.map { $0 + translation }, handleExtent: handleExtent)
    }
    mutating func updateViewport(width: Double, height: Double) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { cancelDrag(); return }
        let next = CGSize(width: width, height: height)
        guard next != viewport else { return }
        cancelDrag()
        portrait = width < height
        viewport = next
    }
    mutating func beginDrag(height: Double, handleExtent: Double = 44) {
        guard dragOrigin == nil, height.isFinite, height > 104 + handleExtent else { return }
        dragOrigin = geometry(width: 0, height: height, handleExtent: handleExtent).a.height
        translation = 0
    }
    mutating func updateDrag(translation: Double) {
        guard isDragging, translation.isFinite else { return }
        self.translation = translation
    }
    mutating func endDrag(height: Double, handleExtent: Double = 44) {
        guard isDragging else { return }
        guard height.isFinite, height > 104 + handleExtent else { cancelDrag(); return }
        let layout = geometry(width: 0, height: height, handleExtent: handleExtent)
        share = layout.a.height / (layout.a.height + layout.b.height)
        cancelDrag()
    }
    mutating func ensureHeight(upper: Bool, minimum: Double, height: Double, handleExtent: Double = 44) {
        guard minimum.isFinite, height.isFinite else { return }
        let layout = geometry(width: 0, height: height, handleExtent: handleExtent)
        let current = upper ? layout.a.height : layout.b.height
        guard current < minimum else { return }
        let desired = min(max(52, minimum), max(52, height - handleExtent - 52))
        adjust(by: (desired - current) * (upper ? 1 : -1), height: height, handleExtent: handleExtent)
    }
    mutating func cancelDrag() { dragOrigin = nil; translation = 0 }
    mutating func balance() { cancelDrag(); share = 0.5 }
    mutating func adjust(by delta: Double, height: Double, handleExtent: Double = 44) {
        guard delta.isFinite else { return }
        cancelDrag()
        beginDrag(height: height, handleExtent: handleExtent)
        updateDrag(translation: delta)
        endDrag(height: height, handleExtent: handleExtent)
    }
}
