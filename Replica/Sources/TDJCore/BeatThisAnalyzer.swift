import CoreML
import Foundation

enum BeatThisAnalyzer {
    private static let window = 1500
    private static let border = 6
    private static let compiledModel = Result {
        guard
            let source = Bundle.module.url(
                forResource: "BeatThisSmall", withExtension: "mlpackage", subdirectory: "BeatThisAssets")
        else {
            throw CoreError.invalidAudio("The beat analysis model is missing.")
        }
        return try MLModel.compileModel(at: source)
    }

    static func analyze(
        url: URL, sourceFrames: Int64, configuration: AnalysisConfiguration,
        checkCancellation: @Sendable () throws -> Void
    ) throws -> BeatThisGrid? {
        guard sourceFrames >= 2 else { return nil }
        try checkCancellation()
        let span = AnalysisMeasurement.begin("beatThisTotal")
        defer { span?.finish() }
        AnalysisMeasurement.current?.update { $0.modelID = "BeatThisSmall/small0" }
        let audio = try AnalysisMeasurement.measure("beatThisInputSetup") {
            try BeatThisAudio(url: url, sourceFrames: sourceFrames)
        }
        let settings = MLModelConfiguration()
        settings.computeUnits = .cpuOnly
        let model = try AnalysisMeasurement.measure("beatThisModelLoad") {
            try MLModel(contentsOf: compiledModel.get(), configuration: settings)
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
        for start in starts {
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
                let result = try AnalysisMeasurement.measure("beatThisInference") { try model.prediction(from: input) }
                let first = max(border, beatLogits.count - start)
                let end = min(window - border, frameCount - start)
                try append(result, name: "beats", range: first..<end, to: &beatLogits)
                try append(result, name: "downbeats", range: first..<end, to: &barLogits)
            }
        }
        try checkCancellation()
        let beats = peaks(beatLogits)
        guard !beats.isEmpty else { return nil }
        var beatIndex = 0
        var bars: [Double] = []
        for bar in peaks(barLogits) {
            while beatIndex + 1 < beats.count, abs(beats[beatIndex + 1] - bar) < abs(beats[beatIndex] - bar) {
                beatIndex += 1
            }
            if bars.last != beats[beatIndex] { bars.append(beats[beatIndex]) }
        }
        return try AnalysisMeasurement.measure("beatThisGridFit") {
            try BeatThisGrid.fit(
                beats: beats, bars: bars, configuration: configuration, checkCancellation: checkCancellation)
        }
    }

    private static func append(
        _ prediction: any MLFeatureProvider, name: String, range: Range<Int>, to logits: inout [Float]
    ) throws {
        guard let values = prediction.featureValue(for: name)?.multiArrayValue,
            values.dataType == .float32, values.count == window, let stride = values.strides.last?.intValue
        else { throw CoreError.invalidAudio("The beat analysis model returned invalid predictions.") }
        values.withUnsafeBufferPointer(ofType: Float.self) { buffer in
            for index in range { logits.append(buffer[index * stride]) }
        }
    }

    private static func peaks(_ logits: [Float]) -> [Double] {
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
