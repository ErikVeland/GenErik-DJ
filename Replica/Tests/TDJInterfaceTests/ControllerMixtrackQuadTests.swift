import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixtrackQuad(_ allDecks: Bool = true, _ body: (ControllerMIDIConnection) throws -> Void)
    rethrows
{
    let suite = "mixtrack-quad-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { allDecks ? DeckID.allCases : DeckID.primary })
    let name = "MixTrack Quad"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func quadPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMixtrackQuadKeepsFactorySetupPaletteAndDocumentedAudio() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["MixTrack Quad"], automaticOnly: true))
    #expect(profile.rawValue == "Numark Mixtrack Quad")
    #expect(profile != ControllerFactoryProfile.matching(["Mixtrack Pro II"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 106 && data.outputs.count == 36)
    #expect(data.startup.count == 9 && data.shutdown.count == 52)
    #expect(profile.hasAutomaticSplitOutput)
    #expect(data.startup.contains([0xB1, 60, 0]) && data.startup.contains([0x94, 72, 127]))
    #expect(data.startup.dropFirst().allSatisfy { $0.count == 3 })
    let colour = try #require(profile.feedback(destination: 20).first { $0.action == .hotcue4B && $0.targetDeck == .d })
    #expect(colour.message(value: 1) == [0x94, 112, 5])
    #expect(colour.message(value: 0) == [0x94, 112, 0])
    let loop = try #require(profile.feedback(destination: 20).first { $0.action == .loopA && $0.targetDeck == .a })
    #expect(loop.message(value: 1) == [0x91, 85, 8])
}

@Test @MainActor func controllerCatalogueMixtrackQuadRetainsFourLoadChannelsAndDedicatedMixerControls() {
    withMixtrackQuad { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for channel: UInt8 in 1...4 { quadPacket([0x90 + channel, channel % 2 == 1 ? 75 : 76, 127], to: input) }
        #expect(events.compactMap { $0.0.deck } == DeckID.allCases)
        events.removeAll()
        quadPacket(
            [
                0xB0, 16, 64, 17, 64, 18, 64, 20, 127, 21, 64, 22, 64, 23, 64, 25, 127,
                26, 64, 27, 64, 28, 64, 30, 127, 31, 64, 32, 64, 33, 64, 35, 127,
            ], to: input)
        #expect(events.count == 16)
        #expect(Set(events.compactMap { $0.0.deck }) == Set(DeckID.allCases))
        #expect(
            events.filter { $0.0.action == .highA || $0.0.action == .midA || $0.0.action == .lowA }.allSatisfy {
                $0.1 == 0.5
            })
        #expect(!events.contains { $0.0.action == .gainA || $0.0.action == .gainB })
    }
    withMixtrackQuad(false) { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        quadPacket([0x93, 75, 127, 0x94, 76, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMixtrackQuad600CountJogPitchAndCrossfaderKeepSourcePolarity() {
    withMixtrackQuad { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var events: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { events.append(($0, $1)) }
        quadPacket([0x91, 77, 127, 0xB1, 37, 1], to: input)
        #expect(jogs.last?.0 == .init(.jogA, deck: .a, argument: 600))
        #expect(jogs.last?.1 == .relative(1))
        quadPacket([0xB4, 37, 127], to: input)
        #expect(jogs.last?.0 == .init(.jogB, deck: .d, argument: 600))
        #expect(jogs.last?.1 == .relative(-1))
        quadPacket([0xB1, 13, 0], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 1)
        quadPacket([0xB1, 13, 127], to: input)
        #expect(events.last?.1 == 0)
        quadPacket([0xB0, 10, 0], to: input)
        #expect(events.last?.0.action == .crossfader && events.last?.1 == 1)
        quadPacket([0xB0, 36, 127], to: input)
        #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 - 1.0 / 126)
    }
}

@Test @MainActor func controllerCatalogueMixtrackQuadShiftBendReleaseAndBankKeepSideOwnership() {
    withMixtrackQuad { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        quadPacket([0x91, 67, 127, 97, 127, 67, 0], to: input)
        #expect(events.map { $0.0.action } == [.pitchBendDownA, .pitchBendDownA])
        #expect(events.last?.1 == 0)
        events.removeAll()
        quadPacket([0x91, 67, 127, 0x92, 51, 127], to: input)
        #expect(events.map { $0.0.action } == [.keylockA, .cuePreviewB])
        quadPacket([0x90, 78, 127, 0x93, 97, 0, 51, 127], to: input)
        #expect(events.last?.0 == .init(.cuePreviewA, deck: .c))
        let count = events.count
        quadPacket([0x80, 78, 0], to: input)
        #expect(events.count == count)
        quadPacket([0x92, 51, 0, 0x93, 51, 0], to: input)
        #expect(events.suffix(2).map { $0.0.deck } == [.b, .c])
    }
}

@Test @MainActor func controllerCatalogueMixtrackQuadPadsKeepNativeLoopPageAndRejectShiftedClearAndSamples() {
    withMixtrackQuad { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        quadPacket([0x91, 109, 127, 110, 127, 111, 127, 112, 127], to: input)
        #expect(events.compactMap { $0.action.hotcueSlot } == Array(0..<4))
        events.removeAll()
        quadPacket([0x91, 83, 127, 84, 127, 85, 127, 99, 127, 99, 0, 97, 127, 99, 127], to: input)
        #expect(events.map(\.action) == [.loopInA, .loopOutOrExitA, .reloopA, .loopDownA, .loopUpA])
        events.removeAll()
        quadPacket([0x91, 109, 0, 109, 127, 101, 127, 102, 127, 103, 127, 104, 127], to: input)
        #expect(events.isEmpty)
        quadPacket([0x91, 109, 0, 97, 0, 109, 127], to: input)
        #expect(events.map(\.action) == [.hotcue1A])
    }
}

@Test @MainActor func controllerCatalogueMixtrackQuadShiftBlocksWheelModeChangesWithoutBlockingItsMixer() {
    withMixtrackQuad { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var events: [(ControllerActionTarget, Double)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { events.append(($0, $1)) }
        quadPacket([0x91, 97, 127, 77, 127, 0xB1, 37, 1, 0xB0, 16, 64], to: input)
        #expect(jogs.isEmpty)
        #expect(events.map { $0.0.action } == [.highA])
        quadPacket([0x91, 77, 0, 97, 0, 77, 127, 97, 127, 77, 0], to: input)
        #expect(events.suffix(2).map { $0.0.action } == [.jogTouchA, .jogTouchA])
        #expect(events.last?.1 == 0)
    }
}
