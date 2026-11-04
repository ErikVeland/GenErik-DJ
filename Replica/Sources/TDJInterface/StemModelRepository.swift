import CoreML
import CryptoKit
import Foundation

public enum StemModelRepositoryError: LocalizedError {
    case invalidResponse
    case invalidArtifact(String)
    case insufficientStorage

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The stem model download returned an invalid response."
        case .invalidArtifact(let name):
            return "The downloaded stem model file failed its integrity check: \(name)."
        case .insufficientStorage:
            return "Free at least 500 MB of storage before installing the stem model."
        }
    }
}

public protocol StemModelDownloading: Sendable {
    func download(from source: URL, to destination: URL) async throws
}

public struct URLSessionStemModelDownloader: StemModelDownloading {
    public init() {}

    public func download(from source: URL, to destination: URL) async throws {
        let (temporary, response) = try await URLSession.shared.download(from: source)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw StemModelRepositoryError.invalidResponse
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}

public protocol StemModelCompiling: Sendable {
    func compile(packageAt url: URL) async throws -> URL
}

public struct CoreMLStemModelCompiler: StemModelCompiling {
    public init() {}

    public func compile(packageAt url: URL) async throws -> URL {
        try await MLModel.compileModel(at: url)
    }
}

/// Downloads and compiles a pinned four-stem Core ML model into local app storage.
public actor StemModelRepository {
    private struct Artifact: Sendable {
        let name: String
        let path: String
        let size: Int64
        let sha256: String
    }

    private static let revision = "8b4d481"
    private static let modelName = "htdemucs-coreml-fp16-\(revision)"
    private static let packageManifest = """
    {
      "fileFormatVersion": "1.0.0",
      "itemInfoEntries": {
        "02CB79C0-A986-4E3F-ABF8-796A39543460": {
          "author": "com.apple.CoreML",
          "description": "CoreML Model Weights",
          "name": "weights",
          "path": "com.apple.CoreML/weights"
        },
        "5472320A-6037-4CD3-AA89-B348A89A8D53": {
          "author": "com.apple.CoreML",
          "description": "CoreML Model Specification",
          "name": "model.mlmodel",
          "path": "com.apple.CoreML/model.mlmodel"
        }
      },
      "rootModelIdentifier": "5472320A-6037-4CD3-AA89-B348A89A8D53"
    }
    """

    private static let artifacts = [
        Artifact(
            name: "model.mlmodel",
            path: "Data/com.apple.CoreML/model.mlmodel",
            size: 42_887_847,
            sha256: "307ddf24af60111ba821d4ad6bf2d1d987d6531ca2f487b6a95ec16a16a9c644"
        ),
        Artifact(
            name: "weight.bin",
            path: "Data/com.apple.CoreML/weights/weight.bin",
            size: 190_099_328,
            sha256: "efab790ad07d93faeb5a19b6e1eedad8c37ad351563a891a153fce307811c099"
        )
    ]

    private let root: URL
    private let downloader: any StemModelDownloading
    private let compiler: any StemModelCompiling

    public init(root: URL, downloader: any StemModelDownloading = URLSessionStemModelDownloader(),
                compiler: any StemModelCompiling = CoreMLStemModelCompiler()) {
        self.root = root.appendingPathComponent("StemModels", isDirectory: true)
        self.downloader = downloader
        self.compiler = compiler
    }

    public func compiledModelURL() async throws -> URL {
        let compiled = root.appendingPathComponent(Self.modelName + ".mlmodelc", isDirectory: true)
        if FileManager.default.fileExists(atPath: compiled.path) { return compiled }

        try makeSureStorageIsAvailable()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent(UUID().uuidString + ".mlpackage", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        for artifact in Self.artifacts {
            try Task.checkCancellation()
            let destination = staging.appendingPathComponent(artifact.path)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let source = URL(string: "https://huggingface.co/dexxdean/htdemucs-coreml/resolve/\(Self.revision)/HTDemucs_CoreML_FP16.mlpackage/\(artifact.path)")!
            try await downloader.download(from: source, to: destination)
            let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
            guard (attributes[.size] as? NSNumber)?.int64Value == artifact.size,
                  try Self.sha256(of: destination) == artifact.sha256 else {
                throw StemModelRepositoryError.invalidArtifact(artifact.name)
            }
        }

        try Data(Self.packageManifest.utf8).write(
            to: staging.appendingPathComponent("Manifest.json"),
            options: .atomic
        )
        try Task.checkCancellation()
        let temporaryCompiled = try await compiler.compile(packageAt: staging)
        if FileManager.default.fileExists(atPath: compiled.path) {
            try FileManager.default.removeItem(at: compiled)
        }
        try FileManager.default.moveItem(at: temporaryCompiled, to: compiled)
        return compiled
    }

    private func makeSureStorageIsAvailable() throws {
        guard let capacity = try? root.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage,
              capacity >= 500 * 1_024 * 1_024 else {
            throw StemModelRepositoryError.insufficientStorage
        }
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hash.update(data: data)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
