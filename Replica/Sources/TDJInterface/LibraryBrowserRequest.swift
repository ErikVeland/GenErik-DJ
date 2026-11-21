import Foundation
import TDJCore

struct LibraryBrowserRequest: Hashable {
    let revision: Int
    let version: UUID
    let catalogueVersion: UInt64
    let query: String
    let sort: CollectionSort?
    var reversed: Bool = false
    let category: CollectionCategory
    let group: String?
    let suggestionIDs: [String]?

    func resetsScroll(comparedTo previous: Self?) -> Bool {
        guard let previous else { return true }
        return query != previous.query || sort != previous.sort || reversed != previous.reversed || category != previous.category
            || group != previous.group || suggestionIDs != previous.suggestionIDs
    }
}

enum LibraryHeaderSwipeAction: Equatable {
    case none, dismissKeyboard, closeLibrary

    static func resolve(horizontal: Double, vertical: Double, searchFocused: Bool) -> Self {
        guard vertical > 36, vertical > abs(horizontal) else { return .none }
        return searchFocused ? .dismissKeyboard : .closeLibrary
    }
}
