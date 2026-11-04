import AVFoundation
import Foundation
import TDJCore

extension TDJTool {
    private struct PitchCheck: Codable {
        let speed: Double
        let keylock: Bool
        let measuredHz: Double
        let expectedHz: Double
        let errorCents: Double
    }
    private struct GrooveCheck: Codable {
        let file: String
        let masterBPM: Double
        let keylock: Bool
        let frames: Int
        let peak: Float
    }
    private struct KeylockReport: Encodable {
        let kind = "Synthetic development signals; original NI sound equivalence unmeasured"
        let sampleRate = 48000
        let pitch: [PitchCheck]
        let audio: [GrooveCheck]
    }
    static func keylockProbe(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rate = 48000.0
        let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: rate)
        var tone = [Float](repeating: 0, count: 48000 * 4 * 2)
        for i in 0..<(tone.count / 2) { tone[i * 2] = Float(0.2 * sin(2 * .pi * 440 * Double(i) / rate)) }
        let toneAsset = try PCMAsset(interleavedStereo: tone, sampleRate: rate)
        var pitch: [PitchCheck] = []
        for speed in [0.8, 1.075, 1.25] {
            for enabled in [false, true] {
                let core = try SampleTransport()
                let a = try core.load(toneAsset, deck: .a, grid: grid, keylock: enabled)
                try core.setMasterBPM(120 * speed)
                try core.play(deck: .a, generation: a)
                let output = core.renderOffline(frames: 96000)
                var crossings: [Double] = []
                for i in 24001..<90000 where output.left[i - 1] <= 0 && output.left[i] > 0 {
                    crossings.append(
                        Double(i - 1) + Double(-output.left[i - 1]) / Double(output.left[i] - output.left[i - 1]))
                }
                guard crossings.count > 2 else { throw TransportError.invalid }
                let measured = Double(crossings.count - 1) * rate / (crossings.last! - crossings.first!)
                let expected = enabled ? 440 : 440 * speed
                let error = 1200 * log2(measured / expected)
                guard abs(error) < 3 else { throw TransportError.invalid }
                pitch.append(
                    .init(speed: speed, keylock: enabled, measuredHz: measured, expectedHz: expected, errorCents: error)
                )
            }
        }
        var groove = [Float](repeating: 0, count: 48000 * 8 * 2)
        var random: UInt32 = 27
        for i in 0..<(groove.count / 2) {
            let t = Double(i) / rate
            let beat = t.truncatingRemainder(dividingBy: 0.5)
            random = random &* 1_664_525 &+ 1_013_904_223
            let noise = Double(random) / Double(UInt32.max) * 2 - 1
            let kick = 0.27 * exp(-beat * 25) * sin(2 * .pi * (52 * beat + 2 * (1 - exp(-beat * 45))))
            let hatTime = t.truncatingRemainder(dividingBy: 0.25)
            let hat = noise * 0.04 * exp(-hatTime * 120)
            let snare = Int(t * 2).isMultiple(of: 2) ? 0 : noise * 0.12 * exp(-beat * 40)
            let envelope = 0.8 + 0.2 * cos(2 * .pi * 0.25 * t)
            let frequencies = [220.0, 277.18263098, 329.62755691]
            let chord = frequencies.reduce(0.0) { $0 + sin(2 * .pi * $1 * t) * 0.035 } * envelope
            groove[i * 2] = Float(kick + snare + hat + chord)
            groove[i * 2 + 1] = Float(kick + snare - hat + chord * 0.75 + 0.02 * sin(2 * .pi * 440 * t))
        }
        let asset = try PCMAsset(interleavedStereo: groove, sampleRate: rate)
        var audio: [GrooveCheck] = []
        for (bpm, enabled) in [(120.0, true), (129, true), (129, false), (96, true), (150, true)] {
            let core = try SampleTransport()
            let a = try core.load(asset, deck: .a, grid: grid, keylock: enabled)
            try core.setMasterBPM(bpm)
            try core.play(deck: .a, generation: a)
            let frames = Int(ceil(48000 * 8 * 120 / bpm))
            let output = core.renderOffline(frames: frames)
            let name = "groove-\(Int(bpm))-keylock-\(enabled ? "on" : "off").wav"
            try writeKeylockWAV(left: output.left, right: output.right, directory.appendingPathComponent(name))
            let peak = max(output.left.map { abs($0) }.max() ?? 0, output.right.map { abs($0) }.max() ?? 0)
            guard peak < 1, output.left.allSatisfy(\.isFinite), output.right.allSatisfy(\.isFinite) else {
                throw TransportError.invalid
            }
            audio.append(.init(file: name, masterBPM: bpm, keylock: enabled, frames: frames, peak: peak))
        }
        let report = KeylockReport(pitch: pitch, audio: audio)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: directory.appendingPathComponent("keylock-signals.json"), options: .atomic)
        try emit(report)
    }
    private static func writeKeylockWAV(left: [Float], right: [Float], _ url: URL) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(left.count)),
            let channels = buffer.floatChannelData
        else { throw TransportError.allocation }
        buffer.frameLength = AVAudioFrameCount(left.count)
        for i in left.indices {
            channels[0][i] = left[i]
            channels[1][i] = right[i]
        }
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM), AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }
}
