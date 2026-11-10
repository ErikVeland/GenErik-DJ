import Foundation
import TDJCore

/// The signed Mac runner uses the same private CloudKit transport as the device app.
public enum LibraryCloudTransfer {
    public struct Report: Codable, Sendable {
        public let account: String
        public let confirmed: [String]
        public let message: String
        public let completedUTC: String
    }

    public static func synchronize(outboxes: [URL], root: URL, expectedAccount: String?) async throws -> Report {
        let store = try WorkspaceStore(root: root)
        let sync = CloudPreparationSync()
        let result = try await sync.synchronize(
            store: store, tracks: [], performance: .init(), automatic: true,
            incomingDirectories: outboxes, expectedAccount: expectedAccount
        ) { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }
        let confirmed = result.revisions.filter {
            $0.automaticAnalysis == true
                && FileManager.default.fileExists(atPath: result.root.appendingPathComponent($0.id + ".confirmed").path)
        }.map(\.id).sorted()
        return Report(account: result.root.lastPathComponent, confirmed: confirmed,
                      message: result.message, completedUTC: Date().ISO8601Format())
    }
}
