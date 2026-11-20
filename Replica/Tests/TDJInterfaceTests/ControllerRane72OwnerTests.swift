import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRane72Owner(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "rane72-owner-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual original Seventy-Two subset must not configure hardware.")
            return false
        }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id), name: "Rane SEVENTY-TWO",
            identity: .init(id: id, device: UInt32(id), names: ["Rane SEVENTY-TWO"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    let p = try #require(ControllerFactoryProfile.matching(["Rane SEVENTY-TWO"]))
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
    #expect(input.bindingCount == 14)
    try body(input)
}

@MainActor private func rane72OwnerPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRane72OwnerIdentityDoesNotInheritMKIIOrAudio() throws {
    let p = try #require(ControllerFactoryProfile.matching(["Rane SEVENTY-TWO"]))
    let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == 7 && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
    #expect(d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(ControllerFactoryProfile.matching(["Rane SEVENTY-TWO"], automaticOnly: true) == nil)
    for name in ["Rane SEVENTY-TWO MKII", "Seventy-Two MK2", "Rane SEVENTY", "Rane PERFORMER", "Rane TWELVE"] {
        #expect(ControllerFactoryProfile.matching([name]) != p)
    }
    #expect(p.feedback(destination: 20).isEmpty)
    try withRane72Owner { _ in }
}

@Test @MainActor func controllerCatalogueRane72OwnerButtonsKeepOwnChannelsTargetsAndBothReleases() throws {
    try withRane72Owner { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for deck in DeckID.primary {
            let channel: UInt8 = deck == .a ? 4 : 5
            for (action, ch, n): (ControllerAction, UInt8, UInt8) in [
                (.playA, channel, 40), (.syncA, channel, 41), (.loadA, 15, deck == .a ? 2 : 3),
            ] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    rane72OwnerPacket(
                        [0x90 + ch, n, 127, n, 127, off + ch, n, off == 0x80 ? 127 : 0, 0x90 + ch, n, 1, n, 0], input)
                    #expect(events == Array(repeating: .init(action.assigned(to: deck), deck: deck), count: 2))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueRane72OwnerBrowseUsesSignedSevenBitCounts() throws {
    try withRane72Owner { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rane72OwnerPacket([0xBF, 0, 0], input)
        #expect(events.isEmpty)
        for value: UInt8 in [1, 1, 127, 127, 63, 64] { rane72OwnerPacket([0xBF, 0, value], input) }
        #expect(events.count == 7 && events.allSatisfy { $0.0 == .init(.browse) })
        #expect(events[0].1 > 0.5 && events[1].1 > 0.5 && events[2].1 < 0.5 && events[3].1 < 0.5)
        #expect(events[4].1 > 0.5 && events[5].1 < 0.5 && events[6].1 < 0.5)
    }
}

@Test @MainActor func controllerCatalogueRane72OwnerButtonDebounceIsSourceOwned() throws {
    try withRane72Owner { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        rane72OwnerPacket([0x94, 40, 127], input)
        events.removeAll()
        rane72OwnerPacket([0x84, 40, 127], input, source: 11)
        rane72OwnerPacket([0x94, 40, 127], input)
        #expect(events.isEmpty)
        rane72OwnerPacket([0x94, 40, 127], input, source: 11)
        #expect(events == [.init(.playA, deck: .a)])
        events.removeAll()
        rane72OwnerPacket([0x84, 40, 127, 0x94, 40, 127, 40, 0], input)
        #expect(events == [.init(.playA, deck: .a)])
    }
}

@Test @MainActor func controllerCatalogueRane72OwnerPadsMixerForeignWiresAndGroupsRemainInactive() throws {
    try withRane72Owner { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        let p = try #require(ControllerFactoryProfile.matching(["Rane SEVENTY-TWO"]))
        let bindings = p.bindings(source: 10)
        for channel: UInt8 in 0..<16 {
            for number: UInt8 in 0..<128 {
                if !bindings.contains(where: { $0.kind == .note && $0.channel == channel && $0.number == number }) {
                    rane72OwnerPacket([0x90 + channel, number, 127, number, 0], input)
                }
                if !bindings.contains(where: { $0.kind == .control && $0.channel == channel && $0.number == number }) {
                    rane72OwnerPacket([0xB0 + channel, number, 0, number, 64, number, 127], input)
                }
            }
            rane72OwnerPacket([0xE0 + channel, 0, 64], input)
        }
        rane72OwnerPacket([0x94, 40, 127, 0xBF, 0, 1], input, source: 999)
        input.receive(.init(kind: .note, group: 1, channel: 4, number: 40, value: 127), source: 10)
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}
