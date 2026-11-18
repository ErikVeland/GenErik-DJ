import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSeventy(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "seventy-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func seventyPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSeventyKeepsTwoManualIdentitiesAndNoUnqualifiedSetup() throws {
    for (name, count) in [("Rane Seventy MIDI", 27), ("Seventy A-Trak MIDI", 19)] {
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        #expect(!profile.selectsAutomatically && !profile.hasAutomaticSplitOutput)
        let data = try #require(profile.definition)
        #expect(data.inputs.count == count && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
        #expect(data.inputModes == nil)
        for other in [
            "RANE SEVENTY-TWO", "RANE SEVENTY-TWO MKII",
            name == "Rane Seventy MIDI" ? "Seventy A-Trak MIDI" : "Rane Seventy MIDI",
        ] {
            #expect(ControllerFactoryProfile.matching([other]) != profile)
        }
    }
}

@Test @MainActor func controllerCatalogueSeventyKeepsCommonTwoDeckLoopsLoadAndSync() throws {
    for name in ["Rane Seventy MIDI", "Seventy A-Trak MIDI"] {
        try withSeventy(name) { input in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            seventyPacket(
                [
                    0x9F, 2, 127, 3, 127, 0x90, 2, 127, 0x91, 2, 127, 0x94, 64, 127, 65, 127, 52, 127, 53, 127, 54, 127,
                    55, 127, 0x95, 64, 127, 65, 127, 52, 127, 53, 127, 54, 127, 55, 127,
                ], to: input)
            #expect(
                events.map(\.action) == [
                    .loadA, .loadB, .syncA, .syncB, .loopA, .reloopA, .loopDownA, .loopUpA, .loopInA, .loopOutA, .loopB,
                    .reloopB, .loopDownB, .loopUpB, .loopInB, .loopOutB,
                ])
        }
    }
}

@Test @MainActor func controllerCatalogueSeventyKeepsFlippedBrowserAndGroupCounts() throws {
    for name in ["Rane Seventy MIDI", "Seventy A-Trak MIDI"] {
        try withSeventy(name) { input in
            var events: [(ControllerAction, Double)] = []
            input.onAction = { events.append(($0, $1)) }
            seventyPacket([0xBF, 0, 65], to: input)
            #expect(events.last?.0 == .browse && events.last?.1 == 0.5 - 1.0 / 126)
            seventyPacket([0xBF, 1, 63], to: input)
            #expect(events.last?.0 == .browseGroups && events.last?.1 == 0.5 + 1.0 / 126)
            seventyPacket([0x9F, 7, 127], to: input)
            #expect(events.last?.0 == .openGroup)
        }
    }
}

@Test @MainActor func controllerCatalogueSeventyCustomTransportStaysInTheReviewedStandardOwnerSubset() throws {
    for name in ["Rane Seventy MIDI", "Seventy A-Trak MIDI"] {
        try withSeventy(name) { input in
            var events: [(ControllerAction, Double)] = []
            input.onAction = { events.append(($0, $1)) }
            seventyPacket([0x94, 103, 127, 96, 127, 97, 127, 0x95, 103, 127, 96, 127, 97, 127], to: input)
            if name == "Seventy A-Trak MIDI" {
                #expect(events.isEmpty)
            } else {
                #expect(
                    events.map(\.0) == [.playA, .pitchBendDownA, .pitchBendUpA, .playB, .pitchBendDownB, .pitchBendUpB])
                seventyPacket([0x84, 96, 127, 97, 127, 0x95, 96, 0, 97, 0], to: input)
                #expect(events.suffix(4).map(\.1) == [0, 0, 0, 0])
            }
            events.removeAll()
            seventyPacket(
                [0x94, 0, 127, 86, 127, 102, 127, 0x90, 60, 127, 0xB0, 28, 127, 0xBF, 8, 127, 0x96, 103, 127], to: input
            )
            #expect(events.isEmpty)
        }
    }
}
