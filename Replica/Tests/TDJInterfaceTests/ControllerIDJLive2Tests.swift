import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func attachIDJ2(_ input: ControllerMIDIConnection, source: Int32 = 10, device: UInt32 = 1) {
    let name = "iDJ Live II"
    input.sources.append(
        .init(id: source, reference: 100, name: name, identity: .init(id: source, device: device, names: [name])))
    input.destinations.append(
        .init(
            id: source + 10, reference: 200, name: name, identity: .init(id: source + 10, device: device, names: [name])
        ))
    input.reconcileFactoryProfiles()
}

@MainActor private func idj2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
    input.flushPendingActions()
}

@MainActor private func withIDJ2(_ body: (ControllerMIDIConnection, UserDefaults) throws -> Void) rethrows {
    let suite = "idj2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    attachIDJ2(input)
    try body(input, preferences)
}

@Test @MainActor func controllerCatalogueIDJLive2RetainsQueryCleanupAndDistinctIdentities() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["iDJ Live II"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 27 && data.outputs.count == 4)
    #expect(data.startup == [[240, 0, 1, 63, 127, 46, 96, 0, 1, 1, 247], [0x90, 72, 127]])
    #expect(data.shutdown == [[0x90, 74, 0], [0x90, 64, 0], [0x90, 76, 0], [0x90, 71, 0], [0x90, 72, 0]])
    #expect(!profile.hasAutomaticSplitOutput)
    for name in ["iDJ Live", "iDJ Pro", "iDJ Live III"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
    withIDJ2 { input, _ in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        idj2Packet([0x90, 51, 127, 59, 127, 60, 127, 66, 127, 75, 127, 52, 127, 72, 127, 79, 127], to: input)
        #expect(actions == [.cueSetA, .cueGotoA, .cueSetB, .cueGotoB, .loadA, .loadB])
    }
}

@Test @MainActor func controllerCatalogueIDJLive2JogsRequireTheirOwnSourceAndThresholdContact() {
    withIDJ2 { input, _ in
        attachIDJ2(input, source: 11, device: 2)
        var touches: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .jogTouchA { touches.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        idj2Packet([0xB0, 25, 1, 24, 1, 0x90, 77, 63, 0xB0, 25, 1], to: input)
        #expect(touches.isEmpty && jogs.isEmpty)
        idj2Packet([0x90, 77, 64, 0xB0, 25, 3], to: input)
        #expect(touches == [1] && jogs.count == 1 && jogs[0].0.argument == 640 && jogs[0].1 == .relative(3))
        idj2Packet([0xB0, 25, 1], to: input, source: 11)
        idj2Packet([0xB0, 24, 1], to: input)
        #expect(jogs.count == 1)
        idj2Packet([0x90, 77, 63, 0xB0, 25, 1], to: input)
        #expect(touches == [1, 0] && jogs.count == 1)
        idj2Packet([0x90, 78, 127, 0xB0, 24, 127, 0x80, 78, 127, 0xB0, 24, 1], to: input)
        #expect(jogs.count == 2 && jogs[1].0.deck == .b && jogs[1].1 == .relative(-1))
        input.receive(.init(kind: .note, channel: 0, number: 77, value: 32768, maximum: 65535), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 77, value: 32767, maximum: 65535), source: 10)
        #expect(touches == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueIDJLive2CustomReconnectRetainsTouchGateAndResolution() {
    withIDJ2 { input, preferences in
        input.select(10)
        input.learning = .cueA
        idj2Packet([0x90, 100, 127], to: input)
        let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
        attachIDJ2(restored, source: 11)
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        restored.onJogAction = { jogs.append(($0, $1)) }
        idj2Packet([0xB0, 25, 1, 0x90, 77, 63, 0xB0, 25, 1], to: restored, source: 11)
        #expect(jogs.isEmpty)
        idj2Packet([0x90, 77, 64, 0xB0, 25, 2], to: restored, source: 11)
        #expect(jogs.count == 1 && jogs[0].0.argument == 640 && jogs[0].1 == .relative(2))
    }
}

@Test @MainActor func controllerCatalogueIDJLive2RejectsInvalidTouchMetadata() throws {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 { url.deleteLastPathComponent() }
    url.appendPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json")
    let bundled = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let profiles = try #require(bundled["profiles"] as? [[String: Any]])
    let original = try #require(profiles.first { $0["id"] as? String == "Numark iDJ Live II" })
    for mutation in 0..<3 {
        var profile = original
        var inputs = try #require(profile["inputs"] as? [[String: Any]])
        if mutation == 0 { inputs[0]["requiresTouch"] = true }
        if mutation == 1 { inputs[0]["encoding"] = "touchGate" }
        if mutation == 2 { inputs.removeAll { ($0["action"] as? String) == "jogTouchA" } }
        profile["inputs"] = inputs
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [profile]])
        #expect(throws: Error.self) { try ControllerProfileCatalogue.decode(data) }
    }
}

@Test @MainActor func controllerCatalogueIDJLive2CueSetAndGotoPreservePausedAndPlayingTransport() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    try model.playback.setSync(false, deck: .a)
    model.refreshPlayback()
    withIDJ2 { input, _ in
        input.onTargetAction = { target, value in
            model.applyController(target.action, value: value, targetDeck: target.deck)
        }
        model.jump(2000, deck: .a, quantized: false)
        idj2Packet([0x90, 51, 127, 51, 0], to: input)
        #expect(model.cuePoints[.a] == 2000)
        model.jump(5000, deck: .a, quantized: false)
        let paused = model.playbackSnapshot?.a.phase
        idj2Packet([0x90, 59, 127, 59, 0], to: input)
        #expect(model.playbackSnapshot?.a.sourceFrame == 2000 && model.playbackSnapshot?.a.phase == paused)
        model.pressPlay(deck: .a, vinylStop: false)
        _ = model.playback.core.renderOffline(frames: 1000)
        model.refreshPlayback()
        idj2Packet([0x90, 51, 127, 51, 0], to: input)
        let cue = model.cuePoints[.a]
        #expect(cue != 2000 && model.playbackSnapshot?.a.phase == .playing)
        _ = model.playback.core.renderOffline(frames: 1000)
        model.refreshPlayback()
        idj2Packet([0x90, 59, 127], to: input)
        #expect(model.playbackSnapshot?.a.sourceFrame == cue && model.playbackSnapshot?.a.phase == .playing)
        #expect(model.playbackSnapshot?.a.synced == false)
    }
}
