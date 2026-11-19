import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withHerculesMix(_ body: (ControllerMIDIConnection, () -> [[UInt8]]) throws -> Void) rethrows {
    let suite = "hercules-mix-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, destination in
            #expect(destination == 20)
            packets.append(bytes)
            return true
        })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "DJControl MIX",
            identity: .init(id: 10, device: 1, names: ["DJControl MIX"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: "DJControl MIX",
            identity: .init(id: 20, device: 1, names: ["DJControl MIX"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input, { packets })
}

@MainActor private func herculesMixPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueHerculesMixUsesItsOwnExactIdentityAndSetup() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJControl MIX"], automaticOnly: true))
    #expect(profile.rawValue == "Hercules DJControl MIX")
    #expect(profile.definition?.inputs.count == 68)
    #expect(profile.feedback(destination: 20).count == 22)
    #expect(ControllerFactoryProfile.matching(["DJControl MIX ULTRA"], automaticOnly: true) != profile)
    #expect(ControllerFactoryProfile.matching(["Hercules MIX"], automaticOnly: true) == nil)
    withHerculesMix { input, packets in
        #expect(input.isInputActive(10))
        #expect(packets() == [[0x91, 3, 127], [0xB0, 127, 127]])
        input.reconcileFactoryProfiles()
        #expect(packets().count == 2)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        #expect(packets().last == [0xB0, 127, 0])
        input.sources = sources
        input.reconcileFactoryProfiles()
        #expect(Array(packets().suffix(2)) == [[0x91, 3, 127], [0xB0, 127, 127]])
    }
}

@Test @MainActor func controllerCatalogueHerculesMixBlocksShiftSearchAndRestoresNormalJogs() {
    withHerculesMix { input, _ in
        var edges: [ControllerAction] = []
        var jogs: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, _ in edges.append(target.action) }
        input.onJogAction = { target, motion in
            if case .relative(let value) = motion { jogs.append((target, value)); edges.append(target.action) }
        }
        herculesMixPacket([0x90, 3, 127], to: input)
        herculesMixPacket([0x95, 8, 127, 0xB5, 10, 127, 0x85, 8, 0], to: input)
        herculesMixPacket([0x94, 8, 127, 0xB4, 10, 1, 0x84, 8, 0], to: input)
        input.flushPendingActions()
        #expect(edges.isEmpty)
        #expect(jogs.isEmpty)
        herculesMixPacket([0x80, 3, 0, 0xB2, 10, 127, 0xB1, 10, 1], to: input)
        input.flushPendingActions()
        #expect(edges.count == 2 && Set(edges) == Set([.jogB, .jogA]))
        #expect(jogs.first { $0.0.action == .jogB }?.0 == .init(.jogB, deck: .b, argument: 248))
        #expect(jogs.first { $0.0.action == .jogB }?.1 == -1)
        #expect(jogs.first { $0.0.action == .jogA }?.0 == .init(.jogA, deck: .a, argument: 248))
        #expect(jogs.first { $0.0.action == .jogA }?.1 == 1)
    }
}

@Test @MainActor func controllerCatalogueHerculesMixKeepsNormalTouchRimAndCoreControlsSeparate() {
    withHerculesMix { input, _ in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        input.onJogAction = { target, _ in targets.append(target) }
        herculesMixPacket([0x91, 8, 127, 0xB1, 10, 1, 0x81, 8, 0, 0xB2, 9, 127], to: input)
        input.flushPendingActions()
        #expect(
            targets == [
                .init(.jogTouchA, deck: .a), .init(.jogA, deck: .a, argument: 248),
                .init(.jogTouchA, deck: .a), .init(.wheelJogB, deck: .b, argument: 248),
            ])
        targets.removeAll()
        herculesMixPacket([0x91, 7, 127, 0x92, 5, 127, 0x96, 0, 127, 0x97, 3, 127], to: input)
        #expect(
            targets == [
                .init(.playA, deck: .a), .init(.syncB, deck: .b),
                .init(.hotcue1A, deck: .a), .init(.hotcue4B, deck: .b),
            ])
        targets.removeAll()
        herculesMixPacket([0x91, 3, 127, 0x94, 12, 127, 0x95, 12, 127], to: input)
        input.flushPendingActions()
        #expect(targets.isEmpty)
    }
}
