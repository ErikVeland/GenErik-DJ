import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withContour(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "contour-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Reloop CONTOUR",
            identity: .init(id: id, device: UInt32(id), names: ["Reloop CONTOUR"]))
    }
    input.reconcileFactoryProfiles(); #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0)
    try body(input)
}
@MainActor private func contourPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueContourBothEditionsAndSourceOwnedShiftReleaseAliases() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Reloop CONTOUR"])); let d = try #require(p.definition)
    #expect(p.selectsAutomatically && d.isValid && d.inputs.count == 164 && d.outputs.count == 48)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    for name in ["Reloop Contour Controller Edition", "Reloop Contour Interface Edition"] {
        #expect(ControllerFactoryProfile.matching([name]) == p)
    }
    #expect(ControllerFactoryProfile.matching(["Reloop Jockey 3"]) != p)
    try withContour { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        for status: UInt8 in [0x80, 0x90] {
            for number: UInt8 in [38, 102] {
                values.removeAll(); contourPacket([0x90, 38, 127, 38, 127], input)
                contourPacket([0x90, 38, 127], input, source: 11)
                contourPacket([status, number, status == 0x80 ? 127 : 0], input); #expect(values == [1])
                contourPacket([status, number, status == 0x80 ? 127 : 0], input, source: 11); #expect(values == [1, 0])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueContourDeckAndModeSelectorsPreserveFreshContacts() throws {
    try withContour { input in
        var events: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA || target.action == .cuePreviewB { events.append((target.deck, value)) }
        }
        contourPacket([0x90, 38, 127, 0x91, 6, 127, 38, 127, 6, 0], input)
        #expect(events.map(\.1) == [1, 0, 1] && events.last?.0 == .b)
        contourPacket([0x81, 38, 127], input); #expect(events.map(\.1) == [1, 0, 1, 0])
        events.removeAll(); contourPacket([0x90, 38, 127, 0x91, 38, 127, 0x90, 32, 127], input)
        #expect(events.count == 3 && events.last?.0 == .a && events.last?.1 == 0)
        contourPacket([0x91, 33, 127], input); #expect(events.count == 4 && events.last?.0 == .b && events.last?.1 == 0)
    }
}

@Test @MainActor func controllerCatalogueContourNormalScratchContactsGateRawCountsAndModeRetiresOwnership() throws {
    try withContour { input in
        var jogs: [ControllerMIDIValue] = [];
        input.onJogAction = { target, value in
            #expect(target.argument == 150 && target.deck == .a); jogs.append(value)
        }
        for number: UInt8 in [47, 48] {
            jogs.removeAll(); contourPacket([0xB0, number, 69], input); #expect(jogs.isEmpty)
            contourPacket([0x90, number, 127], input)
            for value: UInt8 in [65, 69, 63] { contourPacket([0xB0, number, value], input) }
            #expect(jogs == [.relative(1), .relative(5), .relative(-1)])
            contourPacket([0x90, 33, 127, 0xB0, number, 65], input); #expect(jogs.count == 3)
            contourPacket([0x80, number + 64, 127], input)
        }
    }
}

@Test @MainActor func controllerCatalogueContourEightCuesRelativeControlsAndRejectedCopiedRoles() throws {
    try withContour { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck) in zip(UInt8(0)...3, DeckID.allCases) {
            for (slot, number) in [UInt8(26), 27, 28, 29, 52, 53, 54, 55].enumerated() {
                events.removeAll(); contourPacket([0x90 + ch, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0.action.hotcueSlot == slot && events.first?.0.deck == deck)
            }
        }
        for (number, action): (UInt8, ControllerAction) in [(9, .browse), (22, .loopSizeA)] {
            events.removeAll(); contourPacket([0xB0, number, 69], input); contourPacket([0xB0, number, 59], input)
            #expect(
                events.map(\.1) == [0.5 + 5.0 / 126, 0.5 - 5.0 / 126] && events.allSatisfy { $0.0.action == action })
        }
        events.removeAll();
        contourPacket([0xE0, 0, 64, 0xB0, 109, 64, 110, 64, 49, 65, 0x90, 102, 127, 103, 127, 104, 127], input)
        #expect(events.isEmpty)
    }
    let p = try #require(ControllerFactoryProfile.matching(["Reloop CONTOUR"]))
    for lamp in p.feedback(destination: 20) {
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
        #expect(lamp.number != 8 && lamp.number < 64)
    }
}
