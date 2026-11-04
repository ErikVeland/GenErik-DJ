import CoreGraphics
import Foundation

enum BrowserColumn: CaseIterable, Hashable {
    case categories, playlists, detail
    var minimum: Double { self == .detail ? 260 : self == .playlists ? 180 : 144 }
    var initial: Double { self == .detail ? 320 : self == .playlists ? 240 : 180 }
    var cap: Double { self == .detail ? 640 : self == .playlists ? 420 : 320 }
}

struct BrowserColumnsGeometry {
    let leading: CGRect
    let leadingHandle: CGRect
    let list: CGRect
    let detailHandle: CGRect
    let detail: CGRect
    let sideBudget: Double
    init(width: Double, leading: Double, detail: Double, hasLeading: Bool = true) {
        func finite(_ value: Double) -> Double { value.isFinite ? max(0, value) : 0 }
        let width = finite(width)
        let lane = min(44, width)
        sideBudget = max(0, width - lane)
        let left = hasLeading ? min(sideBudget, finite(leading)) : 0
        let right = min(sideBudget, finite(detail))
        self.leading = CGRect(x: 0, y: 0, width: left, height: 1)
        leadingHandle = CGRect(x: left, y: 0, width: hasLeading ? lane : 0, height: 1)
        list = CGRect(x: 0, y: 0, width: width, height: 1)
        self.detail = CGRect(x: width - right, y: 0, width: right, height: 1)
        detailHandle = CGRect(x: width - right - lane, y: 0, width: lane, height: 1)
    }
}

/// Drawer widths remain separate from full-width list navigation and presentation.
struct BrowserColumnSizingState {
    private struct Bank {
        var panels = Dictionary(
            uniqueKeysWithValues: BrowserColumn.allCases.map {
                ($0, TouchPanelState(minimumExtent: $0.minimum, initialExtent: $0.initial))
            })
    }
    private var portraitBank = Bank()
    private var landscapeBank = Bank()
    private var portrait = false
    private var width = 0.0
    private var leading: BrowserColumn? = .categories
    private var presented: Set<BrowserColumn> = []
    private var commands = Dictionary(uniqueKeysWithValues: BrowserColumn.allCases.map { ($0, UUID()) })
    private var bank: Bank {
        get { portrait ? portraitBank : landscapeBank }
        set { if portrait { portraitBank = newValue } else { landscapeBank = newValue } }
    }
    init() {
        for kind in BrowserColumn.allCases {
            portraitBank.panels[kind]!.setPresented(false, maximumExtent: 10000)
            landscapeBank.panels[kind]!.setPresented(false, maximumExtent: 10000)
        }
    }
    var isDragging: Bool { BrowserColumn.allCases.contains { bank.panels[$0]!.isDragging } }
    func isPresented(_ kind: BrowserColumn) -> Bool { presented.contains(kind) }
    func presentationID(for kind: BrowserColumn) -> UUID { commands[kind]! }
    func extent(_ kind: BrowserColumn) -> Double { isPresented(kind) ? bank.panels[kind]!.extent : 0 }
    func geometry() -> BrowserColumnsGeometry {
        .init(
            width: width, leading: leading.map { extent($0) } ?? 0, detail: extent(.detail), hasLeading: leading != nil)
    }
    func maximum(_ kind: BrowserColumn) -> Double { min(kind.cap, max(0, width - 44)) }
    mutating func configure(width: Double, portrait: Bool, leading: BrowserColumn?) {
        guard width.isFinite, width >= 0 else { return }
        guard self.width != width || self.portrait != portrait || self.leading != leading else { return }
        let changedBank = self.portrait != portrait
        for kind in BrowserColumn.allCases { cancel(kind) }
        self.width = width
        self.portrait = portrait
        self.leading = leading
        if changedBank {
            for kind in BrowserColumn.allCases {
                let visible = isPresented(kind)
                mutate(kind) { $0.setPresented(visible, maximumExtent: 10000) }
            }
        }
        for kind in BrowserColumn.allCases { commands[kind] = UUID() }
    }
    mutating func setPresented(_ kind: BrowserColumn, _ visible: Bool) {
        cancel(kind)
        let limit = maximum(kind)
        guard !visible || limit >= kind.minimum else { return }
        let wasPresented = isPresented(kind)
        if visible { presented.insert(kind) } else { presented.remove(kind) }
        mutate(kind) { $0.setPresented(visible, maximumExtent: limit) }
        if wasPresented != visible { commands[kind] = UUID() }
    }
    mutating func begin(_ kind: BrowserColumn) {
        guard !bank.panels[kind]!.isDragging, maximum(kind) >= kind.minimum else { return }
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
        if bank.panels[kind]!.extent == 0 { presented.remove(kind) }
    }
    mutating func cancel(_ kind: BrowserColumn) {
        let dragging = bank.panels[kind]!.isDragging
        mutate(kind) { $0.cancelDrag() }
        if dragging, bank.panels[kind]!.extent == 0 { presented.remove(kind) }
    }
    mutating func adjust(_ kind: BrowserColumn, by delta: Double) {
        guard delta.isFinite else { return }
        if !isPresented(kind), delta > 0 {
            setPresented(kind, true)
        } else if extent(kind) <= kind.minimum, delta < 0 {
            setPresented(kind, false)
        } else {
            begin(kind)
            update(kind, translation: delta)
            end(kind, velocity: 0)
        }
    }
    private mutating func mutate(_ kind: BrowserColumn, _ body: (inout TouchPanelState) -> Void) {
        var value = bank
        body(&value.panels[kind]!)
        bank = value
    }
}
