import TDJCore
import Testing

@testable import TDJInterface

private let originalZ1 = AudioOutputDevice(name: "Traktor Kontrol Z1", wired: true)
private let speaker = AudioOutputDevice(name: "iPad Speaker", wired: false)

@Test @MainActor func z1AudioRoutingNeedsNoUserSelection() throws {
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([originalZ1])
    #expect(controller.automaticOutputDevice == "Z1")
    #expect(controller.outputRoute == .masterAndHeadphones)
    try controller.setOutputRoute(.stereoMaster)
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([speaker])
    #expect(controller.automaticOutputDevice == nil)
    #expect(controller.outputRoute == .stereoMaster)
    controller.updateOutputDevice([originalZ1])
    #expect(controller.automaticOutputDevice == "Z1")
    #expect(controller.outputRoute == .masterAndHeadphones)
}

@Test @MainActor func z1AudioRoutingDoesNotClaimOtherOutputs() throws {
    let controller = try PlaybackController(offline: true)
    for outputs in [
        [speaker], [],
        [
            AudioOutputDevice(name: "Traktor Kontrol S2", wired: true),
            AudioOutputDevice(name: "Traktor Kontrol S4 MK3", wired: true),
        ],
        [AudioOutputDevice(name: "Traktor Kontrol Z1", wired: false)],
        [originalZ1, speaker],
    ] {
        controller.updateOutputDevice(outputs)
        #expect(controller.automaticOutputDevice == nil)
        #expect(controller.outputRoute == .stereoMaster)
    }
    controller.updateOutputDevice([AudioOutputDevice(name: "TRAKTOR KONTROL Z1", wired: true)])
    #expect(controller.automaticOutputDevice == "Z1")
    try controller.setOutputRoute(.stereoMaster)
    #expect(controller.outputRoute == .masterAndHeadphones)
}

@Test @MainActor func z1AudioRoutingPreservesManualChoiceForOtherDevices() throws {
    let controller = try PlaybackController(offline: true)
    try controller.setOutputRoute(.masterAndHeadphones)
    controller.updateOutputDevice([originalZ1])
    controller.updateOutputDevice([AudioOutputDevice(name: "Other interface", wired: true)])
    #expect(controller.automaticOutputDevice == nil)
    #expect(controller.outputRoute == .masterAndHeadphones)
}

@Test(arguments: [
    "Traktor Kontrol Z1", "Numark Scratch", "Hercules DJControl Inpulse 200", "Hercules DJ Control Instinct",
    "Behringer BCD3000", "Hercules DJ Control AIR", "Behringer CMD STUDIO 4a", "Stanton DJC.4", "Hercules P32 DJ",
    "Korg KAOSS DJ", "Reloop Digital Jockey 2 Interface Edition", "Numark Mixtrack Quad", "MixVibes U-Mix Control Pro",
    "Reloop Mixtour", "Reloop Beatpad 2", "Behringer CMD STUDIO 2a", "Traktor Audio 2 MK2",
])
@MainActor func documentedControllerAudioRoutingRecoveryPreservesTransportWithoutSpeakerLeak(deviceName: String) throws
{
    let device = AudioOutputDevice(name: deviceName, wired: true)
    let expectedName = ["Traktor Kontrol Z1": "Z1", "Traktor Audio 2 MK2": "Audio 2 Mk2"][deviceName] ?? deviceName
    let controller = try PlaybackController(offline: true)
    let core = controller.core
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.25, count: 192000), sampleRate: 48000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    let generation = try core.load(asset, deck: .a, grid: grid, synced: true)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 1024)
    let before = try #require(core.snapshot())
    var routes: [AudioOutputRoute] = []
    controller.handleOutputEvent(.routeChanged(disconnected: false), outputs: [device]) {
        routes.append(controller.outputRoute)
    }
    #expect(routes == [.masterAndHeadphones])
    controller.handleOutputEvent(.interruptionBegan, outputs: []) { routes.append(controller.outputRoute) }
    #expect(controller.automaticOutputDevice == expectedName)
    controller.handleOutputEvent(.interruptionEnded(shouldResume: true), outputs: [device]) {
        routes.append(controller.outputRoute)
    }
    #expect(routes == [.masterAndHeadphones, .masterAndHeadphones])
    // A configuration event can arrive before the disconnect notification.
    controller.handleOutputEvent(.configurationChanged, outputs: [speaker]) { routes.append(controller.outputRoute) }
    controller.handleOutputEvent(.routeChanged(disconnected: true), outputs: [speaker]) {
        routes.append(controller.outputRoute)
    }
    #expect(controller.automaticOutputDevice == nil)
    #expect(controller.outputRoute == .stereoMaster)
    #expect(routes.count == 2)
    controller.handleOutputEvent(.routeChanged(disconnected: false), outputs: [device]) {
        routes.append(controller.outputRoute)
    }
    #expect(controller.automaticOutputDevice == expectedName)
    #expect(controller.outputRoute == .masterAndHeadphones)
    #expect(routes.count == 2)
    let after = try #require(core.snapshot())
    #expect(after.a.sourceFrame == before.a.sourceFrame)
    #expect(after.a.phase == .playing)
    #expect(after.a.synced)
    #expect(after.masterBeat == before.masterBeat)
    controller.stopAudio()
}

@Test(arguments: [
    "Traktor Kontrol Z1", "Numark Scratch", "Hercules DJControl Inpulse 200", "Hercules DJ Control Instinct",
    "Behringer BCD3000", "Hercules DJ Control AIR", "Behringer CMD STUDIO 4a", "Stanton DJC.4", "Hercules P32 DJ",
    "Korg KAOSS DJ", "Reloop Digital Jockey 2 Interface Edition", "Numark Mixtrack Quad", "MixVibes U-Mix Control Pro",
    "Reloop Mixtour", "Reloop Beatpad 2", "Behringer CMD STUDIO 2a", "Traktor Audio 2 MK2",
])
@MainActor func documentedControllerAudioRoutingRepeatedDetectionDoesNotAlterSamples(deviceName: String) throws {
    let device = AudioOutputDevice(name: deviceName, wired: true)
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([device])
    let reference = try SampleTransport(sampleRate: 48000)
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.25, count: 192000), sampleRate: 48000)
    for core in [controller.core, reference] {
        let generation = try core.load(asset, deck: .a, grid: nil)
        try core.setMixer(.cue, value: 1, deck: .a)
        try core.play(deck: .a, generation: generation)
        _ = core.renderBusesOffline(frames: 1024)
    }
    for _ in 0..<50 {
        controller.updateOutputDevice([device])
        try controller.setOutputRoute(.stereoMaster)
    }
    let actual = controller.core.renderBusesOffline(frames: 512)
    let expected = reference.renderBusesOffline(frames: 512)
    #expect(actual.left == expected.left)
    #expect(actual.right == expected.right)
    #expect(actual.cueLeft == expected.cueLeft)
    #expect(actual.cueRight == expected.cueRight)
    #expect(actual.cueLeft.contains { $0 != 0 })
    controller.stopAudio()
}

@Test(arguments: ["Z1 Mk2", "S2 Mk2", "S2 Mk3", "S3", "S4 Mk2"])
@MainActor func documentedNIControllerUsesAutomaticSplitOutput(model: String) throws {
    let controller = try PlaybackController(offline: true)
    let port = AudioOutputDevice(name: "Traktor Kontrol \(model)", wired: true)
    controller.handleOutputEvent(.routeChanged(disconnected: false), outputs: [port]) {
        Issue.record("An idle route change must not start playback.")
    }
    #expect(controller.automaticOutputDevice == model)
    #expect(controller.outputRoute == .masterAndHeadphones)
    try controller.setOutputRoute(.stereoMaster)
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.handleOutputEvent(.routeChanged(disconnected: true), outputs: [speaker]) {
        Issue.record("An idle disconnect must not start playback.")
    }
    #expect(controller.automaticOutputDevice == nil)
    #expect(controller.outputRoute == .stereoMaster)
}
