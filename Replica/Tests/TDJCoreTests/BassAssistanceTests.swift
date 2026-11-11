import Foundation
import Testing

@testable import TDJCore

@Test func bassAssistanceOldPreferencesStayOffAndPreserveSync() throws {
    let data = Data(#"{"filterResonanceA":0.3,"filterResonanceB":0.7,"syncA":false,"syncB":true}"#.utf8)
    let saved = try JSONDecoder().decode(MixerPreferences.self, from: data)
    #expect(saved.bassAssistance == nil)
    #expect((saved.bassAssistance ?? .off) == .off)
    #expect(saved.syncA == false && saved.syncB == true)
    #expect(saved.filterResonanceA == 0.3 && saved.filterResonanceB == 0.7)
}

@Test(arguments: BassAssistanceMode.allCases)
func bassAssistanceModeSurvivesPreferenceRoundTrip(mode: BassAssistanceMode) throws {
    var preferences = MixerPreferences()
    preferences.bassAssistance = mode
    preferences.primaryKeylock = false
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let file = root.appendingPathComponent("mixer.json")
    try preferences.save(to: file)
    #expect(try MixerPreferences.load(from: file) == preferences)
}

@Test func bassAssistanceMeasurementMatchesUnassistedOutput() throws {
    let plain = try SampleTransport()
    let measured = try SampleTransport()
    let signal = (0..<24000).flatMap { frame -> [Float] in
        let value = Float(0.3 * sin(2 * .pi * 50 * Double(frame) / 48000))
        return [value, -value]
    }
    let asset = try PCMAsset(interleavedStereo: signal, sampleRate: 48000)
    for core in [plain, measured] {
        for deck in [DeckID.a, .b] {
            let generation = try core.load(asset, deck: deck, grid: nil, synced: false)
            try core.play(deck: deck, generation: generation)
        }
    }
    measured.setBassAssistance(.measure)
    let expected = plain.renderBusesOffline(frames: 16000)
    let actual = measured.renderBusesOffline(frames: 16000)
    #expect(expected.left == actual.left && expected.right == actual.right)
    #expect(expected.cueLeft == actual.cueLeft && expected.cueRight == actual.cueRight)
    #expect(measured.bassAssistanceMeter.available)
    #expect(measured.bassAssistanceMeter.correlation > 0.99)
    #expect(measured.bassAssistanceMeter.reductionADB == 0)
    #expect(measured.bassAssistanceMeter.reductionBDB == 0)
    #expect(measured.snapshot()?.a.sourceFrame == plain.snapshot()?.a.sourceFrame)
}
