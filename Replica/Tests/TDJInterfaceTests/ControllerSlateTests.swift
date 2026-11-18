import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSlate(
    manual: Bool = false, _ body: (ControllerMIDIConnection) throws -> Void
) throws {
    let suite = "slate-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = manual ? "SLATE4-4 decks" : "SLATE Audio"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) == !manual)
    if manual {
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    }
    try body(input)
}

@MainActor private func slatePacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueSlateKeepsOriginalAndFourDeckModelIdentitiesSeparate() throws {
    let original = try #require(ControllerFactoryProfile.matching(["SLATE Audio"], automaticOnly: true))
    #expect(original.rawValue == "Gemini Slate")
    #expect(ControllerFactoryProfile.matching(["Gemini Slate 4"], automaticOnly: true) == nil)
    let four = try #require(ControllerFactoryProfile.matching(["SLATE4-4 decks"]))
    #expect(four.rawValue == "Gemini Slate 4" && four != original)
    #expect(!original.hasAutomaticSplitOutput && !four.hasAutomaticSplitOutput)
    let data = try #require(four.definition)
    #expect(data.inputs.allSatisfy { ![.jogTouchA, .jogTouchB, .tempoA, .tempoB].contains($0.action) })
    #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
}

@Test @MainActor func controllerCatalogueSlateTransportLoadAndCueReleaseKeepBothDecks() throws {
    for manual in [false, true] {
        try withSlate(manual: manual) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { events.append(($0, $1)) }
            slatePacket(
                [
                    0x90, 1, 127, 3, 127, 2, 127, 2, 127, 0x80, 2, 127, 0x91, 2, 127, 2, 0, 0x93, 1, 127, 2, 127, 5,
                    127, 6, 127,
                ], to: input)
            #expect(
                events.map { $0.0.action } == [
                    .playA, .syncA, .cuePreviewA, .cuePreviewA, .cuePreviewB, .cuePreviewB, .loadA, .loadB, .cueA,
                    .cueB,
                ])
            #expect(events.filter { [.cuePreviewA, .cuePreviewB].contains($0.0.action) }.map(\.1) == [1, 0, 1, 0])
        }
    }
}

@Test @MainActor func controllerCatalogueSlateOriginalPitchAndJogRetainDirectionWithoutInventedResolution() throws {
    try withSlate { input in
        var events: [(ControllerActionTarget, Double)] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.onJogAction = { jogs.append(($0, $1)) }
        slatePacket([0xB0, 1, 0, 0xB1, 1, 127], to: input)
        #expect(events.contains { $0.0 == .init(.tempoA, deck: .a) && $0.1 == 1 })
        #expect(events.contains { $0.0 == .init(.tempoB, deck: .b) && $0.1 == 0 })
        slatePacket([0x90, 57, 127, 0xB0, 4, 65, 0xB1, 4, 63, 0x80, 57, 127], to: input)
        #expect(jogs.contains { $0.0 == .init(.jogA, deck: .a) && $0.1 == .relative(1) })
        #expect(jogs.contains { $0.0 == .init(.jogB, deck: .b) && $0.1 == .relative(-1) })
    }
    try withSlate(manual: true) { input in
        var events: [ControllerAction] = []
        input.onTargetAction = { target, _ in events.append(target.action) }
        slatePacket([0xB0, 1, 127, 0xB1, 1, 0, 0x90, 57, 127, 0x91, 57, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueSlateOriginalPadsKeepDistinctNotesAndBlockShiftClear() throws {
    try withSlate { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for note: UInt8 in stride(from: 6, through: 27, by: 3) {
            slatePacket([0x90, note, 127, note, 0], to: input)
        }
        #expect(events.compactMap { $0.action.hotcueSlot } == Array(0..<8))
        events.removeAll()
        for note: UInt8 in stride(from: 8, through: 29, by: 3) {
            slatePacket([0x91, note, 127, note, 0], to: input)
        }
        #expect(events.compactMap(\.argument) == [0.125, 0.25, 0.5, 1, 2, 4, 8, 16])
        events.removeAll()
        slatePacket([0x93, 13, 127, 0x90, 6, 127, 6, 0, 0x93, 13, 0], to: input)
        #expect(events.isEmpty)
        slatePacket([0x90, 6, 127, 6, 0], to: input)
        #expect(events.count == 1 && events.first?.action == .hotcue1A)
    }
}

@Test @MainActor func controllerCatalogueSlateMixerPickupStaysOnGlobalChannelAndForeignChannelsStayInactive() throws {
    for manual in [false, true] {
        try withSlate(manual: manual) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { events.append(($0, $1)) }
            input.currentTargetValue = { $0 == .init(.midA, deck: .a) ? 0.5 : nil }
            slatePacket([0xB3, 5, 127], to: input)
            #expect(events.isEmpty)
            slatePacket([0xB3, 5, 64, 21, 127, 22, 0, 25, 127, 26, 0], to: input)
            #expect(events.contains { $0.0 == .init(.midA, deck: .a) && abs($0.1 - 0.5) < 0.005 })
            #expect(events.contains { $0.0 == .init(.levelA, deck: .a) && $0.1 == 1 })
            #expect(events.contains { $0.0 == .init(.levelB, deck: .b) && $0.1 == 0 })
            let count = events.count
            slatePacket([0xB2, 21, 127, 0x92, 1, 127, 2, 127], to: input)
            #expect(events.count == count)
        }
    }
}

@Test @MainActor func controllerCatalogueSlateOriginalSetupFeedbackAndReconnectStayBounded() throws {
    let suite = "slate-lifecycle-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        })
    let source = ControllerMIDIConnection.Source(
        id: 10, reference: 100, name: "SLATE Audio", identity: .init(id: 10, device: 1, names: ["SLATE Audio"]))
    let destination = ControllerMIDIConnection.Source(
        id: 20, reference: 200, name: "SLATE Audio", identity: .init(id: 20, device: 1, names: ["SLATE Audio"]))
    input.sources = [source]
    input.destinations = [destination]
    input.reconcileFactoryProfiles()
    #expect(packets == [[0x90, 56, 127], [0x91, 56, 127]])
    input.reconcileFactoryProfiles()
    #expect(packets.count == 2)
    let profile = try #require(ControllerFactoryProfile.matching(["SLATE Audio"]))
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cuePreviewA })
    #expect(cue.message(value: 1) == [0x90, 2, 127])
    #expect(cue.message(value: 0) == [0x90, 2, 0])
    input.sources = []
    input.reconcileFactoryProfiles()
    input.sources = [source]
    input.reconcileFactoryProfiles()
    #expect(Array(packets.suffix(2)) == [[0x90, 56, 127], [0x91, 56, 127]])
}

@Test @MainActor func controllerCatalogueSlateSetupFailureKeepsInputInactiveAndBrowserDirectionsStayDistinct() throws {
    let suite = "slate-setup-failure-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in false })
    input.sources = [
        .init(id: 10, reference: 100, name: "SLATE Audio", identity: .init(id: 10, device: 1, names: ["SLATE Audio"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "SLATE Audio", identity: .init(id: 20, device: 1, names: ["SLATE Audio"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    for manual in [false, true] {
        try withSlate(manual: manual) { input in
            var values: [Double] = []
            input.onTargetAction = { target, value in if target.action == .browse { values.append(value) } }
            slatePacket([0xB3, 30, 65], to: input)
            #expect(values.last == 0.5 + 1.0 / 126)
            slatePacket([0xB3, 30, manual ? 63 : 1], to: input)
            #expect(values.last == 0.5 - 1.0 / 126)
            slatePacket([0xB3, 30, 64], to: input)
            #expect(values.count == 2)
        }
    }
}
