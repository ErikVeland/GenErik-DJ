import CoreGraphics
import Foundation

struct DeckSplitGeometry {
    static let handleHeight = 44.0
    static let minimumDeckHeight = AdaptivePerformanceLayout.minimumCompactDeckHeight
    let a: CGRect
    let handle: CGRect
    let b: CGRect

    init(
        width: Double, height: Double, share: Double, proposedAHeight: Double? = nil, handleExtent: Double = 44,
        minimumDeckHeight: Double = Self.minimumDeckHeight
    ) {
        let width = width.isFinite ? max(0, width) : 0
        let height = height.isFinite ? max(0, height) : 0
        let lane = min(handleExtent, height)
        let usable = height - lane
        let minimum = min(minimumDeckHeight, usable / 2)
        let share = share.isFinite ? min(1, max(0, share)) : 0.5
        let proposed = proposedAHeight.flatMap { $0.isFinite ? $0 : nil } ?? usable * share
        let aHeight = min(usable - minimum, max(minimum, proposed))
        a = CGRect(x: 0, y: 0, width: width, height: aHeight)
        handle = CGRect(x: 0, y: aHeight, width: width, height: lane)
        b = CGRect(x: 0, y: aHeight + lane, width: width, height: usable - aHeight)
    }
}

struct DeckSplitState {
    private static let focusedShare = 2.0 / 3
    private var innerPortraitShare = Self.focusedShare
    private var innerPortrait = false
    private(set) var focusedUpper = true
    private var portraitShare = 0.5
    private var landscapeShare = 0.5
    private var portrait = false
    private var viewport = CGSize.zero
    private var dragOrigin: Double?
    private var translation = 0.0
    var isDragging: Bool { dragOrigin != nil }
    private var minimumDeckHeight: Double {
        innerPortrait ? AdaptivePerformanceLayout.minimumDeckHeight : DeckSplitGeometry.minimumDeckHeight
    }
    private var share: Double {
        get { innerPortrait ? innerPortraitShare : portrait ? portraitShare : landscapeShare }
        set {
            if innerPortrait { innerPortraitShare = newValue }
            else if portrait { portraitShare = newValue }
            else { landscapeShare = newValue }
        }
    }

    func geometry(width: Double, height: Double, handleExtent: Double = 44) -> DeckSplitGeometry {
        .init(
            width: width, height: height, share: share, proposedAHeight: dragOrigin.map { $0 + translation },
            handleExtent: handleExtent, minimumDeckHeight: minimumDeckHeight)
    }
    mutating func updateViewport(width: Double, height: Double, innerPortrait: Bool = false) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            cancelDrag()
            return
        }
        let next = CGSize(width: width, height: height)
        guard next != viewport || innerPortrait != self.innerPortrait else { return }
        cancelDrag()
        self.innerPortrait = innerPortrait
        portrait = width < height
        viewport = next
    }
    mutating func focus(upper: Bool) {
        guard innerPortrait else { return }
        cancelDrag()
        focusedUpper = upper
        share = upper ? Self.focusedShare : 1 - Self.focusedShare
    }
    mutating func beginDrag(height: Double, handleExtent: Double = 44) {
        guard dragOrigin == nil, height.isFinite, height > 2 * minimumDeckHeight + handleExtent else {
            return
        }
        dragOrigin = geometry(width: 0, height: height, handleExtent: handleExtent).a.height
        translation = 0
    }
    mutating func updateDrag(translation: Double) {
        guard isDragging, translation.isFinite else { return }
        self.translation = translation
    }
    mutating func endDrag(height: Double, handleExtent: Double = 44) {
        guard isDragging else { return }
        guard height.isFinite, height > 2 * minimumDeckHeight + handleExtent else {
            cancelDrag()
            return
        }
        let layout = geometry(width: 0, height: height, handleExtent: handleExtent)
        share = layout.a.height / (layout.a.height + layout.b.height)
        cancelDrag()
    }
    mutating func ensureHeight(upper: Bool, minimum: Double, height: Double, handleExtent: Double = 44) {
        guard minimum.isFinite, height.isFinite else { return }
        let layout = geometry(width: 0, height: height, handleExtent: handleExtent)
        let current = upper ? layout.a.height : layout.b.height
        guard current < minimum else { return }
        let desired = min(
            max(minimumDeckHeight, minimum),
            max(minimumDeckHeight, height - handleExtent - minimumDeckHeight))
        adjust(by: (desired - current) * (upper ? 1 : -1), height: height, handleExtent: handleExtent)
    }
    mutating func cancelDrag() {
        dragOrigin = nil
        translation = 0
    }
    mutating func balance() {
        cancelDrag()
        share = 0.5
    }
    mutating func adjust(by delta: Double, height: Double, handleExtent: Double = 44) {
        guard delta.isFinite else { return }
        cancelDrag()
        beginDrag(height: height, handleExtent: handleExtent)
        updateDrag(translation: delta)
        endDrag(height: height, handleExtent: handleExtent)
    }
}
