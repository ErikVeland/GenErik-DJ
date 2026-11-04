import SwiftUI

struct BrowserColumnContent<Content: View>: View {
    let width: Double
    let minimum: Double
    let presented: Bool
    let acceptsInput: Bool
    let trailing: Bool
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .transformEnvironment(\.frontDeckSwipeEnabled) { $0 = $0 && presented && acceptsInput }
            .environment(\.deckPanelPresented, presented)
            .environment(\.touchSurfaceAcceptsNewContacts, acceptsInput)
            .frame(width: max(minimum, width))
            .frame(width: width, alignment: trailing ? .trailing : .leading)
            .clipped().contentShape(Rectangle())
            .overlay {
                if !acceptsInput { Color.clear.contentShape(Rectangle()) }
            }
            .allowsHitTesting(presented)
            .accessibilityHidden(!acceptsInput)
    }
}
