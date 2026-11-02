import Foundation
import Testing
@testable import TDJCore
@testable import TDJInterface
@testable import TDJRuntimeChecks

private func nearDoubleFixture(bpm: Double?) throws -> Track {
    let analysis=AudioAnalysis(implementation:"test",configurationID:"stress-propagation",
        contentSHA256:"near-double-fixture",sampleRate:48000,frameCount:48000*16,channelCount:2,
        waveformFramesPerBin:256,waveform:[],bpm:bpm,beatAnchorFrame:240,
        tempoConfidence:1,key:nil,keyConfidence:0,chroma:[],timbre:[])
    return try Track(title:"Synthetic stress",mediaFilename:"synthetic.wav",analysis:analysis)
}

private func nearDoubleRig(_ track: Track) throws -> (SampleTransport,[DeckID:UInt64]) {
    let core=try SampleTransport(sampleRate:48000)
    let asset=try PCMAsset(interleavedStereo:[Float](repeating:0.125,count:48000*2),sampleRate:48000)
    var generations:[DeckID:UInt64]=[:]
    for deck in DeckID.allCases {
        generations[deck]=try core.load(asset,deck:deck,grid:track.grid,synced:true,keylock:true)
    }
    core.processControlsWhileIdle()
    _=core.acknowledgements()
    return (core,generations)
}

@Test func nearDoublePresetsAreExplicitAndKeepTheOriginalModes() throws {
    let original:[(AudioRuntimeCheckLaunch,Double,Bool,Bool,Bool)]=[
        (.loop60,60,false,false,false),(.loop300,300,false,false,false),
        (.sequential300,300,true,false,false),(.ui60,60,false,true,false),
        (.uiLoop300Panels,300,false,true,true),(.uiSequential300Panels,300,true,true,true)]
    for (mode,seconds,sequential,live,motion) in original {
        #expect(mode.durationSeconds == seconds && mode.sequential == sequential)
        #expect(mode.liveInterface == live && mode.panelMotion == motion)
        #expect(mode.keylockStress == .detectedGrid)
    }
    for mode in [AudioRuntimeCheckLaunch.loop60Near2x,.loop300Near2x,.uiLoop300PanelsNear2x] {
        #expect(try AudioRuntimeCheckLaunch.parse(arguments:["app","--audio-check="+mode.rawValue]) == mode)
        #expect(mode.durationSeconds == (mode == .loop60Near2x ? 60:300) && !mode.sequential && mode.keylockStress == .manual60BPM)
        #expect(mode.liveInterface == (mode == .uiLoop300PanelsNear2x))
        #expect(mode.panelMotion == (mode == .uiLoop300PanelsNear2x))
    }
}

@Test func nearDoublePolicyPreservesDetectorResultsAndOverridesOnlyPreparation() throws {
    let detectedTempos: [Double?]=[nil,60,120,61.4]
    for bpm in detectedTempos {
        let original=try nearDoubleFixture(bpm:bpm)
        #expect(try AudioRuntimeKeylockStress.detectedGrid.configuredFixture(original) == original)
        let manual=try AudioRuntimeKeylockStress.manual60BPM.configuredFixture(original)
        #expect(manual.analysis == original.analysis)
        #expect(manual.id == original.id && manual.mediaFilename == original.mediaFilename)
        #expect(manual.preparation.gridIsManual)
        #expect(manual.grid == (try BeatGrid(bpm:60,anchorFrame:0,sampleRate:48000,downbeatOffset:0)))
        #expect(!original.preparation.gridIsManual)
    }
}

@Test func nearDoubleNativeGridAndSpeedReachBothRequestedEndpoints() throws {
    let original=try nearDoubleFixture(bpm:120)
    let manual=try AudioRuntimeKeylockStress.manual60BPM.configuredFixture(original)
    let (core,_)=try nearDoubleRig(manual)
    var observation=RuntimeKeylockStressObservation(policy:.manual60BPM,original:original,
        configured:manual,initial:core.snapshot())
    #expect(observation.configurationMatches)
    for bpm in [112.0,120.0,128.0] {
        try core.setMasterBPM(bpm);core.processControlsWhileIdle()
        let snapshot=try #require(core.snapshot())
        for deck in DeckID.allCases {
            #expect(snapshot[deck].grid == manual.grid)
            #expect(snapshot[deck].synced && snapshot[deck].keylock)
            #expect(abs(snapshot[deck].speed-bpm/60)<1e-9)
        }
        observation.observe(snapshot)
    }
    let report=observation.report
    #expect(report.configurationMatches && report.observedWorkloadMatches)
    #expect(report.detectedFixtureBPM == 120 && report.requestedFixtureBPM == 60)
    #expect(report.observedMinimumSpeedA == 112/60.0 && report.observedMaximumSpeedB == 128/60.0)
    #expect(report.observedSnapshots == 3 && report.invalidObservations == 0)
    #expect(!(try JSONEncoder().encode(report)).isEmpty)
}

@Test func nearDoubleRejectsUntouchedDetectedGridAndIncompleteSweep() throws {
    let original=try nearDoubleFixture(bpm:120)
    let manual=try AudioRuntimeKeylockStress.manual60BPM.configuredFixture(original)
    let (wrong,_)=try nearDoubleRig(original)
    var mismatch=RuntimeKeylockStressObservation(policy:.manual60BPM,original:original,
        configured:manual,initial:wrong.snapshot())
    mismatch.observe(wrong.snapshot())
    #expect(!mismatch.configurationMatches && mismatch.report.invalidObservations == 1)
    #expect(!mismatch.report.observedWorkloadMatches)
    let (core,_)=try nearDoubleRig(manual)
    var incomplete=RuntimeKeylockStressObservation(policy:.manual60BPM,original:original,
        configured:manual,initial:core.snapshot())
    incomplete.observe(core.snapshot())
    #expect(incomplete.configurationMatches && !incomplete.report.observedWorkloadMatches)
    incomplete.observe(nil)
    #expect(incomplete.report.invalidObservations == 1)
    #expect(!(try JSONEncoder().encode(incomplete.report)).isEmpty)
}

@Test func nearDoubleRejectsLossOfKeylockSyncOrManualGrid() throws {
    let original=try nearDoubleFixture(bpm:120)
    let manual=try AudioRuntimeKeylockStress.manual60BPM.configuredFixture(original)
    for fault in 0..<3 {
        let (core,generations)=try nearDoubleRig(manual)
        var observation=RuntimeKeylockStressObservation(policy:.manual60BPM,original:original,
            configured:manual,initial:core.snapshot())
        let generation=try #require(generations[.b])
        switch fault {
        case 0: try core.setKeylock(false,deck:.b,generation:generation)
        case 1: try core.setSync(false,deck:.b,generation:generation)
        default: try core.updateGrid(try #require(original.grid),deck:.b,generation:generation)
        }
        core.processControlsWhileIdle();observation.observe(core.snapshot())
        #expect(observation.report.invalidObservations == 1)
        #expect(!observation.report.observedWorkloadMatches)
    }
}

@Test @MainActor func nearDoubleInvalidScenariosFailBeforeCreatingOutput() async {
    for (seconds,sequential) in [(30.0,false),(60.0,true),(300.0,true),(301.0,false)] {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            _=try await AudioRuntimeChecks.run(outputDirectory:root,seconds:seconds,sequential:sequential,
                keylockStress:.manual60BPM,searchCatalogTracks:1)
            Issue.record("Invalid near-2× scenario was accepted.")
        } catch {}
        #expect(!FileManager.default.fileExists(atPath:root.path))
    }
}

@Test @MainActor func nearDoubleProductionPreparationReplacesBothLoadedDetectorGrids() async throws {
    var base=URL(fileURLWithPath:#filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model=try ReplicaModel(root:root,playback:PlaybackController(offline:true))
    defer { model.stopAudio();try? FileManager.default.removeItem(at:root) }
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let original=try #require(model.library.tracks.first)
    for deck in DeckID.allCases { model.load(trackID:original.id,deck:deck) }
    await model.flushWrites()
    try await model.prepareLoadedWaveforms()
    let loadedAnalysisA=try #require(model.track(.a)?.analysis)
    let loadedAnalysisB=try #require(model.track(.b)?.analysis)
    #expect(loadedAnalysisA.replacingWaveform([]) == original.analysis.replacingWaveform([]))
    #expect(loadedAnalysisB.replacingWaveform([]) == original.analysis.replacingWaveform([]))
    let detected=try #require(model.playback.core.snapshot())
    #expect(detected.a.grid?.bpm != 60 && detected.b.grid?.bpm != 60)
    let configured=try AudioRuntimeKeylockStress.manual60BPM.configuredFixture(original)
    try await AudioRuntimeKeylockStress.manual60BPM.prepareLoadedFixture(configured,model:model)
    var observation=RuntimeKeylockStressObservation(policy:.manual60BPM,original:original,
        configured:configured,initial:model.playback.core.snapshot())
    #expect(observation.configurationMatches)
    #expect(model.track(.a)?.analysis == loadedAnalysisA && model.track(.b)?.analysis == loadedAnalysisB)
    for bpm in [112.0,120.0,128.0] {
        try model.playback.setMasterBPM(bpm)
        await model.playback.flushSourcePreparations()
        model.refreshPlayback()
        observation.observe(model.playbackSnapshot)
    }
    #expect(observation.report.observedWorkloadMatches)
    #expect(observation.report.actualInitialSpeedA == 2 && observation.report.actualInitialSpeedB == 2)
}
