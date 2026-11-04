import Foundation

private final class LibraryBrowserStorage: Sendable {
    let entries: [LibraryBrowserEntry]
    let allEntries: [LibraryBrowserEntry]
    let groups: [CollectionGroup]
    let groupSource: LibraryGroupSource
    let playlistTargets: LibraryGroupSource
    let selectedGroup: CollectionGroup?
    private static let retirement = DispatchQueue(label: "org.generikdj.browser-retirement", qos: .background)
    init(
        entries: [LibraryBrowserEntry], allEntries: [LibraryBrowserEntry], groups: [CollectionGroup],
        groupSource: LibraryGroupSource, playlistTargets: LibraryGroupSource, selectedGroup: CollectionGroup?
    ) {
        self.entries = entries
        self.allEntries = allEntries
        self.groups = groups
        self.selectedGroup = selectedGroup
        self.groupSource = groupSource
        self.playlistTargets = playlistTargets
    }
    deinit {
        let entries = self.entries
        let allEntries = self.allEntries
        let groups = self.groups
        Self.retirement.async(qos: .background, flags: .enforceQoS) {
            withExtendedLifetime((entries, allEntries, groups)) {}
        }
    }
}

public struct LibraryBrowserProjection: Sendable {
    private let storage: LibraryBrowserStorage
    public var entries: [LibraryBrowserEntry] { storage.entries }
    public var allEntries: [LibraryBrowserEntry] { storage.allEntries }
    public var groups: [CollectionGroup] { storage.groups }
    public var groupSource: LibraryGroupSource { storage.groupSource }
    public var playlistTargets: LibraryGroupSource { storage.playlistTargets }
    public var selectedGroup: CollectionGroup? { storage.selectedGroup }
    private static let worker = AnalysisWorker()

    public static func build(
        tracks: [Track], suggestionIDs: [String]?, search: String, sort: CollectionSort?, category: CollectionCategory,
        group: String?, playlists: CollectionPlaylists, catalog: MusicLibraryCatalog?, previous: Self? = nil,
        hints: [String: BrowserPreparationHint] = [:]
    ) async throws -> Self {
        try await worker.run { check in
            try buildOnWorker(
                tracks: tracks, suggestionIDs: suggestionIDs, search: search, sort: sort, category: category,
                group: group, playlists: playlists, catalog: catalog, previous: previous, hints: hints, check: check)
        }
    }
    package static func build(
        librarySource: BackgroundOwnedValue<LibrarySnapshot>, catalogSource: BackgroundOwnedValue<MusicLibraryCatalog>?,
        suggestionIDs: [String]?, search: String, sort: CollectionSort?, category: CollectionCategory, group: String?,
        playlists: CollectionPlaylists, previous: Self? = nil, hints: [String: BrowserPreparationHint] = [:]
    ) async throws -> Self {
        try await worker.run { check in
            let tracks = librarySource.withValue { $0.tracks }
            let catalog = catalogSource?.withValue { $0 }
            return try buildOnWorker(
                tracks: tracks, suggestionIDs: suggestionIDs, search: search, sort: sort, category: category,
                group: group, playlists: playlists, catalog: catalog, previous: previous, hints: hints, check: check)
        }
    }
    private static func buildOnWorker(
        tracks: [Track], suggestionIDs: [String]?, search: String, sort: CollectionSort?, category: CollectionCategory,
        group: String?, playlists: CollectionPlaylists, catalog: MusicLibraryCatalog?, previous: Self?,
        hints: [String: BrowserPreparationHint] = [:], check: @Sendable () throws -> Void
    ) throws -> Self {
        try check()
        var steps = 0
        func tick() throws {
            steps &+= 1
            if steps & 255 == 0 { try check() }
        }
        var byTrack: [String: Track] = [:]
        var bySourceID: [String: Track] = [:]
        for track in tracks {
            try tick()
            if byTrack[track.id] == nil { byTrack[track.id] = track }
            for source in track.musicLibrarySources ?? [] where bySourceID[source.id] == nil {
                bySourceID[source.id] = track
            }
        }
        var native: [LibraryBrowserEntry] = []
        var byNative: [String: LibraryBrowserEntry] = [:]
        var represented: Set<String> = []
        var itemsBySource: [MusicLibrarySource: MusicLibraryItem] = [:]
        for item in catalog?.items ?? [] {
            try tick()
            guard item.isOnDevice else { continue }
            guard byNative[item.id] == nil else { continue }
            let track = bySourceID[item.source.id]
            let entry = LibraryBrowserEntry(nativeItem: item, track: track, hint: hints[item.id])
            native.append(entry)
            byNative[item.id] = entry
            itemsBySource[item.source] = item
            if let track { represented.insert(track.id) }
        }
        func nativeEntry(_ id: String) throws -> LibraryBrowserEntry? {
            try tick()
            return byNative[id]
        }
        func canonical(_ track: Track) -> LibraryBrowserEntry? {
            guard track.nativeLibraryOnly == true else { return .init(track: track) }
            let items = (track.musicLibrarySources ?? []).compactMap { itemsBySource[$0] }
            if let item = items.first(where: \.isOnDevice) { return .init(track: track, nativeItem: item) }
            return nil
        }
        var all = native
        for track in tracks where !represented.contains(track.id) {
            try tick()
            if let entry = canonical(track) { all.append(entry) }
        }
        var playlistTargets: [CollectionGroup] = []
        for playlist in playlists.playlists {
            try tick()
            playlistTargets.append(.init(id: playlist.id.uuidString, name: playlist.name))
        }
        let groups: [CollectionGroup]
        if category == .playlists {
            var values = playlistTargets
            for playlist in catalog?.playlists ?? [] where playlist.itemIDs.contains(where: { byNative[$0] != nil }) {
                try tick()
                values.append(.init(id: "music:" + playlist.id, name: playlist.name + " · Music"))
            }
            groups = values
        } else if category == .songs {
            groups = []
        } else {
            var values: Set<String> = []
            for entry in all {
                try tick()
                values.insert(categoryValue(entry, category: category))
            }
            groups = try values.sorted { a, b in
                try tick()
                return a.localizedStandardCompare(b) == .orderedAscending
            }.map { .init(id: $0, name: $0.isEmpty ? "Unknown" : $0) }
        }
        func resolve(_ ids: [String], nativeOnly: Bool = false) throws -> [LibraryBrowserEntry] {
            var result: [LibraryBrowserEntry] = []
            var seen: Set<String> = []
            for id in ids {
                try tick()
                let entry: LibraryBrowserEntry?
                if !nativeOnly, let track = byTrack[id] {
                    entry = canonical(track)
                } else if let native = try nativeEntry(id) {
                    entry = native
                } else if !nativeOnly, let track = bySourceID[id], let canonicalEntry = canonical(track) {
                    entry = canonicalEntry.withOccurrenceID(id)
                } else {
                    entry = nil
                }
                if let entry, seen.insert(entry.id).inserted { result.append(entry) }
            }
            return result
        }
        let words = search.split(whereSeparator: \.isWhitespace).map(String.init)
        var candidates = all
        if words.isEmpty, let suggestionIDs {
            candidates = try resolve(suggestionIDs)
        } else if words.isEmpty, let group {
            if category == .playlists {
                if group.hasPrefix("music:") {
                    let id = String(group.dropFirst(6))
                    let occurrences = try LibraryPlaylistOccurrences.build(
                        playlistID: id, itemIDs: catalog?.playlists.first { $0.id == id }?.itemIDs ?? [],
                        checkCancellation: check)
                    var rows: [LibraryBrowserEntry] = []
                    rows.reserveCapacity(occurrences.count)
                    for occurrence in occurrences {
                        try tick()
                        if let entry = try nativeEntry(occurrence.membershipID) {
                            rows.append(entry.withOccurrenceID(occurrence.id))
                        }
                    }
                    candidates = rows
                } else {
                    candidates = try resolve(playlists.playlists.first { $0.id.uuidString == group }?.trackIDs ?? [])
                }
            } else if category != .songs {
                candidates = try all.filter { entry in
                    try tick()
                    return categoryValue(entry, category: category) == group
                }
            }
        }
        var indices: [Int] = []
        for index in candidates.indices {
            try tick()
            let entry = candidates[index]
            if words.allSatisfy({ word in
                [entry.title, entry.artist, entry.album, entry.genre ?? ""].contains {
                    $0.localizedStandardContains(word)
                }
            }) {
                indices.append(index)
            }
        }
        if let sort, suggestionIDs == nil || !words.isEmpty {
            indices = try indices.sorted { a, b in
                try tick()
                let left = candidates[a]
                let right = candidates[b]
                switch sort {
                case .title, .artist, .album:
                    let lhs = sort == .title ? left.title : sort == .artist ? left.artist : left.album
                    let rhs = sort == .title ? right.title : sort == .artist ? right.artist : right.album
                    let order = lhs.localizedStandardCompare(rhs)
                    if order != .orderedSame { return order == .orderedAscending }
                case .key:
                    let lhs = left.key?.name
                    let rhs = right.key?.name
                    if lhs != rhs {
                        guard let lhs else { return false }
                        guard let rhs else { return true }
                        return lhs.localizedStandardCompare(rhs) == .orderedAscending
                    }
                case .bpm:
                    let lhs = left.bpm ?? .infinity
                    let rhs = right.bpm ?? .infinity
                    if lhs != rhs { return lhs < rhs }
                }
                return a < b
            }
        }
        var result: [LibraryBrowserEntry] = []
        result.reserveCapacity(indices.count)
        for index in indices {
            try tick()
            result.append(candidates[index])
        }
        try check()
        let source = try LibraryGroupSource.prepared(
            groups: groups, sortByName: false, reusing: previous?.groupSource, checkCancellation: check)
        let targets = try LibraryGroupSource.prepared(
            groups: playlistTargets, sortByName: false, reusing: previous?.playlistTargets, checkCancellation: check)
        return Self(
            storage: .init(
                entries: result, allEntries: all, groups: groups, groupSource: source, playlistTargets: targets,
                selectedGroup: source.group(for: group)))
    }
    public static func selectedIDs(selection: Set<String>, tracks: [Track], catalog: MusicLibraryCatalog?) async throws
        -> [String]
    {
        try await worker.run { check in
            try selectedIDsOnWorker(selection: selection, tracks: tracks, catalog: catalog, check: check)
        }
    }
    package static func selectedIDs(
        selection: Set<String>, librarySource: BackgroundOwnedValue<LibrarySnapshot>,
        catalogSource: BackgroundOwnedValue<MusicLibraryCatalog>?
    ) async throws -> [String] {
        try await worker.run { check in
            let tracks = librarySource.withValue { $0.tracks }
            let catalog = catalogSource?.withValue { $0 }
            return try selectedIDsOnWorker(selection: selection, tracks: tracks, catalog: catalog, check: check)
        }
    }
    private static func selectedIDsOnWorker(
        selection: Set<String>, tracks: [Track], catalog: MusicLibraryCatalog?, check: @Sendable () throws -> Void
    ) throws -> [String] {
        var ids: [String] = []
        var seen: Set<String> = []
        let localItems = (catalog?.items ?? []).filter(\.isOnDevice)
        let localItemIDs = Set(localItems.map(\.id))
        let localSources = Set(localItems.map(\.source))
        for track in tracks {
            try check()
            let hasLocalSource = (track.musicLibrarySources ?? []).contains(where: { localSources.contains($0) })
            if track.nativeLibraryOnly != true || hasLocalSource {
                if selection.contains(track.id), seen.insert(track.id).inserted { ids.append(track.id) }
            }
        }
        for item in localItems {
            try check()
            if selection.contains(item.id), seen.insert(item.id).inserted { ids.append(item.id) }
        }
        for track in tracks where track.nativeLibraryOnly != true {
            try check()
            for source in track.musicLibrarySources ?? [] where !localItemIDs.contains(source.id) {
                try check()
                if selection.contains(source.id), seen.insert(track.id).inserted { ids.append(track.id) }
            }
        }
        for track in tracks {
            try check()
            for source in track.musicLibrarySources ?? [] {
                try check()
                let id = source.id
                if localItemIDs.contains(id), selection.contains(id), seen.insert(id).inserted { ids.append(id) }
            }
        }
        return ids
    }
    private static func categoryValue(_ entry: LibraryBrowserEntry, category: CollectionCategory) -> String {
        switch category {
        case .artists: return entry.artist
        case .albums: return entry.album
        case .genre: return entry.genre ?? ""
        default: return ""
        }
    }
}

public struct LibraryBrowserRowWindow: Sendable {
    public static let rowHeight = 58.0
    public static let maximumRows = 128
    public let range: Range<Int>
    public let topHeight: Double
    public let bottomHeight: Double
    public init(count: Int, offset: Double, viewportHeight: Double) {
        let count = max(0, count)
        let height = viewportHeight.isFinite ? max(0, viewportHeight) : 0
        guard count > 0 else {
            range = 0..<0
            topHeight = 0
            bottomHeight = 0
            return
        }
        let offset = offset.isFinite ? max(0, offset) : 0
        let position = min(offset, max(0, Double(count) * Self.rowHeight - height))
        let first = min(count - 1, Int(position / Self.rowHeight))
        let visible = Int(min(Double(Self.maximumRows - 24), ceil(height / Self.rowHeight) + 1))
        let lower = max(0, first - 12)
        let upper = min(count, first + visible + 12)
        range = lower..<min(upper, lower + Self.maximumRows)
        topHeight = Double(range.lowerBound) * Self.rowHeight
        bottomHeight = Double(count - range.upperBound) * Self.rowHeight
    }
}

/// Every index a lazy browser list renders, first to last. Rows are fixed at LibraryBrowserRowWindow.rowHeight.
public struct LibraryBrowserRows: Sendable, Equatable {
    public let count: Int
    public init(count: Int) { self.count = max(0, count) }
    public var indices: Range<Int> { 0..<count }
    public var contentHeight: Double { Double(count) * LibraryBrowserRowWindow.rowHeight }
}
