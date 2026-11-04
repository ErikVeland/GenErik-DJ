import SwiftUI

/// Closing a drawer cancels its contacts before its visual removal transition begins.
@MainActor
final class TouchSurfaceInputGate {
    private(set) var isEnabled=true
    private var cancellations:[UUID:()->Void]=[:]
    private var enabledObservers:[UUID:(Bool)->Void]=[:]
    func permits(_ phase: SurfaceEvent.Phase) -> Bool { isEnabled || phase == .cancelled }
    func register(_ cancel: @escaping ()->Void) -> UUID {
        let id=UUID()
        cancellations[id]=cancel
        if !isEnabled { cancel() }
        return id
    }
    func unregister(_ id: UUID?) {
        if let id { cancellations[id]=nil }
    }
    /// State observers are separate from contact cancellation and receive the current value immediately.
    func observeEnabled(_ observer: @escaping (Bool)->Void) -> UUID {
        let id=UUID()
        enabledObservers[id]=observer
        observer(isEnabled)
        return id
    }
    func removeEnabledObserver(_ id: UUID?) {
        if let id { enabledObservers[id]=nil }
    }
    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled=enabled
        if !enabled {
            // A cancellation may remove its own surface from the registry.
            for cancel in Array(cancellations.values) { cancel() }
        }
        guard !enabledObservers.isEmpty else { return }
        // A callback may remove itself or another observer. Recheck membership before delivery.
        for id in Array(enabledObservers.keys) {
            // A nested state change has already delivered the newer state.
            guard isEnabled == enabled else { break }
            enabledObservers[id]?(enabled)
        }
    }
}

private struct TouchSurfaceInputGateKey: EnvironmentKey {
    static let defaultValue: TouchSurfaceInputGate? = nil
}
extension EnvironmentValues {
    var touchSurfaceInputGate: TouchSurfaceInputGate? {
        get { self[TouchSurfaceInputGateKey.self] }
        set { self[TouchSurfaceInputGateKey.self]=newValue }
    }
    var touchSurfaceAcceptsNewContacts: Bool {
        get { self[TouchSurfaceNewContactsKey.self] }
        set { self[TouchSurfaceNewContactsKey.self] = newValue }
    }
    var touchSurfaceInterruption: UUID {
        get { self[TouchSurfaceInterruptionKey.self] }
        set { self[TouchSurfaceInterruptionKey.self] = newValue }
    }
}

private struct TouchSurfaceNewContactsKey: EnvironmentKey {
    static let defaultValue = true
}

private struct TouchSurfaceInterruptionKey: EnvironmentKey {
    static let defaultValue = UUID()
}

/// Refresh the callback without ending a contact when SwiftUI updates the surface.
@MainActor
final class SurfaceEventActionRelay {
    private var action: (SurfaceEvent)->Void = { _ in }
    func update(_ action: @escaping (SurfaceEvent)->Void) { self.action=action }
    func send(_ event: SurfaceEvent) { action(event) }
}

private struct DeckPanelPresentedKey: EnvironmentKey {
    static let defaultValue = true
}
extension EnvironmentValues {
    var deckPanelPresented: Bool {
        get { self[DeckPanelPresentedKey.self] }
        set { self[DeckPanelPresentedKey.self] = newValue }
    }
}
