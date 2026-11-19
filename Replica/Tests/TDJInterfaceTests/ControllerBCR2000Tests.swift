import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withBCR2000(
    failDestination: Int32? = nil, paired: Bool = true,
    _ body: (ControllerMIDIConnection, [([UInt8], Int32)]) throws -> Void
) rethrows {
    let suite = "bcr2000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [([UInt8], Int32)] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, destination in
            packets.append((bytes, destination))
            return destination != failDestination
        }, factoryInputConnector: { _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "BCR2000", identity: .init(id: 10, device: 1, names: ["BCR2000"])),
        .init(id: 11, reference: 101, name: "BCR2000", identity: .init(id: 11, device: 2, names: ["BCR2000"])),
    ]
    if paired {
        input.destinations = [
            .init(id: 20, reference: 200, name: "BCR2000", identity: .init(id: 20, device: 1, names: ["BCR2000"])),
            .init(id: 21, reference: 201, name: "BCR2000", identity: .init(id: 21, device: 2, names: ["BCR2000"])),
        ]
    }
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func bcrPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueBCR2000SelectsOnlyPresetOneWithTwoWireBytesAndFailsClosed() throws {
    try withBCR2000 { input, packets in
        #expect(input.isInputActive(10) && input.isInputActive(11))
        #expect(packets.map(\.0) == [[0xC0, 0], [0xC0, 0]])
        #expect(Set(packets.map(\.1)) == [20, 21])
        input.reconcileFactoryProfiles()
        let profile = try #require(ControllerFactoryProfile.matching(["BCR2000"]))
        #expect(profile.selectsAutomatically && profile.definition?.inputs.count == 12)
        #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
        #expect(ControllerFactoryProfile.matching(["BCF2000"]) != profile)
        #expect(!ControllerProfileData.validSetupMessage([0xC0, 0, 0]))
    }
    withBCR2000(failDestination: 20) { input, packets in
        #expect(!input.isInputActive(10) && input.isInputActive(11))
        #expect(packets.count == 2)
    }
    withBCR2000(paired: false) { input, packets in
        #expect(!input.isInputActive(10) && !input.isInputActive(11))
        #expect(packets.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueBCR2000RoutesEveryNormalEQFilterAndIgnoresUnimplementedModes() {
    withBCR2000 { input, _ in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (index, deck) in DeckID.primary.enumerated() {
            for (offset, action): (UInt8, ControllerAction) in [(0, .filterKnobA), (1, .lowA), (2, .midA), (3, .highA)]
            {
                events.removeAll()
                let number = UInt8(9 + index * 4) + offset
                bcrPacket([0xB0, number, 64], to: input)
                bcrPacket([0xB0, number, 127], to: input)
                #expect(events.count == 2)
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                #expect(events.map(\.1) == [64.0 / 127, 1])
            }
        }
        events.removeAll()
        for number: UInt8 in Array(1...8) + Array(33...64) + [66, 67, 70, 71] + Array(73...108) {
            bcrPacket([0xB0, number, 127, number, 0], to: input)
        }
        bcrPacket([0xB1, 9, 127, 65, 127, 0x90, 65, 127, 0xC0, 0], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueBCR2000StateButtonsKeepEveryOnOffWithoutPickupOrSoftwareToggle() throws {
    try withBCR2000 { input, _ in
        input.currentTargetValue = { _ in 0.8 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (number, deck): (UInt8, DeckID) in [(65, .a), (69, .b)] {
            events.removeAll()
            bcrPacket([0xB0, number, 127, number, 127, number, 0, number, 0, number, 127, number, 0], to: input)
            let action = try #require(ControllerAction(rawValue: "keylockState" + deck.rawValue.uppercased()))
            #expect(!action.isButton && action.isDirectState && !action.isLearnable)
            #expect(events.count == 6)
            #expect(events.allSatisfy { $0.0 == .init(action, deck: deck) })
            #expect(events.map(\.1) == [1, 1, 0, 0, 1, 0])
        }
    }
}

@Test @MainActor func controllerCatalogueBCR2000ShiftUsesOneSharedLastMessageStatePerSource() {
    withBCR2000 { input, _ in
        var values: [Double] = []
        input.onTargetAction = { target, value in if target.action.rawValue == "keylockStateA" { values.append(value) }
        }
        bcrPacket([0xB0, 68, 127, 72, 127, 65, 127], to: input)
        #expect(values.isEmpty)
        bcrPacket([0xB0, 65, 127], to: input, source: 11)
        #expect(values == [1])
        bcrPacket([0xB0, 68, 0, 65, 127, 65, 0], to: input)
        #expect(values == [1, 1, 0])
        bcrPacket([0xB0, 72, 127, 65, 127, 72, 0, 65, 0], to: input)
        #expect(values == [1, 1, 0, 0])
        let sources = input.sources
        let destinations = input.destinations
        input.stop()
        input.sources = sources
        input.destinations = destinations
        input.reconcileFactoryProfiles()
        bcrPacket([0xB0, 65, 127], to: input)
        #expect(values.last == 1)
    }
}

@Test @MainActor func controllerCatalogueBCR2000CoreFeedbackUsesExactCCAddressesAndNoInputStateAction() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["BCR2000"]))
    let lamps = profile.feedback(destination: 20)
    #expect(lamps.count == 10 && lamps.allSatisfy(\.isValid))
    #expect(Set(lamps.map(\.number)) == Set(Array(9...16) + [65, 69]))
    for lamp in lamps {
        #expect(lamp.kind == .control && lamp.channel == 0 && lamp.destination == 20)
        #expect(lamp.message(value: 0) == [0xB0, lamp.number, 0])
        #expect(lamp.message(value: 1) == [0xB0, lamp.number, 127])
        if lamp.number < 65 { #expect(lamp.message(value: 0.5) == [0xB0, lamp.number, 64]) }
        #expect(!lamp.action.isDirectState)
    }
}
