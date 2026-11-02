import Foundation
import SwiftUI
import AppKit
import Testing
import TDJCore
@testable import TDJInterface

@MainActor private func arrangementFixture() async throws -> (ReplicaModel, URL, Track) {
    var project=URL(fileURLWithPath:#filePath)
    for _ in 0..<4 { project.deleteLastPathComponent() }
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    await model.importFiles([project.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track=try #require(model.library.tracks.first)
    model.load(trackID:track.id,deck:.a)
    await model.flushWrites(); await model.flushWaveforms()
    await model.prepareArrangement(deck:.a)
    return (model,root,track)
}

@Test @MainActor func arrangementEditsPersistWithoutChangingHotCuesOrGrid() async throws {
    let (model,root,track)=try await arrangementFixture()
    defer { try? FileManager.default.removeItem(at:root) }
    model.performance.cues[track.id]=[0:.init(frame:42),3:.init(frame:100,loopEnd:200)]
    let original=model.performance.cues
    let grid=model.grid(.a)
    var value=try #require(model.arrangements[track.id])
    value.sections[0].name="VERSE 2"; value.sections[0].role = .verse; value.sections[0].locked=true
    let pickup=ArrangementLandmark(frame:123,name:"Vocal pickup",kind:.vocal,state:.accepted,locked:true)
    value.landmarks.append(pickup)
    #expect(model.updateArrangement(value,deck:.a))
    await model.flushPreferenceWrites()
    #expect(model.performance.cues == original)
    #expect(model.grid(.a) == grid)
    let restored=try JSONDecoder().decode(ArrangementCache.self,from:Data(contentsOf:model.arrangementURL(track.id)))
    #expect(restored.arrangement.sections[0].name == "VERSE 2")
    model.promoteLandmark(pickup,deck:.a)
    #expect(model.performance.cues[track.id]?[1]?.frame == 123)
    #expect(model.performance.cues[track.id]?[0]?.frame == 42)
    #expect(model.performance.cues[track.id]?[3]?.loopEnd == 200)
    await model.finishForShutdown()
}

@Test @MainActor func arrangementRejectsInvalidRegionsWithoutLosingPreparation() async throws {
    let (model,root,track)=try await arrangementFixture()
    defer { try? FileManager.default.removeItem(at:root) }
    let original=try #require(model.arrangements[track.id])
    var invalid=original
    invalid.landmarks.append(.init(frame:100,end:50,name:"Invalid region"))
    #expect(!model.updateArrangement(invalid,deck:.a))
    #expect(model.arrangements[track.id] == original)
    await model.finishForShutdown()
}

@Test @MainActor func arrangementSnapshotShowsPreparedSections() async throws {
    guard let output=ProcessInfo.processInfo.environment["TDJ_ARRANGEMENT_SNAPSHOT"] else { return }
    let (model,root,track)=try await arrangementFixture()
    defer { try? FileManager.default.removeItem(at:root) }
    let end=Double(track.analysis.frameCount), size=end/6
    let roles: [ArrangementRole]=[.intro,.verse,.preChorus,.chorus,.bridge,.outro]
    let sections=roles.enumerated().map { i,role in
        ArrangementSection(start:Double(i)*size,end:Double(i+1)*size,role:role,name:role.label,locked:true)
    }
    model.arrangements[track.id] = .init(sections:sections,landmarks:[.init(frame:size*3,name:"Chorus",kind:.arrival)],musicalEnd:end,rhythmicEnd:nil)
    model.loaded[.b]=track.id; model.browserVisible=false
    model.viewport[.a]=size*2; model.viewport[.b]=size*4
    let view=try await ReplicaView(model:model).preparedForSnapshot()
    let renderer=ImageRenderer(content:view.frame(width:1024,height:768))
    let image=try #require(renderer.nsImage)
    let tiff=try #require(image.tiffRepresentation)
    let bitmap=try #require(NSBitmapImageRep(data:tiff))
    try #require(bitmap.representation(using:.png,properties:[:])).write(to:URL(fileURLWithPath:output))
    await model.finishForShutdown()
}
