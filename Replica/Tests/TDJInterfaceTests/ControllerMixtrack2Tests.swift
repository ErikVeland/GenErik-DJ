import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let mixtrack2Names = ["Mixtrack Pro II", "Mixtrack II"]

@MainActor private func withMixtrack2(_ name: String, body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "mixtrack2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func mixtrack2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueMixtrack2KeepsSeparateModelNamesAndOnePhysicalChannel() throws {
    for name in mixtrack2Names {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(Set(profile.bindings(source: 10).map(\.channel)) == [0])
        #expect(profile.feedback(destination: 20).allSatisfy { $0.onValue == 100 && $0.offValue == 0 })
        withMixtrack2(name) { input in
            var received: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in received.append(target) }
            mixtrack2Packet([0x90, 59, 127, 66, 127, 75, 127, 52, 127], to: input)
            #expect(
                received == [
                    .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.loadA, deck: .a), .init(.loadB, deck: .b),
                ])
        }
    }
    #expect(ControllerFactoryProfile.matching(["Mixtrack Pro II clone"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueMixtrack2KeepsShiftIndependentDespiteTheSharedChannel() {
    for name in mixtrack2Names {
        withMixtrack2(name) { input in
            var received: [ControllerAction] = []
            input.onAction = { action, _ in received.append(action) }
            mixtrack2Packet([0x90, 97, 127, 59, 127, 66, 127, 67, 127], to: input)
            #expect(received == [.playB, .keylockA])
            mixtrack2Packet([0x80, 59, 0, 97, 0, 0x90, 98, 127, 59, 127, 69, 127], to: input)
            #expect(received == [.playB, .keylockA, .playA, .keylockB])
        }
    }
}

@Test @MainActor func controllerCatalogueMixtrack2ShiftChangesOneLoopStepInsteadOfDispatchingBoth() {
    withMixtrack2("Mixtrack Pro II") { input in
        var received: [ControllerAction] = []
        input.onAction = { action, _ in received.append(action) }
        mixtrack2Packet([0x90, 99, 127, 0x80, 99, 0, 0x90, 97, 127, 99, 127], to: input)
        #expect(received == [.loopDownA, .loopUpA])
        mixtrack2Packet([0x90, 100, 127], to: input)
        #expect(received.last == .loopDownB)
        #expect(received.count == 3)
    }
}

@Test @MainActor func controllerCatalogueMixtrack2RetainsSignedJogAndNormalXMLTempoDirection() {
    for name in mixtrack2Names {
        withMixtrack2(name) { input in
            var received: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in received.append((target, value)) }
            mixtrack2Packet([0xB0, 24, 127, 14, 0], to: input)
            input.flushPendingActions()
            #expect(received.first { $0.0.action == .jogB }?.1 == 0.375)
            #expect(received.first { $0.0.action == .tempoB }?.1 == 1)
            mixtrack2Packet([0xB0, 14, 127], to: input)
            input.flushPendingActions()
            #expect(received.last?.0.action == .tempoB)
            #expect(received.last?.1 == 0)
        }
    }
}

@Test @MainActor func controllerCatalogueMixtrack2ReleasesTouchDuringShiftAndClearsShiftOnReconnect() {
    withMixtrack2("Mixtrack II") { input in
        var received: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in received.append((target, value)) }
        mixtrack2Packet([0x90, 77, 127, 97, 127, 0x80, 77, 0], to: input)
        #expect(received.map(\.0) == [.init(.jogTouchA, deck: .a), .init(.jogTouchA, deck: .a)])
        #expect(received.map(\.1) == [1, 0])
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        mixtrack2Packet([0x90, 59, 127], to: input)
        #expect(received.last?.0 == .init(.playA, deck: .a))
    }
}
