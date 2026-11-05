import Foundation

enum BrowserPresentation {
    case standard, frontPhone

    /// Use the whole window width, before help, docks or drawers consume space.
    static func select(isPhone: Bool, windowWidth: Double) -> Self {
        guard isPhone, windowWidth.isFinite, windowWidth > 0, windowWidth < 600 else { return .standard }
        return .frontPhone
    }
}

enum LibraryBrowserPresentation: Equatable {
    case content, loading, empty, noMatches
    case failed(String)

    static func resolve(
        count: Int, catalogueReady: Bool, catalogueRefreshing: Bool, projecting: Bool, requestReady: Bool,
        hasQuery: Bool, error: String?
    ) -> Self {
        if count > 0 { return .content }
        if catalogueRefreshing || projecting || !requestReady { return .loading }
        if let error { return .failed(error) }
        if !catalogueReady { return .loading }
        return hasQuery ? .noMatches : .empty
    }
}
