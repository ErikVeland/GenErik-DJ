import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let jbKontrolModels = ["JB Systems DJ KONTROL2", "JB Systems DJ KONTROL3"]

@MainActor private func withJBKontrol(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "jb-kontrol-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11) && writes == 0)
    let p = try #require(ControllerFactoryProfile.matching([name]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 50 && writes == 0); try body(input)
}
@MainActor private func jbKontrolPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: jbKontrolModels) @MainActor func controllerCatalogueJBKontrolIndependentManualIdentityNoSetupOrLamps(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.inputs.count == 25 && d.outputs.isEmpty)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    #expect(p.feedback(destination: 20).isEmpty)
    for other in [
        "ABMA USBAUDIO", "Beyond Music ABMA1", "Beyond Music ABMA3", "DJ-KONTROL 1", "DJ-KONTROL 3S", "DJ-KONTROL 4",
    ] { #expect(ControllerFactoryProfile.matching([other]) != p) }
    try withJBKontrol(name) { _ in }
}

@Test(arguments: jbKontrolModels) @MainActor func controllerCatalogueJBKontrolQualifiedButtonsAndRejectedSiblingRoles(
    _ name: String
) throws {
    try withJBKontrol(name) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (wire, action, deck): (UInt8, ControllerAction, DeckID) in [
            (67, .playA, .a), (76, .playB, .b), (75, .loadA, .a), (52, .loadB, .b), (85, .cueA, .a), (86, .cueB, .b),
            (73, .loopInA, .a), (74, .loopOutA, .a), (77, .loopInB, .b), (78, .loopOutB, .b),
        ] {
            events.removeAll(); jbKontrolPacket([0x90, wire, 127, wire, 127, 0x80, wire, 127], input)
            #expect(events == [.init(action, deck: deck)])
            events.removeAll(); jbKontrolPacket([0x90, wire, 127, wire, 0], input)
            #expect(events == [.init(action, deck: deck)])
        }
        events.removeAll();
        jbKontrolPacket(
            [
                0x90, 51, 127, 60, 127, 64, 127, 71, 127, 56, 127, 63, 127, 115, 127, 121, 127, 120, 127, 90, 127, 87,
                127, 4, 127, 5, 127, 0xB0, 24, 1, 25, 1, 34, 64, 0x91, 67, 127, 0xE0, 0, 64,
            ], input)
        #expect(events.isEmpty)
    }
}

@Test(arguments: jbKontrolModels) @MainActor func controllerCatalogueJBKontrolOwnMixerPitchDirectionAndSourcePickup(
    _ name: String
) throws {
    try withJBKontrol(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (wire, action, deck): (UInt8, ControllerAction, DeckID?) in [
            (8, .levelA, .a), (9, .levelB, .b), (13, .gainA, .a), (14, .gainB, .b), (16, .highA, .a), (17, .highB, .b),
            (18, .midA, .a), (19, .midB, .b), (20, .lowA, .a), (21, .lowB, .b), (11, .tempoA, .a), (12, .tempoB, .b),
            (10, .crossfader, nil), (32, .cueMix, nil),
        ] {
            let inverted = [.tempoA, .tempoB, .crossfader].contains(action)
            events.removeAll(); jbKontrolPacket([0xB0, wire, 64], input)
            jbKontrolPacket([0xB0, wire, inverted ? 0 : 127], input)
            #expect(events.count == 2 && events.last?.0 == .init(action, deck: deck) && events.last?.1 == 1)
        }
        events.removeAll(); jbKontrolPacket([0xB0, 13, 127], input, source: 11); #expect(events.isEmpty)
        jbKontrolPacket([0xB0, 13, 64], input, source: 11); #expect(events.count == 1)
    }
}

@Test(arguments: jbKontrolModels) @MainActor func controllerCatalogueJBKontrolOnlyQualified127And1LibrarySteps(
    _ name: String
) throws {
    try withJBKontrol(name) { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            #expect(target.action == .browse); values.append(value)
        }
        for value: UInt8 in [0, 2, 63, 64, 65, 126] { jbKontrolPacket([0xB0, 26, value], input) }
        #expect(values.isEmpty)
        jbKontrolPacket([0xB0, 26, 1], input); jbKontrolPacket([0xB0, 26, 127], input)
        #expect(values == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
    }
}
