import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withStudio2A(_ body: (ControllerMIDIConnection) -> Void) {
    let suite = "studio2a-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "Studio 2A", identity: .init(id: 10, device: 1, names: ["Studio 2A"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "Studio 2A", identity: .init(id: 20, device: 1, names: ["Studio 2A"]))
    ]
    input.reconcileFactoryProfiles()
    body(input)
}

@MainActor private func studio2APacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueStudio2AKeepsIndependentIdentityLampsAndDocumentedAudio() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Studio 2A"], automaticOnly: true))
    #expect(profile.rawValue == "Behringer CMD STUDIO 2a" && profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["CMD STUDIO 4a"]) != profile)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 41 && data.outputs.count == 14)
    #expect(data.startup == [[0x90, 34, 1]])
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewB })
    #expect(cue.message(value: 1) == [0x90, 49, 1])
    #expect(cue.message(value: 0) == [0x90, 49, 0])
    #expect(!data.outputs.contains { [.syncA, .syncB].contains($0.action) })
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([.init(name: "Studio 2A", wired: true)])
    #expect(controller.automaticOutputDevice == "Behringer CMD STUDIO 2a")
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.stopAudio()
}

@Test @MainActor func controllerCatalogueStudio2AKeepsTwoDecksHeldControlsAndFourCuesSeparate() {
    withStudio2A { input in
        #expect(input.isInputActive(10))
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        studio2APacket([0x90, 1, 127, 2, 127, 49, 127, 50, 127, 23, 127, 71, 127, 10, 127, 61, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .playA, .cuePreviewB, .playB, .loadA, .loadB, .hotcue1A, .hotcue4B])
        studio2APacket([0x80, 1, 127, 49, 127], to: input)
        #expect(events.suffix(2).map(\.1) == [0, 0])
        events.removeAll()
        studio2APacket([0x90, 3, 127, 51, 127, 6, 127, 55, 127, 0x80, 3, 127, 51, 127, 6, 127, 55, 127], to: input)
        #expect(
            events.map(\.0) == [
                .jogTouchA, .jogTouchB, .pitchBendDownA, .pitchBendUpB, .jogTouchA, .jogTouchB, .pitchBendDownA,
                .pitchBendUpB,
            ])
        #expect(events.map(\.1) == [1, 1, 1, 1, 0, 0, 0, 0])
        events.removeAll()
        studio2APacket([0x91, 2, 127, 0x90, 34, 127, 35, 127, 37, 127, 8, 127, 9, 127, 14, 127, 17, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueStudio2AKeepsRelativePitchAndJogEncoders() {
    withStudio2A { input in
        var events: [(ControllerAction, Double)] = []
        var jogs: [ControllerMIDIValue] = []
        input.currentValue = { _ in 0.5 }
        input.onAction = { events.append(($0, $1)) }
        input.onJogAction = { _, value in jogs.append(value) }
        studio2APacket([0xB0, 5, 65], to: input)
        #expect(events.last?.0 == .tempoA && events.last?.1 == 0.5 + 1.0 / 127)
        studio2APacket([0xB0, 53, 63], to: input)
        #expect(events.last?.0 == .tempoB && events.last?.1 == 0.5 - 1.0 / 127)
        studio2APacket([0xB0, 3, 63], to: input)
        studio2APacket([0xB0, 3, 64], to: input)
        studio2APacket([0xB0, 51, 65], to: input)
        #expect(jogs == [.relative(-1), .relative(1)])
        let count = events.count
        studio2APacket([0xB0, 5, 64, 53, 64], to: input)
        #expect(events.count == count)
    }
}

@Test @MainActor func controllerCatalogueStudio2AKeepsMixerAndNavigationAddresses() {
    withStudio2A { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in events.append(action) }
        studio2APacket(
            [0xB0, 19, 127, 20, 127, 21, 127, 24, 127, 67, 127, 68, 127, 69, 127, 72, 127, 32, 127, 33, 127], to: input)
        #expect(
            Set(events) == Set([.highA, .midA, .lowA, .levelA, .highB, .midB, .lowB, .levelB, .crossfader, .monitor]))
        events.removeAll()
        studio2APacket([0x90, 36, 127, 39, 127, 38, 127], to: input)
        #expect(events == [.browsePrevious, .browseNext, .openGroup])
    }
}
