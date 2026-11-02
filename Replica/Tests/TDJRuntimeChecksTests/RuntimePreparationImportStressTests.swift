import AVFoundation
import Foundation
import Testing
import TDJCore
import TDJInterface
@testable import TDJRuntimeChecks

@Test func preparationImportModeRequiresAnExplicitValidFlag() throws {
    #expect(!AudioRuntimeControlConfiguration().preparationImport)
    #expect(!(try AudioRuntimeControlConfiguration.parse(arguments:["check"])).preparationImport)
    let enabled=try AudioRuntimeControlConfiguration.parse(arguments:["check","--audio-control-preparation-import","--audio-control-model-fx","--audio-control-model-filter","--audio-control-driver=direct-main-event"])
    #expect(enabled.preparationImport && enabled.modelFX && enabled.modelFilter && enabled.driver == .directMainEvent)
    for flags in [["--audio-control-preparation-import","--audio-control-preparation-import"],["--audio-control-preparation-import=false"]] {
        #expect(throws:AudioRuntimeControlConfiguration.InvalidArgument.self) {
            _=try AudioRuntimeControlConfiguration.parse(arguments:["check"]+flags)
        }
    }
}

@Test func preparationImportSyntheticCollectionsHaveDistinctValidatedReferences() throws {
    let a=try RuntimePreparationImportStress.collection(duration:16)
    let b=try RuntimePreparationImportStress.collection(duration:16,variant:1)
    #expect(a != b)
    let catalog=try TraktorPreparationCatalog.read(a)
    #expect(catalog.records.count==10_000)
    let record=try #require(catalog.match(.init(platform:.iosMusic,persistentID:"4660")))
    #expect(record.canReuseMusicalPreparation && record.bpm==123)
    #expect(throws:TransportError.self) { _=try RuntimePreparationImportStress.collection(duration:.nan) }
}

@Test @MainActor func preparationImportStressRetainsPlayingDecksAndRejectsStaleSuccess() async throws {
    var fixture=URL(fileURLWithPath:#filePath)
    for _ in 0..<4 { fixture.deleteLastPathComponent() }
    fixture.appendPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let file=try AVAudioFile(forReading:fixture),root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let duration=Double(file.length)/file.processingFormat.sampleRate
    let provider=RuntimePreparationLibrary(source:fixture,duration:duration)
    let model=try ReplicaModel(root:root.appendingPathComponent("Workspace"),playback:PlaybackController(offline:true),musicLibraryProvider:provider)
    await model.refreshMusicLibrary()
    await model.importMusicLibraryItems([provider.item.id])
    let track=try #require(model.library.tracks.first)
    for deck in DeckID.allCases { model.load(trackID:track.id,deck:deck) }
    await model.flushWrites()
    for deck in DeckID.allCases {
        try model.playback.setSync(false,deck:deck)
        model.pressPlay(deck:deck)
    }
    await model.flushTransportRequests()
    _=model.playback.core.renderOffline(frames:256)
    for deck in DeckID.allCases { #expect(model.playback.core.snapshot()?[deck].phase == .playing) }
    let grids=Dictionary(uniqueKeysWithValues:DeckID.allCases.compactMap { deck in model.track(deck)?.grid.map { (deck,$0) } })
    #expect(grids.count==2)
    let collections=try RuntimePreparationImportStress.prepareCollections(directory:root,duration:duration)
    var report=RuntimePreparationImportReport(entriesPerCollection:10_000)
    #expect(!report.passed)
    for collection in collections {
        await RuntimePreparationImportStress.importOnce(model:model,collection:collection,track:track,expectedGrids:grids,report:&report)
    }
    #expect(report.passed && report.completedImports==2 && report.referencesBound==2)
    let encoded=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(report)) as? [String:Any])
    #expect(encoded["passed"] as? Bool == true)
    let invalid=root.appendingPathComponent("invalid.nml")
    try Data("<NML>broken".utf8).write(to:invalid)
    await RuntimePreparationImportStress.importOnce(model:model,collection:.init(url:invalid,sha256:collections[0].sha256),track:track,expectedGrids:grids,report:&report)
    #expect(report.failures==1 && !report.passed && report.completedImports==2)
    await model.finishForShutdown()
}

@Test func preparationImportGateRejectsMissingFailedOrUnexpectedWorkloads() {
    #expect(RuntimePreparationImportReport.qualifies(enabled:false,report:nil))
    #expect(!RuntimePreparationImportReport.qualifies(enabled:true,report:nil))
    var report=RuntimePreparationImportReport(entriesPerCollection:10_000)
    #expect(!RuntimePreparationImportReport.qualifies(enabled:true,report:report))
    report.completedImports=1;report.referencesBound=1
    #expect(RuntimePreparationImportReport.qualifies(enabled:true,report:report))
    #expect(!RuntimePreparationImportReport.qualifies(enabled:false,report:report))
    report.activePreparationUnchanged=false
    #expect(!RuntimePreparationImportReport.qualifies(enabled:true,report:report))
}
