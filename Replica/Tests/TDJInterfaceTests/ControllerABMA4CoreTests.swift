import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let abma4CoreNames = ["BeyondMusic (BMI) ABMA4", "JB Systems DJ KONTROL1"]

@MainActor private func withABMA4Core(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "abma4-core-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual ABMA4/KONTROL1 core must not configure hardware."); return false
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

@MainActor private func abma4CorePacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: abma4CoreNames) @MainActor func controllerCatalogueABMA4CoreManualIdentityHasNoSetupOrFeedback(
    name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == 33 && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    for other in ["ABMA1", "ABMA2", "ABMA3", "DJ-KONTROL 2", "DJ-KONTROL 3", "DJ KONTROL3S", "DJ KONTROL4"] {
        #expect(ControllerFactoryProfile.matching([other]) != p)
    }
    #expect(p.feedback(destination: 20).isEmpty)
    try withABMA4Core(name) { _ in }
}

@Test(arguments: abma4CoreNames) @MainActor func controllerCatalogueABMA4CoreNormalButtonsRearmOnEveryChannel(
    name: String
) throws {
    try withABMA4Core(name) { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 0..<16 {
            for (deck, notes): (DeckID, [UInt8]) in [
                (.a, [67, 64, 56, 75, 85, 114, 113]), (.b, [76, 71, 63, 52, 86, 97, 96]),
            ] {
                for (action, n) in zip(
                    [ControllerAction.playA, .syncA, .keylockA, .loadA, .cueA, .loopDownA, .loopUpA], notes)
                {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        abma4CorePacket(
                            [0x90 + ch, n, 127, n, 127, off + ch, n, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0],
                            input)
                        #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                    }
                }
            }
        }
    }
}

@Test(arguments: abma4CoreNames) @MainActor func controllerCatalogueABMA4CoreCueBendsKeepChannelIndependentReleases(
    name: String
) throws {
    try withABMA4Core(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for ch: UInt8 in 0..<16 {
            for (deck, notes): (DeckID, [UInt8]) in [(.a, [51, 121, 120]), (.b, [60, 104, 103])] {
                for (action, n) in zip([ControllerAction.cuePreviewA, .pitchBendDownA, .pitchBendUpA], notes) {
                    for velocity: UInt8 in [1, 64, 127] {
                        for off: UInt8 in [0x80, 0x90] {
                            events.removeAll();
                            abma4CorePacket([0x90 + ch, n, velocity, n, 127, off, n, off == 0x80 ? 127 : 0], input)
                            #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                            #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                        }
                    }
                }
            }
        }
    }
}

@Test(arguments: abma4CoreNames) @MainActor
func controllerCatalogueABMA4CoreThirteenMixerControlsKeepPickupAndCrossInversion(name: String) throws {
    for ch: UInt8 in 0..<16 {
        try withABMA4Core(name) { input in
            input.currentTargetValue = { _ in 0.5 }
            var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
            let p = try #require(ControllerFactoryProfile.matching([name]))
            let controls = p.bindings(source: 10).filter { $0.kind == .control }; #expect(controls.count == 13)
            for b in controls {
                events.removeAll(); abma4CorePacket([0xB0 + ch, b.number, 0], input); #expect(events.isEmpty)
                abma4CorePacket([0xB0 + ch, b.number, 64], input); abma4CorePacket([0xB0 + ch, b.number, 127], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == b.target })
                #expect(events.last?.1 == (b.action == .crossfader ? 0 : 1))
            }
        }
    }
}

@Test(arguments: abma4CoreNames) @MainActor func controllerCatalogueABMA4CoreCueAndPickupRemainSourceOwned(name: String)
    throws
{
    try withABMA4Core(name) { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        abma4CorePacket([0x9F, 51, 127], input); abma4CorePacket([0x93, 51, 127], input, source: 11)
        events.removeAll(); abma4CorePacket([0x80, 51, 127], input); #expect(events.isEmpty)
        abma4CorePacket([0x88, 51, 127], input, source: 11)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
        input.currentTargetValue = { _ in 0.5 }
        abma4CorePacket([0xBF, 8, 64], input); abma4CorePacket([0xB1, 8, 127], input)
        events.removeAll(); abma4CorePacket([0xB0, 8, 0], input, source: 11); #expect(events.isEmpty)
        abma4CorePacket([0xB7, 8, 0], input); #expect(events.map(\.1) == [0])
    }
}

@Test(arguments: abma4CoreNames) @MainActor
func controllerCatalogueABMA4CoreUnqualifiedModesReportsAndForeignGroupsStayInactive(name: String) throws {
    try withABMA4Core(name) { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        let p = try #require(ControllerFactoryProfile.matching([name])); let bindings = p.bindings(source: 10)
        let notes = bindings.filter { $0.kind == .note }.map(\.number)
        let controls = bindings.filter { $0.kind == .control }.map(\.number)
        for ch: UInt8 in 0..<16 {
            for n: UInt8 in 0..<128 where !notes.contains(n) { abma4CorePacket([0x90 + ch, n, 127, n, 0], input) }
            for n: UInt8 in 0..<128 where !controls.contains(n) {
                abma4CorePacket([0xB0 + ch, n, 0, n, 64, n, 127], input)
            }
            abma4CorePacket([0xE0 + ch, 0, 64], input)
        }
        abma4CorePacket([0x90, 67, 127, 0xB0, 8, 64], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 67, value: 127), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
