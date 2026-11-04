import AVFoundation
import Foundation
import TDJCore

/// Fixture input validation occurs before any output directory or audio file is created.
enum AudioRuntimeFixture {
    static func validSampleRate(_ rate: Double) -> Bool { rate == 44100 || rate == 48000 }
    static func frameCount(seconds: Double, sampleRate: Double) throws -> Int {
        guard validSampleRate(sampleRate), seconds.isFinite, seconds > 0, seconds <= 8116, seconds * sampleRate >= 1
        else { throw TransportError.invalid }
        return Int(seconds * sampleRate)
    }
}

struct RuntimeFixtureFile: Encodable, Sendable {
    let sampleRate: Double
    let frames: Int64
    let channels: UInt32
    init(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        sampleRate = file.fileFormat.sampleRate
        frames = file.length
        channels = file.fileFormat.channelCount
    }
}

struct RuntimeFixtureSourceReport: Encodable, Sendable {
    let requestedSampleRate: Double
    let requestedFrames: Int64
    let generated: RuntimeFixtureFile
    let analyzedSampleRate: Double
    let analyzedFrames: Int64
    let nativeAssetSampleRateA: Double?
    let nativeAssetSampleRateB: Double?
    let nativeAssetFramesA: UInt64?
    let nativeAssetFramesB: UInt64?
    let nativeGridSampleRateA: Double?
    let nativeGridSampleRateB: Double?
    let outputRenderSampleRate: Double
    let matchesRequestedSource: Bool

    init(
        requestedSampleRate: Double, sourceSeconds: Double, generated: RuntimeFixtureFile, track: Track,
        core: SampleTransport, snapshot: PlaybackSnapshot?
    ) throws {
        self.requestedSampleRate = requestedSampleRate
        requestedFrames = Int64(
            try AudioRuntimeFixture.frameCount(seconds: sourceSeconds, sampleRate: requestedSampleRate))
        self.generated = generated
        analyzedSampleRate = track.analysis.sampleRate
        analyzedFrames = track.analysis.frameCount
        let a = snapshot.flatMap { core.asset(generation: $0.a.generation) }
        let b = snapshot.flatMap { core.asset(generation: $0.b.generation) }
        nativeAssetSampleRateA = a?.sampleRate
        nativeAssetSampleRateB = b?.sampleRate
        nativeAssetFramesA = a?.frames
        nativeAssetFramesB = b?.frames
        nativeGridSampleRateA = snapshot?.a.grid?.sampleRate
        nativeGridSampleRateB = snapshot?.b.grid?.sampleRate
        outputRenderSampleRate = core.sampleRate
        matchesRequestedSource =
            generated.sampleRate == requestedSampleRate && generated.frames == requestedFrames
            && generated.channels == 2 && analyzedSampleRate == generated.sampleRate
            && analyzedFrames == generated.frames && a?.sampleRate == generated.sampleRate
            && b?.sampleRate == generated.sampleRate && a?.frames == UInt64(generated.frames)
            && b?.frames == UInt64(generated.frames)
            && (track.grid == nil
                || (nativeGridSampleRateA == requestedSampleRate && nativeGridSampleRateB == requestedSampleRate))
            && outputRenderSampleRate == 48000
    }
}
