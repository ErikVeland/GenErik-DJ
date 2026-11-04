import CryptoKit
import Foundation
import TDJCore

/// A collection chosen once in Files stays linked. Every launch and activation reads it (never
/// writes it) and imports it again when its contents change, so later exports arrive automatically.
extension ReplicaModel {
    var collectionLinkURL: URL { store.root.appendingPathComponent("collection-link.bookmark") }

    func saveCollectionLink(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return }
        try? bookmark.write(to: collectionLinkURL, options: .atomic)
    }

    /// Resolves the linked file. Nil when nothing is linked or the link no longer resolves.
    nonisolated static func resolveCollectionLink(_ bookmark: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    func refreshLinkedCollection() async {
        guard let bookmark = try? Data(contentsOf: collectionLinkURL), let url = Self.resolveCollectionLink(bookmark)
        else { return }
        let digest: String? = await nativeMusic.files.run {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        guard let digest, digest != (await service.activeCollectionDigest()) else { return }
        do {
            let summary = try await importAccess.withAccess(to: url) {
                try await self.service.importTraktorCollection(url: url)
            }
            traktorPreparationRecords = summary.document.entryCount
            logAnalysis("Linked collection updated: \(summary.document.entryCount) records")
        } catch { logAnalysis("Linked collection not imported: \(error.localizedDescription)") }
    }
}
