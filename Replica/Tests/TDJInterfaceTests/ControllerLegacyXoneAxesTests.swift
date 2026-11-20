import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let xoneAxisModels = ["Allen & Heath XONE 1D", "Allen & Heath XONE 2D", "Allen & Heath XONE 4D"]

@MainActor private func withXoneAxes(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "xone-axes-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11) && writes == 0)
    let p = try #require(ControllerFactoryProfile.matching([name]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == p.bindings(source: 10).count * 2 && writes == 0)
    try body(input)
}
@MainActor private func xoneAxisPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: xoneAxisModels) @MainActor func controllerCatalogueLegacyXoneAxesIndependentManualIdentityAndCapacity(
    _ name: String
) throws {
    let index = try #require(xoneAxisModels.firstIndex(of: name));
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.inputs.count == [18, 19, 35][index])
    #expect(
        d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    #expect(
        ControllerFactoryProfile.matching(["Xone MIDI Device"]) != p
            && ControllerFactoryProfile.matching(["USB Audio Device"]) != p)
    for other in xoneAxisModels where other != name { #expect(ControllerFactoryProfile.matching([other]) != p) }
    try withXoneAxes(name) { _ in }
}

@Test(arguments: xoneAxisModels) @MainActor func controllerCatalogueLegacyXoneAxesFourTargetsAndSourceSpecificPickup(
    _ name: String
) throws {
    try withXoneAxes(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        let pods = name == xoneAxisModels[0] ? [0] : name == xoneAxisModels[1] ? [1] : [0, 1]
        for pod in pods {
            for (i, deck) in DeckID.allCases.enumerated() {
                for (action, number): (ControllerAction, Int) in [
                    (.levelA, 19 + 12 * pod - i), (.highA, 9 + 12 * pod + 2 * i), (.lowA, 8 + 12 * pod + 2 * i),
                ] {
                    events.removeAll(); let n = UInt8(number)
                    xoneAxisPacket([0xBF, n, 0], input); #expect(events.isEmpty)
                    xoneAxisPacket([0xBF, n, 64], input);
                    #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
                    events.removeAll(); xoneAxisPacket([0xBF, n, 0], input, source: 11); #expect(events.isEmpty)
                    xoneAxisPacket([0xBF, n, 64], input, source: 11);
                    #expect(events.count == 1 && events.first?.0.deck == deck)
                }
            }
        }
    }
}

@Test(arguments: xoneAxisModels) @MainActor
func controllerCatalogueLegacyXoneAxesRelativeGainLibraryAndLoopKeepTheirOwnFamilies(_ name: String) throws {
    try withXoneAxes(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        let pod = name == xoneAxisModels[1] ? 1 : 0
        let pods = name == xoneAxisModels[2] ? [0, 1] : [pod]
        for sourcePod in pods {
            for (i, deck) in DeckID.allCases.enumerated() {
                events.removeAll(); let n = UInt8(32 + 8 * sourcePod + i)
                xoneAxisPacket([0xBF, n, 1], input); xoneAxisPacket([0xBF, n, 127], input)
                #expect(events.map(\.1) == [0.5 + 1.0 / 127, 0.5 - 1.0 / 127])
                #expect(events.allSatisfy { $0.0 == .init(ControllerAction.gainA.assigned(to: deck), deck: deck) })
            }
        }
        for (number, action): (UInt8, ControllerAction) in [(UInt8(37 + 8 * pod), .browse)]
            + (name == xoneAxisModels[2] ? [] : [(UInt8(36 + 8 * pod), .loopSizeA)])
        {
            events.removeAll(); xoneAxisPacket([0xBF, number, 1], input); xoneAxisPacket([0xBF, number, 127], input)
            #expect(
                events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126] && events.allSatisfy { $0.0.action == action })
        }
    }
}

@Test(arguments: xoneAxisModels) @MainActor
func controllerCatalogueLegacyXoneAxesRejectUnqualifiedChannelsNotesAndShiftFamilies(_ name: String) throws {
    try withXoneAxes(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        xoneAxisPacket([0xB0, 19, 64, 32, 1, 0xBE, 19, 64, 31, 64, 0x9F, 26, 127, 26, 0, 0xEF, 0, 64], input)
        #expect(events.isEmpty)
        if name == xoneAxisModels[1] { xoneAxisPacket([0xBF, 19, 64, 32, 1, 37, 1], input); #expect(events.isEmpty) }
        if name == xoneAxisModels[0] {
            xoneAxisPacket([0xBF, 31, 64, 40, 1, 45, 1, 5, 64], input); #expect(events.isEmpty)
        }
        if name == xoneAxisModels[2] { xoneAxisPacket([0xBF, 36, 1, 44, 1], input); #expect(events.isEmpty) }
    }
}
