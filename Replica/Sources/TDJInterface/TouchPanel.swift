import SwiftUI

struct TouchPanelHandle: View {
    let presented: Bool
    let maximumExtent: Double
    let presentationID: UUID
    var edge = TouchPanelEdge.bottom
    var title = "LIBRARY"
    var accessibilityName = "Music library"
    var canToggle = true
    let toggle: () -> Void
    let begin: () -> Void
    let update: (Double) -> Void
    let end: (Double) -> Void
    let cancel: () -> Void
    let adjust: (Double) -> Void
    @GestureState private var active = false
    @State private var ownsDrag: Bool?
    @State private var ignoreUntilRelease = false

    var body: some View {
        Group {
            if edge.horizontal {
                VStack(spacing: 8) {
                    toggleButton
                    Spacer(minLength: 0)
                    Capsule().fill(PerformancePalette.secondaryText).frame(width: 4, height: 44)
                    Spacer(minLength: 0)
                    Text(title).font(.system(size: 10, weight: .semibold)).padding(.bottom, 8)
                }.frame(width: 44).frame(minHeight: 44)
            } else {
                HStack(spacing: 8) {
                    toggleButton
                    Spacer(minLength: 0)
                    Capsule().fill(PerformancePalette.secondaryText).frame(width: 44, height: 4)
                    Spacer(minLength: 0)
                    Text(title).font(.system(size: 11, weight: .semibold)).padding(.trailing, 12)
                }.frame(height: AdaptivePerformanceLayout.libraryHandleHeight)
            }
        }
        .background(PerformancePalette.frame)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($active) { _, active, _ in active = true }
            .onChanged { value in
                guard !ignoreUntilRelease else { return }
                if ownsDrag == nil {
                    ownsDrag = edge.horizontal ? abs(value.translation.width) > abs(value.translation.height) : abs(value.translation.height) >= abs(value.translation.width)
                    if ownsDrag == true { begin() }
                }
                if ownsDrag == true { update(edge.translation(horizontal: value.translation.width, vertical: value.translation.height)) }
            }
            .onEnded { value in
                if ownsDrag == true, !ignoreUntilRelease {
                    update(edge.translation(horizontal: value.translation.width, vertical: value.translation.height))
                    end(edge.translation(horizontal: value.velocity.width, vertical: value.velocity.height))
                }
                ownsDrag = nil
                ignoreUntilRelease = false
            })
        .onChange(of: active) { _, active in
            if !active { cancel(); ownsDrag = nil; ignoreUntilRelease = false }
        }
        .onChange(of: maximumExtent) { _, _ in if !edge.horizontal { invalidateDrag() } }
        .onChange(of: presentationID) { _, _ in invalidateDrag() }
        .onDisappear { cancel() }
        .accessibilityLabel("\(accessibilityName) resize handle")
        .accessibilityAdjustableAction { direction in adjust(direction == .increment ? 44 : -44) }
    }

    private var toggleButton: some View {
        let symbol: String = switch edge {
        case .bottom: presented ? "chevron.down" : "chevron.up"
        case .leading: presented ? "chevron.left" : "chevron.right"
        case .trailing: presented ? "chevron.right" : "chevron.left"
        }
        return Button(action: toggle) { Image(systemName: symbol).frame(width: 44, height: 44) }
            .accessibilityLabel("\(presented ? "Hide" : "Show") \(accessibilityName)")
            .disabled(!canToggle)
    }

    private func invalidateDrag() {
        if active { cancel(); ignoreUntilRelease = true }
    }
}

struct LibraryWorkspaceShortcuts: View {
    let selected: LibraryWorkspaceShortcut?
    let apply: (LibraryWorkspaceShortcut) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(LibraryWorkspaceShortcut.allCases, id: \.self) { shortcut in
                    Button { apply(shortcut) } label: {
                        Text(shortcut.rawValue).font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10).frame(minWidth: 44, minHeight: 44)
                            .background(selected == shortcut ? PerformancePalette.cyan.opacity(0.2) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 5))
                    }
                    .accessibilityLabel("\(shortcut.rawValue) layout")
                    .accessibilityHint(hint(shortcut))
                    .accessibilityAddTraits(selected == shortcut ? .isSelected : [])
                }
            }
            Menu {
                ForEach(LibraryWorkspaceShortcut.allCases, id: \.self) { shortcut in
                    Button { apply(shortcut) } label: {
                        if selected == shortcut { Label(shortcut.rawValue, systemImage: "checkmark") }
                        else { Text(shortcut.rawValue) }
                    }
                }
            } label: {
                Label("Layout", systemImage: "rectangle.split.1x2").frame(minWidth: 44, minHeight: 44)
            }.accessibilityLabel("Library layout shortcuts")
        }
        .foregroundStyle(PerformancePalette.text)
        .padding(.trailing, 8)
        .background(PerformancePalette.frame)
    }

    private func hint(_ shortcut: LibraryWorkspaceShortcut) -> String {
        switch shortcut {
        case .performance: "Hide the song browser"
        case .browse: "Share space between the decks and song browser"
        case .expand: "Give the song browser the most space"
        }
    }
}

private struct PerformancePanelPortraitKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var performancePanelPortrait: Bool {
        get { self[PerformancePanelPortraitKey.self] }
        set { self[PerformancePanelPortraitKey.self] = newValue }
    }
}
