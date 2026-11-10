import CoreML
import Foundation

/// Foreground library preparation can use accelerators without increasing job concurrency.
public enum AnalysisExecution {
    @TaskLocal public static var foregroundLibrary = false

    public static let supportsAcceleration: Bool = {
        // R129 found bar-position regressions with the accelerated Mac first pass.
        // Deep analysis uses a separate model policy.
        #if os(iOS) && !targetEnvironment(simulator)
            return MLComputeDevice.allComputeDevices.contains {
                if case .neuralEngine = $0 { return true }
                return false
            }
        #else
            return false
        #endif
    }()

    static func accelerated(foreground: Bool, supported: Bool) -> Bool { foreground && supported }

    static var usesAcceleration: Bool {
        accelerated(foreground: foregroundLibrary, supported: supportsAcceleration)
    }

    static var computeUnits: MLComputeUnits { usesAcceleration ? .cpuAndNeuralEngine : .cpuOnly }
}

/// A failed accelerator load or prediction retries once on the CPU. Cancellation never retries.
final class BeatThisModelSession<Model> {
    private let load: (MLComputeUnits) throws -> Model
    private var model: Model?
    private(set) var computeUnits: MLComputeUnits

    init(
        computeUnits: MLComputeUnits,
        load: @escaping (MLComputeUnits) throws -> Model
    ) {
        self.computeUnits = computeUnits
        self.load = load
    }

    func prediction<Result>(
        checkCancellation: () throws -> Void, _ predict: (Model) throws -> Result
    ) throws -> Result {
        try checkCancellation()
        do {
            return try predict(loadedModel(checkCancellation: checkCancellation))
        } catch {
            if error is CancellationError { throw error }
            try checkCancellation()
            guard computeUnits != .cpuOnly else { throw error }
            model = nil
            computeUnits = .cpuOnly
            AnalysisMeasurement.current?.count("beatThisCPUFallbacks", 1)
            return try predict(loadedModel(checkCancellation: checkCancellation))
        }
    }

    private func loadedModel(checkCancellation: () throws -> Void) throws -> Model {
        if let model { return model }
        try checkCancellation()
        let loaded = try load(computeUnits)
        try checkCancellation()
        model = loaded
        AnalysisMeasurement.current?.update {
            $0.beatThisEffectiveComputeUnits = computeUnits == .cpuAndNeuralEngine ? "cpuAndNeuralEngine" : "cpuOnly"
        }
        return loaded
    }
}
