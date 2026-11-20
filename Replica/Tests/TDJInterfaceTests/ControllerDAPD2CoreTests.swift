import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let dapD2CoreNames = ["DAP KONTROL D2"]

@MainActor private func withDAPD2Core(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "dap-d2-core-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual DAP D2 core must not configure hardware."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching([name]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 66)
    try body(input)
}

@MainActor private func dapD2CorePacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: dapD2CoreNames) @MainActor func controllerCatalogueDAPD2CoreManualIdentityHasNoSetupOrFeedback(
    name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == 33 && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    for other in ["Traktor Kontrol D2", "Native Instruments Kontrol D2", "DAP Kontrol D4i", "ABMA4"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    #expect(p.feedback(destination: 20).isEmpty)
    try withDAPD2Core(name) { _ in }
}

@Test(arguments: dapD2CoreNames) @MainActor func controllerCatalogueDAPD2CoreNormalButtonsRearmOnEveryChannel(
    name: String
) throws {
    try withDAPD2Core(name) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 0..<16 {
            for deck in DeckID.primary {
                let buttons: [(ControllerAction, UInt8)] =
                    deck == .a
                    ? [
                        (.playA, 67), (.cueStopA, 51), (.syncA, 64), (.keylockA, 56), (.loadA, 75), (.cueA, 85),
                        (.loopDownA, 114),
                    ]
                    : [
                        (.playA, 76), (.cueStopA, 60), (.syncA, 71), (.keylockA, 63), (.loadA, 52), (.cueA, 86),
                        (.loopDownA, 97), (.loopUpA, 96), (.reloopA, 95),
                    ]
                for (action, n) in buttons {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        dapD2CorePacket(
                            [0x90 + ch, n, 127, n, 127, off + ch, n, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0],
                            input)
                        #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                    }
                }
            }
        }
    }
}

@Test(arguments: dapD2CoreNames) @MainActor func controllerCatalogueDAPD2CoreCueBendsKeepChannelIndependentReleases(
    name: String
) throws {
    try withDAPD2Core(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for ch: UInt8 in 0..<16 {
            for (deck, notes): (DeckID, [UInt8]) in [(.a, [59, 121, 120]), (.b, [68, 104, 103])] {
                for (action, n) in zip([ControllerAction.cuePreviewA, .pitchBendDownA, .pitchBendUpA], notes) {
                    for velocity: UInt8 in [1, 64, 127] {
                        for off: UInt8 in [0x80, 0x90] {
                            events.removeAll();
                            dapD2CorePacket([0x90 + ch, n, velocity, n, 127, off, n, off == 0x80 ? 127 : 0], input)
                            #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                            #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                        }
                    }
                }
            }
        }
    }
}

@Test(arguments: dapD2CoreNames) @MainActor
func controllerCatalogueDAPD2CoreElevenMixerControlsKeepPickupAndOwnTargets(name: String) throws {
    for ch: UInt8 in 0..<16 {
        try withDAPD2Core(name) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            let p = try #require(ControllerFactoryProfile.matching([name]))
            let controls = p.bindings(source: 10).filter { $0.kind == .control }; #expect(controls.count == 11)
            for b in controls {
                events.removeAll(); dapD2CorePacket([0xB0 + ch, b.number, 0], input); #expect(events.isEmpty)
                dapD2CorePacket([0xB0 + ch, b.number, 64], input); dapD2CorePacket([0xB0 + ch, b.number, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == b.target })
                #expect(events.last?.1 == 1)
            }
        }
    }
}

@Test(arguments: dapD2CoreNames) @MainActor func controllerCatalogueDAPD2CoreCueAndPickupRemainSourceOwned(name: String)
    throws
{
    try withDAPD2Core(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        dapD2CorePacket([0x9F, 59, 127], input); dapD2CorePacket([0x93, 59, 127], input, source: 11)
        events.removeAll(); dapD2CorePacket([0x80, 59, 127], input); #expect(events.isEmpty)
        dapD2CorePacket([0x88, 59, 127], input, source: 11)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
        input.currentTargetValue = { _ in 0.5 }
        dapD2CorePacket([0xBF, 8, 64], input); dapD2CorePacket([0xB1, 8, 127], input)
        events.removeAll(); dapD2CorePacket([0xB0, 8, 0], input, source: 11); #expect(events.isEmpty)
        dapD2CorePacket([0xB7, 8, 0], input); #expect(events.map(\.1) == [0])
    }
}

@Test(arguments: dapD2CoreNames) @MainActor
func controllerCatalogueDAPD2CoreUnqualifiedModesReportsAndForeignGroupsStayInactive(name: String) throws {
    try withDAPD2Core(name) { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        let p = try #require(ControllerFactoryProfile.matching([name])); let bindings = p.bindings(source: 10)
        let notes = bindings.filter { $0.kind == .note }.map(\.number)
        let controls = bindings.filter { $0.kind == .control }.map(\.number)
        for ch: UInt8 in 0..<16 {
            for n: UInt8 in 0..<128 where !notes.contains(n) { dapD2CorePacket([0x90 + ch, n, 127, n, 0], input) }
            for n: UInt8 in 0..<128 where !controls.contains(n) {
                dapD2CorePacket([0xB0 + ch, n, 0, n, 64, n, 127], input)
            }
            dapD2CorePacket([0xE0 + ch, 0, 64], input)
        }
        dapD2CorePacket([0x90, 67, 127, 0xB0, 8, 64], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 67, value: 127), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
