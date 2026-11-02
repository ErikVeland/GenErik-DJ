import Foundation
import Testing
@testable import TDJCore

@Test func keylockPrimeProbeJoinsBothDecksToTheRenderCallbackWithoutChangingAudio() throws {
    let metrics=try AudioCallbackMetrics(sampleRate:8000,traceThreadCPU:true)
    let traced=try SampleTransport(sampleRate:8000,keylockDiagnostics:metrics)
    let reference=try SampleTransport(sampleRate:8000)
    let samples=(0..<64000).map { Float(sin(Double($0)*0.017))*0.2 }
    for core in [traced,reference] {
        for deck in DeckID.allCases {
            let generation=try core.load(PCMAsset(interleavedStereo:samples,sampleRate:8000),deck:deck,
                grid:BeatGrid(bpm:120,anchorFrame:0,sampleRate:8000),keylock:true)
            core.processControlsWhileIdle()
            try core.play(deck:deck,generation:generation)
        }
        for _ in 0..<32 { _=core.renderOffline(frames:512) }
        #expect(core.snapshot()?.a.phase == .playing && core.snapshot()?.b.phase == .playing)
        try core.setMasterBPM(128);core.processControlsWhileIdle()
    }
    let began=metrics.begin(),actual=traced.renderOffline(frames:512)
    metrics.end(began:began,frames:512,sampleTime:0,validTime:true)
    let expected=reference.renderOffline(frames:512)
    #expect(actual.left == expected.left && actual.right == expected.right)
    let summary=metrics.summary(),probe=try #require(summary.keylockPrimeProbe)
    #expect(probe.events.count == 2 && Set(probe.events.map(\.deck)) == [0,1])
    #expect(probe.events.allSatisfy { $0.callbackIndex == 1 && $0.threadCPUMicroseconds != nil })
    #expect(probe.eventsDropped == 0 && probe.invalidMeasurements == 0 && probe.unavailableCPUReadings == 0)
    for event in probe.events {
        #expect(event.beganMachTicks<=event.resetDoneMachTicks && event.resetDoneMachTicks<=event.historyDoneMachTicks && event.historyDoneMachTicks<=event.endedMachTicks)
        #expect(abs(event.totalMicroseconds-event.resetMicroseconds-event.historyMicroseconds-event.prerollMicroseconds)<0.000001)
    }
}

@Test func keylockPrimeProbeOwnerOutlivesItsExternalReference() throws {
    weak var retained: AudioCallbackMetrics?
    var core: SampleTransport?
    do {
        let metrics=try AudioCallbackMetrics(sampleRate:8000,traceThreadCPU:true)
        retained=metrics
        core=try SampleTransport(sampleRate:8000,keylockDiagnostics:metrics)
    }
    #expect(retained != nil && core != nil)
    core=nil
    #expect(retained == nil)
}
