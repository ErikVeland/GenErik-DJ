import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let mixtrack3Names = ["Mixtrack Pro 3", "Mixtrack 3"]

@MainActor private func withMixtrack3(_ name: String, body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "mixtrack3-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func mixtrack3Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueMixtrack3RetainsSeparateNamesAndPublishedCoreChannels() throws {
    for name in mixtrack3Names {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(Set(profile.bindings(source: 10).compactMap(\.targetDeck)) == Set(DeckID.primary))
        #expect(profile.bindings(source: 10).filter { $0.action == .shift }.map(\.shiftChannel) == [1, 2])
        #expect(!profile.bindings(source: 10).contains { $0.action.hotcueSlot != nil })
        withMixtrack3(name) { input in
            var received: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in received.append(target) }
            mixtrack3Packet([0x91, 1, 127, 0x92, 1, 127, 0x90, 16, 127, 17, 127], to: input)
            #expect(
                received == [
                    .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.loadA, deck: .a), .init(.loadB, deck: .b),
                ])
        }
    }
    #expect(ControllerFactoryProfile.matching(["Mixtrack Pro 3 clone"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueMixtrack3ShiftBlocksOnlyItsOwnDeck() {
    for name in mixtrack3Names {
        withMixtrack3(name) { input in
            var received: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in received.append(target) }
            mixtrack3Packet([0x91, 11, 127, 1, 127, 0x81, 1, 0, 0x92, 1, 127], to: input)
            #expect(received == [.init(.playB, deck: .b)])
            mixtrack3Packet([0x92, 11, 127, 0x81, 11, 0, 0x91, 1, 127, 0x82, 1, 0, 0x92, 1, 127], to: input)
            #expect(received == [.init(.playB, deck: .b), .init(.playA, deck: .a)])
            mixtrack3Packet([0x90, 16, 127, 17, 127], to: input)
            #expect(received.last == .init(.loadA, deck: .a))
            #expect(received.count == 3)
        }
    }
}

@Test @MainActor func controllerCatalogueMixtrack3AllowsTouchReleaseDuringShiftAndClearsModifiersOnReconnect() {
    withMixtrack3("Mixtrack Pro 3") { input in
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        mixtrack3Packet([0x91, 12, 127, 11, 127, 0x81, 12, 0], to: input)
        #expect(received.map(\.0) == [.init(.jogTouchA, deck: .a), .init(.jogTouchA, deck: .a)])
        #expect(received.map(\.1) == [1, 0])
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        mixtrack3Packet([0x91, 1, 127], to: input)
        #expect(received.last?.0 == .init(.playA, deck: .a))
    }
}

@Test @MainActor func controllerCatalogueMixtrack3KeepsSignedJogNativeTempoDirectionAndGlobalMixerControls() {
    for name in mixtrack3Names {
        withMixtrack3(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            mixtrack3Packet([0xB2, 17, 127, 24, 127, 56, 127, 1, 127, 0xB0, 7, 127], to: input)
            input.flushPendingActions()
            #expect(received.first { $0.0.action == .jogB }?.1 == 0.375)
            #expect(received.first { $0.0.action == .tempoB }?.1 == 1)
            #expect(received.first { $0.0.action == .highB }?.1 == 1)
            #expect(received.first { $0.0.action == .crossfader }?.1 == 1)
        }
    }
}

@Test @MainActor func controllerCatalogueMixtrack3BlocksShiftedMixerAndKeepsManualLoopMessages() {
    withMixtrack3("Mixtrack 3") { input in
        var received: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in received.append(target) }
        mixtrack3Packet([0x91, 11, 127, 0xB1, 1, 127, 0xB2, 1, 127], to: input)
        input.flushPendingActions()
        #expect(received == [.init(.highB, deck: .b)])
        mixtrack3Packet([0x92, 19, 127, 20, 127, 21, 127, 22, 127], to: input)
        #expect(Array(received.suffix(4)).map(\.action) == [.loopInB, .loopOutB, .reloopB, .loopDownB])
    }
}
