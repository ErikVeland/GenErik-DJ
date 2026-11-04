import Foundation

struct SectionEditIdentity: Identifiable {
    let id = UUID()
    let trackID: String
    let loadID: UUID?
    func matches(trackID: String?, loadID: UUID?) -> Bool { self.trackID == trackID && self.loadID == loadID }
}

struct SectionEditorPanelState {
    private var portraitPanel = TouchPanelState(minimumExtent: 132, initialExtent: 260)
    private var landscapePanel = TouchPanelState(minimumExtent: 132, initialExtent: 260)
    private var portrait = false
    private var maximum = 0.0
    private var dragWasPresented: Bool?
    private(set) var session: SectionEditIdentity?
    private(set) var isPresented = false
    private(set) var presentationID = UUID()
    private var panel: TouchPanelState {
        get { portrait ? portraitPanel : landscapePanel }
        set { if portrait { portraitPanel = newValue } else { landscapePanel = newValue } }
    }
    init() {
        portraitPanel.setPresented(false, maximumExtent: 10000)
        landscapePanel.setPresented(false, maximumExtent: 10000)
    }
    var extent: Double { isPresented ? min(maximum, panel.extent) : 0 }
    var maximumExtent: Double { maximum }
    var isDragging: Bool { panel.isDragging }
    var acceptsContentInput: Bool { isPresented && extent >= 132 }
    func matches(trackID: String?, loadID: UUID?) -> Bool { session?.matches(trackID: trackID, loadID: loadID) == true }
    mutating func configure(height: Double, portrait: Bool, handleExtent: Double) {
        guard height.isFinite else { return }
        if self.portrait != portrait {
            cancelDrag()
            self.portrait = portrait
            presentationID = UUID()
        }
        maximum = max(0, height - 52 - handleExtent)
        if isPresented, !isDragging, panel.extent == 0 { panel.setPresented(true, maximumExtent: maximum) }
    }
    mutating func open(trackID: String, loadID: UUID?) {
        if !matches(trackID: trackID, loadID: loadID) {
            discard()
            session = .init(trackID: trackID, loadID: loadID)
        }
        setPresented(true)
    }
    mutating func setPresented(_ visible: Bool) {
        guard !visible || session != nil else { return }
        cancelDrag()
        isPresented = visible
        panel.setPresented(visible, maximumExtent: maximum)
        presentationID = UUID()
    }
    mutating func discard() {
        setPresented(false)
        session = nil
    }
    mutating func validate(trackID: String?, loadID: UUID?) {
        if session != nil, !matches(trackID: trackID, loadID: loadID) { discard() }
    }
    mutating func beginDrag() {
        guard session != nil else { return }
        dragWasPresented = isPresented
        isPresented = true
        panel.beginDrag()
    }
    mutating func updateDrag(translation: Double) { panel.updateDrag(translation: translation, maximumExtent: maximum) }
    mutating func endDrag(velocity: Double) {
        panel.endDrag(velocity: velocity, maximumExtent: maximum)
        isPresented = panel.extent > 0
        dragWasPresented = nil
    }
    mutating func cancelDrag() {
        panel.cancelDrag()
        if let previous = dragWasPresented { isPresented = previous }
        dragWasPresented = nil
    }
    mutating func adjust(by delta: Double) {
        guard delta.isFinite else { return }
        if !isPresented, delta > 0 {
            setPresented(true)
        } else {
            beginDrag()
            updateDrag(translation: delta)
            endDrag(velocity: 0)
        }
    }
}
