import SwiftUI

enum FrontDeckSwipeEvent {
    case began(horizontal: Double, vertical: Double)
    case changed(horizontal: Double, vertical: Double)
    case ended(horizontal: Double, vertical: Double, velocity: Double)
    case cancelled
}

struct FrontDeckSwipeProtectionKey: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] { [] }
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) { value += nextValue() }
}

private struct FrontDeckSwipeEnabledKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var frontDeckSwipeEnabled: Bool {
        get { self[FrontDeckSwipeEnabledKey.self] }
        set { self[FrontDeckSwipeEnabledKey.self] = newValue }
    }
}

private struct FrontDeckSwipeProtection: ViewModifier {
    @Environment(\.frontDeckSwipeEnabled) private var enabled
    func body(content: Content) -> some View {
        content.anchorPreference(key: FrontDeckSwipeProtectionKey.self, value: .bounds) { enabled ? [$0] : [] }
    }
}

extension View { func protectsFrontDeckSwipe() -> some View { modifier(FrontDeckSwipeProtection()) } }

#if os(iOS)
    import UIKit

    /// Observe safe front-screen drags without placing a touch-blocking view above controls.
    struct FrontDeckSwipeCapture: UIViewRepresentable {
        let protectedRegions: [CGRect]
        let selectorRegion: CGRect
        let contactID: UUID
        let acceptsNewSwipe: Bool
        let event: (FrontDeckSwipeEvent) -> Void

        func makeCoordinator() -> Coordinator { Coordinator() }
        func makeUIView(context: Context) -> CaptureView {
            let view = CaptureView()
            view.isUserInteractionEnabled = false
            view.coordinator = context.coordinator
            context.coordinator.view = view
            return view
        }
        func updateUIView(_ view: CaptureView, context: Context) {
            context.coordinator.regions = protectedRegions
            context.coordinator.selectorRegion = selectorRegion
            context.coordinator.contactID = contactID
            context.coordinator.acceptsNewSwipe = acceptsNewSwipe
            context.coordinator.event = event
        }
        static func dismantleUIView(_ view: CaptureView, coordinator: Coordinator) { coordinator.attach(to: nil) }

        final class CaptureView: UIView {
            weak var coordinator: Coordinator?
            override func didMoveToWindow() {
                super.didMoveToWindow()
                coordinator?.attach(to: window)
            }
        }

        @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            weak var view: CaptureView?
            private weak var window: UIWindow?
            private var pan: UIPanGestureRecognizer?
            var regions: [CGRect] = []
            var selectorRegion = CGRect.zero
            var contactID = UUID()
            private var initialContact: UUID?
            var acceptsNewSwipe = true
            var event: ((FrontDeckSwipeEvent) -> Void)?

            func attach(to window: UIWindow?) {
                guard self.window !== window else { return }
                if let pan { self.window?.removeGestureRecognizer(pan) }
                self.window = window
                pan = nil
                guard let window else { return }
                let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
                recognizer.minimumNumberOfTouches = 1
                recognizer.maximumNumberOfTouches = 1
                recognizer.cancelsTouchesInView = true
                recognizer.delegate = self
                window.addGestureRecognizer(recognizer)
                pan = recognizer
            }

            func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
                guard acceptsNewSwipe, let view, view.window != nil,
                    FrontDeckSwipePolicy.allowsStart(
                        at: touch.location(in: view), bounds: view.bounds, protected: regions)
                else { return false }
                if selectorRegion.contains(touch.location(in: view)) {
                    initialContact = contactID
                    return true
                }
                var target = touch.view
                while let current = target {
                    if current is TouchSurface.ContactView || current is UIControl || current is UITextView {
                        return false
                    }
                    target = current.superview
                }
                initialContact = contactID
                return true
            }

            func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
                guard acceptsNewSwipe, initialContact == contactID,
                    let pan = gestureRecognizer as? UIPanGestureRecognizer, let view
                else { return false }
                let velocity = pan.velocity(in: view)
                return abs(velocity.x) > abs(velocity.y) * 1.4
            }

            func gestureRecognizer(
                _ gestureRecognizer: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
            ) -> Bool { true }

            @objc private func handle(_ pan: UIPanGestureRecognizer) {
                guard initialContact == contactID, let view else { return }
                let translation = pan.translation(in: view)
                switch pan.state {
                case .began: event?(.began(horizontal: translation.x, vertical: translation.y))
                case .changed: event?(.changed(horizontal: translation.x, vertical: translation.y))
                case .ended:
                    initialContact = nil
                    event?(
                        .ended(horizontal: translation.x, vertical: translation.y, velocity: pan.velocity(in: view).x))
                case .cancelled, .failed:
                    initialContact = nil
                    event?(.cancelled)
                default: break
                }
            }
        }
    }
#else
    struct FrontDeckSwipeCapture: View {
        let protectedRegions: [CGRect]
        let selectorRegion: CGRect
        let contactID: UUID
        let acceptsNewSwipe: Bool
        let event: (FrontDeckSwipeEvent) -> Void
        var body: some View { Color.clear.allowsHitTesting(false) }
    }
#endif
