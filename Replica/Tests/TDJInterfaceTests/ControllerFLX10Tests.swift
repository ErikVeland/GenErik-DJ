import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withFLX10(
    _ decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "flx10-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [
        .init(id: 10, reference: 100, name: "DDJ-FLX10", identity: .init(id: 10, device: 1, names: ["DDJ-FLX10"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "DDJ-FLX10", identity: .init(id: 20, device: 1, names: ["DDJ-FLX10"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func flx10Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueFLX10TargetsFourDecksAndUsesPublishedLoopFunctions() {
    withFLX10 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        flx10Packet([0x92, 11, 127, 0x93, 12, 127, 0x92, 16, 127, 17, 127, 20, 127], to: input)
        #expect(events.map(\.deck) == [.c, .d, .c, .c, .c])
        #expect(events.map(\.action) == [.playA, .cuePreviewB, .loopInOrHalveA, .loopOutOrDoubleA, .toggleFixedLoopA])
        #expect(events.last?.argument == 4)
    }
}

@Test @MainActor func controllerCatalogueFLX10BeatJumpsKeepFourAndSixteenBeatDistances() {
    withFLX10 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        flx10Packet([0x90, 94, 127, 95, 127, 63, 127, 97, 127, 98, 127], to: input)
        #expect(events.map(\.action) == [.fixedJumpA, .fixedJumpA, .fixedJumpA, .fixedJumpA])
        #expect(events.map(\.argument) == [-4, 4, -16, 16])
    }
}

@Test @MainActor func controllerCatalogueFLX10BankReportsReleaseOnlyTheirSidesCueAndRearmPickup() {
    withFLX10 { input in
        input.currentTargetValue = { [.tempoA, .tempoB].contains($0.action) ? 0.5 : nil }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        flx10Packet([0xB0, 0, 64, 32, 0, 0xB1, 0, 64, 32, 0, 0x90, 12, 127, 0x91, 12, 127], to: input)
        events.removeAll()
        flx10Packet([0x92, 60, 127], to: input)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)])
        #expect(events.map(\.1) == [0])
        events.removeAll()
        flx10Packet([0xB0, 0, 0, 32, 0, 0xB1, 0, 0, 32, 0], to: input)
        #expect(events.map(\.0) == [.init(.tempoB, deck: .b)])
    }
}

@Test @MainActor func controllerCatalogueFLX10KeepsPhysicalShiftAcrossBanksAndLeavesOtherSideUsable() {
    withFLX10 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        flx10Packet([0x90, 63, 127, 0x92, 60, 127, 97, 127, 0x91, 11, 127], to: input)
        #expect(events == [.init(.fixedJumpA, deck: .c, argument: -16), .init(.playB, deck: .b)])
        events.removeAll()
        flx10Packet([0x82, 63, 0, 0x90, 60, 127, 11, 127], to: input)
        #expect(events == [.init(.playA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueFLX10DoesNotScratchFromShiftedGridEditingOrVinylOffMessages() {
    withFLX10 { input in
        var movements: [ControllerActionTarget] = []
        var touches: [Double] = []
        input.onJogAction = { target, _ in movements.append(target) }
        input.onTargetAction = { target, value in if target.action == .jogTouchA { touches.append(value) } }
        flx10Packet([0xB0, 35, 65], to: input)
        #expect(movements.map(\.action) == [.wheelJogA])
        movements.removeAll()
        flx10Packet([0x90, 54, 127, 63, 127, 103, 127, 103, 0, 0xB0, 31, 65, 38, 65, 41, 65], to: input)
        #expect(touches == [1, 0])
        #expect(movements.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueFLX10RespectsDeckCapacityAndDoesNotAliasOtherModels() {
    withFLX10([.a, .b]) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        flx10Packet([0x92, 11, 127, 0x93, 11, 127, 0x96, 72, 127, 0x9B, 0, 127, 0x90, 11, 127], to: input)
        #expect(events == [.init(.playA, deck: .a)])
    }
    #expect(ControllerFactoryProfile.matching(["DDJ-FLX10"])?.rawValue == "DDJ-FLX10")
    #expect(ControllerFactoryProfile.matching(["AlphaTheta DDJ-FLX10"]) == .flx10)
    #expect(ControllerFactoryProfile.matching(["DDJ-FLX10+"]) == nil)
    #expect(Set(ControllerFactoryProfile.allCases).count == ControllerFactoryProfile.allCases.count)
}

@MainActor private func withFLX10Playback(_ body: (ReplicaModel) async throws -> Void) async throws {
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
        .init(id: 10, reference: 100, name: "DDJ-FLX10", identity: .init(id: 10, device: 1, names: ["DDJ-FLX10"]))
    ]
    model.controllerInput.reconcileFactoryProfiles()
    try await body(model)
}

@Test @MainActor func controllerCatalogueFLX10NativeLoopsSetBoundariesThenHalveDoubleAndToggleFourBeats() async throws {
    try await withFLX10Playback { model in
        let sampleRate = try #require(model.track(.a)?.analysis.sampleRate)
        let input = model.controllerInput
        flx10Packet([0x90, 16, 127], to: input)
        model.jump(sampleRate, deck: .a, quantized: false)
        flx10Packet([0x90, 17, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        #expect(abs((model.playbackSnapshot?.a.loopEnd ?? -1) - sampleRate) <= 1)
        flx10Packet([0x90, 16, 0, 16, 127], to: input)
        #expect(abs((model.playbackSnapshot?.a.loopEnd ?? -1) - sampleRate / 2) <= 1)
        flx10Packet([0x90, 17, 0, 17, 127], to: input)
        #expect(abs((model.playbackSnapshot?.a.loopEnd ?? -1) - sampleRate) <= 1)
        flx10Packet([0x90, 20, 127], to: input)
        let state = try #require(model.playbackSnapshot?.a)
        #expect(state.loopEnabled)
        #expect(abs(state.loopEnd - state.loopStart - sampleRate * 2) <= 1)
        flx10Packet([0x90, 20, 0, 20, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        #expect(model.playbackSnapshot?.a.synced == true)
    }
}

@Test @MainActor func controllerCatalogueFLX10NativeBeatJumpsIgnoreTheSelectedLoopSize() async throws {
    try await withFLX10Playback { model in
        model.setLoopSize(1, deck: .a)
        let grid = try #require(model.timing(.a))
        let first = try #require(model.playbackSnapshot?.a.sourceFrame)
        flx10Packet([0x90, 95, 127], to: model.controllerInput)
        #expect(
            abs((model.playbackSnapshot?.a.sourceFrame ?? -1) - grid.frame(atBeat: grid.beat(atFrame: first) + 4)) <= 1)
        flx10Packet([0x90, 63, 127, 97, 127], to: model.controllerInput)
        #expect(abs(model.playbackSnapshot?.a.sourceFrame ?? -1) <= 1)
        #expect(model.playbackSnapshot?.a.synced == true)
        #expect(model.playbackSnapshot?.a.phase.active == false)
    }
}

@Test @MainActor func controllerCatalogueFLX10RoutesLoadPadsAndShiftedTempoToTheSelectedDeck() {
    withFLX10 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        flx10Packet([0x96, 70, 127, 71, 127, 72, 127, 73, 127, 0x9B, 7, 127, 0x9D, 7, 127], to: input)
        #expect(events.map(\.deck) == [.a, .b, .c, .d, .c, .d])
        #expect(events.suffix(2).map(\.action) == [.hotcue8A, .hotcue8B])
        events.removeAll()
        flx10Packet([0x92, 63, 127, 0xB2, 5, 64, 37, 0], to: input)
        #expect(events == [.init(.tempoA, deck: .c)])
    }
}

@Test @MainActor func controllerCatalogueFLX10MigrationKeepsStoredCustomMappings() throws {
    try withFLX10 { original in
        let suite = "flx10-custom-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let custom = ControllerBinding(
            source: 10, group: 0, channel: 0, kind: .note, number: 11, parameter: nil, noteNumber: nil,
            action: .playB, encoding: .absolute, inverted: false, shifted: false)
        preferences.set(try JSONEncoder().encode([custom]), forKey: "controllers.midiBindings.v1")
        let restored = ControllerMIDIConnection(preferences: preferences)
        restored.sources = original.sources
        restored.destinations = original.destinations
        restored.reconcileFactoryProfiles()
        var events: [ControllerActionTarget] = []
        restored.onTargetAction = { target, _ in events.append(target) }
        flx10Packet([0x90, 11, 127], to: restored)
        #expect(events == [.init(.playB)])
    }
}
