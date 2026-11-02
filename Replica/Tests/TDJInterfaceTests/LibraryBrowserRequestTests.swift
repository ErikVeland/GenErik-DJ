import Foundation
import Testing
import TDJCore
@testable import TDJInterface

private func browserRequest(revision: Int = 1, version: UUID, query: String = "", sort: CollectionSort? = .title,
    category: CollectionCategory = .songs, group: String? = nil, suggestionIDs: [String]? = nil) -> LibraryBrowserRequest {
    .init(revision: revision, version: version, query: query, sort: sort,
          category: category, group: group, suggestionIDs: suggestionIDs)
}

@Test func backgroundLibraryAndCatalogueRefreshesKeepTheBrowserScrollPosition() {
    let version = UUID(), previous = browserRequest(version: version)
    let analysis = browserRequest(revision: 2, version: version)
    let catalogue = browserRequest(revision: 2, version: UUID())
    #expect(analysis != previous)
    #expect(catalogue != previous)
    #expect(!analysis.resetsScroll(comparedTo: previous))
    #expect(!catalogue.resetsScroll(comparedTo: previous))
}

@Test func newBrowserContextsResetScrollAfterTheirResultsArrive() {
    let version = UUID(), previous = browserRequest(version: version)
    let changes = [browserRequest(version: version, query: "House"),
        browserRequest(version: version, sort: .bpm), browserRequest(version: version, category: .artists),
        browserRequest(version: version, group: "music:chosen"), browserRequest(version: version, suggestionIDs: ["b", "a"])]
    #expect(previous.resetsScroll(comparedTo: nil))
    #expect(!previous.resetsScroll(comparedTo: previous))
    for changed in changes { #expect(changed.resetsScroll(comparedTo: previous)) }
    let ranked = browserRequest(version: version, suggestionIDs: ["a", "b"])
    #expect(ranked.resetsScroll(comparedTo: changes.last))
}
