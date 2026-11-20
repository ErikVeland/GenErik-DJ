import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withCDMP7000(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "cdmp7000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual CDMP-7000 profile must not send source setup or display commands.")
            return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "CDMP-7000",
            identity: .init(id: id, device: UInt32(id), names: ["CDMP-7000"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Gemini CDMP-7000"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 26)
    try body(input)
}

@MainActor private func cdmp7000Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueCDMP7000ManualIdentityKeepsSiblingClaimsAndOutputsInactive() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Gemini CDMP-7000"]))
    let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == 13 && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["CDMP-7000"], automaticOnly: true) == nil)
    for name in ["CDJ-700", "Gemini CDJ700", "Gemini CDMP-2700", "Gemini MDJ-1000", "Gemini GMX"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
    #expect(p.feedback(destination: 20).isEmpty)
    try withCDMP7000 { _ in }
}

@Test @MainActor func controllerCatalogueCDMP7000NormalButtonsRearmOnBothReleaseForms() throws {
    try withCDMP7000 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for (action, n): (ControllerAction, UInt8) in [
            (.playA, 2), (.loadA, 15), (.loopInA, 16), (.loopOutA, 17), (.reloopA, 18),
        ] {
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                cdmp7000Packet([0x90, n, 127, n, 127, off, n, off == 0x80 ? 127 : 0, 0x90, n, 1, n, 0], input)
                #expect(events == Array(repeating: .init(action, deck: .a), count: 2))
            }
        }
    }
}

@Test @MainActor func controllerCatalogueCDMP7000CueBendsAndContactKeepBothReleaseFormsAndSourceOwnership() throws {
    try withCDMP7000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (action, n): (ControllerAction, UInt8) in [
            (.cuePreviewA, 1), (.pitchBendUpA, 3), (.pitchBendDownA, 4), (.jogTouchA, 24),
        ] {
            for velocity: UInt8 in [1, 64, 127] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    cdmp7000Packet([0x90, n, velocity, n, 127, off, n, off == 0x80 ? 127 : 0], input)
                    #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                    #expect(events.allSatisfy { $0.0 == .init(action, deck: .a) })
                }
            }
            cdmp7000Packet([0x90, n, 127], input)
            cdmp7000Packet([0x90, n, 127], input, source: 11)
            events.removeAll()
            cdmp7000Packet([0x80, n, 127], input)
            #expect(events.isEmpty)
            cdmp7000Packet([0x90, n, 0], input, source: 11)
            #expect(events.map(\.1) == [0])
        }
    }
}

@Test @MainActor func controllerCatalogueCDMP7000NavigationUsesRepeatedDirectionalNotePulses() throws {
    try withCDMP7000 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for (n, action): (UInt8, ControllerAction) in [(11, .browsePrevious), (12, .browseNext)] {
            events.removeAll()
            cdmp7000Packet([0x90, n, 127, n, 127, n, 1, n, 0, 0x80, n, 127], input)
            #expect(events == Array(repeating: .init(action), count: 3))
        }
    }
}

@Test @MainActor func controllerCatalogueCDMP7000JogKeeps128CountsAndTempoKeepsInvertedPickup() throws {
    try withCDMP7000 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        cdmp7000Packet([0xB0, 32, 64], input)
        #expect(jogs.isEmpty)
        for value: UInt8 in [65, 63, 127, 1] { cdmp7000Packet([0xB0, 32, value], input) }
        #expect(jogs.map(\.1) == [.relative(1), .relative(-1), .relative(63), .relative(-63)])
        #expect(jogs.allSatisfy { $0.0 == .init(.jogA, deck: .a, argument: 128) })
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        cdmp7000Packet([0xB0, 33, 0], input)
        #expect(events.isEmpty)
        cdmp7000Packet([0xB0, 33, 64], input)
        cdmp7000Packet([0xB0, 33, 127], input)
        #expect(events.count == 2 && events.last?.1 == 0 && events.allSatisfy { $0.0 == .init(.tempoA, deck: .a) })
        events.removeAll()
        cdmp7000Packet([0xB0, 33, 127], input, source: 11)
        #expect(events.isEmpty)
        cdmp7000Packet([0xB0, 33, 64], input, source: 11)
        #expect(events.count == 1)
    }
}

@Test @MainActor func controllerCatalogueCDMP7000UnqualifiedChannelsModesWiresAndGroupsStayInactive() throws {
    try withCDMP7000 { input in
        var events: [ControllerActionTarget] = []
        var jogs: [ControllerMIDIValue] = []
        input.onTargetAction = { target, _ in events.append(target) }
        input.onJogAction = { _, value in jogs.append(value) }
        let p = try #require(ControllerFactoryProfile.matching(["CDMP-7000"]))
        let bindings = p.bindings(source: 10)
        for channel: UInt8 in 0..<16 {
            for number: UInt8 in 0..<128 {
                if channel > 0 || !bindings.contains(where: { $0.kind == .note && $0.number == number }) {
                    cdmp7000Packet([0x90 + channel, number, 127, number, 0], input)
                }
                if channel > 0 || !bindings.contains(where: { $0.kind == .control && $0.number == number }) {
                    cdmp7000Packet([0xB0 + channel, number, 0, number, 64, number, 127], input)
                }
            }
            cdmp7000Packet([0xE0 + channel, 0, 64], input)
        }
        cdmp7000Packet([0x90, 2, 127, 0xB0, 32, 65], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 2, value: 127), source: 10)
        input.flushPendingActions()
        #expect(events.isEmpty && jogs.isEmpty)
    }
}
