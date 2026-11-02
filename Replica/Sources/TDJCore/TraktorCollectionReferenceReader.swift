import Foundation
import CryptoKit
import zlib

public struct TraktorCollectionReferenceSummary: Codable, Equatable, Sendable {
    public enum Encoding: String, Codable, Sendable { case xml, gzip }
    public let sourceSHA256: String
    public let encoding: Encoding
    public let document: TraktorNMLReferenceSummary
}

extension TraktorNMLReferenceReader {
    /// Run on a background worker. Stage entries until decompression and the complete XML scan succeed.
    public static func scanCollection(_ data:Data,limits:TraktorNMLReadLimits = .init(),
                                      maximumCompressedBytes:Int=16*1024*1024,
                                      checkCancellation:@escaping @Sendable () throws -> Void = {},
                                      entry:@escaping (TraktorNMLElement) throws -> Void) throws -> TraktorCollectionReferenceSummary {
        try checkCancellation()
        let compressed=data.starts(with:[0x1f,0x8b])
        let xml:Data
        if compressed {
            guard maximumCompressedBytes>0,data.count<=maximumCompressedBytes,limits.maximumBytes>0 else {
                throw TraktorNMLReadError.limitExceeded
            }
            xml=try expandGzip(data,maximumBytes:limits.maximumBytes,check:checkCancellation)
        } else { xml=data }
        let document=try scan(xml,limits:limits,checkCancellation:checkCancellation,entry:entry)
        try checkCancellation()
        let digest=SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
        try checkCancellation()
        return .init(sourceSHA256:digest,encoding:compressed ? .gzip:.xml,document:document)
    }
}

private func expandGzip(_ data:Data,maximumBytes:Int,check:() throws -> Void) throws -> Data {
    guard data.count<=Int(uInt.max) else { throw TraktorNMLReadError.limitExceeded }
    var stream=z_stream()
    guard inflateInit2_(&stream,15+16,ZLIB_VERSION,Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
        throw TraktorNMLReadError.invalidCompression
    }
    defer { inflateEnd(&stream) }
    return try data.withUnsafeBytes { input in
        stream.next_in=UnsafeMutablePointer(mutating:input.bindMemory(to:Bytef.self).baseAddress)
        stream.avail_in=uInt(input.count)
        let capacity=32*1024
        var buffer=[UInt8](repeating:0,count:capacity),result=Data()
        while true {
            try check()
            let status=buffer.withUnsafeMutableBytes { output in
                stream.next_out=output.bindMemory(to:Bytef.self).baseAddress
                stream.avail_out=uInt(capacity)
                return inflate(&stream,Z_NO_FLUSH)
            }
            guard status == Z_OK || status == Z_STREAM_END else { throw TraktorNMLReadError.invalidCompression }
            let produced=capacity-Int(stream.avail_out)
            guard produced<=maximumBytes-result.count else { throw TraktorNMLReadError.limitExceeded }
            result.append(contentsOf:buffer.prefix(produced))
            if status == Z_STREAM_END {
                // One collection member is supported. Do not ignore trailing bytes or another member.
                guard stream.avail_in == 0 else { throw TraktorNMLReadError.invalidCompression }
                try check();return result
            }
            guard produced>0 || stream.avail_in>0 else { throw TraktorNMLReadError.invalidCompression }
        }
    }
}
