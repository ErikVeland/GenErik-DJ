import SwiftUI

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
    var geometryPolicy = TouchSurfaceGeometryPolicy.cancelOnResize
    var action: (SurfaceEvent) -> Void
    func makeUIView(context: Context) -> ContactView {
        let view=ContactView()
        view.action=action
        configure(view, context:context)
        return view
    }
    func updateUIView(_ view: ContactView, context: Context) {
        view.action=action
        configure(view, context:context)
    }
    private func configure(_ view: ContactView, context: Context) {
        view.setCapturesDrag(capturesDrag)
        view.configureGeometry(policy:geometryPolicy, acceptsNewContacts:context.environment.touchSurfaceAcceptsNewContacts,
            interruption:context.environment.touchSurfaceInterruption)
        view.bindInputGate(context.environment.touchSurfaceInputGate)
    }
    static func dismantleUIView(_ view: ContactView, coordinator: ()) { view.cancel(); view.bindInputGate(nil) }

    final class ContactView: UIView {
        var action: ((SurfaceEvent) -> Void)?
        private var contacts: [UITouch: Int] = [:]
        private var nextID=0
        private var geometry=TouchContactGeometry(policy:.cancelOnResize)
        private var acceptsNewContacts=true
        private var interruption=UUID()
        private weak var inputGate: TouchSurfaceInputGate?
        private var inputRegistration: UUID?
        private var exclusiveGesture: ExclusiveSurfaceGestureRecognizer?
        private var surfaceFrame: CGRect { convert(bounds,to:window) }
        private var viewport: TouchSurfaceViewport {
            .init(size:window?.bounds.size ?? .zero,orientation:window?.windowScene?.interfaceOrientation.rawValue ?? 0,
                  interruption:interruption)
        }
        func configureGeometry(policy: TouchSurfaceGeometryPolicy, acceptsNewContacts: Bool, interruption: UUID) {
            if geometry.policy != policy { cancel(); geometry=TouchContactGeometry(policy:policy) }
            if self.interruption != interruption { cancel(); self.interruption=interruption }
            self.acceptsNewContacts=acceptsNewContacts
        }
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            acceptsNewContacts && inputGate?.isEnabled != false && super.point(inside:point,with:event)
        }
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
            let frame=surfaceFrame
            let points=contacts.compactMap { touch,id in
                geometry.point(id:id,location:touch.location(in:window),frame:frame)
            }.sorted { $0.id < $1.id }
            if let event=SurfaceEvent.owned(phase:phase,points:points,changed:changedIDs,
                                             ending:Set(ending.compactMap { contacts[$0] })) { action?(event) }
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard acceptsNewContacts,inputGate?.isEnabled != false else { return }
            if geometry.requiresCancellation(frame:surfaceFrame,viewport:viewport) { cancel() }
            for touch in touches where contacts[touch] == nil {
                nextID+=1
                if geometry.begin(id:nextID,frame:surfaceFrame,viewport:viewport) { contacts[touch]=nextID }
            }
            send(.began,changed:touches)
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            if geometry.requiresCancellation(frame:surfaceFrame,viewport:viewport) { cancel(); return }
            send(.moved,changed:touches)
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            if geometry.requiresCancellation(frame:surfaceFrame,viewport:viewport) { cancel(); return }
            send(.ended,changed:touches,ending:touches)
            geometry.end(ids:Set(touches.compactMap { contacts[$0] }))
            for touch in touches { contacts[touch]=nil }
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            if touches.contains(where: { contacts[$0] != nil }) { cancel() }
        }
        func cancel() {
            guard !contacts.isEmpty else { return }
            let owned=Set(contacts.keys)
            send(.cancelled,changed:owned,ending:owned); contacts.removeAll(); geometry.cancel()
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            if geometry.requiresCancellation(frame:surfaceFrame,viewport:viewport) { cancel() }
        }
        override func didMoveToWindow() { if window == nil { cancel() } }
    }
}
#else
/// Mouse fallback exercises the same one-contact path. It does not certify iPad multitouch.
struct TouchSurface: View {
    var capturesDrag = false
    var geometryPolicy = TouchSurfaceGeometryPolicy.cancelOnResize
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
