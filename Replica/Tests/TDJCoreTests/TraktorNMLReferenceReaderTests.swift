import Foundation
import Testing
@testable import TDJCore

private func nmlData(_ body:String,count:String="1") -> Data {
    Data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><NML VERSION=\"synthetic-1\"><HEAD PROGRAM=\"Synthetic fixture\"/><COLLECTION ENTRIES=\"\(count)\">\(body)</COLLECTION><PLAYLISTS><ENTRY AUDIO_ID=\"playlist-only\"/></PLAYLISTS></NML>".utf8)
}

@Test func nmlReferencePreservesRawPreparationAndNeverTreatsPlaylistEntriesAsMusic() throws {
    let data=nmlData("""
    <ENTRY AUDIO_ID="opaque-not-sha256" TITLE="A &amp; B" ARTIST="Synthetic">
      <LOCATION DIR="/:Music/:" FILE="same-name.wav" VOLUME="Fixture"/>
      <TEMPO BPM="127.5"/><MUSICAL_KEY VALUE="17"/>
      <PRIMARYKEY TYPE="opaque" KEY="not-a-Music-ID"/>
      <CUE_V2 TYPE="4" START="123.456" LEN="0" HOTCUE="0"><GRID BPM="127.5"/></CUE_V2>
      <CUE_V2 TYPE="5" START="1000" LEN="4000" HOTCUE="7"/>
      <UNKNOWN VALUE="preserved"><TEXT><![CDATA[raw reference]]></TEXT></UNKNOWN>
    </ENTRY>
    """)
    var entries:[TraktorNMLElement]=[]
    let summary=try TraktorNMLReferenceReader.scan(data) { entries.append($0) }
    #expect(summary.version == "synthetic-1" && summary.program == "Synthetic fixture" && summary.entryCount == 1)
    let item=try #require(entries.first)
    #expect(item.attributes["AUDIO_ID"] == "opaque-not-sha256" && item.attributes["TITLE"] == "A & B")
    #expect(item.children.first(where: { $0.name == "MUSICAL_KEY" })?.attributes["VALUE"] == "17")
    let cues=item.children.filter { $0.name == "CUE_V2" }
    #expect(cues.count == 2 && cues[0].attributes["START"] == "123.456")
    #expect(cues[0].children.first?.attributes["BPM"] == "127.5")
    #expect(cues[1].attributes["HOTCUE"] == "7" && cues[1].attributes["LEN"] == "4000")
    #expect(item.children.last?.children.first?.text == "raw reference")
    #expect(try JSONDecoder().decode(TraktorNMLElement.self,from:JSONEncoder().encode(item)) == item)
    #expect(try JSONDecoder().decode(TraktorNMLReferenceSummary.self,from:JSONEncoder().encode(summary)) == summary)
}

@Test func nmlReferenceSupportsAnEmptyCollection() throws {
    let summary=try TraktorNMLReferenceReader.scan(nmlData("",count:"0")) { _ in Issue.record("Unexpected entry") }
    #expect(summary.entryCount == 0)
}

@Test(arguments:["bytes","entries","depth","nodes","attributes","text"])
func nmlReferenceEnforcesEveryBound(_ bound:String) {
    var limits=TraktorNMLReadLimits()
    var data=nmlData("<ENTRY A=\"1\" B=\"2\"><INFO>12345</INFO><TEMPO BPM=\"120\"/></ENTRY>")
    switch bound {
    case "bytes":limits.maximumBytes=data.count-1
    case "entries":limits.maximumEntries=1;data=nmlData("<ENTRY/><ENTRY/>",count:"2")
    case "depth":limits.maximumDepth=2
    case "nodes":limits.maximumNodesPerEntry=2
    case "attributes":limits.maximumAttributesPerNode=1
    default:limits.maximumTextBytesPerEntry=4
    }
    #expect(throws:TraktorNMLReadError.limitExceeded) { try TraktorNMLReferenceReader.scan(data,limits:limits) { _ in } }
}

@Test(arguments:["<NML VERSION=\"1\"><COLLECTION><ENTRY></COLLECTION></NML>",
                 "<OTHER VERSION=\"1\"><COLLECTION/></OTHER>",
                 "<NML><COLLECTION/></NML>",
                 "<NML VERSION=\"1\"><COLLECTION/><COLLECTION/></NML>",
                 "<NML VERSION=\"1\"><COLLECTION ENTRIES=\"2\"><ENTRY/></COLLECTION></NML>",
                 "<NML VERSION=\"1\"><COLLECTION ENTRIES=\"-1\"/></NML>"])
func nmlReferenceRejectsMalformedOrInconsistentDocuments(_ text:String) {
    #expect(throws:TraktorNMLReadError.invalidDocument) { try TraktorNMLReferenceReader.scan(Data(text.utf8)) { _ in } }
}

@Test func nmlReferenceRejectsEntitiesAndUnsupportedEncoding() {
    let declarations="<!DOCTYPE NML [<!ENTITY value SYSTEM 'file:///synthetic-unreadable'>]><NML VERSION=\"1\"><COLLECTION/></NML>"
    #expect(throws:TraktorNMLReadError.declarationsNotAllowed) { try TraktorNMLReferenceReader.scan(Data(declarations.utf8)) { _ in } }
    #expect(throws:TraktorNMLReadError.unsupportedEncoding) { try TraktorNMLReferenceReader.scan(Data([0xff,0xfe,0x00])) { _ in } }
    let encoding="<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><NML VERSION=\"1\"><COLLECTION/></NML>"
    #expect(throws:TraktorNMLReadError.unsupportedEncoding) { try TraktorNMLReferenceReader.scan(Data(encoding.utf8)) { _ in } }
}

private enum SyntheticImportFailure: Error { case cancelledByConsumer }
@Test func nmlReferencePropagatesCancellationAndConsumerFailureWithoutACompletedSummary() {
    #expect(throws:CancellationError.self) {
        try TraktorNMLReferenceReader.scan(nmlData("<ENTRY/>"),checkCancellation:{ throw CancellationError() }) { _ in }
    }
    var delivered=0
    #expect(throws:SyntheticImportFailure.cancelledByConsumer) {
        try TraktorNMLReferenceReader.scan(nmlData("<ENTRY/><ENTRY/>",count:"2")) { _ in
            delivered+=1;throw SyntheticImportFailure.cancelledByConsumer
        }
    }
    #expect(delivered == 1)
}

@Test func nmlReferenceDeliversEntriesIndividuallyAndRejectsAChangedCountAtTheEnd() throws {
    let data=nmlData((0..<5000).map { "<ENTRY AUDIO_ID=\"\($0)\"><INFO KEY=\"Cm\"/></ENTRY>" }.joined(),count:"5000")
    var count=0,first:TraktorNMLElement?,last:TraktorNMLElement?
    let summary=try TraktorNMLReferenceReader.scan(data) { item in
        if first == nil { first=item };last=item;count+=1
    }
    #expect(summary.entryCount == 5000 && count == 5000)
    #expect(first?.attributes["AUDIO_ID"] == "0" && last?.attributes["AUDIO_ID"] == "4999")
    var staged:[TraktorNMLElement]=[]
    #expect(throws:TraktorNMLReadError.invalidDocument) {
        try TraktorNMLReferenceReader.scan(nmlData("<ENTRY/>",count:"2")) { staged.append($0) }
    }
    #expect(staged.count == 1)
}

private final class NMLCancellationFlag: @unchecked Sendable {
    private let lock=NSLock()
    private var cancelled=false
    func cancel() { lock.lock();cancelled=true;lock.unlock() }
    func check() throws {
        lock.lock();let value=cancelled;lock.unlock()
        if value { throw CancellationError() }
    }
}

@Test func nmlReferenceCancellationBetweenEntriesStopsFurtherDelivery() {
    let flag=NMLCancellationFlag()
    var delivered=0
    #expect(throws:CancellationError.self) {
        try TraktorNMLReferenceReader.scan(nmlData("<ENTRY/><ENTRY/>",count:"2"),checkCancellation:{ try flag.check() }) { _ in
            delivered+=1;flag.cancel()
        }
    }
    #expect(delivered == 1)
}
