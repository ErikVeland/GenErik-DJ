import Foundation
import Testing
import TDJCore
@testable import TDJRuntimeChecks

@Test func runtimeModelFilterFlagIsExplicitAndPreservesDriverAndModelFXDefaults() throws {
    let plain=try AudioRuntimeControlConfiguration.parse(arguments:["app"])
    #expect(!plain.modelFilter && !plain.modelFX && !plain.traceSubmissions && plain.driver == .asyncContinuation)
    let enabled=try AudioRuntimeControlConfiguration.parse(arguments:["app","--audio-control-model-filter","--audio-control-model-fx","--audio-control-driver=direct-main-event"])
    #expect(enabled.modelFilter && enabled.modelFX && !enabled.traceSubmissions && enabled.driver == .directMainEvent)
    for flags in [["--audio-control-model-filter","--audio-control-model-filter"],["--audio-control-model-filter=0"],["--audio-control-model-filter=true"]] {
        #expect(throws:AudioRuntimeControlConfiguration.InvalidArgument.self) { try AudioRuntimeControlConfiguration.parse(arguments:["app"]+flags) }
    }
}

@Test func runtimeModelFilterReportRequiresRealActiveChangingFiltersAndExactCounts() throws {
    let core=try SampleTransport()
    var observation=RuntimeFilterStressObservation()
    for step in 0..<3 {
        for deck in DeckID.allCases {
            try core.setMixer(.filterEnabled,value:1,deck:deck)
            try core.setMixer(.filterX,value:Double(step)/4,deck:deck)
            try core.setMixer(.filterY,value:Double(step)/5,deck:deck)
        }
        core.processControlsWhileIdle();observation.observe(core.snapshot())
    }
    func report(batches:Int=3,setup:Int=2,touches:Int=6,cancelled:Int=2,cancellationFailures:Int=0,observed:RuntimeFilterStressObservation?=nil,
                persisted:Bool=true,disabled:Bool=true) -> RuntimeModelFilterStressReport {
        .init(batches:batches,setupTouches:setup,controlTouches:touches,cancelledContacts:cancelled,cancellationFailures:cancellationFailures,observation:observed ?? observation,
            persistedStateMatches:persisted,filtersDisabledAfterShutdown:disabled)
    }
    let value=report()
    #expect(value.passed && value.activeBatchesA == 3 && value.controlTouches == 6)
    #expect(try JSONDecoder().decode(RuntimeModelFilterStressReport.self,from:JSONEncoder().encode(value)).passed)
    #expect(!report(cancellationFailures:1).passed)
    #expect(!report(setup:1).passed && !report(touches:5).passed && !report(cancelled:1).passed)
    #expect(!report(persisted:false).passed && !report(disabled:false).passed && !report(batches:0,touches:0).passed)
    #expect(!report(observed:RuntimeFilterStressObservation()).passed)
    var short=observation;short.a.activeBatches=2
    #expect(!report(observed:short).passed)
}
