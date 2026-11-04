import CoreML
import CryptoKit
import Foundation

public enum StemModelRepositoryError: LocalizedError {
    case missingBundledModel
    case invalidArtifact(String)
    case insufficientStorage

    public var errorDescription: String? {
        switch self {
        case .missingBundledModel:
            return "The bundled stem model is missing. Reinstall GenErik DJ to restore it."
        case .invalidArtifact(let name):
            return "The bundled stem model file failed its integrity check: \(name)."
        case .insufficientStorage:
            return "Free at least 500 MB of storage before preparing the stem model."
        }
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

/// Reconstructs and compiles the pinned four-stem model that ships in the app bundle.
public actor StemModelRepository {
    private struct Artifact: Sendable {
        let name: String
        let path: String
        let size: Int64
        let sha256: String
    }

    private static let modelIdentity = "htdemucs-coreml-fp16-8b4d481"
    private static let packageName = "HTDemucs_CoreML_FP16.mlpackage"
    private static let manifestSHA256 = "14606502456a841e914dd1231cefd357eaf4cf3e2e7323c939543ab49f661b4c"
    private static let weightParts = ["weight.bin.part-aa", "weight.bin.part-ab", "weight.bin.part-ac"]
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
    private let compiler: any StemModelCompiling
    private var compilationTask: Task<URL, Error>?

    public init(root: URL, compiler: any StemModelCompiling = CoreMLStemModelCompiler()) {
        self.root = root.appendingPathComponent("StemModels", isDirectory: true)
        self.compiler = compiler
    }

    public func compiledModelURL() async throws -> URL {
        if let compilationTask { return try await compilationTask.value }
        let task = Task { try await self.compileBundledModel() }
        compilationTask = task
        do {
            let url = try await task.value
            compilationTask = nil
            return url
        } catch {
            compilationTask = nil
            throw error
        }
    }

    private func compileBundledModel() async throws -> URL {
        let compiled = root.appendingPathComponent(Self.modelIdentity + ".mlmodelc", isDirectory: true)
        if FileManager.default.fileExists(atPath: compiled.path) { return compiled }

        try makeSureStorageIsAvailable()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent(UUID().uuidString + ".mlpackage", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        try reconstructBundledPackage(at: staging)
        try Task.checkCancellation()
        let temporaryCompiled = try await compiler.compile(packageAt: staging)
        if FileManager.default.fileExists(atPath: compiled.path) {
            try FileManager.default.removeItem(at: compiled)
        }
        try FileManager.default.moveItem(at: temporaryCompiled, to: compiled)
        return compiled
    }

    private func reconstructBundledPackage(at destination: URL) throws {
        let bundledPackage = try bundledPackageURL()
        let manifest = bundledPackage.appendingPathComponent("Manifest.json")
        let manifestAttributes = try FileManager.default.attributesOfItem(atPath: manifest.path)
        guard (manifestAttributes[.size] as? NSNumber)?.int64Value == 617,
              try Self.sha256(of: manifest) == Self.manifestSHA256 else {
            throw StemModelRepositoryError.invalidArtifact("Manifest.json")
        }
        try FileManager.default.copyItem(at: manifest, to: destination.appendingPathComponent("Manifest.json"))

        for artifact in Self.artifacts {
            try Task.checkCancellation()
            let target = destination.appendingPathComponent(artifact.path)
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if artifact.name == "weight.bin" {
                try concatenateBundledWeights(to: target)
            } else {
                let source = bundledPackage.appendingPathComponent(artifact.path)
                try FileManager.default.copyItem(at: source, to: target)
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
            guard (attributes[.size] as? NSNumber)?.int64Value == artifact.size,
                  try Self.sha256(of: target) == artifact.sha256 else {
                throw StemModelRepositoryError.invalidArtifact(artifact.name)
            }
        }
    }

    private func bundledPackageURL() throws -> URL {
        guard let resources = Bundle.module.resourceURL else {
            throw StemModelRepositoryError.missingBundledModel
        }
        let url = resources
            .appendingPathComponent("StemModelAssets", isDirectory: true)
            .appendingPathComponent(Self.packageName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StemModelRepositoryError.missingBundledModel
        }
        return url
    }

    private func concatenateBundledWeights(to destination: URL) throws {
        guard let resources = Bundle.module.resourceURL else {
            throw StemModelRepositoryError.missingBundledModel
        }
        let weightDirectory = resources
            .appendingPathComponent("StemModelAssets", isDirectory: true)
            .appendingPathComponent(Self.packageName, isDirectory: true)
            .appendingPathComponent("Data/com.apple.CoreML/weights", isDirectory: true)

        try Data().write(to: destination, options: .atomic)
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        for part in Self.weightParts {
            try Task.checkCancellation()
            let source = weightDirectory.appendingPathComponent(part)
            let input = try FileHandle(forReadingFrom: source)
            defer { try? input.close() }
            while let data = try input.read(upToCount: 1_048_576), !data.isEmpty {
                try output.write(contentsOf: data)
            }
        }
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
