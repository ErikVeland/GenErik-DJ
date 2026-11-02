import SwiftUI

struct SurfacePoint: Equatable {
    let id: Int
    var x: Double
    var y: Double
}
struct SurfaceEvent {
    enum Phase { case began, moved, ended, cancelled }
    let phase: Phase
    /// Includes ending contacts for the final event, allowing release-position inspection.
    let points: [SurfacePoint]
    let ending: Set<Int>
    var remaining: [SurfacePoint] { points.filter { !ending.contains($0.id) } }
    static func owned(phase: Phase, points: [SurfacePoint], changed: Set<Int>, ending: Set<Int> = []) -> SurfaceEvent? {
        guard !points.isEmpty, !changed.isDisjoint(with:points.lazy.map(\.id)) else { return nil }
        return .init(phase:phase,points:points,ending:ending.intersection(points.lazy.map(\.id)))
    }
}

/// Keeps the last mouse contact available for cancellation without synthesising a release.
struct MouseContactSession {
    private var point: SurfacePoint?
    private var waitingForRelease=false

    mutating func move(to position: SurfacePoint, action: (SurfaceEvent) -> Void) {
        guard !waitingForRelease else { return }
        let began=point == nil
        point=position
        if began { action(.init(phase:.began,points:[position],ending:[])) }
        action(.init(phase:.moved,points:[position],ending:[]))
    }
    mutating func end(at position: SurfacePoint, action: (SurfaceEvent) -> Void) {
        defer { point=nil; waitingForRelease=false }
        guard !waitingForRelease,point != nil else { return }
        action(.init(phase:.ended,points:[position],ending:[position.id]))
    }
    mutating func cancel(untilRelease: Bool = true, action: (SurfaceEvent) -> Void) {
        guard point != nil || waitingForRelease else { return }
        let previous=point
        point=nil; waitingForRelease=untilRelease
        if let previous { action(.init(phase:.cancelled,points:[previous],ending:[previous.id])) }
    }
}

#if os(iOS)
import UIKit
import UIKit.UIGestureRecognizerSubclass

final class ExclusiveSurfaceGestureRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { state = .began }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { state = .changed }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .ended }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .cancelled }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

struct TouchSurface: UIViewRepresentable {
    var capturesDrag = false
    var action: (SurfaceEvent) -> Void
    func makeUIView(context: Context) -> ContactView {
        let view=ContactView(); view.setCapturesDrag(capturesDrag); view.action=action; view.bindInputGate(context.environment.touchSurfaceInputGate); return view
    }
    func updateUIView(_ view: ContactView, context: Context) {
        view.setCapturesDrag(capturesDrag); view.bindInputGate(context.environment.touchSurfaceInputGate); view.action=action
    }
    static func dismantleUIView(_ view: ContactView, coordinator: ()) { view.cancel(); view.bindInputGate(nil) }

    final class ContactView: UIView {
        var action: ((SurfaceEvent) -> Void)?
        private var contacts: [UITouch: Int] = [:]
        private var nextID=0
        private var previousSize=CGSize.zero
        private weak var inputGate: TouchSurfaceInputGate?
        private var inputRegistration: UUID?
        private var exclusiveGesture: ExclusiveSurfaceGestureRecognizer?
        func setCapturesDrag(_ captures: Bool) {
            if captures && exclusiveGesture == nil {
                let recognizer = ExclusiveSurfaceGestureRecognizer()
                recognizer.cancelsTouchesInView = false
                addGestureRecognizer(recognizer)
                exclusiveGesture = recognizer
            } else if !captures, let recognizer = exclusiveGesture {
                removeGestureRecognizer(recognizer)
                exclusiveGesture = nil
            }
        }
        func bindInputGate(_ gate: TouchSurfaceInputGate?) {
            guard inputGate !== gate else { return }
            cancel()
            inputGate?.unregister(inputRegistration)
            inputGate=gate
            inputRegistration=gate?.register { [weak self] in self?.cancel() }
        }
        override init(frame: CGRect) {
            super.init(frame:frame); isMultipleTouchEnabled=true; backgroundColor = .clear
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        private func send(_ phase: SurfaceEvent.Phase, changed: Set<UITouch>, ending: Set<UITouch> = []) {
            guard inputGate?.permits(phase) != false else { return }
            let changedIDs=Set(changed.compactMap { contacts[$0] })
            guard !changedIDs.isEmpty else { return }
            let points=contacts.map { touch,id in
                let p=touch.location(in:self)
                return SurfacePoint(id:id,x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height))
            }.sorted { $0.id < $1.id }
            if let event=SurfaceEvent.owned(phase:phase,points:points,changed:changedIDs,
                                             ending:Set(ending.compactMap { contacts[$0] })) { action?(event) }
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard inputGate?.isEnabled != false else { return }
            for touch in touches { nextID+=1; contacts[touch]=nextID }
            send(.began,changed:touches)
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { send(.moved,changed:touches) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            send(.ended,changed:touches,ending:touches); for touch in touches { contacts[touch]=nil }
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            if touches.contains(where: { contacts[$0] != nil }) { cancel() }
        }
        func cancel() {
            guard !contacts.isEmpty else { return }
            let owned=Set(contacts.keys)
            send(.cancelled,changed:owned,ending:owned); contacts.removeAll()
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            if previousSize != .zero && previousSize != bounds.size { cancel() }
            previousSize=bounds.size
        }
        override func didMoveToWindow() { if window == nil { cancel() } }
    }
}
#else
/// Mouse fallback exercises the same one-contact path. It does not certify iPad multitouch.
struct TouchSurface: View {
    var capturesDrag = false
    var action: (SurfaceEvent) -> Void
    @State private var contact=MouseContactSession()
    @State private var currentAction=SurfaceEventActionRelay()
    @GestureState private var dragging=false
    @Environment(\.touchSurfaceInputGate) private var inputGate
    @State private var registeredInputGate: TouchSurfaceInputGate?
    @State private var inputRegistration: UUID?
    @State private var cancelRegisteredContact: (() -> Void)?
    var body: some View {
        // This holder is not observable; refreshing it does not publish view state.
        let _ = currentAction.update(action)
        GeometryReader { geometry in
            Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0)
                .updating($dragging) { _,active,_ in active=true }
                .onChanged { value in
                    guard inputGate?.isEnabled != false else { return }
                    let p=SurfacePoint(id:0,x:value.location.x/max(1,geometry.size.width),y:value.location.y/max(1,geometry.size.height))
                    contact.move(to:p,action:currentAction.send)
                }.onEnded { value in
                    contact.end(at:.init(id:0,x:value.location.x/max(1,geometry.size.width),y:value.location.y/max(1,geometry.size.height)),action:currentAction.send)
                })
                .onChange(of:geometry.size) { _,_ in contact.cancel(action:currentAction.send) }
        }
        .onAppear { contact=MouseContactSession(); bindInputGate() }
        .onDisappear {
            contact.cancel(action:currentAction.send)
            registeredInputGate?.unregister(inputRegistration)
            registeredInputGate=nil; inputRegistration=nil; cancelRegisteredContact=nil
        }
        .onChange(of:inputGate.map(ObjectIdentifier.init)) { _,_ in bindInputGate() }
        .onChange(of:dragging) { _,active in
            if !active { contact.cancel(untilRelease:false,action:currentAction.send) }
        }
    }
    private func bindInputGate() {
        cancelRegisteredContact?()
        registeredInputGate?.unregister(inputRegistration)
        registeredInputGate=inputGate
        guard let inputGate else { inputRegistration=nil; cancelRegisteredContact=nil; return }
        let state=$contact, handler=currentAction
        let cancelContact = {
            var session=state.wrappedValue
            session.cancel(action:handler.send)
            state.wrappedValue=session
        }
        cancelRegisteredContact=cancelContact
        inputRegistration=inputGate.register(cancelContact)
    }
}
#endif
