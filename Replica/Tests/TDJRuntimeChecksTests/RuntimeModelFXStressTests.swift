import Foundation
import Testing
@testable import TDJRuntimeChecks

@Test func runtimeModelFXRequiresAnExplicitFlagAndRetainsExistingOptions() throws {
    let normal=AudioRuntimeControlConfiguration()
    #expect(!normal.modelFX && !normal.traceSubmissions && normal.driver == .asyncContinuation)
    let parsed=try AudioRuntimeControlConfiguration.parse(arguments:["app","--audio-control-model-fx",
        "--audio-control-driver=direct-main-event","--audio-control-submit-trace"])
    #expect(parsed.modelFX && parsed.traceSubmissions && parsed.driver == .directMainEvent)
    let original=try AudioRuntimeControlConfiguration.parse(arguments:["app","--audio-control-driver=direct-main-event"])
    #expect(!original.modelFX && !original.traceSubmissions)
    for flags in [["--audio-control-model-fx","--audio-control-model-fx"],
                  ["--audio-control-model-fx=true"],["--audio-control-model-fx=0"]] {
        #expect(throws:AudioRuntimeControlConfiguration.InvalidArgument.self) {
            try AudioRuntimeControlConfiguration.parse(arguments:["app"]+flags)
        }
    }
}

@Test func runtimeModelFXReportRejectsMissingPublicationsPersistenceAndEmptyWork() throws {
    func report(_ batches: Int = 250, _ setup: Int = 6, _ submissions: Int = 1500,
                _ requests: Int = 12, _ persisted: Bool = true) -> RuntimeModelFXStressReport {
        .init(batches:batches,setupSubmissions:setup,controlSubmissions:submissions,
              controlPersistenceRequests:requests,persistedStateMatches:persisted)
    }
    let complete=report()
    #expect(complete.passed && complete.expectedControlSubmissions == 1500)
    #expect(complete.expectedControlPersistenceRequests == 12 && complete.path == "ReplicaModel.setEffect")
    #expect(!report(250,5).passed && !report(250,6,1499).passed)
    #expect(!report(250,6,1500,11).passed && !report(250,6,1500,12,false).passed)
    #expect(!report(0,6,0,0,true).passed)
    let decoded=try JSONDecoder().decode(RuntimeModelFXStressReport.self,from:JSONEncoder().encode(complete))
    #expect(decoded.passed && decoded.controlSubmissions == 1500 && decoded.persistedStateMatches)
}
