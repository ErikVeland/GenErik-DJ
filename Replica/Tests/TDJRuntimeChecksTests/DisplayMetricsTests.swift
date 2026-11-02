import Foundation
import Testing
import TDJRuntimeChecks

@Test func displayObservationsSeparateCallbacksFromSnapshotUpdates() throws {
    var observations=AudioCheckDisplayAccumulator()
    for (time,frame) in [(0.0,UInt64(0)),(0.016,0),(0.032,512),(0.080,1024)] {
        observations.observe(timestamp:time,expectedInterval:0.016,outputFrame:frame)
    }
    let result=observations.summary
    #expect(result.callbacks == 4 && result.observedSnapshotVersions == 3)
    #expect(abs(result.maximumCallbackIntervalMilliseconds-48)<0.000001)
    #expect(abs(result.maximumIntervalToExpectedPeriodRatio-3)<0.000001)
    #expect(abs(try #require(result.meanSnapshotUpdateIntervalMilliseconds)-40)<0.000001)
    #expect(result.scope.contains("do not prove"))
    _=try JSONEncoder().encode(result)
}

@Test func displayObservationsRejectInvalidTimesAndEncodeAnEmptyCheck() throws {
    var observations=AudioCheckDisplayAccumulator()
    _=try JSONEncoder().encode(observations.summary)
    observations.observe(timestamp:10,expectedInterval:0,outputFrame:nil)
    observations.observe(timestamp:.nan,expectedInterval:0.016,outputFrame:0)
    observations.observe(timestamp:9,expectedInterval:0.016,outputFrame:0)
    observations.observe(timestamp:10,expectedInterval:0.016,outputFrame:0)
    observations.observe(timestamp:11,expectedInterval:.infinity,outputFrame:1)
    let result=observations.summary
    #expect(result.callbacks == 2 && result.invalidTimestamps == 3)
    #expect(result.observedSnapshotVersions == 1 && result.meanSnapshotUpdateIntervalMilliseconds == nil)
    #expect(result.maximumIntervalToExpectedPeriodRatio == 0)
    _=try JSONEncoder().encode(result)
}
