import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withEncore(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "encore-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("Manual Encore input must not configure hardware."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Encore 2000",
            identity: .init(id: id, device: UInt32(id), names: ["Encore 2000"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Encore 2000"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 136 && input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

@MainActor private func encorePacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueEncoreOwnConfiguredIdentityAndSixNormalLamps() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Encore 2000"])); let d = try #require(p.definition)
    #expect(d.isValid && !p.selectsAutomatically && d.inputs.count == 68 && d.outputs.count == 6)
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["Encore 2000"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["Encore 1000"]) != p)
    for lamp in p.feedback(destination: 20) {
        #expect(lamp.channel < 2 && [6, 19, 23].contains(lamp.number))
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
    try withEncore { _ in }
}

@Test @MainActor func controllerCatalogueEncoreNormalTransportLoopsAndKeylockRearmAcrossTAPReleases() throws {
    try withEncore { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            for (action, n): (ControllerAction, UInt8) in [
                (.playA, 23), (.keylockA, 6), (.loopInA, 15), (.loopOutA, 11), (.reloopA, 12),
            ] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll(); encorePacket([0x90 + ch, n + 63, 127, n + 63, 0], input);
                    #expect(events.isEmpty)
                    encorePacket(
                        [0x90 + ch, n, 127, n, 127, off + ch, n + 63, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0],
                        input)
                    #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueEncoreCueAndBendsKeepThreeVelocitiesAndBothReleaseForms() throws {
    try withEncore { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            for (action, n): (ControllerAction, UInt8) in [
                (.cuePreviewA, 19), (.pitchBendDownA, 8), (.pitchBendUpA, 16),
            ] {
                for velocity: UInt8 in [1, 64, 127] {
                    for off: UInt8 in [0x80, 0x90] {
                        events.removeAll();
                        encorePacket([0x90 + ch, n, velocity, n, 127, off + ch, n + 63, off == 0x80 ? 127 : 0], input)
                        #expect(
                            events.map(\.1) == [Double(velocity) / 127, 0]
                                && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueEncoreTwentyNormalAndTAPMixerRowsKeepPickup() throws {
    try withEncore { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        let p = try #require(ControllerFactoryProfile.matching(["Encore 2000"]))
        let mixer = p.bindings(source: 10).filter { $0.kind == .control }; #expect(mixer.count == 20)
        for binding in mixer {
            events.removeAll(); encorePacket([0xB0 + binding.channel, binding.number, 0], input);
            #expect(events.isEmpty)
            encorePacket([0xB0 + binding.channel, binding.number, 64], input);
            encorePacket([0xB0 + binding.channel, binding.number, 127], input)
            #expect(events.count == 2 && events.allSatisfy { $0.0 == binding.target } && events.last?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCatalogueEncoreFolderLoadAliasesAndRepeatedTrackGroupStepsStaySeparate() throws {
    try withEncore { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (ch, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            events.removeAll();
            encorePacket(
                [0x90 + ch, 13, 127, 13, 127, 76, 0, 13, 1, 13, 0, 76, 127, 76, 127, 13, 0, 76, 1, 76, 0], input)
            #expect(
                events == [
                    .init(.openGroup), .init(.openGroup), .init(.loadA.assigned(to: deck), deck: deck),
                    .init(.loadA.assigned(to: deck), deck: deck),
                ])
            for (n, action): (UInt8, ControllerAction) in [
                (17, .browsePrevious), (21, .browseNext), (80, .browsePreviousGroup), (84, .browseNextGroup),
            ] {
                events.removeAll(); encorePacket([0x90 + ch, n, 127, n, 127, n, 0], input)
                #expect(events == [.init(action), .init(action)])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueEncoreTAPRetiresOnlyOwnedDeckBeforeUnmappedChannelChanges() throws {
    try withEncore { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        encorePacket([0x90, 19, 127, 0x91, 19, 127], input); encorePacket([0x90, 19, 127], input, source: 11);
        events.removeAll()
        encorePacket([0x90, 4, 127, 0x92, 19, 127, 23, 127, 4, 0], input); #expect(events.isEmpty)
        encorePacket([0x80, 19, 127], input, source: 11)
        #expect(events.map { $0.0 } == [.init(.cuePreviewA, deck: .a)] && events.map(\.1) == [0])
        events.removeAll(); encorePacket([0x91, 4, 127, 4, 0], input)
        #expect(events.map { $0.0 } == [.init(.cuePreviewB, deck: .b)] && events.map(\.1) == [0])
        events.removeAll()
        for ch: UInt8 in 0..<16 {
            encorePacket(
                [
                    0xB0 + ch, 32, 65, 38, 127, 48, 127, 49, 127, 50, 127, 51, 127, 52, 127, 95, 65, 111, 127, 112, 127,
                    113, 127, 114, 127, 115, 127, 0x90 + ch, 1, 127, 2, 127, 5, 127, 7, 127, 9, 127, 10, 127, 14, 127,
                    18, 127, 22, 127, 27, 127, 32, 127, 53, 127, 54, 127, 95, 127, 0xE0 + ch, 0, 0,
                ], input)
            if ch > 1 { encorePacket([0x90 + ch, 19, 127, 23, 127, 0xB0 + ch, 37, 64], input) }
        }
        #expect(events.isEmpty)
    }
}
