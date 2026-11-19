import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMK4(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "hercules-mk4-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [10, 11].map { id in
        .init(
            id: id, reference: UInt32(id + 100), name: "DJ Console Mk4",
            identity: .init(id: id, device: UInt32(id), names: ["DJ Console Mk4"]))
    }
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && !input.isInputActive(11))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["DJ Console Mk4"])))
    #expect(input.bindingCount == 38)
    try body(input)
}

@MainActor private func mk4Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMK4TransportAndHeldReleasesKeepFactoryDeckAddresses() throws {
    try withMK4 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (side, deck) in DeckID.primary.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [
                (15, .playA), (14, .cuePreviewA), (18, .syncA), (16, .cueA), (17, .loadA), (10, .pitchBendDownA),
                (11, .pitchBendUpA),
            ] {
                for off: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    let note = number + UInt8(side * 20)
                    mk4Packet([0x90, note, 127, note, 127, off, note, off == 0x80 ? 127 : 0], to: input)
                    #expect(events.count == (action.isMomentary ? 2 : 1))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    if action.isMomentary { #expect(events.map(\.1) == [1, 0]) }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueMK4LoopsUseNativeFixedSizesAndOtherKBankStaysInactive() throws {
    try withMK4 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in if !target.action.isJog { events.append(target) } }
        for (side, deck) in DeckID.primary.enumerated() {
            for (slot, beats) in [1.0, 2, 4, 8].enumerated() {
                events.removeAll()
                let number = UInt8(1 + slot + side * 20)
                mk4Packet([0x90, number, 127, number, 0], to: input)
                #expect(events.count == 1)
                #expect(
                    events.first
                        == .init(ControllerAction.toggleFixedLoopA.assigned(to: deck), deck: deck, argument: beats))
            }
        }
        events.removeAll()
        for note: UInt8 in [5, 6, 7, 8, 9, 12, 13, 19, 20, 25, 26, 27, 28, 29, 32, 33, 39, 40, 43, 44, 45, 46] {
            mk4Packet([0x90, note, 127, note, 0], to: input)
        }
        mk4Packet([0x91, 15, 127, 0xB1, 52, 127, 0xB0, 127, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMK4MixerKeepsIndependentWorkingSourceDirectionAndPickup() throws {
    try withMK4 { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (side, deck) in DeckID.primary.enumerated() {
            for (offset, action) in [ControllerAction.levelA, .highA, .midA, .lowA].enumerated() {
                events.removeAll()
                let number = UInt8(52 + side * 5 + offset)
                mk4Packet([0xB0, number, 0], to: input)
                #expect(events.isEmpty)
                mk4Packet([0xB0, number, 64], to: input)
                mk4Packet([0xB0, number, 127], to: input)
                #expect(events.map(\.1) == [64.0 / 127, 1])
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
        for (number, action): (UInt8, ControllerAction) in [(56, .crossfader), (61, .cueMix)] {
            events.removeAll()
            mk4Packet([0xB0, number, 64], to: input)
            mk4Packet([0xB0, number, 0], to: input)
            #expect(events.map(\.1) == [64.0 / 127, 0])
            #expect(events.allSatisfy { $0.0.action == action })
        }
        events.removeAll()
        mk4Packet([0x90, 41, 127, 41, 0, 42, 127, 42, 0], to: input)
        #expect(events.map { $0.0.action } == [.browsePrevious, .browseNext])
    }
}

@Test @MainActor func controllerCatalogueMK4RelativePitchAndSensorlessWheelsKeepSignedMagnitude() throws {
    try withMK4 { input in
        input.currentTargetValue = { _ in 0.5 }
        var pitches: [(ControllerActionTarget, Double)] = []
        var wheels: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if target.action == .tempoA || target.action == .tempoB { pitches.append((target, value)) }
        }
        input.onJogAction = { target, value in if case .relative(let counts) = value { wheels.append((target, counts)) }
        }
        for (side, deck) in DeckID.primary.enumerated() {
            pitches.removeAll(); wheels.removeAll()
            let pitch = UInt8(50 + side), wheel = UInt8(48 + side)
            mk4Packet([0xB0, pitch, 0], to: input)
            #expect(pitches.isEmpty)
            mk4Packet([0xB0, pitch, 1], to: input)
            mk4Packet([0xB0, pitch, 127], to: input)
            #expect(pitches.map(\.1) == [0.5 + 1.0 / 127, 0.5 - 1.0 / 127])
            #expect(pitches.allSatisfy { $0.0 == .init(ControllerAction.tempoA.assigned(to: deck), deck: deck) })
            mk4Packet([0xB0, wheel, 1], to: input)
            mk4Packet([0xB0, wheel, 127], to: input)
            #expect(wheels.map(\.1) == [1, -1])
            #expect(
                wheels.allSatisfy {
                    $0.0 == .init(ControllerAction.wheelJogA.assigned(to: deck), deck: deck, argument: 128)
                })
        }
        pitches.removeAll(); wheels.removeAll()
        input.select(11)
        mk4Packet([0xB0, 50, 1, 48, 1], to: input, source: 11)
        #expect(pitches.isEmpty && wheels.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMK4ManualFeedbackHasOnlyExplicitFactoryLampsAndNoLifecycle() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJ Console Mk4"]))
    #expect(!profile.selectsAutomatically)
    #expect(profile.definition?.startup.isEmpty == true && profile.definition?.shutdown.isEmpty == true)
    #expect(profile.definition?.audioOutput == nil)
    let lights = profile.feedback(destination: 20)
    #expect(lights.count == 8)
    #expect(Set(lights.map(\.number)) == [14, 15, 16, 18, 34, 35, 36, 38])
    for light in lights {
        #expect(light.message(value: 1) == [0x90, light.number, 127])
        #expect(light.message(value: 0) == [0x90, light.number, 0])
    }
    for other in ["DJ Console 4-Mx", "DJ Console RMX", "DJ Console MK2"] {
        #expect(ControllerFactoryProfile.matching([other]) != profile)
    }
}
