import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withIDJ3(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "idj3-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: "iDJ3", identity: .init(id: 10, device: 1, names: ["iDJ3"]))]
    input.destinations = [
        .init(id: 20, reference: 200, name: "iDJ3", identity: .init(id: 20, device: 1, names: ["iDJ3"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func idj3Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueIDJ3KeepsItsIdentityAndOnlyReviewedSteadyLamps() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["iDJ3"], automaticOnly: true))
    #expect(profile.rawValue == "Numark iDJ3" && !profile.hasAutomaticSplitOutput)
    for name in ["iDJ Live", "iDJ Live II", "Mixtrack", "Mixtrack Pro"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
    let definition = try #require(profile.definition)
    #expect(definition.inputs.count == 44 && definition.outputs.count == 8)
    #expect(!definition.inputs.contains { $0.action == .master || $0.kind == .pitch })
    let outputs = profile.feedback(destination: 20)
    #expect(!outputs.contains { [.syncA, .syncB].contains($0.action) })
    let cue = try #require(outputs.first { $0.action == .cuePreviewB })
    #expect(cue.message(value: 1) == [0x90, 60, 127])
    #expect(cue.message(value: 0) == [0x90, 60, 0])
}

@Test @MainActor func controllerCatalogueIDJ3DispatchesBothDecksAndRejectsSiblingOrUnknownAddresses() {
    withIDJ3 { input in
        #expect(input.isInputActive(10))
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        idj3Packet(
            [
                0x90, 59, 127, 51, 127, 0x80, 51, 127, 0x90, 66, 127, 60, 127, 60, 0, 75, 127, 52, 127, 79, 127, 105,
                127,
            ], to: input)
        #expect(
            events.map(\.0) == [
                .playA, .cuePreviewA, .cuePreviewA, .playB, .cuePreviewB, .cuePreviewB, .loadA, .loadB, .openGroup,
                .openGroup,
            ])
        events.removeAll()
        idj3Packet(
            [0x91, 59, 127, 0x90, 72, 127, 80, 127, 74, 127, 76, 127, 99, 127, 100, 127, 0xB0, 23, 127], to: input)
        #expect(events.isEmpty)
        idj3Packet([0x90, 78, 127, 77, 127, 67, 127, 70, 127, 0x80, 78, 127, 77, 127, 67, 127, 70, 127], to: input)
        #expect(
            events.map(\.0) == [
                .jogTouchA, .jogTouchB, .pitchBendDownA, .pitchBendUpB, .jogTouchA, .jogTouchB, .pitchBendDownA,
                .pitchBendUpB,
            ])
        #expect(events.map(\.1) == [1, 1, 1, 1, 0, 0, 0, 0])
    }
}

@Test @MainActor func controllerCatalogueIDJ3KeepsSourceRaw64PositiveJogAndBrowserCounts() {
    withIDJ3 { input in
        var jogs: [ControllerMIDIValue] = []
        var browse: [Double] = []
        input.onJogAction = { _, value in jogs.append(value) }
        input.onAction = { action, value in if action == .browse { browse.append(value) } }
        idj3Packet([0xB0, 25, 64], to: input)
        idj3Packet([0xB0, 24, 127], to: input)
        #expect(jogs == [.relative(64), .relative(-1)])
        idj3Packet([0xB0, 26, 64], to: input)
        #expect(abs(browse.reduce(0) { $0 + ($1 - 0.5) * 126 } - 64) < 0.000001)
        browse.removeAll()
        idj3Packet([0xB0, 26, 127], to: input)
        #expect(browse == [0.5 - 1.0 / 126])
    }
}

@Test @MainActor func controllerCatalogueIDJ3KeepsMixerAndUninvertedPitchAddresses() {
    withIDJ3 { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        idj3Packet(
            [0xB0, 8, 127, 9, 127, 16, 127, 17, 127, 18, 127, 19, 127, 20, 127, 21, 127, 10, 127, 11, 127, 12, 127],
            to: input)
        #expect(
            Set(events.map(\.0))
                == Set([.levelA, .levelB, .highA, .highB, .midA, .midB, .lowA, .lowB, .crossfader, .monitor, .cueMix]))
        idj3Packet([0xB0, 13, 0], to: input)
        #expect(events.last?.0 == .tempoA && events.last?.1 == 0)
        idj3Packet([0xB0, 14, 127], to: input)
        #expect(events.last?.0 == .tempoB && events.last?.1 == 1)
    }
}
