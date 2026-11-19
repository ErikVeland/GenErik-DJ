import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func traktorAudio2MK2MatchesOnlyTheDocumentedWiredName() {
    for name in ["Traktor Audio 2 MK2", "TRAKTOR AUDIO 2 MK2", "  Traktor Audio 2 MK2  "] {
        #expect(AudioOutputDevice(name: name, wired: true).automaticSplitOutputName == "Audio 2 Mk2")
        #expect(AudioOutputDevice(name: name, wired: false).automaticSplitOutputName == nil)
    }
    for name in [
        "Audio 2 DJ", "Traktor Audio 2", "Traktor Audio 2 MK1", "Traktor Audio 2 MK3", "Traktor Audio 6",
        "Traktor Audio 10", "USB Audio Device",
    ] {
        #expect(AudioOutputDevice(name: name, wired: true).automaticSplitOutputName == nil)
    }
    #expect(ControllerFactoryProfile.matching(["Traktor Audio 2 MK2"]) == nil)
}

@Test @MainActor func traktorAudio2MK2RoutingPreservesManualChoiceAndRejectsAmbiguousOutputs() throws {
    let controller = try PlaybackController(offline: true)
    defer { controller.stopAudio() }
    let audio2 = AudioOutputDevice(name: "Traktor Audio 2 MK2", wired: true)
    controller.updateOutputDevice([audio2])
    #expect(controller.automaticOutputDevice == "Audio 2 Mk2" && controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([audio2, .init(name: "Other output", wired: true)])
    #expect(controller.automaticOutputDevice == nil && controller.outputRoute == .stereoMaster)
    try controller.setOutputRoute(.masterAndHeadphones)
    controller.updateOutputDevice([audio2]); controller.updateOutputDevice([])
    #expect(controller.automaticOutputDevice == nil && controller.outputRoute == .masterAndHeadphones)
    try controller.setOutputRoute(.stereoMaster)
    controller.updateOutputDevice([audio2]);
    controller.updateOutputDevice([.init(name: "Traktor Audio 2 MK2", wired: false)])
    #expect(controller.automaticOutputDevice == nil && controller.outputRoute == .stereoMaster)
}

@Test @MainActor func traktorAudio2MK2OutputPolicyKeepsOfflineAudioAndSavedSyncContinuous() throws {
    let controller = try PlaybackController(offline: true)
    defer { controller.stopAudio() }
    let reference = try SampleTransport(sampleRate: controller.core.sampleRate)
    let asset = try PCMAsset(
        interleavedStereo: Array(repeating: 0.25, count: 192000), sampleRate: controller.core.sampleRate)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: controller.core.sampleRate)
    for core in [controller.core, reference] {
        let generation = try core.load(asset, deck: .a, grid: grid, synced: true)
        core.processControlsWhileIdle(); _ = core.acknowledgements()
        try core.play(deck: .a, generation: generation); _ = core.renderOffline(frames: 1024)
    }
    for outputs: [AudioOutputDevice] in [
        [.init(name: "Traktor Audio 2 MK2", wired: true)], [],
        [.init(name: "Traktor Audio 2 MK2", wired: true), .init(name: "Other output", wired: true)],
        [.init(name: "Traktor Audio 2 MK2", wired: true)],
    ] {
        controller.updateOutputDevice(outputs)
        let actual = controller.core.renderOffline(frames: 512), expected = reference.renderOffline(frames: 512)
        #expect(actual.left == expected.left && actual.right == expected.right)
        #expect(controller.core.snapshot()?.a.phase == .playing && controller.core.snapshot()?.a.synced == true)
    }
}
