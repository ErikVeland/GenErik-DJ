import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalMixDeck(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "original-mixdeck-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "MIXDECK",
            identity: .init(id: id, device: UInt32(id), names: ["MIXDECK"]))
    }
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let profile = try #require(ControllerFactoryProfile.matching(["Numark MixDeck"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0); try body(input)
}
@MainActor private func originalMixDeckPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalMixDeckKeepsIndependentManualDeckOnlyIdentity() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Numark MixDeck"])); let d = try #require(p.definition)
    #expect(
        d.inputs.count == 32 && !p.selectsAutomatically && d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty
            && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["MixDeck"], automaticOnly: true) == nil)
    for name in ["MixDeck Express", "MixDeck Quad", "MIXDECK clone"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
}

@Test @MainActor func controllerCatalogueOriginalMixDeckSoftwareTransportAndCueSetUseOriginalABWires() throws {
    try withOriginalMixDeck { input in
        var events: [(ControllerActionTarget, Double)] = []; input.onTargetAction = { events.append(($0, $1)) }
        for (channel, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            for (number, action): (UInt8, ControllerAction) in [
                (58, .playA), (57, .cueSetA), (81, .syncA), (59, .keylockA), (48, .loopInA), (49, .loopOutA),
                (50, .reloopA), (70, .loadA),
            ] {
                events.removeAll(); originalMixDeckPacket([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(events.count == 1 && events.first?.0 == .init(action.assigned(to: deck), deck: deck))
            }
            for off: UInt8 in [0x80 + channel, 0x90 + channel] {
                events.removeAll();
                originalMixDeckPacket([0x90 + channel, 56, 127, 56, 127, off, 56, off < 0x90 ? 127 : 0], input)
                #expect(
                    events.map(\.1) == [1, 0]
                        && events.allSatisfy {
                            $0.0 == .init(ControllerAction.cuePreviewA.assigned(to: deck), deck: deck)
                        })
            }
            for (number, action): (UInt8, ControllerAction) in [(60, .pitchBendDownA), (61, .pitchBendUpA)] {
                events.removeAll();
                originalMixDeckPacket([0x90 + channel, number, 127, 0x80 + channel, number, 127], input)
                #expect(
                    events.map(\.1) == [1, 0]
                        && events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalMixDeckLoopPadsUseDocumentedOneFourEightBeatArguments() throws {
    try withOriginalMixDeck { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for (channel, deck): (UInt8, DeckID) in [(0, .a), (1, .b)] {
            for (number, beats): (UInt8, Double) in [(51, 1), (52, 4), (53, 8)] {
                events.removeAll(); originalMixDeckPacket([0x90 + channel, number, 127, number, 127, number, 0], input)
                #expect(
                    events == [.init(ControllerAction.toggleFixedLoopA.assigned(to: deck), deck: deck, argument: beats)]
                )
            }
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalMixDeckBothBrowsersRequireExactSignedSteps() throws {
    try withOriginalMixDeck { input in
        var events: [(ControllerAction, Double)] = []; input.onAction = { events.append(($0, $1)) }
        for channel: UInt8 in [0, 1] {
            events.removeAll(); originalMixDeckPacket([0xB0 + channel, 33, 0, 33, 64, 33, 65, 33, 2, 33, 126], input);
            #expect(events.isEmpty)
            originalMixDeckPacket([0xB0 + channel, 33, 1], input);
            originalMixDeckPacket([0xB0 + channel, 33, 127], input)
            #expect(events.map(\.0) == [.browse, .browse] && events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
            events.removeAll(); originalMixDeckPacket([0x90 + channel, 73, 127, 73, 0], input);
            #expect(events.map(\.0) == [.openGroup])
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalMixDeckCueOwnershipAndStopKeepOtherSourcesIndependent() throws {
    try withOriginalMixDeck { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in
            if target.action == .cuePreviewA && target.deck == .a { values.append(value) }
        }
        originalMixDeckPacket([0x90, 56, 127], input); originalMixDeckPacket([0x90, 56, 127], input, source: 11)
        originalMixDeckPacket([0x80, 56, 127], input); #expect(values == [1])
        originalMixDeckPacket([0x90, 56, 0], input, source: 11); #expect(values == [1, 0])
        originalMixDeckPacket([0x90, 56, 127], input); input.stop(); #expect(values == [1, 0, 1, 0])
    }
}

@Test @MainActor func controllerCatalogueOriginalMixDeckRejectsUnqualifiedJogPitchMixerAndOtherModelWires() throws {
    try withOriginalMixDeck { input in
        var events: [ControllerActionTarget] = []; input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in [0, 1] {
            originalMixDeckPacket(
                [0xB0 + channel, 32, 1, 34, 65, 35, 127, 36, 127, 37, 127, 0xE0 + channel, 0, 127], input)
            for number: UInt8 in [62, 63, 64, 65, 66, 67, 68, 69, 74, 78, 79, 80, 89] {
                originalMixDeckPacket([0x90 + channel, number, 127, number, 0], input)
            }
        }
        originalMixDeckPacket([0x92, 58, 127, 58, 0, 0x93, 56, 127, 56, 0, 0xB4, 7, 127, 13, 127], input);
        #expect(events.isEmpty)
    }
}
