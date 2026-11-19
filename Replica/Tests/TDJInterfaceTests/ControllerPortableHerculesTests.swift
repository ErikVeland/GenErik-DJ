import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let portableNames = ["Hercules DJControl Starlight", "Hercules DJControl MIX"]

@MainActor private func portableInput(
    _ name: String, preferences: UserDefaults, sender: @escaping ([UInt8], Int32) -> Bool
) -> ControllerMIDIConnection {
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: sender)
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    return input
}

@MainActor private func withPortable(
    _ name: String, _ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void
) rethrows {
    let suite = "portable-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = portableInput(name, preferences: preferences) { bytes, _ in
        packets.append(bytes); return true
    }
    try body(input, packets)
}

@MainActor private func portablePacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCataloguePortableHerculesKeepSeparateSetupAndPhysicalControlScope() throws {
    for name in portableNames {
        try withPortable(name) { input, packets in
            #expect(input.isInputActive(10))
            let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
            let data = try #require(profile.definition)
            let mix = name.hasSuffix("MIX")
            #expect(data.inputs.count == (mix ? 68 : 66) && data.outputs.count == 22)
            #expect(
                packets
                    == (mix
                        ? [[0x91, 3, 127], [0xB0, 127, 127]] : [[0x90, 36, 0], [0x91, 3, 127], [0xB0, 127, 127]]))
            #expect(
                !data.inputs.contains { [.loadA, .loadB, .browse, .midA, .midB, .highA, .highB].contains($0.action) })
            #expect(data.inputs.contains { $0.action == .master } == mix)
        }
    }
    #expect(ControllerFactoryProfile.matching(["Hercules DJControl MIX ULTRA"], automaticOnly: true)?.rawValue != "Hercules DJControl MIX")
    #expect(ControllerFactoryProfile.matching(["Hercules DJControl Starlight 2"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCataloguePortableHerculesSeparateLoopAndSamplerPages() {
    for name in portableNames {
        withPortable(name) { input, _ in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            portablePacket([0x96, 16, 127, 17, 127, 18, 127, 19, 127, 48, 127, 49, 127, 50, 127, 51, 127], to: input)
            #expect(targets == [1.0, 2, 4, 8].map { .init(.toggleFixedLoopA, deck: .a, argument: $0) })
            targets.removeAll()
            portablePacket(
                [0x97, 0, 127, 1, 127, 2, 127, 3, 127, 8, 127, 9, 127, 10, 127, 11, 127, 32, 127], to: input)
            #expect(targets.map(\.action) == [.hotcue1B, .hotcue2B, .hotcue3B, .hotcue4B, .clearHotcue1B, .clearHotcue2B, .clearHotcue3B, .clearHotcue4B])
            #expect(targets.allSatisfy { $0.deck == .b })
        }
    }
}

@Test @MainActor func controllerCataloguePortableHerculesAlternateChannelsFinishCueAndTheCorrectPlatter() {
    for name in portableNames {
        for release: UInt8 in [0x90, 0x80] {
            withPortable(name) { input, _ in
                var events: [(ControllerActionTarget, Double)] = []
                input.onTargetAction = { events.append(($0, $1)) }
                portablePacket(
                    [
                        0x91, 6, 127, 7, 127, 0x92, 8, 127, 0x90, 3, 127,
                        release + 4, 6, 0, 7, 0, release + 5, 8, 0,
                        0x80, 3, 0, 0x91, 7, 127,
                    ], to: input)
                #expect(events.filter { $0.0.action == .cuePreviewA }.map(\.1) == [1, 0])
                #expect(events.filter { $0.0.action == .jogTouchB }.map(\.1) == [1, 0])
                #expect(events.filter { $0.0.action == .playA }.count == 2)
                #expect(!events.contains { $0.0.action == .jogTouchA })
            }
        }
    }
}

@Test @MainActor func controllerCataloguePortableHerculesSingleStepJogsKeep248CountsAndBlockShiftSearch() {
    for name in portableNames {
        withPortable(name) { input, _ in
            var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
            input.onJogAction = { jogs.append(($0, $1)) }
            portablePacket([0xB1, 10, 1, 0xB2, 9, 127], to: input)
            #expect(jogs.count == 2 && jogs.allSatisfy { $0.0.argument == 248 })
            #expect(jogs.first { $0.0.action == .jogA }?.1 == .relative(1))
            #expect(jogs.first { $0.0.action == .wheelJogB }?.1 == .relative(-1))
            jogs.removeAll()
            portablePacket([0x90, 3, 127, 0xB4, 10, 1, 0xB5, 10, 127, 0xB2, 9, 1, 0xB1, 10, 1], to: input)
            #expect(jogs.isEmpty)
            portablePacket([0x80, 3, 0, 0xB2, 10, 127], to: input)
            #expect(jogs.count == 1 && jogs.first?.0 == .init(.jogB, deck: .b, argument: 248))
        }
    }
}

@Test @MainActor func controllerCataloguePortableHerculesPitchKeepsInversionAndRearmsPickupAfterShift() {
    for name in portableNames {
        withPortable(name) { input, _ in
            var tempos: [Double] = []
            input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
            input.onTargetAction = { target, value in if target.action == .tempoA { tempos.append(value) } }
            portablePacket([0xB1, 8, 127, 40, 127], to: input)
            #expect(tempos.isEmpty)
            portablePacket([0xB1, 8, 64, 40, 0], to: input)
            portablePacket([0xB1, 8, 0, 40, 0], to: input)
            #expect(tempos == [1 - 8192.0 / 16383, 1])
            portablePacket([0x90, 3, 127, 0xB1, 8, 100, 0x80, 3, 0, 0xB1, 40, 0], to: input)
            #expect(tempos.count == 2)
            portablePacket([0xB1, 8, 64, 40, 0], to: input)
            #expect(tempos.count == 3)
        }
    }
}

@Test @MainActor func controllerCataloguePortableHerculesCueDeletePressClearsAndReleaseRearms() {
    for name in portableNames {
        withPortable(name) { input, _ in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            portablePacket([0x96, 0, 127, 0x90, 3, 127, 0x96, 8, 127, 8, 0, 0x80, 3, 0, 0x96, 0, 127], to: input)
            #expect(targets == [.init(.hotcue1A, deck: .a), .init(.clearHotcue1A, deck: .a), .init(.hotcue1A, deck: .a)])
        }
    }
}

@Test @MainActor func controllerCataloguePortableHerculesNativeScratchAndFixedLoopsKeepSync() async throws {
    for name in portableNames {
        var base = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { base.deleteLastPathComponent() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "portable-playback-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
        await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
        let track = try #require(model.library.tracks.first)
        model.load(trackID: track.id, deck: .a)
        await model.flushWrites()
        let input = portableInput(name, preferences: preferences) { _, _ in true }
        input.onJogAction = { model.applyControllerJog($0, motion: $1) }
        input.onTargetAction = { target, value in
            model.applyController(target.action, value: value, targetDeck: target.deck, argument: target.argument)
        }
        let sync = model.playbackSnapshot?.a.synced
        portablePacket([0x91, 8, 127, 0xB1, 10, 1], to: input)
        try await Task.sleep(for: .milliseconds(80))
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        let frame = try #require(model.playbackSnapshot?.a.sourceFrame)
        #expect(model.playbackSnapshot?.a.touchActive == true)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(abs((model.playbackSnapshot?.a.sourceFrame ?? -100) - frame) <= 1)
        portablePacket([0x81, 8, 0, 0x96, name.hasSuffix("MIX") ? 49 : 17, 127], to: input)
        _ = model.playback.core.renderOffline(frames: 4096)
        model.refreshPlayback()
        #expect(model.playbackSnapshot?.a.touchActive == false)
        #expect(model.playbackSnapshot?.a.synced == sync)
        #expect(model.performance.loopBeats(for: .a) == 2)
    }
}
