import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMC4000(body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "mc4000-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "MC4000", identity: .init(id: 10, device: 1, names: ["MC4000"]))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: "MC4000", identity: .init(id: 20, device: 1, names: ["MC4000"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func mc4000Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueMC4000UsesFactoryDeckAndGlobalChannels() throws {
    for name in ["MC4000", "Denon MC4000", "Denon DJ MC4000"] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.definition?.startup.first == [240, 0, 2, 11, 127, 1, 96, 0, 4, 4, 1, 0, 0, 247])
        #expect(
            profile.feedback(destination: 20).allSatisfy {
                $0.kind == .note && $0.onValue == ($0.action.hotcueSlot == nil ? 127 : 1) && $0.offValue == 0
            })
    }
    withMC4000 { input in
        var received: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in received.append(target) }
        mc4000Packet([0x90, 0, 127, 0x91, 0, 127, 13, 127, 0x9F, 2, 127, 3, 127], to: input)
        #expect(
            received == [
                .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.keylockB, deck: .b), .init(.loadA, deck: .a),
                .init(.loadB, deck: .b),
            ])
    }
    #expect(ControllerFactoryProfile.matching(["MC4000 clone"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueMC4000KeepsWorkingTempoPairAndSignedJog() {
    withMC4000 { input in
        var received: [(ControllerAction, Double)] = []
        input.onAction = { action, value in received.append((action, value)) }
        mc4000Packet([0xB1, 9, 127, 41, 127, 6, 127], to: input)
        input.flushPendingActions()
        #expect(received.first { $0.0 == .tempoB }?.1 == 0)
        #expect(received.first { $0.0 == .jogB }?.1 == 0.375)
        mc4000Packet([0xB1, 9, 0, 41, 0], to: input)
        input.flushPendingActions()
        #expect(received.last?.0 == .tempoB)
        #expect(received.last?.1 == 1)
    }
}

@Test @MainActor func controllerCatalogueMC4000KeepsShiftedManualLoopsSeparate() {
    withMC4000 { input in
        var received: [ControllerAction] = []
        input.onAction = { action, _ in received.append(action) }
        mc4000Packet([0x94, 50, 127, 0x9F, 50, 127, 0x91, 0, 127, 0x94, 56, 127, 0x95, 57, 127], to: input)
        #expect(received == [.loopA, .loopInA, .loopOutB])
        mc4000Packet([0x8F, 50, 0, 0x81, 0, 0, 0x91, 0, 127], to: input)
        #expect(received.last == .playB)
    }
}

@Test @MainActor func controllerCatalogueMC4000SeparatesHotCuesFromUnsupportedPadModesAndReleasesHeldTouch() {
    withMC4000 { input in
        var received: [(ControllerAction, Double)] = []
        input.onAction = { action, value in received.append((action, value)) }
        mc4000Packet(
            [0x94, 20, 127, 0x9A, 127, 127, 0x94, 20, 127, 0x90, 10, 127, 6, 127, 0x9F, 50, 127, 0x80, 6, 0], to: input)
        #expect(received.map(\.0) == [.hotcue1A, .jogTouchA, .jogTouchA])
        #expect(received.map(\.1) == [1, 1, 0])
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        mc4000Packet([0x90, 0, 127], to: input)
        #expect(received.last?.0 == .playA)
    }
}

@Test @MainActor func controllerCatalogueMC4000BendsUseFactoryNotesAndBothAlternateReleaseForms() throws {
    withMC4000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for channel: UInt8 in [0, 1] {
            for (number, alternate, action): (UInt8, UInt8, ControllerAction) in [
                (12, 32, channel == 0 ? .pitchBendDownA : .pitchBendDownB),
                (11, 33, channel == 0 ? .pitchBendUpA : .pitchBendUpB),
            ] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    mc4000Packet([0x90 + channel, number, 127, number, 127, alternate, 127], to: input)
                    input.receiveBytes([off + channel, alternate, off == 0x80 ? 127 : 0], source: 999)
                    #expect(events.map(\.1) == [1])
                    mc4000Packet([off + channel, alternate, off == 0x80 ? 127 : 0], to: input)
                    #expect(events.map { $0.0.action } == [action, action])
                    #expect(events.map(\.1) == [1, 0])
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMC4000ShiftedCueNegativeReleasesOnlyItsOwnHeldCue() {
    withMC4000 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for channel: UInt8 in [0, 1] {
            for off: UInt8 in [0x80, 0x90] {
                events.removeAll()
                mc4000Packet([0x90 + channel, 1, 127, 5, 127], to: input)
                input.receiveBytes([off + channel, 5, off == 0x80 ? 127 : 0], source: 999)
                #expect(events.map(\.1) == [1])
                mc4000Packet([off + channel, 5, off == 0x80 ? 127 : 0], to: input)
                #expect(
                    events.map { $0.0.action } == Array(repeating: channel == 0 ? .cuePreviewA : .cuePreviewB, count: 2)
                )
                #expect(events.map(\.1) == [1, 0])
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMC4000HotCueFeedbackUsesOnlyBlueAndOffFactoryValues() throws {
    let p = try #require(ControllerFactoryProfile.matching(["MC4000"]))
    let leds = p.feedback(destination: 20).filter { $0.action.hotcueSlot != nil }
    #expect(leds.count == 8)
    for led in leds {
        #expect(led.message(value: 1) == [0x90 + led.channel, led.number, 1])
        #expect(led.message(value: 0) == [0x90 + led.channel, led.number, 0])
    }
    #expect(!p.feedback(destination: 20).contains { $0.action.clearHotcueSlot != nil })
}
