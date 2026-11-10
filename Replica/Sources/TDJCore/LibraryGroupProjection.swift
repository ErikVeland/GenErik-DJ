import Foundation

private final class LibraryGroupStorage: Sendable {
    let inputGroups: [CollectionGroup]
    let groups: [CollectionGroup]
    let lookup: [String: Int]
    let sortByName: Bool
    let prepared: Bool
    private static let retirement = DispatchQueue(label: "org.generikdj.group-retirement", qos: .background)
    init(
        inputGroups: [CollectionGroup], groups: [CollectionGroup], lookup: [String: Int], sortByName: Bool,
        prepared: Bool
    ) {
        self.inputGroups = inputGroups
        self.groups = groups
        self.lookup = lookup
        self.sortByName = sortByName
        self.prepared = prepared
    }
    deinit {
        let input = inputGroups
        let groups = self.groups
        let lookup = self.lookup
        Self.retirement.async(qos: .background, flags: .enforceQoS) { withExtendedLifetime((input, groups, lookup)) {} }
    }
}
public struct LibraryGroupSource: Sendable, Identifiable {
    public static let empty = Self(
        storage: .init(inputGroups: [], groups: [], lookup: [:], sortByName: false, prepared: true))
    public let id: UUID
    private let storage: LibraryGroupStorage
    fileprivate var groups: [CollectionGroup] { storage.groups }
    public init(groups: [CollectionGroup], sortByName: Bool = true) {
        self.init(
            storage: .init(inputGroups: groups, groups: groups, lookup: [:], sortByName: sortByName, prepared: false))
    }
    private init(storage: LibraryGroupStorage) {
        id = UUID()
        self.storage = storage
    }
    fileprivate func prepared(checkCancellation: @Sendable () throws -> Void) throws -> Self {
        if storage.prepared { return self }
        return try Self.prepared(
            groups: storage.groups, sortByName: storage.sortByName, checkCancellation: checkCancellation)
    }
    func group(for id: String?) -> CollectionGroup? {
        guard let id, let index = storage.lookup[id] else { return nil }
        return storage.groups[index]
    }
    static func prepared(
        groups: [CollectionGroup], sortByName: Bool = true, reusing previous: Self? = nil,
        checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }
    ) throws -> Self {
        try checkCancellation()
        if let previous, previous.storage.prepared, previous.storage.sortByName == sortByName,
            previous.storage.inputGroups.count == groups.count
        {
            var matches = true
            for index in groups.indices {
                if index & 255 == 0 { try checkCancellation() }
                let old = previous.storage.inputGroups[index]
                let new = groups[index]
                if old.id != new.id || old.name != new.name || old.isAppPlaylist != new.isAppPlaylist {
                    matches = false
                    break
                }
            }
            if matches { return previous }
        }
        var indices: [Int] = []
        var seen: Set<String> = []
        var steps = 0
        func tick() throws {
            steps &+= 1
            if steps & 255 == 0 { try checkCancellation() }
        }
        for index in groups.indices {
            try tick()
            if seen.insert(groups[index].id).inserted { indices.append(index) }
        }
        if sortByName {
            indices = try indices.sorted { a, b in
                try tick()
                let order = groups[a].name.localizedStandardCompare(groups[b].name)
                return order == .orderedSame ? a < b : order == .orderedAscending
            }
        }
        var result: [CollectionGroup] = []
        var lookup: [String: Int] = [:]
        result.reserveCapacity(indices.count)
        for index in indices {
            try tick()
            lookup[groups[index].id] = result.count
            result.append(groups[index])
        }
        try checkCancellation()
        return Self(
            storage: .init(inputGroups: groups, groups: result, lookup: lookup, sortByName: sortByName, prepared: true))
    }
}
public struct LibraryGroupRequest: Hashable, Sendable {
    public let sourceID: UUID
    public let search: String
    public let selectedID: String?
    public let context: String
    public init(sourceID: UUID, search: String, selectedID: String?, context: String) {
        self.sourceID = sourceID
        self.search = search
        self.selectedID = selectedID
        self.context = context
    }
    public func canPresentResult(from previous: Self?) -> Bool {
        guard let previous else { return false }
        return sourceID == previous.sourceID && context == previous.context && search == previous.search
    }
    public func resetsScroll(comparedTo previous: Self?) -> Bool {
        guard let previous else { return true }
        return search != previous.search || context != previous.context
    }
}
public struct LibraryGroupProjection: Sendable {
    private let source: LibraryGroupSource
    public var groups: [CollectionGroup] { source.groups }
    public var count: Int { groups.count }
    public let selectedGroup: CollectionGroup?
    private static let worker = AnalysisWorker()
    public func visibleGroups(in range: Range<Int>) -> [CollectionGroup] {
        let groups = source.groups
        let lower = min(groups.count, max(0, range.lowerBound))
        let upper = min(groups.count, max(lower, min(range.upperBound, lower + LibraryBrowserRowWindow.maximumRows)))
        return Array(groups[lower..<upper])
    }
    public static func build(source: LibraryGroupSource, search: String, selectedID: String? = nil) async throws -> Self
    {
        try await worker.run { check in
            try check()
            let prepared = try source.prepared(checkCancellation: check)
            let selected = prepared.group(for: selectedID)
            let words = search.split(whereSeparator: \.isWhitespace).map(String.init)
            if words.isEmpty { return Self(source: prepared, selectedGroup: selected) }
            var result: [CollectionGroup] = []
            for (index, group) in prepared.groups.enumerated() {
                if index & 255 == 0 { try check() }
                if words.allSatisfy({ group.name.localizedStandardContains($0) }) { result.append(group) }
            }
            let filtered = try LibraryGroupSource.prepared(groups: result, sortByName: false, checkCancellation: check)
            try check()
            return Self(source: filtered, selectedGroup: selected)
        }
    }
}
