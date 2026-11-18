import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withInpulse200MK2(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "inpulse200mk2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, deckAvailability: { DeckID.allCases })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "DJControl Inpulse 200 Mk2",
            identity: .init(id: 10, device: 1, names: ["DJControl Inpulse 200 Mk2"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func inpulse200Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueInpulse200MK2UsesSeparateIdentityAndTwoBandEQ() throws {
    try withInpulse200MK2 { input in
        #expect(input.isInputActive(10))
        let profile = try #require(
            ControllerFactoryProfile.matching(["DJControl Inpulse 200 MK2"], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == 57 && data.outputs.count == 16)
        #expect(data.startup.isEmpty && data.shutdown.isEmpty)
        #expect(!data.inputs.contains { $0.action == .midA || $0.action == .midB })
        #expect(ControllerFactoryProfile.matching(["DJControl Inpulse 200"]) != profile)
        #expect(ControllerFactoryProfile.matching(["DJControl Inpulse 200 MK3"]) == nil)
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        inpulse200Packet([0x91, 7, 127, 13, 127, 0x92, 12, 127, 0xB1, 5, 100, 4, 127, 2, 0], to: input)
        #expect(Set(events.map(\.action)) == [.playA, .loadA, .cueB, .gainA, .highA, .lowA])
    }
}

@Test @MainActor func controllerCatalogueInpulse200MK2ShiftedPadReleaseRearmsNormalHotCueWithoutDelete() {
    for trueNoteOff in [false, true] {
        for releaseShiftFirst in [false, true] {
            withInpulse200MK2 { input in
                var cues = 0
                input.onTargetAction = { target, _ in if target.action == .hotcue1A { cues += 1 } }
                inpulse200Packet([0x96, 0, 127, 0, 127, 0x91, 4, 127, 0x96, 8, 127], to: input)
                #expect(cues == 1)
                if releaseShiftFirst { inpulse200Packet([0x81, 4, 0], to: input) }
                inpulse200Packet([trueNoteOff ? 0x86 : 0x96, 8, 0], to: input)
                if !releaseShiftFirst { inpulse200Packet([0x81, 4, 0], to: input) }
                inpulse200Packet([0x96, 0, 127, 0, 0], to: input)
                #expect(cues == 2)
            }
        }
    }
}

@Test @MainActor func controllerCatalogueInpulse200MK2KeepsCueReleaseAndPadModesSeparate() {
    withInpulse200MK2 { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { target, value in events.append((target.action, value)) }
        inpulse200Packet([0x91, 6, 127, 4, 127, 6, 0, 7, 127, 0x96, 0, 127, 8, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewA])
        #expect(events.map(\.1) == [1, 0])
        inpulse200Packet([0x96, 16, 127, 32, 127, 48, 127, 0x90, 1, 127, 3, 127], to: input)
        #expect(events.count == 2)
        inpulse200Packet([0x94, 9, 127, 10, 127, 0x81, 4, 0, 0x91, 6, 127, 0x81, 6, 0], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewA, .loopDownA, .loopUpA, .cuePreviewA, .cuePreviewA])
    }
}

@Test @MainActor func controllerCatalogueInpulse200MK2GuardsTempoAndRearmsPickupAfterShift() {
    withInpulse200MK2 { input in
        var tempos: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { tempos.append(value) } }
        inpulse200Packet([0xB1, 8, 0], to: input)
        #expect(tempos.isEmpty)
        inpulse200Packet([0xB1, 8, 64], to: input)
        #expect(tempos == [0.5])
        inpulse200Packet([0x91, 4, 127, 0xB1, 8, 127, 0x81, 4, 0, 0xB1, 8, 127], to: input)
        #expect(tempos == [0.5])
        inpulse200Packet([0xB1, 8, 64], to: input)
        inpulse200Packet([0xB1, 8, 127], to: input)
        #expect(tempos == [0.5, 0.5, 0])
    }
}

@Test @MainActor func controllerCatalogueInpulse200MK2UsesSourceJogDirectionsAndGuardsUnknownShiftScale() {
    withInpulse200MK2 { input in
        var jogs: [ControllerMIDIValue] = []
        input.onJogAction = { _, value in jogs.append(value) }
        inpulse200Packet([0xB1, 10, 1], to: input)
        inpulse200Packet([0xB2, 9, 127], to: input)
        inpulse200Packet([0x91, 4, 127, 0xB1, 10, 1, 0xB4, 9, 1], to: input)
        #expect(jogs == [.relative(1), .relative(-1)])
    }
}
