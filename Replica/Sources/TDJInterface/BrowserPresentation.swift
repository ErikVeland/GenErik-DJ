import Foundation

enum BrowserPresentation {
    case standard, frontPhone

    /// Use the whole window width, before help, docks or drawers consume space.
    static func select(isPhone: Bool, windowWidth: Double) -> Self {
        guard isPhone, windowWidth.isFinite, windowWidth > 0, windowWidth < 600 else {
            return .standard
        }
        return .frontPhone
    }
}
