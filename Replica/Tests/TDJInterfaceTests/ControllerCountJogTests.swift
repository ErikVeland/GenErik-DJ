import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withCountJogPlayback(_ body: (ReplicaModel) async throws -> Void) async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.configureControllerMIDI()
    model.controllerInput.sources = [
        .init(id: 10, reference: 100, name: "DDJ-T1", identity: .init(id: 10, device: 1, names: ["DDJ-T1"]))
    ]
    model.controllerInput.reconcileFactoryProfiles()
    #expect(model.controllerInput.isInputActive(10))
    try await body(model)
}

@MainActor private func countJogPacket(_ bytes: [UInt8], model: ReplicaModel) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { model.controllerInput.receive(message, source: 10) }
    model.controllerInput.flushPendingActions()
}

@Test @MainActor func controllerCatalogueCountJogStopsMovingWhenTheTouchedWheelStops() async throws {
    try await withCountJogPlayback { model in
        countJogPacket([0x90, 54, 127, 0xB0, 1, 0, 33, 1], model: model)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let first = try #require(model.playbackSnapshot?.a.sourceFrame)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let second = try #require(model.playbackSnapshot?.a.sourceFrame)
        #expect(abs(second - first) <= 1)
    }
}

@Test @MainActor func controllerCatalogueCountJogCanMoveAPausedDeckWithoutAPlatterTouch() async throws {
    try await withCountJogPlayback { model in
        let first = try #require(model.playbackSnapshot?.a.sourceFrame)
        let sync = model.playbackSnapshot?.a.synced
        let expected = model.snappedFrame(first + (model.track(.a)?.analysis.sampleRate ?? 0) * 1.8, deck: .a)
        countJogPacket([0xB0, 1, 18, 33, 126], model: model)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let second = try #require(model.playbackSnapshot?.a.sourceFrame)
        #expect(abs(second - expected) <= 1)
        #expect(model.playbackSnapshot?.a.synced == sync)
        #expect(model.playbackSnapshot?.a.phase.active == false)
    }
}

@Test func controllerCatalogueCountJogMotionUsesResolutionAndBounds() throws {
    var motion = try #require(
        ControllerCountJogMotion(
            frame: 100, generation: 2, sampleRate: 1000,
            limit: 10000, resolution: 2430, time: 10))
    motion.move(counts: 2430, time: 11)
    #expect(abs(motion.frame - 1900) < 0.001)
    motion.move(counts: -4860, time: 12)
    #expect(motion.frame == 0)
    motion.move(counts: .infinity, time: 13)
    motion.move(counts: 2430, time: 11)
    #expect(motion.frame == 0)
    motion.move(counts: 24300, time: 14)
    #expect(motion.frame == 10000)
    #expect(
        ControllerCountJogMotion(
            frame: 0, generation: 0, sampleRate: 1000,
            limit: 10000, resolution: 0, time: 10) == nil)
}

@Test @MainActor func controllerCatalogueCountJogRetainsCountsAndOrdersTouchEdges() throws {
    let suite = "count-jog-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [
        .init(
            id: 10, reference: 100, name: "DDJ-T1",
            identity: .init(id: 10, device: 1, names: ["DDJ-T1"]))
    ]
    input.reconcileFactoryProfiles()
    var events: [String] = []
    var counts: [Double] = []
    input.onJogAction = { target, motion in
        #expect(target.argument == 2430)
        if case .relative(let value) = motion { counts.append(value); events.append("jog") }
    }
    input.onTargetAction = { target, value in
        if target.action == .jogTouchA { events.append(value > 0 ? "down" : "up") }
        if target.action == .loadA { events.append("load") }
    }
    var decoder = ControllerMIDIDecoder()
    /**
     * Retains both count pairs before the touch release.
     */
    for message in decoder.append([0x90, 54, 127, 0xB0, 1, 18, 33, 126, 1, 18, 33, 126, 0x80, 54, 0]) {
        input.receive(message, source: 10)
    }
    input.flushPendingActions()
    #expect(counts == [4860])
    #expect(events == ["down", "jog", "up"])
    events.removeAll()
    for message in decoder.append([0xB0, 1, 0, 33, 1, 0x96, 70, 127]) { input.receive(message, source: 10) }
    input.flushPendingActions()
    #expect(events == ["jog", "load"])
}

@Test @MainActor func controllerCatalogueCountJogReleaseCancelsIdleAndPreservesPausedState() async throws {
    try await withCountJogPlayback { model in
        let sync = model.playbackSnapshot?.a.synced
        countJogPacket([0x90, 54, 127, 0xB0, 1, 18, 33, 126, 0x80, 54, 0], model: model)
        #expect(model.controllerCountJogs[.a] == nil)
        #expect(model.controllerCountJogTasks[.a] == nil)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == false)
        #expect(model.playbackSnapshot?.a.synced == sync)
    }
}

@Test @MainActor func controllerCatalogueCountJogSpeedReportsKeepTheirExistingPath() async throws {
    try await withCountJogPlayback { model in
        countJogPacket([0x90, 54, 127], model: model)
        model.applyControllerJog(.init(.jogA), motion: .absolute(0.75))
        #expect(model.controllerCountJogs[.a] == nil)
        #expect(model.controllerCountJogTasks[.a] == nil)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.sourceFrame ?? 0 > 100)
        #expect(model.playbackSnapshot?.a.touchActive == true)
    }
}

@Test @MainActor func controllerCatalogueCountJogIdleCannotTouchAReplacementTrack() async throws {
    try await withCountJogPlayback { model in
        countJogPacket([0x90, 54, 127, 0xB0, 1, 18, 33, 126], model: model)
        let oldGeneration = try #require(model.playbackSnapshot?.a.generation)
        model.perform(.touch, deck: .a, enabled: false)
        let track = try #require(model.library.tracks.first)
        model.load(trackID: track.id, deck: .a)
        await model.flushWrites()
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.generation != oldGeneration)
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.phase.active == false)
    }
}

@Test func controllerCatalogueCountJogResolutionRequiresRelativeMotion() throws {
    for (encoding, resolution, valid) in [
        ("twosComplement", 2430.0, true),
        ("twosComplement", 0.0, false), ("twosComplement", 65537.0, false),
        ("absolute", 2430.0, false), ("cdjPlatterSpeed", 2430.0, false),
    ] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "fixture", "aliases": ["fixture"],
                    "inputs": [
                        [
                            "action": "jogA", "kind": "control", "channel": 0, "number": 6,
                            "encoding": encoding, "inverted": false, "argument": resolution,
                        ]
                    ],
                    "outputs": [], "startup": [], "shutdown": [], "autoSelect": true,
                    "scope": "fixture", "source": "fixture",
                ]
            ],
        ])
        if valid {
            #expect(try ControllerProfileCatalogue.decode(data).profiles.count == 1)
        } else {
            #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
        }
    }
}
