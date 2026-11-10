import CoreML
import Foundation

enum BeatThisAnalyzer {
    struct Evidence {
        let grid: BeatThisGrid?
        let refinedTempo: Double?
    }
    private static let window = 1500
    private static let border = 6
    static let mixOpeningSeconds = 90.0
    private static let compiledCPUModel = Result { try compile("BeatThisSmall") }
    private static let compiledNeuralModel = Result { try compile("BeatThisSmallANE") }

    private static func compile(_ name: String) throws -> URL {
        guard
            let source = Bundle.module.url(
                forResource: name, withExtension: "mlpackage", subdirectory: "BeatThisAssets")
        else {
            throw CoreError.invalidAudio("The beat analysis model is missing.")
        }
        return try MLModel.compileModel(at: source)
    }

    static func sourceFrameLimit(_ sourceFrames: Int64, sampleRate: Double) -> Int64 {
        guard NativeAnalysisPlan.isMix(duration: Double(sourceFrames) / sampleRate) else { return sourceFrames }
        return Int64((mixOpeningSeconds * sampleRate).rounded(.down))
    }

    static func analyze(
        url: URL, sourceFrames: Int64, configuration: AnalysisConfiguration, requireOpeningBar: Bool,
        fallbackBPM: Double? = nil, checkCancellation: @Sendable () throws -> Void
    ) throws -> Evidence {
        guard sourceFrames >= 2 else { return .init(grid: nil, refinedTempo: nil) }
        try checkCancellation()
        let span = AnalysisMeasurement.begin("beatThisTotal")
        defer { span?.finish() }
        let audio = try AnalysisMeasurement.measure("beatThisInputSetup") {
            try BeatThisAudio(url: url, sourceFrames: sourceFrames)
        }
        let computeUnits = AnalysisExecution.computeUnits
        AnalysisMeasurement.current?.update {
            $0.beatThisRequestedComputeUnits = computeUnits == .cpuAndNeuralEngine ? "cpuAndNeuralEngine" : "cpuOnly"
        }
        let session = BeatThisModelSession(computeUnits: computeUnits) { units in
            let settings = MLModelConfiguration()
            settings.computeUnits = units
            return try AnalysisMeasurement.measure("beatThisModelLoad") {
                let neural = units == .cpuAndNeuralEngine
                let url = try (neural ? compiledNeuralModel : compiledCPUModel).get()
                let model = try MLModel(contentsOf: url, configuration: settings)
                AnalysisMeasurement.current?.update {
                    $0.modelID = neural ? "BeatThisSmall/small0-fp16-v1" : "BeatThisSmall/small0"
                }
                return model
            }
        }
        let features = try MLMultiArray(
            shape: [1, NSNumber(value: window), NSNumber(value: BeatThisAudio.bands)], dataType: .float32)
        let input = try MLDictionaryFeatureProvider(dictionary: ["spectrogram": features])
        let strideSize = window - 2 * border
        let frameCount = audio.frameCount
        var beatLogits: [Float] = []
        var barLogits: [Float] = []
        var starts = Array(stride(from: -border, to: frameCount - border, by: strideSize))
        if frameCount > strideSize { starts[starts.count - 1] = frameCount - window + border }
        var progress = AnalysisWorkProgress.Step(0.76...0.95)
        for (index, start) in starts.enumerated() {
            try checkCancellation()
            try AnalysisMeasurement.measure("beatThisDecodeAndSpectrogram") {
                try features.withUnsafeMutableBufferPointer(ofType: Float.self) { values, _ in
                    values.update(repeating: 0)
                    try audio.fill(
                        start..<(start + window), into: values.baseAddress!, checkCancellation: checkCancellation)
                }
            }
            try checkCancellation()
            try autoreleasepool {
                let result = try session.prediction(checkCancellation: checkCancellation) { model in
                    let result = try AnalysisMeasurement.measure("beatThisInference") {
                        try model.prediction(from: input)
                    }
                    try validateLogits(result)
                    return result
                }
                let first = max(border, beatLogits.count - start)
                let end = min(window - border, frameCount - start)
                try append(result, name: "beats", range: first..<end, to: &beatLogits)
                try append(result, name: "downbeats", range: first..<end, to: &barLogits)
            }
            progress.advance(Int64(index + 1), of: Int64(starts.count))
        }
        try checkCancellation()
        let grid = try fit(
            beats: beatLogits, downbeats: barLogits, configuration: configuration,
            requireOpeningBar: requireOpeningBar, checkCancellation: checkCancellation)
        let tempo: Double?
        if grid == nil, !requireOpeningBar, let fallbackBPM {
            tempo = try BeatThisTempo.refine(
                fallbackBPM: fallbackBPM, beats: peaks(beatLogits), configuration: configuration,
                checkCancellation: checkCancellation)
        } else { tempo = nil }
        return .init(grid: grid, refinedTempo: tempo)
    }

    static func fit(
        beats beatLogits: [Float], downbeats barLogits: [Float], configuration: AnalysisConfiguration,
        requireOpeningBar: Bool, checkCancellation: @Sendable () throws -> Void
    ) throws -> BeatThisGrid? {
        let beats = peaks(beatLogits)
        guard !beats.isEmpty else { return nil }
        var beatIndex = 0
        var bars: [Double] = []
        for bar in peaks(barLogits) {
            while beatIndex + 1 < beats.count, abs(beats[beatIndex + 1] - bar) < abs(beats[beatIndex] - bar) {
                beatIndex += 1
            }
            let beat = beats[beatIndex]
            if requireOpeningBar && abs(beat - bar) > 0.06 { continue }
            if bars.last != beat { bars.append(beat) }
        }
        return try AnalysisMeasurement.measure("beatThisGridFit") {
            guard let grid = try BeatThisGrid.fit(
                beats: beats, bars: bars, configuration: configuration, requireOpeningBar: requireOpeningBar,
                checkCancellation: checkCancellation) else { return nil }
            if let corrected = BeatThisOpeningBar.correct(grid, beats: beats, barLogits: barLogits) {
                AnalysisMeasurement.current?.count("openingBarCorrections", 1)
                return corrected
            }
            return grid
        }
    }

    static func validateLogits(_ prediction: any MLFeatureProvider) throws {
        for name in ["beats", "downbeats"] {
            guard let values = prediction.featureValue(for: name)?.multiArrayValue,
                values.dataType == .float32, values.count == window, let stride = values.strides.last?.intValue
            else { throw CoreError.invalidAudio("The beat analysis model returned invalid predictions.") }
            let finite = values.withUnsafeBufferPointer(ofType: Float.self) { buffer in
                (0..<window).allSatisfy { buffer[$0 * stride].isFinite }
            }
            guard finite else {
                throw CoreError.invalidAudio("The beat analysis model returned non-finite predictions.")
            }
        }
    }

    static func append(
        _ prediction: any MLFeatureProvider, name: String, range: Range<Int>, to logits: inout [Float]
    ) throws {
        guard let values = prediction.featureValue(for: name)?.multiArrayValue,
            values.dataType == .float32, values.count == window, let stride = values.strides.last?.intValue
        else { throw CoreError.invalidAudio("The beat analysis model returned invalid predictions.") }
        values.withUnsafeBufferPointer(ofType: Float.self) { buffer in
            for index in range { logits.append(buffer[index * stride]) }
        }
    }

    static func peaks(_ logits: [Float]) -> [Double] {
        var times: [Double] = []
        var previous = -2
        var sum = 0
        var count = 0
        for index in logits.indices where logits[index] > 0 {
            let neighbours = max(0, index - 3)...min(logits.count - 1, index + 3)
            guard neighbours.allSatisfy({ logits[$0] <= logits[index] }) else { continue }
            if index > previous + 1, count > 0 {
                times.append(Double(sum) / Double(count) / 50)
                sum = 0
                count = 0
            }
            sum += index
            count += 1
            previous = index
        }
        if count > 0 { times.append(Double(sum) / Double(count) / 50) }
        return times
    }
}
