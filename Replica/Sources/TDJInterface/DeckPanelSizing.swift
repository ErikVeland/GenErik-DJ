import CoreGraphics
import Foundation

enum PerformancePanel: CaseIterable, Hashable { case effects, mixer, extra }

struct DeckPanelsGeometry {
    let mainWidth: Double
    let extraWidth: Double
    let maximumExtraWidth: Double
    let extraBudget: Double
    let waveformWidth: Double
    let sideBudget: Double
    let effectsContent: CGRect
    let effectsHandle: CGRect
    let waveform: CGRect
    let mixerHandle: CGRect
    let mixerContent: CGRect

    init(
        width: Double, height: Double, effects: Double, mixer: Double, extra: Double, handleExtent: Double = 44,
        inlineControls: Bool = false
    ) {
        func finite(_ value: Double) -> Double { value.isFinite ? max(0, value) : 0 }
        let inner = max(0, finite(width) - 8)
        extraBudget = max(0, inner - handleExtent - 8 - 2 * handleExtent - 44)
        maximumExtraWidth = min(320, extraBudget)
        extraWidth = inlineControls ? 0 : min(maximumExtraWidth, finite(extra))
        mainWidth = inlineControls ? inner : max(0, inner - extraWidth - handleExtent - 8)
        waveformWidth = mainWidth
        sideBudget = max(0, waveformWidth - 2 * handleExtent - 44)
        let fx = min(max(0, sideBudget - min(200, finite(mixer))), finite(effects))
        let eq = min(max(0, sideBudget - fx), finite(mixer))
        let height = finite(height)
        effectsContent = CGRect(x: 0, y: 0, width: fx, height: height)
        effectsHandle = CGRect(x: fx, y: 0, width: min(handleExtent, waveformWidth), height: height)
        let mixerX = max(effectsHandle.maxX, waveformWidth - eq - handleExtent)
        waveform = CGRect(x: effectsHandle.maxX, y: 0, width: max(0, mixerX - effectsHandle.maxX), height: height)
        mixerHandle = CGRect(x: mixerX, y: 0, width: min(handleExtent, max(0, waveformWidth - mixerX)), height: height)
        mixerContent = CGRect(x: mixerHandle.maxX, y: 0, width: eq, height: height)
    }
}

struct DeckPanelsState {
    private struct Bank {
        var panels: [PerformancePanel: TouchPanelState] = [:]
        var customized: Set<PerformancePanel> = []
        init() {
            for kind in PerformancePanel.allCases {
                let width = kind == .extra ? 160.0 : 200.0
                var state = TouchPanelState(minimumExtent: kind == .extra ? 144 : 200, initialExtent: width)
                if kind != .extra { state.setPresented(false, maximumExtent: 10000) }
                panels[kind] = state
            }
        }
    }
    init(extraVisible: Bool = true, adaptiveDefaults: Bool = false, overlayControls: Bool = false) {
        self.adaptiveDefaults = adaptiveDefaults
        self.overlayControls = overlayControls
        if !extraVisible {
            presented.remove(.extra)
            portrait.panels[.extra]!.setPresented(false, maximumExtent: 10000)
            landscape.panels[.extra]!.setPresented(false, maximumExtent: 10000)
        }
    }
    private var adaptiveDefaults = false
    private var overlayControls = false
    private var handleExtent = 44.0
    private var portrait = Bank()
    private var landscape = Bank()
    private var isPortrait = false
    private var width = 0.0
    private var presented: Set<PerformancePanel> = [.extra]
    private var dragOffsets: [PerformancePanel: Double] = [:]
    private var collapsedExtras: Set<PerformancePanel> = []
    private var bank: Bank {
        get { isPortrait ? portrait : landscape }
        set { if isPortrait { portrait = newValue } else { landscape = newValue } }
    }

    func isPresented(_ kind: PerformancePanel) -> Bool { presented.contains(kind) }
    func extent(_ kind: PerformancePanel) -> Double { isPresented(kind) ? bank.panels[kind]!.extent : 0 }
    func isDragging(_ kind: PerformancePanel) -> Bool { bank.panels[kind]!.isDragging }
    var isDragging: Bool { PerformancePanel.allCases.contains { isDragging($0) } }
    func geometry(height: Double) -> DeckPanelsGeometry {
        .init(
            width: width, height: height, effects: extent(.effects), mixer: extent(.mixer), extra: extent(.extra),
            handleExtent: handleExtent, inlineControls: overlayControls)
    }
    func maximum(_ kind: PerformancePanel) -> Double {
        let layout = geometry(height: 1)
        switch kind {
        case .effects: return max(0, layout.sideBudget - layout.mixerContent.width)
        case .mixer: return max(0, layout.sideBudget - layout.effectsContent.width)
        case .extra: return layout.maximumExtraWidth
        }
    }

    mutating func configure(width: Double, portrait: Bool, handleExtent: Double = 44) {
        guard width.isFinite, width >= 0,
            self.width != width || isPortrait != portrait || self.handleExtent != handleExtent
        else { return }
        let restoreBank = self.width == 0 || isPortrait != portrait
        for kind in PerformancePanel.allCases { cancel(kind) }
        self.width = width
        self.handleExtent = handleExtent
        isPortrait = portrait
        if !restoreBank {
            if adaptiveDefaults {
                for kind in [PerformancePanel.effects, .mixer]
                where isPresented(kind) && !bank.customized.contains(kind) { setPresented(kind, true) }
            }
            return
        }
        let visible = presented
        for kind in [PerformancePanel.extra, .effects, .mixer] { setPresented(kind, visible.contains(kind)) }
    }

    mutating func setPresented(_ kind: PerformancePanel, _ visible: Bool) {
        if visible, kind != .extra { makeRoom(for: kind) }
        let maximum = maximum(kind)
        let minimum = bank.panels[kind]!.minimumExtent
        if visible, maximum < minimum, !isPresented(kind) { return }
        if visible { presented.insert(kind) } else { presented.remove(kind) }
        if visible && adaptiveDefaults && kind != .extra && !bank.customized.contains(kind) {
            let preferred = min(maximum, max(minimum, geometry(height: 1).extraBudget / 2))
            mutate(kind) { $0.expand(maximumExtent: preferred) }
        } else {
            mutate(kind) { $0.setPresented(visible, maximumExtent: maximum) }
        }
    }

    private mutating func makeRoom(for kind: PerformancePanel) {
        if maximum(kind) < 200, isPresented(.extra) { setPresented(.extra, false) }
        let other: PerformancePanel = kind == .effects ? .mixer : .effects
        if maximum(kind) < 200, isPresented(other), geometry(height: 1).sideBudget >= 400 {
            mutate(other) { $0.setPresented(true, maximumExtent: 200) }
        }
    }

    mutating func begin(_ kind: PerformancePanel) {
        let before = geometry(height: 1)
        let hadExtras = isPresented(.extra)
        if kind != .extra, extent(kind) == 0 { makeRoom(for: kind) }
        guard isPresented(kind) || maximum(kind) >= bank.panels[kind]!.minimumExtent else { return }
        if hadExtras && !isPresented(.extra) { collapsedExtras.insert(kind) }
        if adaptiveDefaults, kind != .extra, !isPresented(kind), !bank.customized.contains(kind) {
            let preferred = min(maximum(kind), max(200, geometry(height: 1).extraBudget / 2))
            let limit = maximum(kind)
            mutate(kind) {
                $0.expand(maximumExtent: preferred)
                $0.setPresented(false, maximumExtent: limit)
            }
        }
        let visible =
            kind == .effects
            ? before.effectsContent.width : kind == .mixer ? before.mixerContent.width : before.extraWidth
        let offset =
            visible - extent(kind) + (kind == .mixer ? geometry(height: 1).waveformWidth - before.waveformWidth : 0)
        dragOffsets[kind] = offset
        if !isPresented(kind) { presented.insert(kind) }
        mutate(kind) { $0.beginDrag() }
        let limit = maximum(kind)
        mutate(kind) { $0.updateDrag(translation: 0, maximumExtent: limit, layoutOffset: offset) }
    }
    mutating func update(_ kind: PerformancePanel, translation: Double) {
        let limit = maximum(kind)
        let offset = dragOffsets[kind] ?? 0
        mutate(kind) { $0.updateDrag(translation: translation, maximumExtent: limit, layoutOffset: offset) }
    }
    mutating func end(_ kind: PerformancePanel, velocity: Double) {
        defer {
            dragOffsets[kind] = nil
            collapsedExtras.remove(kind)
        }
        let limit = maximum(kind)
        if limit < bank.panels[kind]!.minimumExtent {
            setPresented(kind, false)
            if collapsedExtras.contains(kind) { setPresented(.extra, true) }
            return
        }
        let wasDragging = isDragging(kind)
        mutate(kind) { $0.endDrag(velocity: velocity, maximumExtent: limit) }
        if wasDragging, velocity.isFinite, abs(velocity) < 600, bank.panels[kind]!.extent > 0 {
            var value = bank
            value.customized.insert(kind)
            bank = value
        }
        if bank.panels[kind]!.extent == 0 {
            presented.remove(kind)
            if collapsedExtras.contains(kind) { setPresented(.extra, true) }
        }
    }
    mutating func cancel(_ kind: PerformancePanel) {
        defer {
            dragOffsets[kind] = nil
            collapsedExtras.remove(kind)
        }
        let dragging = isDragging(kind)
        mutate(kind) { $0.cancelDrag() }
        if dragging, bank.panels[kind]!.extent == 0 { presented.remove(kind) }
        if dragging, collapsedExtras.contains(kind) { setPresented(.extra, true) }
    }
    mutating func adjust(_ kind: PerformancePanel, by delta: Double) {
        guard delta.isFinite else { return }
        if !isPresented(kind), delta > 0 {
            setPresented(kind, true)
        } else if extent(kind) <= bank.panels[kind]!.minimumExtent, delta < 0 {
            setPresented(kind, false)
        } else {
            begin(kind)
            update(kind, translation: delta)
            end(kind, velocity: 0)
        }
    }
    private mutating func mutate(_ kind: PerformancePanel, _ body: (inout TouchPanelState) -> Void) {
        var value = bank
        body(&value.panels[kind]!)
        bank = value
    }
}
