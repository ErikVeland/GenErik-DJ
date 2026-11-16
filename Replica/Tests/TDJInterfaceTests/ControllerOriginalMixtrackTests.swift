import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalMixtrack(_ name: String, body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original-mixtrack-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func originalMixtrackPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueOriginalMixtrackKeepsSharedChannelAndOriginalMixerAddresses() throws {
    for name in ["Numark MIXTRACK", "Mixtrack Pro"] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        let levels = profile.bindings(source: 10).filter { $0.action == .levelA || $0.action == .levelB }
        #expect(levels.map(\.number) == [8, 9])
        #expect(profile.bindings(source: 10).allSatisfy { $0.channel == 0 })
        withOriginalMixtrack(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            originalMixtrackPacket([0x90, 59, 127, 66, 127, 75, 127, 52, 127, 101, 127, 102, 127], to: input)
            #expect(
                targets == [
                    .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.loadA, deck: .a), .init(.loadB, deck: .b),
                    .init(.cueA, deck: .a), .init(.cueB, deck: .b),
                ])
        }
    }
    #expect(ControllerFactoryProfile.matching(["Mixtrack Pro clone"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["MIXTRACK"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueOriginalMixtrackRetainsSourceSpecificTempoDirectionAndExactCentre() {
    for (name, expected) in [("Numark MIXTRACK", [0.0, 64.0 / 127, 1.0]), ("Mixtrack Pro", [1.0, 0.5, 0.0])] {
        withOriginalMixtrack(name) { input in
            var amounts: [Double] = []
            input.onAction = { action, value in if action == .tempoA { amounts.append(value) } }
            for raw in [UInt8(0), 64, 127] {
                originalMixtrackPacket([0xB0, 13, raw], to: input)
                input.flushPendingActions()
            }
            #expect(amounts == expected)
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalMixtrackReversesTheCrossfaderAndRetainsSignedJog() {
    for name in ["Numark MIXTRACK", "Mixtrack Pro"] {
        withOriginalMixtrack(name) { input in
            var amounts: [(ControllerAction, Double)] = []
            input.onAction = { action, value in amounts.append((action, value)) }
            originalMixtrackPacket([0xB0, 10, 0, 24, 127, 8, 127, 9, 0], to: input)
            input.flushPendingActions()
            #expect(amounts.first { $0.0 == .crossfader }?.1 == 1)
            #expect(amounts.first { $0.0 == .jogB }?.1 == 0.375)
            #expect(amounts.first { $0.0 == .levelA }?.1 == 1)
            #expect(amounts.first { $0.0 == .levelB }?.1 == 0)
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalMixtrackPreservesTouchNotesAndFixedManualLoops() {
    for name in ["Numark MIXTRACK", "Mixtrack Pro"] {
        withOriginalMixtrack(name) { input in
            var values: [(ControllerActionTarget, Double)] = []
            input.onTargetAction = { target, value in values.append((target, value)) }
            originalMixtrackPacket([0x90, 78, 127, 77, 127, 83, 127, 87, 127, 88, 127, 0x80, 78, 0, 77, 0], to: input)
            #expect(
                values.map(\.0) == [
                    .init(.jogTouchA, deck: .a), .init(.jogTouchB, deck: .b), .init(.loopInA, deck: .a),
                    .init(.loopOutB, deck: .b), .init(.reloopB, deck: .b), .init(.jogTouchA, deck: .a),
                    .init(.jogTouchB, deck: .b),
                ])
            #expect(values.suffix(2).map(\.1) == [0, 0])
            let count = values.count
            originalMixtrackPacket([0x90, 97, 127, 98, 127, 89, 127, 93, 127], to: input)
            #expect(values.count == count)
        }
    }
}

@Test @MainActor func controllerCatalogueOriginalMixtrackRetainsHundredValueLightsAndNativeScratchSetup() throws {
    for name in ["Numark MIXTRACK", "Mixtrack Pro"] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.definition?.startup.contains([0x90, 72, 100]) == true)
        #expect(profile.definition?.startup.contains([0x90, 80, 100]) == true)
        let cue = try #require(profile.feedback(destination: 20).first { $0.action == .cueA })
        #expect(cue.message(value: 1) == [0x90, 101, 100])
        #expect(cue.message(value: 0) == [0x90, 101, 0])
    }
}
