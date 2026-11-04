import Foundation
import Testing

@testable import TDJCore

@Test func distinctGroupSelectorSearchAndVisibleRowsHandle115000Groups() async throws {
    let groups = (0..<115000).reversed().map { CollectionGroup(id: "artist:\($0)", name: "Artist \($0)") }
    let source = LibraryGroupSource(groups: groups)
    let result = try await LibraryGroupProjection.build(source: source, search: "")
    #expect(result.count == 115000)
    let first = LibraryBrowserRowWindow(count: result.count, offset: 0, viewportHeight: 420)
    let visible = result.visibleGroups(in: first.range)
    #expect(visible.count <= 128 && visible.first?.id == "artist:0")
    for offset in [58000.0, Double.greatestFiniteMagnitude] {
        let window = LibraryBrowserRowWindow(count: result.count, offset: offset, viewportHeight: 420)
        #expect(result.visibleGroups(in: window.range).count <= 128)
    }
    let filtered = try await LibraryGroupProjection.build(source: source, search: "Artist 114999")
    #expect(filtered.count == 1 && filtered.visibleGroups(in: 0..<1).first?.id == "artist:114999")
}
@Test func groupSelectionSurvivesSearchAndMetadataRefresh() async throws {
    let source = LibraryGroupSource(groups: [.init(id: "kept", name: "Old name"), .init(id: "other", name: "Other")])
    let filtered = try await LibraryGroupProjection.build(source: source, search: "Other", selectedID: "kept")
    #expect(filtered.count == 1 && filtered.selectedGroup?.id == "kept" && filtered.selectedGroup?.name == "Old name")
    let refreshed = LibraryGroupSource(groups: [.init(id: "kept", name: "New name"), .init(id: "other", name: "Other")])
    let result = try await LibraryGroupProjection.build(source: refreshed, search: "Other", selectedID: "kept")
    #expect(result.selectedGroup?.id == "kept" && result.selectedGroup?.name == "New name")
}
@Test func groupSearchUsesAllWordsAndStableNaturalSorting() async throws {
    let source = LibraryGroupSource(groups: [
        .init(id: "ten", name: "Écho 10"), .init(id: "two", name: "Echo 2"), .init(id: "one", name: "Other"),
        .init(id: "tie", name: "Echo 2"),
    ])
    let result = try await LibraryGroupProjection.build(source: source, search: "echo")
    #expect(result.visibleGroups(in: 0..<result.count).map(\.id) == ["two", "tie", "ten"])
    let none = try await LibraryGroupProjection.build(source: source, search: "Echo missing")
    #expect(none.count == 0 && none.visibleGroups(in: 0..<0).isEmpty)
}
@Test func groupSourceIdentityAndRequestComparisonAvoidWholeGroupHashes() {
    let source = LibraryGroupSource(groups: [])
    let same = source
    let new = LibraryGroupSource(groups: [])
    #expect(source.id == same.id && source.id != new.id)
    let previous = LibraryGroupRequest(sourceID: source.id, search: "", selectedID: "kept", context: "Artists")
    let refresh = LibraryGroupRequest(sourceID: new.id, search: "", selectedID: "kept", context: "Artists")
    #expect(previous != refresh && !refresh.resetsScroll(comparedTo: previous))
    let selection = LibraryGroupRequest(sourceID: new.id, search: "", selectedID: "other", context: "Artists")
    #expect(!selection.resetsScroll(comparedTo: refresh))
    let search = LibraryGroupRequest(sourceID: new.id, search: "new", selectedID: "kept", context: "Artists")
    let category = LibraryGroupRequest(sourceID: new.id, search: "", selectedID: nil, context: "Albums")
    #expect(search.resetsScroll(comparedTo: previous) && category.resetsScroll(comparedTo: previous))
}
@Test func cancelledGroupSearchCannotReturnAResult() async throws {
    let (stream, continuation) = AsyncStream<Void>.makeStream()
    let task = Task {
        for await _ in stream { break }
        return try await LibraryGroupProjection.build(source: .init(groups: []), search: "")
    }
    task.cancel()
    continuation.finish()
    await #expect(throws: CancellationError.self) { try await task.value }
}

@Test func preparedGroupSourcesReuseMetadataOnlyResultsAndRefreshChangedNames() throws {
    let groups: [CollectionGroup] = [.init(id: "two", name: "Artist 2"), .init(id: "ten", name: "Artist 10")]
    let first = try LibraryGroupSource.prepared(groups: groups)
    let same = try LibraryGroupSource.prepared(groups: groups, reusing: first)
    #expect(same.id == first.id)
    let changed = try LibraryGroupSource.prepared(
        groups: [.init(id: "two", name: "New name"), groups[1]], reusing: first)
    #expect(changed.id != first.id)
}

@Test func preparedGroupsPreservePlaylistOrderAndMissingSelection() async throws {
    let groups: [CollectionGroup] = [.init(id: "music:b", name: "Set B"), .init(id: "local:a", name: "Set A")]
    let source = try LibraryGroupSource.prepared(groups: groups, sortByName: false)
    let result = try await LibraryGroupProjection.build(source: source, search: "Set", selectedID: "vanished")
    #expect(result.visibleGroups(in: 0..<result.count).map(\.id) == ["music:b", "local:a"])
    #expect(result.selectedGroup == nil && result.count == 2)
}

@Test func chooserCannotPresentRowsFromPreviousSourceContextOrSearch() {
    let source = UUID()
    let old = LibraryGroupRequest(sourceID: source, search: "House", selectedID: "kept", context: "Artists")
    let changedSource = LibraryGroupRequest(sourceID: UUID(), search: "House", selectedID: "kept", context: "Artists")
    let changedContext = LibraryGroupRequest(sourceID: source, search: "House", selectedID: "kept", context: "Albums")
    let changedSearch = LibraryGroupRequest(sourceID: source, search: "Jazz", selectedID: "kept", context: "Artists")
    let changedSelection = LibraryGroupRequest(
        sourceID: source, search: "House", selectedID: "other", context: "Artists")
    #expect(old.canPresentResult(from: old) && !old.canPresentResult(from: nil))
    #expect(!changedSource.canPresentResult(from: old))
    #expect(!changedContext.canPresentResult(from: old))
    #expect(!changedSearch.canPresentResult(from: old))
    #expect(changedSelection.canPresentResult(from: old))
}
