import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalIMix(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "original-imix-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Original i-Mix input must not execute source setup or scripts."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "DJ-Tech i-Mix",
            identity: .init(id: id, device: UInt32(id), names: ["DJ-Tech i-Mix"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["DJ-Tech I-MIX"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 62)
    try body(input)
}

@MainActor private func originalIMixPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalIMixIdentityKeepsMalformedModesAndFeedbackInactive() throws {
    let p = try #require(ControllerFactoryProfile.matching(["DJ-Tech I-MIX"]))
    let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == 31 && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["DJ-Tech i-Mix"], automaticOnly: true) == nil)
    for name in ["iMix", "i-Mix", "DJ-Tech i-Mix Club Edition"] {
        #expect(ControllerFactoryProfile.matching([name]) == p)
    }
    for name in ["i-Mix Reload", "DJ-Tech i-Mix Reload", "I-MIX RELOAD MKII", "Kontrol One"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
    #expect(p.feedback(destination: 20).isEmpty)
    try withOriginalIMix { _ in }
}

@Test @MainActor func controllerCatalogueOriginalIMixTransportLoopsAndPFLRearmAfterBothOffForms() throws {
    try withOriginalIMix { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (deck, notes): (DeckID, [UInt8]) in [(.a, [20, 1, 8, 15, 17]), (.b, [55, 36, 43, 50, 24])] {
            for (action, n) in zip([ControllerAction.playA, .loopInA, .loopOutA, .reloopA, .cueA], notes) {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    originalIMixPacket([0x90, n, 127, n, 127, off, n, off == 0x80 ? 127 : 0, 0x90, n, 1, n, 0], input)
                    #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalIMixCueBendsRetainThreeVelocitiesAndBothReleaseForms() throws {
    try withOriginalIMix { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (deck, notes): (DeckID, [UInt8]) in [(.a, [13, 14, 22]), (.b, [48, 49, 29])] {
            for (action, n) in zip([ControllerAction.cuePreviewA, .pitchBendDownA, .pitchBendUpA], notes) {
                for velocity: UInt8 in [1, 64, 127] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        originalIMixPacket([0x90, n, velocity, n, 127, off, n, off == 0x80 ? 127 : 0], input)
                        #expect(events.map(\.1) == [Double(velocity) / 127, 0])
                        #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalIMixElevenMixerRowsKeepTheirOwnNumbersAndPickup() throws {
    try withOriginalIMix { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let p = try #require(ControllerFactoryProfile.matching(["DJ-Tech I-MIX"]))
        let controls = p.bindings(source: 10).filter { $0.kind == .control }; #expect(controls.count == 11)
        for b in controls {
            events.removeAll(); originalIMixPacket([0xB0, b.number, 0], input); #expect(events.isEmpty)
            originalIMixPacket([0xB0, b.number, 64], input); originalIMixPacket([0xB0, b.number, 127], input)
            #expect(events.map(\.1) == [64.0 / 127, 1] && events.allSatisfy { $0.0 == b.target })
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalIMixTrackEncodersAreRepeatedNotePulses() throws {
    try withOriginalIMix { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (n, action): (UInt8, ControllerAction) in [
            (82, .browseNext), (80, .browseNext), (83, .browsePrevious), (81, .browsePrevious),
        ] {
            events.removeAll(); originalIMixPacket([0x90, n, 127, n, 127, n, 1, n, 0, 0x80, n, 127], input)
            #expect(events == Array(repeating: .init(action), count: 3))
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalIMixHeldCueAndPickupRemainSourceOwned() throws {
    try withOriginalIMix { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        originalIMixPacket([0x90, 13, 127], input); originalIMixPacket([0x90, 13, 127], input, source: 11)
        events.removeAll(); originalIMixPacket([0x80, 13, 127], input); #expect(events.isEmpty)
        originalIMixPacket([0x80, 13, 127], input, source: 11)
        #expect(events.map(\.0) == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
        input.currentTargetValue = { _ in 0.5 }
        originalIMixPacket([0xB0, 72, 64], input); originalIMixPacket([0xB0, 72, 127], input)
        events.removeAll(); originalIMixPacket([0xB0, 72, 0], input, source: 11); #expect(events.isEmpty)
        originalIMixPacket([0xB0, 72, 0], input); #expect(events.map(\.1) == [0])
    }
}

@Test @MainActor func controllerCatalogueOriginalIMixUnqualifiedReportsChannelsAndModesStayInactive() throws {
    try withOriginalIMix { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for ch: UInt8 in 1..<16 {
            originalIMixPacket(
                [0x90 + ch, 20, 127, 13, 127, 48, 127, 17, 127, 82, 127, 0xB0 + ch, 72, 64, 65, 64], input)
        }
        let notes: [UInt8] = [20, 13, 1, 8, 15, 14, 22, 17, 55, 48, 36, 43, 50, 49, 29, 24, 80, 81, 82, 83]
        for n: UInt8 in 0..<128 where !notes.contains(n) { originalIMixPacket([0x90, n, 127, n, 0], input) }
        let controls: [UInt8] = [72, 69, 70, 71, 67, 75, 76, 74, 73, 66, 65]
        for n: UInt8 in 0..<128 where !controls.contains(n) { originalIMixPacket([0xB0, n, 0, n, 64, n, 127], input) }
        originalIMixPacket([0xE0, 0, 64], input); originalIMixPacket([0x90, 20, 127, 0xB0, 72, 64], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 20, value: 127), source: 10);
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
