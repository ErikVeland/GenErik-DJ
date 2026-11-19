import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withTwelveMK2(
    expanded: Bool = true, _ body: (ControllerMIDIConnection, ControllerFactoryProfile) throws -> Void
) throws {
    let suite = "twelve-mk2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            Issue.record("The manual Twelve MIDI subset must not configure hardware.")
            return false
        }, deckAvailability: { expanded ? DeckID.allCases : DeckID.primary }, factoryInputConnector: { _ in true })
    let name = "Rane TWELVE MKII"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    let p = try #require(ControllerFactoryProfile.matching([name]))
    input.select(10)
    input.applyFactoryProfile(p)
    #expect(input.bindingCount == 124)
    try body(input, p)
}

@MainActor private func twelveMK2Packet(_ bytes: [UInt8], _ input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueTwelveMK2RemainsManualInputOnlyAndSeparateFromOriginal() throws {
    try withTwelveMK2 { _, p in
        let d = try #require(p.definition)
        #expect(d.isValid && d.role == "accessory" && !p.selectsAutomatically && !p.hasAutomaticSplitOutput)
        #expect(d.inputs.count == 124 && d.outputs.isEmpty && d.startup.isEmpty && d.shutdown.isEmpty)
        #expect(d.audioOutput == nil && p.feedback(destination: 20).isEmpty)
        #expect(ControllerFactoryProfile.matching(["Rane TWELVE MKII"], automaticOnly: true) == nil)
        for name in ["Rane TWELVE", "Rane TWELVE MKI", "Rane PERFORMER", "Rane SYSTEM ONE"] {
            #expect(ControllerFactoryProfile.matching([name]) != p)
        }
    }
}

@Test @MainActor func controllerCatalogueTwelveMK2OwnLoadAndSeekChannelsKeepExplicitFourTargets() throws {
    try withTwelveMK2 { input, _ in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for (index, deck) in DeckID.allCases.enumerated() {
            let ch = UInt8(index)
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                twelveMK2Packet(
                    [0x90 + ch, 2, 127, 2, 127, off + ch, 2, off == 0x80 ? 127 : 0, 0x90 + ch, 2, 1, 2, 0], input)
                #expect(events.count == 2 && events.allSatisfy { $0.0 == .init(.loadA.assigned(to: deck), deck: deck) })
            }
            for value: UInt8 in [0, 64, 127] {
                events.removeAll()
                twelveMK2Packet([0xB0 + ch, 102, value], input)
                #expect(events.count == 1)
                #expect(events.first?.0 == .init(.seekA.assigned(to: deck), deck: deck))
                #expect(abs((events.first?.1 ?? -1) - Double(value) / 127) < 0.00001)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueTwelveMK2DoesNotInventCueOneDeleteMotorPitchOrOtherWires() throws {
    try withTwelveMK2 { input, p in
        let bindings = p.bindings(source: 10)
        #expect(bindings.filter { $0.action.clearHotcueSlot != nil && $0.releaseOnly != true }.count == 28)
        #expect(!bindings.contains { $0.action.clearHotcueSlot == 0 })
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in 0..<16 {
            for number: UInt8 in 0..<128 {
                if !bindings.contains(where: { $0.kind == .note && $0.channel == channel && $0.number == number }) {
                    twelveMK2Packet([0x90 + channel, number, 127, number, 0], input)
                }
                if !bindings.contains(where: { $0.kind == .control && $0.channel == channel && $0.number == number }) {
                    twelveMK2Packet([0xB0 + channel, number, 0, number, 64, number, 127], input)
                }
            }
            twelveMK2Packet([0xE0 + channel, 0, 64], input)
        }
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueTwelveMK2RequiresExpandedDecksForCAndD() throws {
    try withTwelveMK2(expanded: false) { input, _ in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for channel: UInt8 in [2, 3] {
            twelveMK2Packet([0x90 + channel, 2, 127, 2, 0, 0xB0 + channel, 102, 64], input)
            for n: UInt8 in 20...35 {
                twelveMK2Packet([0x94 + channel, n, 127, n, 0], input)
            }
        }
        #expect(events.isEmpty)
        twelveMK2Packet([0x94, 20, 127, 20, 0, 0x95, 35, 127, 35, 0], input)
        #expect(events == [.init(.hotcue1A, deck: .a), .init(.clearHotcue8B, deck: .b)])
    }
}
