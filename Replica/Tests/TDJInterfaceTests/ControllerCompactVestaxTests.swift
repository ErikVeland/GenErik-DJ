import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withCompactVestax(
    _ name: String, _ body: (ControllerMIDIConnection, [[UInt8]]) throws -> Void
) rethrows {
    let suite = "compact-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes); return true
        })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input, packets)
}

@MainActor private func compactPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueCompactVestaxKeepsSeparateProfilesAndBoundedNativeSetup() throws {
    for (name, count) in [("Typhoon", 42), ("Spin", 36)] {
        try withCompactVestax(name) { input, packets in
            #expect(input.isInputActive(10))
            let profile = try #require(ControllerFactoryProfile.matching(["Vestax " + name], automaticOnly: true))
            let data = try #require(profile.definition)
            #expect(data.inputs.count == count && data.outputs.count == 8)
            #expect(packets.first == [0x90, 36, name == "Typhoon" ? 0 : 127])
            #expect(packets.count == (name == "Typhoon" ? 2 : 3))
            #expect(ControllerFactoryProfile.matching([name + " 2"]) != profile)
            #expect(!data.inputs.contains { [.master, .monitor, .cueMix].contains($0.action) })
        }
    }
}

@Test @MainActor func controllerCatalogueCompactVestaxKeepsDifferentLoopLayouts() {
    for name in ["Typhoon", "Spin"] {
        withCompactVestax(name) { input, _ in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            compactPacket([0x91, 32, 127, 33, 127, 66, 127], to: input)
            #expect(
                targets.map(\.action)
                    == (name == "Typhoon" ? [.loopB, .loopDownB, .loopUpB] : [.reloopB, .loopInB, .loopOutB]))
            #expect(targets.allSatisfy { $0.deck == .b })
            #expect(targets.first?.argument == (name == "Typhoon" ? 4 : nil))
        }
    }
}

@Test @MainActor func controllerCatalogueCompactVestaxKeepsPublishedJogDispatchAnd300CountScale() {
    for name in ["Typhoon", "Spin"] {
        withCompactVestax(name) { input, _ in
            var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
            input.onJogAction = { jogs.append(($0, $1)) }
            compactPacket([0xB0, 16, 65], to: input)
            compactPacket([0xB1, 16, 63], to: input)
            compactPacket([0xB0, 17, 65], to: input)
            #expect(jogs.count == (name == "Typhoon" ? 3 : 2))
            #expect(jogs.prefix(2).map(\.1) == [.relative(1), .relative(-1)])
            #expect(jogs.allSatisfy { $0.0.argument == 300 })
        }
    }
}

@Test @MainActor func controllerCatalogueCompactTyphoonHeldFilterGuardsOnlyItsJogAndPreservesRelease() {
    withCompactVestax("Typhoon") { input, _ in
        var targets: [(ControllerActionTarget, Double)] = []
        var jogs: [ControllerActionTarget] = []
        input.onTargetAction = { target, value in if !target.action.isJog { targets.append((target, value)) } }
        input.onJogAction = { target, _ in jogs.append(target) }
        compactPacket([0x90, 46, 127, 36, 127, 47, 0, 0xB0, 17, 65, 0xB1, 16, 65], to: input)
        #expect(targets.map(\.0) == [.init(.jogTouchA, deck: .a), .init(.jogTouchA, deck: .a)])
        #expect(targets.map(\.1) == [1, 0])
        #expect(jogs == [.init(.jogB, deck: .b, argument: 300)])
        compactPacket([0x80, 36, 0, 0xB0, 16, 65], to: input)
        #expect(jogs.last == .init(.jogA, deck: .a, argument: 300))
    }
}

@Test @MainActor func controllerCatalogueCompactVestaxTempoRetainsExactCentreAndPickup() {
    for name in ["Typhoon", "Spin"] {
        withCompactVestax(name) { input, _ in
            var tempos: [Double] = []
            input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
            input.onTargetAction = { target, value in if target.action == .tempoA { tempos.append(value) } }
            compactPacket([0xB0, 14, 127], to: input)
            #expect(tempos.isEmpty)
            compactPacket([0xB0, 14, 64], to: input)
            compactPacket([0xB0, 14, 127], to: input)
            #expect(tempos == [0.5, 1])
        }
    }
}

@Test @MainActor func controllerCatalogueCompactVestaxBrowseButtonsMoveOnceBeforeLoad() {
    for name in ["Typhoon", "Spin"] {
        withCompactVestax(name) { input, _ in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            compactPacket([0x92, 92, 127, 92, 127, 92, 0, 93, 127, 38, 127, 96, 127], to: input)
            #expect(
                targets == [
                    .init(.browsePrevious), .init(.browseNext), .init(.browseNextGroup), .init(.loadA, deck: .a),
                ])
            compactPacket([0x82, 92, 127, 0x92, 92, 127], to: input)
            #expect(targets.last == .init(.browsePrevious))
        }
    }
}

@Test func controllerBrowserStepActionsRetainOneSignedStepAndTheCorrectLibraryScope() {
    for (action, delta, groups) in [
        (ControllerAction.browsePrevious, -1, false), (.browseNext, 1, false), (.browsePreviousGroup, -1, true),
        (.browseNextGroup, 1, true),
    ] {
        #expect(action.isButton && !action.isMomentary && !action.isBrowserEncoder)
        #expect(action.browserStep?.detents == delta && action.browserStep?.groups == groups)
    }
    #expect(ControllerAction.browse.browserStep == nil)
}
