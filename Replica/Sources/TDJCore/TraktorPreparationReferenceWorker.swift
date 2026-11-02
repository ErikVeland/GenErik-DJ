import Foundation

public enum TraktorPreparationReferenceWorker {
    /// Shares the existing serial background analysis worker. Entries remain provisional until the scan succeeds.
    public static func scanCollection(_ data:Data,limits:TraktorNMLReadLimits = .init(),
                                      maximumCompressedBytes:Int=16*1024*1024,
                                      entry:@escaping @Sendable (TraktorNMLElement) throws -> Void) async throws -> TraktorCollectionReferenceSummary {
        try await AnalysisWorker.shared.run { check in
            try withoutActuallyEscaping(check) { cancellation in
                try TraktorNMLReferenceReader.scanCollection(data,limits:limits,maximumCompressedBytes:maximumCompressedBytes,
                    checkCancellation:cancellation,entry:entry)
            }
        }
    }
}
