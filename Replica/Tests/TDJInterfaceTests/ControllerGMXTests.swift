import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withGMX(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "gmx-\(UUID().uuidString)"; let prefs = UserDefaults(suiteName: suite)!
    defer { prefs.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: prefs,
        factoryPacketSender: { _, _ in
            Issue.record("Manual GMX must not change hardware mode or feedback."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: "GMX", identity: .init(id: id, device: UInt32(id), names: ["GMX"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["GMX"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 92)
    try body(input)
}
@MainActor private func gmxPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueGMXManualMIDIIdentityKeepsDRIVEAndHIDSeparate() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Gemini GMX"])); let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == 46 && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
    #expect(
        d.outputs.count == 8 && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    #expect(ControllerFactoryProfile.matching(["GMX"], automaticOnly: true) == nil)
    for name in ["GMX DRIVE", "Gemini GMX DRIVE", "G2V", "G4V"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
    #expect(p.feedback(destination: 20).count == 8)
    try withGMX { _ in }
}

@Test @MainActor func controllerCatalogueGMXNormalButtonsKeepBothReleaseFormsAndNativeTargets() throws {
    try withGMX { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            for (action, n): (ControllerAction, UInt8) in [
                (.playA, 1), (.reloopA, 5), (.keylockA, 19), (.loadA, 28), (.cueA, 34), (.loopInA, 3), (.loopOutA, 4),
            ] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll();
                    gmxPacket(
                        [0x90 + ch, n, 127, n, 127, off + ch, n, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0], input)
                    #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueGMXHeldCueKeepsVelocitiesAndBothOffForms() throws {
    try withGMX { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll();
                    gmxPacket([0x90 + ch, 2, velocity, 2, 127, off + ch, 2, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                    #expect(
                        events.allSatisfy { $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck) }
                    )
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueGMXShiftLoopAliasesRearmNormalButtonsAndBlockOtherModes() throws {
    try withGMX { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            for (normal, alternate, action, shifted): (UInt8, UInt8, ControllerAction, ControllerAction) in [
                (3, 8, .loopInA, .loopDownA), (4, 7, .loopOutA, .loopUpA),
            ] {
                events.removeAll();
                gmxPacket(
                    [
                        0x90 + ch, normal, 127, 43, 127, normal, 127, alternate, 127, alternate, 0, 43, 0, normal, 127,
                        normal, 0,
                    ], input)
                #expect(events == [action, shifted, action].map { .init($0.assigned(to: deck), deck: deck) })
            }
            events.removeAll();
            gmxPacket(
                [
                    0x90 + ch, 7, 127, 7, 0, 8, 127, 8, 0, 43, 127, 1, 127, 1, 0, 2, 127, 2, 0, 19, 127, 19, 0, 20, 127,
                    20, 0, 43, 0,
                ], input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueGMXEighteenAbsoluteRowsKeepPickupAndSixInversions() throws {
    try withGMX { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let p = try #require(ControllerFactoryProfile.matching(["GMX"]));
        let controls = p.bindings(source: 10).filter { $0.kind == .control }
        #expect(controls.count == 18)
        for b in controls {
            events.removeAll(); gmxPacket([0xB0 + b.channel, b.number, 0], input); #expect(events.isEmpty)
            gmxPacket([0xB0 + b.channel, b.number, 64], input); gmxPacket([0xB0 + b.channel, b.number, 127], input)
            #expect(events.count == 2 && events.allSatisfy { $0.0 == b.target })
            let inverted = (b.channel == 3 && (11...14).contains(b.number)) || (b.channel < 2 && b.number == 1)
            #expect(events.last?.1 == (inverted ? 0 : 1))
        }
    }
}

@Test @MainActor func controllerCatalogueGMXOwnedCuePickupAndManualReapplyRemainIndependent() throws {
    try withGMX { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        gmxPacket([0x90, 2, 127], input); gmxPacket([0x90, 2, 127], input, source: 11); events.removeAll()
        gmxPacket([0x80, 2, 127], input); #expect(events.isEmpty)
        gmxPacket([0x90, 2, 0], input, source: 11); #expect(events.map(\.1) == [0])
        input.currentTargetValue = { _ in 0.5 }
        gmxPacket([0xB3, 9, 64], input); gmxPacket([0xB3, 9, 127], input); events.removeAll()
        gmxPacket([0xB3, 9, 0], input, source: 11); #expect(events.isEmpty)
        gmxPacket([0xB3, 9, 0], input); #expect(events.map(\.1) == [0])
        gmxPacket([0x90, 2, 127], input); events.removeAll()
        let p = try #require(ControllerFactoryProfile.matching(["GMX"])); input.select(10); input.applyFactoryProfile(p)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
    }
}

@Test @MainActor func controllerCatalogueGMXUnqualifiedModesWiresAndForeignReportsStayInactive() throws {
    try withGMX { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        let p = try #require(ControllerFactoryProfile.matching(["GMX"])); let bindings = p.bindings(source: 10)
        for ch: UInt8 in 0..<16 {
            let notes = bindings.filter { $0.kind == .note && $0.channel == ch }.map(\.number)
            let controls = bindings.filter { $0.kind == .control && $0.channel == ch }.map(\.number)
            for n: UInt8 in 0..<128 where !notes.contains(n) { gmxPacket([0x90 + ch, n, 127, n, 0], input) }
            for n: UInt8 in 0..<128 where !controls.contains(n) { gmxPacket([0xB0 + ch, n, 0, n, 64, n, 127], input) }
            gmxPacket([0xE0 + ch, 0, 64], input)
        }
        gmxPacket([0x90, 1, 127, 0xB3, 9, 64], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 1, value: 127), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
