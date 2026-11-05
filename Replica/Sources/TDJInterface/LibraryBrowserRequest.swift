import Foundation
import TDJCore

struct LibraryBrowserRequest: Hashable {
    let revision: Int
    let version: UUID
    let catalogueVersion: UInt64
    let query: String
    let sort: CollectionSort?
    let category: CollectionCategory
    let group: String?
    let suggestionIDs: [String]?

    func resetsScroll(comparedTo previous: Self?) -> Bool {
        guard let previous else { return true }
        return query != previous.query || sort != previous.sort || category != previous.category
            || group != previous.group || suggestionIDs != previous.suggestionIDs
    }
}
