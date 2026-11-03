import XCTest
import AVFoundation
import Foundation
@testable import TDJCore

final class LateRhythmTests: XCTestCase {
    private let rate=1000.0
    private let bin=5
    private func frames(duration: Double, start: Double, bpm: Double, intro: Bool) -> [MusicalPulseFrame] {
        let count=Int(duration*rate/Double(bin))
        var values=(0..<count).map { index in
            let t=Double(index*bin)/rate
            let level=t < start ? 0.15:0.001
            return MusicalPulseFrame(rms:level,bass:level,middle:level,high:level,attackFrame:Double(index*bin),rise:0)
        }
        func hit(_ time: Double, _ level: Double) {
            let index=Int((time*rate/Double(bin)).rounded())
            guard values.indices.contains(index) else { return }
            values[index] = .init(rms:level,bass:level,middle:level*0.6,high:level*0.2,attackFrame:Double(index*bin),rise:level)
        }
        if intro {
            var time=0.31, index=0
            while time < start-3 {
                hit(time,1)
                index += 1
                time += 0.83+Double((index*37)%97)/23
            }
        }
        if bpm > 0 {
            var time=start
            while time < duration-0.1 { hit(time,intro ? 0.007:0.2); time += 60/bpm }
        } else { hit(start,0.2) }
        return values
    }
    private func detect(_ values: [MusicalPulseFrame], activity: Double) throws -> MusicalRhythmResult {
        try MusicalRhythmAnalyzer.analyze(frames:values,sampleRate:rate,framesPerBin:bin,spectralActivity:activity,
            configuration:.init(),checkCancellation:{})
    }
    func testQuietLateRhythmIsFoundDespiteLowWholeTrackActivity() throws {
        let start=230.375, bpm=123.0
        let result=try detect(frames(duration:256,start:start,bpm:bpm,intro:false),activity:0.003)
        XCTAssertEqual(result.bpm ?? -1,bpm,accuracy:0.04)
        XCTAssertEqual(result.anchorSeconds ?? -1,start,accuracy:0.015)
    }
    func testLoudIrregularIntroDoesNotMaskMuchQuieterLateBeats() throws {
        let start=223.37, bpm=128.0
        let result=try detect(frames(duration:250,start:start,bpm:bpm,intro:true),activity:0.08)
        XCTAssertEqual(result.bpm ?? -1,bpm,accuracy:0.04)
        XCTAssertEqual(result.anchorSeconds ?? -1,start,accuracy:0.015)
        if let map=result.adaptiveCandidate {
            try map.validate(frameCount:250_000)
            XCTAssertGreaterThanOrEqual(map.anchors.first?.frame ?? -1,start*rate-20)
            XCTAssertEqual(map.frame(atBeat:0)/rate,start,accuracy:0.03)
        }
    }
    func testRhythmNearTheFileEndingRetainsItsSourceAnchor() throws {
        let start=177.3, bpm=96.0
        let result=try detect(frames(duration:191,start:start,bpm:bpm,intro:false),activity:0.002)
        XCTAssertEqual(result.bpm ?? -1,bpm,accuracy:0.04)
        XCTAssertEqual(result.anchorSeconds ?? -1,start,accuracy:0.015)
    }
    func testAnIsolatedLateHitDoesNotInventATempo() throws {
        let result=try detect(frames(duration:180,start:170,bpm:0,intro:false),activity:0.001)
        XCTAssertNil(result.bpm)
    }
    func testExistingSteadyRhythmKeepsItsTempoAndAnchor() throws {
        let result=try detect(frames(duration:32,start:0,bpm:120,intro:false),activity:0.1)
        XCTAssertEqual(result.bpm ?? -1,120,accuracy:0.02)
        XCTAssertEqual(result.anchorSeconds ?? -1,0,accuracy:0.01)
    }
    func testLateSearchHonoursCancellation() throws {
        struct Cancelled: Error {}
        do {
            _=try MusicalRhythmAnalyzer.analyze(frames:frames(duration:256,start:230,bpm:123,intro:false),
                sampleRate:rate,framesPerBin:bin,spectralActivity:0.003,configuration:.init(),checkCancellation:{ throw Cancelled() })
            XCTFail("Cancellation must stop analysis.")
        } catch is Cancelled {}
    }
    func testDecodedAudioWithALongIntroFindsTheQuietLateBeat() throws {
        let rate=22050.0, duration=112.0, start=85.375, bpm=123.0
        let format=try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:rate,channels:1))
        let buffer=try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(duration*rate)))
        buffer.frameLength=buffer.frameCapacity
        let samples=try XCTUnwrap(buffer.floatChannelData)[0]
        for frame in 0..<Int(buffer.frameLength) {
            let time=Double(frame)/rate
            samples[frame]=time < start ? Float(0.08*sin(2 * Double.pi * 220*time)):0
        }
        func hit(_ time: Double, _ amplitude: Double, _ frequency: Double) {
            let first=Int((time*rate).rounded())
            for offset in 0..<Int(rate*0.06) where first+offset < Int(buffer.frameLength) {
                let t=Double(offset)/rate
                samples[first+offset] += Float(amplitude*exp(-t*150)*cos(2 * Double.pi * frequency*t))
            }
        }
        var effect=0.31, index=0
        while effect < start-3 {
            hit(effect,0.7,400)
            index += 1; effect += 0.83+Double((index*37)%97)/23
        }
        var time=start
        while time < duration-0.1 { hit(time,0.01,100); time += 60/bpm }
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
        defer { try? FileManager.default.removeItem(at:url) }
        do { let file=try AVAudioFile(forWriting:url,settings:format.settings); try file.write(from:buffer) }
        let analysis=try AudioAnalyzer.analyze(url:url)
        XCTAssertEqual(analysis.bpm ?? -1,bpm,accuracy:0.05)
        XCTAssertEqual((analysis.beatAnchorFrame ?? -rate)/rate,start,accuracy:0.03)
    }

}
