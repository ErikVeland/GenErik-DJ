import Foundation
import Testing
@testable import TDJCore

private func wideNML(_ text:String,encoding:String,bom:Bool=false) -> Data {
    let width=encoding.hasPrefix("utf32") ? 4:2,little=encoding.hasSuffix("le")
    var data=Data()
    if bom {
        if width == 2 { data.append(contentsOf:little ? [0xff,0xfe]:[0xfe,0xff]) }
        else { data.append(contentsOf:little ? [0xff,0xfe,0,0]:[0,0,0xfe,0xff]) }
    }
    for scalar in text.unicodeScalars {
        precondition(scalar.value<128)
        let shifts=little ? Array(0..<width):Array((0..<width).reversed())
        for shift in shifts { data.append(UInt8(truncatingIfNeeded:scalar.value >> (shift*8))) }
    }
    return data
}
private let syntheticWideEntityXML="<!DOCTYPE NML [<!ENTITY label \"expanded\">]><NML VERSION=\"synthetic\"><COLLECTION ENTRIES=\"1\"><ENTRY TITLE=\"&label;\"/></COLLECTION></NML>"

@Test(arguments:["utf16le","utf16be","utf32le","utf32be"])
func nmlEncodingRejectsWideDocumentsBeforeParserDelivery(_ encoding:String) {
    let plain="<NML VERSION=\"synthetic\"><COLLECTION ENTRIES=\"1\"><ENTRY TITLE=\"raw\"/></COLLECTION></NML>"
    let encodingName=encoding.hasPrefix("utf32") ? "UTF-32":"UTF-16"
    let declared="<?xml version=\"1.0\" encoding=\"\(encodingName)\"?>"+syntheticWideEntityXML
    for xml in [plain,syntheticWideEntityXML,declared] {
        for bom in [false,true] {
            let data=wideNML(xml,encoding:encoding,bom:bom)
            var delivered=0
            #expect(throws:TraktorNMLReadError.unsupportedEncoding) {
                try TraktorNMLReferenceReader.scan(data) { _ in delivered+=1 }
            }
            #expect(delivered == 0)
        }
    }
}

@Test(arguments:[0,20,100])
func nmlEncodingRejectsRawNULBytesInUTF8XML(_ position:Int) {
    var data=Data("<NML VERSION=\"1\"><COLLECTION ENTRIES=\"1\"><ENTRY TITLE=\"raw\"/></COLLECTION></NML>".utf8)
    data.insert(0,at:min(position,data.count))
    var delivered=0
    #expect(throws:TraktorNMLReadError.unsupportedEncoding) { try TraktorNMLReferenceReader.scan(data) { _ in delivered+=1 } }
    #expect(delivered == 0)
}

@Test func nmlEncodingRetainsValidNonASCIIUTF8WithAndWithoutBOM() throws {
    let xml="<?xml version=\"1.0\" encoding=\"UTF-8\"?><NML VERSION=\"synthetic\"><COLLECTION ENTRIES=\"1\"><ENTRY TITLE=\"Café 東京\"><NOTE>Ångström</NOTE></ENTRY></COLLECTION></NML>"
    for bom in [false,true] {
        var data=bom ? Data([0xef,0xbb,0xbf]):Data();data.append(contentsOf:xml.utf8)
        var entries:[TraktorNMLElement]=[]
        let result=try TraktorNMLReferenceReader.scanCollection(data) { entries.append($0) }
        #expect(result.document.entryCount == 1 && entries[0].attributes["TITLE"] == "Café 東京")
        #expect(entries[0].children.first?.text == "Ångström")
    }
}

// Python's standard gzip writer generated these no-BOM synthetic declaration fixtures.
private let wideEntityGzip:[String:Data]=[
    "utf16le":Data(base64Encoded:"H4sIAAAAAAAC/22OMQvCMBCFv58SHVyLs7FLzSBUI7UIIg5qCwoigh303/uSVHFwCJe79727Zxkww1NQs2WFw7BkQam6w0p16mvmUTdcOXCkVTUMVZ/cNbnR6N9okrPXs98dG/kr1vJ7zaYiHrzEd5zl6Lhwii6rBF6OUnwR7wXe9Ncr9U5bgn/c8x8lpEr5gjcQo5+UE/VZ5LO/F5KS0ua8AYUKax8OAQAA")!,
    "utf16be":Data(base64Encoded:"H4sIAAAAAAAC/22OMQvCMBCFv58SHVyLs7FLzSBUI7UIIg5qCwoigh303/uSVHFwCJe79727h2XADE9BzZYVDsOSBaXqjqA69TXzqBuuHDjSqhqGqk/umtxo9G80ydnr2e+OjfwVa/m9ZlMRD17iO85ydFw4RZdVAi9HKb6I9wJv+uuVeqctwT/u+Y8SUqV8wRuI0U/Kifos8tnfC0lJafM3r8H87g4BAAA=")!,
    "utf32le":Data(base64Encoded:"H4sIAAAAAAAC/5WQuwrCQBBF91OihW2wdrWJWwjRSBRBxEJNQEFE0EL/3rNwF4aghcUhmde9O+Odcz2YQgUFrGELSwiQwQLmUCregddsUD3Ozcx87LvCAY7QKo75vuIX3NVzg0b5Rj0T2Ovrv7xjI/8aVvKv1DeWxgPe0n/CWR7x/wIn4+V1g0oepfQLs1/Szzq716oHvSX5Dzv63Zl0K3u/5Js0Bj9uOVI9N/r5HzvYGXvbmP8AFNgdxxwCAAA=")!,
    "utf32be":Data(base64Encoded:"H4sIAAAAAAAC/5WQQQvCMAyF81OmB6/Ds3WX2YOwWZkiiHhQN1AYIuhB/72v8IKh6MHDR5smea+JiDgRGYAZCKAEa7AFS+BBBhagBhXjnXx6PfOxb276Y10PDuAIOsbxfcj4CW6suYKW7y1rCrDn6b78Y0P/BqzoH1g3pcYdvKj/AGd6xPsFnIyX4w4CPSrql2Y+1c+S2RvmPf+i/uNEP+3RXdn9qa9qjH7scsJ8bvTzP2awPXa3xRtqX04zHAIAAA==")!
]
@Test(arguments:["utf16le","utf16be","utf32le","utf32be"])
func nmlEncodingRejectsGzippedWideDeclarations(_ encoding:String) {
    var delivered=0
    #expect(throws:TraktorNMLReadError.unsupportedEncoding) {
        try TraktorNMLReferenceReader.scanCollection(wideEntityGzip[encoding]!) { _ in delivered+=1 }
    }
    #expect(delivered == 0)
}

private final class EncodingDeliveryCounter: @unchecked Sendable {
    private let lock=NSLock()
    private var value=0
    func delivered() { lock.lock();value+=1;lock.unlock() }
    var count:Int { lock.lock();defer { lock.unlock() };return value }
}
@Test(arguments:["utf16le","utf16be","utf32le","utf32be"])
func nmlEncodingBackgroundWorkerRejectsWideDeclarations(_ encoding:String) async {
    let counter=EncodingDeliveryCounter()
    let data=wideNML(syntheticWideEntityXML,encoding:encoding)
    await #expect(throws:TraktorNMLReadError.unsupportedEncoding) {
        try await TraktorPreparationReferenceWorker.scanCollection(data) { _ in counter.delivered() }
    }
    #expect(counter.count == 0)
}
