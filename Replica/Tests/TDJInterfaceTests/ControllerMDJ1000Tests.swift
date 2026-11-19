import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMDJ1000(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "mdj1000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual MDJ-1000 profile must not send source setup or display commands.")
            return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "MDJ-1000",
            identity: .init(id: id, device: UInt32(id), names: ["MDJ-1000"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Gemini MDJ-1000"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 116)
    try body(input)
}

@MainActor private func mdj1000Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMDJ1000ManualIdentityDoesNotInheritOtherGeminiModels() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Gemini MDJ-1000"]))
    let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == 58 && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["MDJ1000"], automaticOnly: true) == nil)
    for name in ["Gemini MDJ-900", "Gemini MDJ-600", "Gemini MDJ-500", "MDJ-1000V2", "Gemini CDMP-7000", "Gemini GMX"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
    #expect(p.feedback(destination: 20).isEmpty)
    try withMDJ1000 { _ in }
}

@Test @MainActor func controllerCatalogueMDJ1000NormalButtonsAndDistinctClearsRearmOnBothReleases() throws {
    try withMDJ1000 { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        var buttons: [(ControllerAction, UInt8)] = [
            (.playA, 2), (.loopInA, 4), (.loopOutA, 5), (.reloopA, 6), (.loopDownA, 7), (.loopUpA, 8), (.keylockA, 19),
            (.loadA, 9), (.syncA, 52),
        ]
        for slot in 1...4 {
            buttons.append((try #require(ControllerAction(rawValue: "hotcue\(slot)A")), UInt8(37 + slot)))
            buttons.append((try #require(ControllerAction(rawValue: "clearHotcue\(slot)A")), UInt8(41 + slot)))
        }
        for (action, n) in buttons {
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll();
                mdj1000Packet([0x90, n, 127, n, 127, off, n, off == 0x80 ? 127 : 0, 0x90, n, 1, n, 0], input)
                #expect(events == Array(repeating: .init(action, deck: .a), count: 2))
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMDJ1000HeldCueBendsKeepBothReleaseFormsAndSourceOwnership() throws {
    try withMDJ1000 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (action, n): (ControllerAction, UInt8) in [(.cuePreviewA, 1), (.pitchBendDownA, 18), (.pitchBendUpA, 17)] {
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll();
                    mdj1000Packet([0x90, n, velocity, n, 127, off, n, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                    #expect(events.allSatisfy { $0.0 == .init(action, deck: .a) })
                }
            }
            mdj1000Packet([0x90, n, 127], input); mdj1000Packet([0x90, n, 127], input, source: 11)
            events.removeAll(); mdj1000Packet([0x80, n, 127], input); #expect(events.isEmpty)
            mdj1000Packet([0x90, n, 0], input, source: 11); #expect(events.map(\.1) == [0])
        }
    }
}

@Test @MainActor func controllerCatalogueMDJ1000TrackPulsesAndInvertedTempoKeepSourcePickup() throws {
    try withMDJ1000 { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (n, action): (UInt8, ControllerAction) in [(11, .browsePrevious), (12, .browseNext)] {
            events.removeAll(); mdj1000Packet([0x90, n, 127, n, 127, n, 1, n, 0, 0x80, n, 127], input)
            #expect(events.map(\.0) == Array(repeating: .init(action), count: 3))
        }
        events.removeAll(); input.currentTargetValue = { _ in 0.5 }
        mdj1000Packet([0xB0, 1, 0], input); #expect(events.isEmpty)
        mdj1000Packet([0xB0, 1, 64], input); mdj1000Packet([0xB0, 1, 127], input)
        #expect(events.count == 2 && events.last?.1 == 0 && events.allSatisfy { $0.0 == .init(.tempoA, deck: .a) })
        events.removeAll(); mdj1000Packet([0xB0, 1, 127], input, source: 11); #expect(events.isEmpty)
        mdj1000Packet([0xB0, 1, 64], input, source: 11); #expect(events.count == 1)
    }
}

@Test @MainActor func controllerCatalogueMDJ1000UnqualifiedModesMotionChannelsAndGroupsStayInactive() throws {
    try withMDJ1000 { input in
        var events: [ControllerActionTarget] = []; var jogs: [ControllerMIDIValue] = []
        input.onTargetAction = { target, _ in events.append(target) };
        input.onJogAction = { _, value in jogs.append(value) }
        let p = try #require(ControllerFactoryProfile.matching(["MDJ-1000"])); let bindings = p.bindings(source: 10)
        for ch: UInt8 in 0..<16 {
            for n: UInt8 in 0..<128 {
                if ch > 0 || !bindings.contains(where: { $0.kind == .note && $0.number == n }) {
                    mdj1000Packet([0x90 + ch, n, 127, n, 0], input)
                }
                if ch > 0 || !bindings.contains(where: { $0.kind == .control && $0.number == n }) {
                    mdj1000Packet([0xB0 + ch, n, 0, n, 64, n, 127], input)
                }
            }
            mdj1000Packet([0xE0 + ch, 0, 64], input)
        }
        mdj1000Packet([0x90, 2, 127, 0xB0, 1, 64], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 42, value: 127), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty && jogs.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMDJ1000NegativePairsRearmOnlyTheirOwnTargetAndArgument() throws {
    try withMDJ1000 { input in
        let p = try #require(ControllerFactoryProfile.matching(["MDJ-1000"]))
        let bindings = p.bindings(source: 10)
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for guardBinding in bindings where guardBinding.releaseOnly == true {
            let positive = try #require(bindings.first { $0.releaseOnly != true && $0.target == guardBinding.target })
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                mdj1000Packet(
                    [
                        0x90, positive.number, 127, off, guardBinding.number, off == 0x80 ? 127 : 0, 0x90,
                        positive.number, 127, positive.number, 0,
                    ], input)
                #expect(events.allSatisfy { $0.0 == positive.target })
                #expect(events.map(\.1) == (positive.action.isMomentary ? [1, 0, 1, 0] : [1, 1]))
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMDJ1000EightFixedLoopOpcodesKeepExactFractionalArguments() throws {
    try withMDJ1000 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for (note, length): (UInt8, Double) in [
            (34, 2), (35, 4), (36, 8), (37, 16), (30, 0.125), (31, 0.25), (32, 0.5), (33, 1),
        ] {
            events.removeAll()
            mdj1000Packet([0x90, note, 127, note, 127, 0x80, note, 127, 0x90, note, 127, note, 0], input)
            #expect(events == Array(repeating: .init(.fixedLoopA, deck: .a, argument: length), count: 2))
        }
    }
}

@Test @MainActor func controllerCatalogueMDJ1000FilterHasItsOwnNormalPolarityAndSourcePickup() throws {
    try withMDJ1000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.currentTargetValue = { _ in 0.5 }
        mdj1000Packet([0xB0, 4, 0], input); #expect(events.isEmpty)
        mdj1000Packet([0xB0, 4, 64], input); mdj1000Packet([0xB0, 4, 127], input)
        #expect(events.count == 2 && events.last?.1 == 1)
        #expect(events.allSatisfy { $0.0 == .init(.filterKnobA, deck: .a) })
        events.removeAll(); mdj1000Packet([0xB0, 4, 127], input, source: 11); #expect(events.isEmpty)
        mdj1000Packet([0xB0, 4, 64], input, source: 11); #expect(events.count == 1)
    }
}
