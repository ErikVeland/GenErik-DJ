import Foundation

enum BrowserPresentation {
    case standard, frontPhone

    /// Use the short edge of the whole phone window so rotation keeps the same presentation.
    static func select(isPhone: Bool, windowWidth: Double, windowHeight: Double) -> Self {
        guard isPhone, windowWidth.isFinite, windowHeight.isFinite, windowWidth > 0, windowHeight > 0,
            min(windowWidth, windowHeight) < 600
        else { return .standard }
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
