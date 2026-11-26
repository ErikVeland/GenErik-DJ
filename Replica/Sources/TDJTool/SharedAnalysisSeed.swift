import Foundation
import TDJCore

extension TDJTool {
    static func prepareSharedAnalysisSeed(vault: URL, selection: URL) throws {
        let revisions = try JSONDecoder().decode([String].self, from: Data(contentsOf: selection))
        guard !revisions.isEmpty, revisions.count <= SharedAnalysisCatalogue.batchSize else {
            throw CoreError.invalidWorkspace("Select between 1 and 16 analysis revisions.")
        }
        let source = try CloudPreparationVault(root: vault)
        let operations = try revisions.map { revision in
            let archive = try source.read(revision)
            guard archive.automaticAnalysis == true, let deep = archive.track.analysis.deepBeatAnalysis else {
                throw CoreError.invalidWorkspace("Select an automatic revision with deep analysis.")
            }
            let data = try JSONEncoder.sortedSeedPayload(deep)
            guard SharedAnalysisCatalogue.decode(data, matching: archive.track) == deep else {
                throw CoreError.invalidWorkspace("Select a valid deep result for the current analysis profile.")
            }
            let record = SeedRecord(recordName: SharedAnalysisCatalogue.recordName(for: archive.track.analysis),
                fields: .init(analysis: .init(value: data)))
            return SeedOperation(record: record)
        }
        guard Set(operations.map { $0.record.recordName }).count == operations.count else {
            throw CoreError.invalidWorkspace("Select only one revision for each audio identity.")
        }
        try emit(SeedRequest(operations: operations))
    }
}

private struct SeedRequest: Encodable {
    let operations: [SeedOperation]
}

private struct SeedOperation: Encodable {
    let operationType = "create"
    let record: SeedRecord
}

private struct SeedRecord: Encodable {
    struct Fields: Encodable {
        struct Analysis: Encodable {
            let type = "BYTES"
            let value: Data
        }

        let analysis: Analysis
    }

    let recordName: String
    let recordType = "SharedAnalysisV1"
    let fields: Fields
}

private extension JSONEncoder {
    static func sortedSeedPayload(_ analysis: DeepBeatAnalysis) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(analysis)
    }
}
