import AVFoundation
import Foundation
import TDJCore

extension TDJTool {
    static func transportProbe(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rate = 48000.0, duration = 4
        var a = [Float](repeating: 0, count: 48000 * 5 * 2), b = a
        for i in 0..<(a.count / 2) {
            a[2*i] = Float(sin(2 * .pi * 440 * Double(i) / rate) * 0.12)
            b[2*i+1] = Float(sin(2 * .pi * 660 * Double(i) / rate) * 0.12)
        }
        var traces: [[String: String]] = []
        for ramp in [false, true] {
            let core = try SampleTransport(sampleRate: rate)
            let first = try core.load(PCMAsset(interleavedStereo: a, sampleRate: rate), deck: .a,
                grid: BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: rate))
            let second = try core.load(PCMAsset(interleavedStereo: b, sampleRate: rate), deck: .b,
                grid: BeatGrid(bpm: 128, anchorFrame: 0, sampleRate: rate))
            try core.play(deck: .a, generation: first)
            let prefix = core.renderOffline(frames: 36000)
            try core.play(deck: .b, generation: second)
            let wait = core.renderOffline(frames: 24000)
            if ramp { try core.setMasterBPM(128) }
            let suffix = core.renderOffline(frames: 48000*duration-60000)
            let left = prefix.left + wait.left + suffix.left
            let right = prefix.right + wait.right + suffix.right
            let expected = ramp ? 93750 : 96000
            guard core.snapshot()?.b.lastStartOutputFrame == UInt64(expected),
                  right.firstIndex(where: { abs($0) > 1e-6 }) == expected + 1 else { throw TransportError.invalid }
            let name = ramp ? "queued-start-tempo-change.wav" : "queued-start-120.wav"
            guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(left.count)),
                  let channels = buffer.floatChannelData else { throw TransportError.allocation }
            buffer.frameLength = AVAudioFrameCount(left.count)
            for i in left.indices { channels[0][i] = left[i]; channels[1][i] = right[i] }
            let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatLinearPCM), AVSampleRateKey: rate,
                AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
            let file = try AVAudioFile(forWriting: directory.appendingPathComponent(name), settings: settings)
            try file.write(from: buffer)
            traces.append(["audio":name,"kind":"synthetic development validation","sampleRate":"48000",
                "playAcceptedOutputFrame":"36000","playAcceptedMasterBeat":"1.5","targetMasterBeat":"4",
                "tempoChangeOutputFrame":ramp ? "60000" : "none", "expectedStartOutputFrame":String(expected),
                "actualStartOutputFrame":String(core.snapshot()!.b.lastStartOutputFrame),
                "firstNonzeroIncomingSample":String(expected+1),"status":"passed"])
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(traces).write(to: directory.appendingPathComponent("transport-traces.json"), options: .atomic)
        try emit(traces)
    }
}
