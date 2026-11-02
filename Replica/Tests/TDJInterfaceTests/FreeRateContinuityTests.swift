import Foundation
import Testing
@testable import TDJCore
@testable import TDJInterface

@Test @MainActor func streamedSpeedChangesKeepPlayingAndMatchPreparedAudio() async throws {
    var base=URL(fileURLWithPath:#filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let source=base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let store=try WorkspaceStore(root:root)
    try FileManager.default.copyItem(at:source,to:store.mediaDirectory.appendingPathComponent("source.wav"))
    let analysis=AudioAnalysis(implementation:"continuity-fixture",configurationID:"fixture",
        contentSHA256:try AudioAnalyzer.sha256(url:source),sampleRate:44100,frameCount:705600,
        channelCount:2,waveformFramesPerBin:441,waveform:[],bpm:120,beatAnchorFrame:0,
        tempoConfidence:1,key:nil,keyConfidence:0,chroma:[],timbre:[])
    let track=try Track(title:"Speed continuity",mediaFilename:"source.wav",analysis:analysis)
    let streamed=try PlaybackController(offline:true,streamingPlayback:true)
    let reference=try PlaybackController(offline:true)
    defer { streamed.stopAudio();reference.stopAudio() }
    for controller in [streamed,reference] {
        try await controller.load(track:track,store:store,deck:.a)
        try controller.setSync(false,deck:.a)
        try controller.play(.a)
    }
    for rate in [0.5,1.5,0.75,1.0] {
        try streamed.setFreeRate(rate,deck:.a)
        await streamed.flushSourcePreparations()
        try reference.setFreeRate(rate,deck:.a)
        #expect(streamed.core.snapshot()?.a.phase == .playing)
        #expect(streamed.core.snapshot()?.a.speed == rate)
        for _ in 0..<12 {
            let actual=streamed.core.renderOffline(frames:512),expected=reference.core.renderOffline(frames:512)
            #expect(actual.left == expected.left)
            #expect(actual.right == expected.right)
            try await Task.sleep(for:.milliseconds(1))
        }
    }
    #expect(!streamed.core.streamingSummary().continuityFailed)
    #expect(streamed.sourcePreparationFailures == 0)
    #expect(streamed.rejectedCommandCount == 0)
}
