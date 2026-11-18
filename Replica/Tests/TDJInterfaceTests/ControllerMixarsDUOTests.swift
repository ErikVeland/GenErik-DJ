import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withDUO(_ name: String, _ body: (ControllerMIDIConnection, UserDefaults) throws -> Void)
    rethrows
{
    let suite = "duo-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    if let profile = ControllerFactoryProfile.matching([name]) {
        input.applyFactoryProfile(profile)
        #expect(input.isInputActive(10))
    } else {
        Issue.record("Missing manual DUO profile")
    }
    try body(input, preferences)
}

@MainActor private func duoPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueDUOKeepsSeparateManualIdentitiesAndEveryCueBankAddress() {
    for name in ["Mixars DUO", "Mixars DUO MKII"] {
        #expect(ControllerFactoryProfile.matching([name])?.rawValue == name)
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
        withDUO(name) { input, _ in
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
            for (channel, deck): (UInt8, DeckID) in [(4, .a), (5, .b)] {
                for slot: UInt8 in 0...7 {
                    events.removeAll()
                    duoPacket([0x90 + channel, 20 + slot, 127, 0x80 + channel, 20 + slot, 127], to: input)
                    #expect(
                        events.count == 1 && events.first?.deck == deck && events.first?.action.hotcueSlot == Int(slot))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueDUORoutesSyncLoopAndLoadWithoutFaderStartOrSamplerActions() {
    for name in ["Mixars DUO", "Mixars DUO MKII"] {
        withDUO(name) { input, _ in
            var events: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { events.append(action) } }
            duoPacket(
                [
                    0x90, 2, 127, 2, 0, 0x91, 2, 127, 2, 0, 0x94, 64, 127, 64, 0, 0x95, 64, 127, 64, 0, 0x9F, 2, 127, 2,
                    0, 3, 127, 3, 0,
                ], to: input)
            #expect(events == [.syncA, .syncB, .loopA, .loopB, .loadA, .loadB])
            events.removeAll()
            duoPacket(
                [
                    0x90, 0, 127, 27, 127, 0xB0, 22, 127, 23, 127, 24, 127, 25, 127, 26, 127, 28, 127, 0x9F, 33, 127,
                    34, 127, 35, 127, 46, 127, 36, 127, 37, 127, 38, 127, 47, 127, 0xB4, 44, 1,
                ], to: input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueDUOShiftedReleasesCannotActivateAndNormalButtonsRearm() {
    for name in ["Mixars DUO", "Mixars DUO MKII"] {
        withDUO(name) { input, _ in
            var events: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { events.append(action) } }
            duoPacket(
                [
                    0x94, 20, 127, 0x9F, 0, 127, 0x94, 28, 127, 28, 0, 21, 127, 21, 0, 0x90, 2, 127, 2, 0, 0x9F, 2, 127,
                    2, 0,
                ], to: input)
            #expect(events == [.hotcue1A])
            duoPacket([0x8F, 0, 127, 0x94, 20, 127, 20, 0, 0x90, 2, 127, 2, 0], to: input)
            #expect(events == [.hotcue1A, .hotcue1A, .syncA])
        }
    }
}

@Test @MainActor func controllerCatalogueDUORejectsRelatedModelsAndKeepsOnlyReviewedManualBindings() {
    for name in ["Mixars PRIMO", "Mixars QUATTRO"] {
        #expect(ControllerFactoryProfile.matching([name]) == nil)
    }
    for name in ["Mixars DUO", "Mixars DUO MKII"] {
        withDUO(name) { input, _ in
            let bindings = ControllerFactoryProfile.matching([name])?.bindings(source: 10) ?? []
            #expect(bindings.count == 43)
            #expect(bindings.allSatisfy { $0.kind == .note })
            #expect(!bindings.contains { $0.action == .playA || $0.action == .playB })
        }
    }
}

@Test @MainActor func controllerCatalogueDUORestartsWithoutHeldShiftAndKeepsOtherSourcesIndependent() throws {
    for name in ["Mixars DUO", "Mixars DUO MKII"] {
        try withDUO(name) { input, preferences in
            input.sources.append(
                .init(
                    id: 11, reference: 101, name: "Other MIDI",
                    identity: .init(id: 11, device: 2, names: ["Other MIDI"])))
            input.select(11)
            input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
            input.select(10)
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            duoPacket([0x9F, 0, 127, 0x94, 20, 127, 20, 0], to: input)
            #expect(actions.isEmpty)
            input.receiveBytes([0x94, 20, 127, 20, 0], source: 11)
            input.flushPendingActions()
            #expect(actions == [.hotcue1A])
            let restored = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
            restored.sources = input.sources
            restored.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            duoPacket([0x94, 27, 127, 27, 0], to: restored)
            #expect(actions == [.hotcue1A, .hotcue8A])
        }
    }
}
