import Foundation
import Testing
@testable import TDJCore

// Python's standard gzip writer generated these synthetic collection bytes with mtime=0.
private let syntheticNMLGzip=Data(base64Encoded:"H4sIAAAAAAAC/7Px8/VRCHMNCvb097NVKq7MK8lILclM1jVUsrPxcHV0UQgI8ncPcvS1VQqGySmkZVaUlBalKunb2Tj7+/i4OocANSu4+oUEeboG2yqBtII4kQqOoS6e/vGeLrZK+QWJhaWpQIkQV98AfwWnAKCBhkYGICP0wWqBNMIsIAfoLDsAYGxy+ZwAAAA=")!
private let syntheticLargeNMLGzip=Data(base64Encoded:"H4sIAAAAAAAC/+3HsQnDMBAAwFWMFzDpFTVCheH9AkUEvP8i8Qrp77orecX27fNzjnzvr72WNiJ6W89r6bnmXTcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA4G/l6LnmXcvRRkRv6xz5JK+oP02qMfR/DQMA")!

@Test func nmlGzipReferenceReadsTheCollectionAndRetainsTheOriginalDigest() throws {
    var entries:[TraktorNMLElement]=[]
    let summary=try TraktorNMLReferenceReader.scanCollection(syntheticNMLGzip) { entries.append($0) }
    #expect(summary.encoding == .gzip && summary.document.entryCount == 1)
    #expect(summary.sourceSHA256 == "e029752d9cb38e1c18caf8706567a13b992b4c5edd31381cb007990afdf85afd")
    #expect(entries.first?.attributes["AUDIO_ID"] == "opaque")
    #expect(try JSONDecoder().decode(TraktorCollectionReferenceSummary.self,from:JSONEncoder().encode(summary)) == summary)
    let plain=Data("<NML VERSION=\"1\"><COLLECTION ENTRIES=\"0\"/></NML>".utf8)
    let uncompressed=try TraktorNMLReferenceReader.scanCollection(plain) { _ in Issue.record("Unexpected entry") }
    #expect(uncompressed.encoding == .xml && uncompressed.document.entryCount == 0)
    #expect(uncompressed.sourceSHA256 != summary.sourceSHA256)
}

@Test(arguments:["truncated","crc","trailing","concatenated"])
func nmlGzipReferenceRejectsCorruptionAndUnconsumedBytes(_ kind:String) {
    var data=syntheticNMLGzip
    switch kind {
    case "truncated":data.removeLast()
    case "crc":data[data.count-8] ^= 1
    case "trailing":data.append(0)
    default:data.append(syntheticNMLGzip)
    }
    var delivered=0
    #expect(throws:TraktorNMLReadError.invalidCompression) {
        try TraktorNMLReferenceReader.scanCollection(data) { _ in delivered+=1 }
    }
    #expect(delivered == 0)
}

@Test func nmlGzipReferenceBoundsBothCompressedAndExpandedDataBeforeDelivery() {
    #expect(throws:TraktorNMLReadError.limitExceeded) {
        try TraktorNMLReferenceReader.scanCollection(syntheticNMLGzip,maximumCompressedBytes:syntheticNMLGzip.count-1) { _ in }
    }
    var limits=TraktorNMLReadLimits();limits.maximumBytes=64
    var delivered=0
    #expect(throws:TraktorNMLReadError.limitExceeded) {
        try TraktorNMLReferenceReader.scanCollection(syntheticLargeNMLGzip,limits:limits) { _ in delivered+=1 }
    }
    #expect(delivered == 0)
}

private final class GzipCancellation: @unchecked Sendable {
    private let lock=NSLock()
    private var calls=0
    func check() throws {
        lock.lock();calls+=1;let cancel=calls>=4;lock.unlock()
        if cancel { throw CancellationError() }
    }
}
@Test func nmlGzipReferenceChecksCancellationBetweenExpansionChunks() {
    let cancellation=GzipCancellation()
    var delivered=0
    #expect(throws:CancellationError.self) {
        try TraktorNMLReferenceReader.scanCollection(syntheticLargeNMLGzip,checkCancellation:{ try cancellation.check() }) { _ in delivered+=1 }
    }
    #expect(delivered == 0)
}
