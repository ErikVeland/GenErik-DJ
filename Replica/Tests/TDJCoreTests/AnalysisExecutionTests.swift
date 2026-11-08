import CoreML
import Foundation
import Testing

@testable import TDJCore

private enum ModelFailure: Error { case unsupported }

@Test func accelerationRequiresForegroundAndCapableHardware() {
    #expect(AnalysisExecution.accelerated(foreground: true, supported: true))
    #expect(!AnalysisExecution.accelerated(foreground: false, supported: true))
    #expect(!AnalysisExecution.accelerated(foreground: true, supported: false))
    #expect(!AnalysisExecution.accelerated(foreground: false, supported: false))
}

@Test func analysisExecutionContextCrossesSerialWorkerWithoutLeaking() async throws {
    let worker = AnalysisWorker()
    let foreground = try await AnalysisExecution.$foregroundLibrary.withValue(true) {
        try await worker.run { _ in AnalysisExecution.foregroundLibrary }
    }
    let next = try await worker.run { _ in AnalysisExecution.foregroundLibrary }
    #expect(foreground)
    #expect(!next)
}

@Test(arguments: [true, false]) func neuralModelFailureRetriesOnceAndRetainsCPUModel(failLoad: Bool) throws {
    var loads: [MLComputeUnits] = []
    let measurement = AnalysisMeasurement(runID: "r87", jobID: "fallback", pass: "matching", duration: 30)
    try AnalysisMeasurement.$current.withValue(measurement) {
        let session = BeatThisModelSession(computeUnits: .cpuAndNeuralEngine) { units in
            loads.append(units)
            if failLoad && units == .cpuAndNeuralEngine { throw ModelFailure.unsupported }
            return units
        }
        for _ in 0..<2 {
            let value = try session.prediction(checkCancellation: {}) { units in
                if units == .cpuAndNeuralEngine { throw ModelFailure.unsupported }
                return 42
            }
            #expect(value == 42)
        }
    }
    #expect(loads == [.cpuAndNeuralEngine, .cpuOnly])
    let record = measurement.finish(outcome: "success")
    #expect(record.counters["beatThisCPUFallbacks"] == 1)
    #expect(record.beatThisEffectiveComputeUnits == "cpuOnly")
}

@Test func neuralModelCancellationDoesNotStartCPUFallback() throws {
    var loads = 0
    var cancelled = false
    let session = BeatThisModelSession(computeUnits: .cpuAndNeuralEngine) { _ in loads += 1; return 42 }
    #expect(throws: CancellationError.self) {
        try session.prediction(checkCancellation: { if cancelled { throw CancellationError() } }) { _ -> Int in
            cancelled = true
            throw ModelFailure.unsupported
        }
    }
    #expect(loads == 1)
    #expect(session.computeUnits == .cpuAndNeuralEngine)
}

@Test func failedCPUFallbackPropagatesWithoutRetryLoop() {
    var loads = 0
    let session = BeatThisModelSession<Int>(computeUnits: .cpuAndNeuralEngine) { _ in
        loads += 1
        throw ModelFailure.unsupported
    }
    #expect(throws: ModelFailure.self) { try session.prediction(checkCancellation: {}) { $0 } }
    #expect(loads == 2)
}
