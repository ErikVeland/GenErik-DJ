import Foundation
import CoreGraphics

enum BrowserColumn: CaseIterable, Hashable {
    case categories, playlists, detail
    var minimum: Double { self == .detail ? 260 : self == .playlists ? 180 : 144 }
    var initial: Double { self == .detail ? 320 : self == .playlists ? 240 : 180 }
    var cap: Double { self == .detail ? 640 : self == .playlists ? 420 : 320 }
}

struct BrowserColumnsGeometry {
    let rail: CGRect
    let leading: CGRect
    let leadingHandle: CGRect
    let list: CGRect
    let detailHandle: CGRect
    let detail: CGRect
    let sideBudget: Double

    init(width: Double, leading: Double, detail: Double, hasLeading: Bool = true, hasDetail: Bool = true) {
        func finite(_ value: Double) -> Double { value.isFinite ? max(0, value) : 0 }
        let width = finite(width)
        let railWidth = min(64, width)
        let available = width - railWidth
        let leftLane = hasLeading ? min(44, available) : 0
        let rightLane = hasDetail ? min(44, available - leftLane) : 0
        sideBudget = max(0, available - leftLane - rightLane - 240)
        let left = hasLeading ? min(sideBudget, finite(leading)) : 0
        let right = hasDetail ? min(max(0, sideBudget - left), finite(detail)) : 0
        rail = CGRect(x: 0, y: 0, width: railWidth, height: 1)
        self.leading = CGRect(x: railWidth, y: 0, width: left, height: 1)
        leadingHandle = CGRect(x: railWidth + left, y: 0, width: leftLane, height: 1)
        detailHandle = CGRect(x: width - right - rightLane, y: 0, width: rightLane, height: 1)
        list = CGRect(x: leadingHandle.maxX, y: 0, width: max(0, detailHandle.minX - leadingHandle.maxX), height: 1)
        self.detail = CGRect(x: detailHandle.maxX, y: 0, width: right, height: 1)
    }
}

/// Each browser column retains its own session widths and resize ownership.
struct BrowserLayoutState {
    private struct Bank {
        var panels = Dictionary(uniqueKeysWithValues: BrowserColumn.allCases.map {
            ($0, TouchPanelState(minimumExtent: $0.minimum, initialExtent: $0.initial))
        })
    }
    private var portraitBank = Bank()
    private var landscapeBank = Bank()
    private var portrait = false
    private var width = 0.0
    private var leading: BrowserColumn? = .categories
    private var showsDetail = true
    private var presented: Set<BrowserColumn> = [.categories, .playlists, .detail]
    private var commands = Dictionary(uniqueKeysWithValues: BrowserColumn.allCases.map { ($0, UUID()) })
    private var displaced: [BrowserColumn: (BrowserColumn, UUID)] = [:]
    private var bank: Bank {
        get { portrait ? portraitBank : landscapeBank }
        set { if portrait { portraitBank = newValue } else { landscapeBank = newValue } }
    }
    init(categoriesHidden: Bool = false) {
        if categoriesHidden {
            presented.remove(.categories)
            portraitBank.panels[.categories]!.setPresented(false, maximumExtent: 10000)
            landscapeBank.panels[.categories]!.setPresented(false, maximumExtent: 10000)
        }
    }
    var detailHidden: Bool { !isPresented(.detail) }
    var listShowsTempoAndKey: Bool { geometry().list.width >= 480 && (detailHidden || geometry().detail.width < BrowserColumn.detail.minimum) }
    var isDragging: Bool { BrowserColumn.allCases.contains { bank.panels[$0]!.isDragging } }
    func isPresented(_ kind: BrowserColumn) -> Bool { presented.contains(kind) }
    func presentationID(for kind: BrowserColumn) -> UUID { commands[kind]! }
    func extent(_ kind: BrowserColumn) -> Double { isPresented(kind) ? bank.panels[kind]!.extent : 0 }
    func geometry() -> BrowserColumnsGeometry {
        .init(width: width, leading: leading.map { extent($0) } ?? 0, detail: extent(.detail), hasLeading: leading != nil, hasDetail: showsDetail)
    }
    func maximum(_ kind: BrowserColumn) -> Double {
        guard kind == .detail ? showsDetail : kind == leading else { return 0 }
        let g = geometry()
        return min(kind.cap, max(0, g.sideBudget - (kind == .detail ? g.leading.width : g.detail.width)))
    }
    mutating func configure(width: Double, portrait: Bool, leading: BrowserColumn?, showsDetail: Bool = true) {
        guard width.isFinite, width >= 0 else { return }
        guard self.width != width || self.portrait != portrait || self.leading != leading || self.showsDetail != showsDetail else { return }
        let changedBank = self.portrait != portrait
        for kind in BrowserColumn.allCases { cancel(kind) }
        self.width = width; self.portrait = portrait; self.leading = leading; self.showsDetail = showsDetail
        if changedBank {
            for kind in BrowserColumn.allCases {
                let visible = isPresented(kind)
                mutate(kind) { $0.setPresented(visible, maximumExtent: 10000) }
            }
        }
        if let leading, isPresented(leading), isPresented(.detail), geometry().detail.width < BrowserColumn.detail.minimum {
            hide(.detail)
        }
        for kind in BrowserColumn.allCases { commands[kind] = UUID() }
    }
    mutating func setPresented(_ kind: BrowserColumn, _ visible: Bool) {
        cancel(kind)
        if visible { _ = makeRoom(for: kind) }
        let limit = maximum(kind)
        guard !visible || limit >= kind.minimum else { return }
        let wasPresented = isPresented(kind)
        if visible { presented.insert(kind) } else { presented.remove(kind) }
        mutate(kind) { $0.setPresented(visible, maximumExtent: limit) }
        if wasPresented != visible { commands[kind] = UUID() }
    }
    mutating func showDetail() { setPresented(.detail, true) }
    mutating func begin(_ kind: BrowserColumn) {
        guard !bank.panels[kind]!.isDragging else { return }
        if !isPresented(kind), let other = makeRoom(for: kind) { displaced[kind] = (other, commands[other]!) }
        guard maximum(kind) >= kind.minimum else { restoreDisplaced(kind); return }
        presented.insert(kind)
        mutate(kind) { $0.beginDrag() }
    }
    mutating func update(_ kind: BrowserColumn, translation: Double) {
        let limit = maximum(kind)
        mutate(kind) { $0.updateDrag(translation: translation, maximumExtent: limit) }
    }
    mutating func end(_ kind: BrowserColumn, velocity: Double) {
        let limit = maximum(kind)
        mutate(kind) { $0.endDrag(velocity: velocity, maximumExtent: limit) }
        if bank.panels[kind]!.extent == 0 { presented.remove(kind); restoreDisplaced(kind) }
        displaced[kind] = nil
    }
    mutating func cancel(_ kind: BrowserColumn) {
        let dragging = bank.panels[kind]!.isDragging
        mutate(kind) { $0.cancelDrag() }
        if dragging, bank.panels[kind]!.extent == 0 { presented.remove(kind) }
        restoreDisplaced(kind)
    }
    mutating func adjust(_ kind: BrowserColumn, by delta: Double) {
        guard delta.isFinite else { return }
        if !isPresented(kind), delta > 0 { setPresented(kind, true) }
        else if extent(kind) <= kind.minimum, delta < 0 { setPresented(kind, false) }
        else { begin(kind); update(kind, translation: delta); end(kind, velocity: 0) }
    }
    private mutating func hide(_ kind: BrowserColumn) {
        cancel(kind)
        let limit = maximum(kind)
        mutate(kind) { $0.setPresented(false, maximumExtent: limit) }
        presented.remove(kind); commands[kind] = UUID()
    }
    private mutating func makeRoom(for kind: BrowserColumn) -> BrowserColumn? {
        guard maximum(kind) < kind.minimum, geometry().sideBudget >= kind.minimum else { return nil }
        guard let other = kind == .detail ? leading : .detail, isPresented(other) else { return nil }
        hide(other)
        return other
    }
    private mutating func restoreDisplaced(_ kind: BrowserColumn) {
        guard let (other, command) = displaced.removeValue(forKey: kind), commands[other] == command, !isPresented(other) else { return }
        let limit = maximum(other)
        if limit >= other.minimum {
            presented.insert(other)
            mutate(other) { $0.setPresented(true, maximumExtent: limit) }
            commands[other] = UUID()
        }
    }
    private mutating func mutate(_ kind: BrowserColumn, _ body: (inout TouchPanelState) -> Void) {
        var value = bank
        body(&value.panels[kind]!)
        bank = value
    }
}
