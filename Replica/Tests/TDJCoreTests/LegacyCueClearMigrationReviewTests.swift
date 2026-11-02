import Foundation
import Testing
@testable import TDJCore

@Test func legacyClearedCueBankDoesNotResurrectImportedCues() throws {
    let analysis = AudioAnalysis(implementation:"Synthetic migration",configurationID:"synthetic",
        contentSHA256:String(repeating:"a",count:64),sampleRate:48000,frameCount:48000,channelCount:2,
        waveformFramesPerBin:512,waveform:[],bpm:110,beatAnchorFrame:0,tempoConfidence:0,
        key:nil,keyConfidence:0,chroma:[],timbre:[])
    let xml = "<NML VERSION=\"17\"><HEAD PROGRAM=\"Traktor DJ\"/><COLLECTION ENTRIES=\"1\"><ENTRY><ITUNES PERSISTENT_ID=\"0000000000001234\" PLAYTIME=\"1000\"/><TEMPO BPM=\"120\"/><MUSICAL_KEY VALUE=\"0\"/><CUE_V2 TYPE=\"4\" START=\"0\" HOTCUE=\"-1\"/><CUE_V2 TYPE=\"0\" START=\"500\" HOTCUE=\"2\"/></ENTRY></COLLECTION></NML>"
    let catalog = try TraktorPreparationCatalog.read(Data(xml.utf8))
    let record = try #require(catalog.records.first)
    var track = try Track(title:"Synthetic",mediaFilename:"synthetic.wav",analysis:analysis)
    track.traktorPreparation = try catalog.bind(record,source:.init(platform:.iosMusic,persistentID:"4660"),analysis:analysis)
    var old = PerformancePreparation()
    old.cues[track.id] = [2:.init(frame:24000)]
    old.cues[track.id]?[2] = nil
    old.gridCueTracks = [track.id]
    var legacy = try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(old)) as? [String:Any])
    legacy.removeValue(forKey:"traktorCueHistory")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:root) }
    let file = root.appendingPathComponent("performance.json")
    try JSONSerialization.data(withJSONObject:legacy).write(to:file,options:.atomic)
    var migrated = try PerformancePreparation.load(from:file)
    #expect(migrated.traktorCueHistory == nil)
    #expect(migrated.cues[track.id]?.isEmpty == true)
    #expect(try migrated.installTraktorCues(for:track))
    #expect(migrated.cues[track.id]?.isEmpty == true)
    #expect(migrated.traktorCueHistory?[track.id]?.protectedEmptySlots == Set(0..<8))
    try migrated.save(to:file)
    migrated = try PerformancePreparation.load(from:file)
    #expect(try !migrated.installTraktorCues(for:track))
    #expect(migrated.cues[track.id]?.isEmpty == true)
}
