import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withXSessionPro(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "xsession-pro-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "M-Audio Xsession pro"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func xSessionPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueXSessionProSelectsFactoryIdentityWithoutEvolutionAlias() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["M-Audio Xsession pro"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 22 && data.outputs.isEmpty)
    #expect(data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["Evolution X-Session"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["USB Audio Device"], automaticOnly: true) == nil)
    withXSessionPro { #expect($0.isInputActive(10)) }
}

@Test @MainActor func controllerCatalogueXSessionProKeepsCueReleasesSeparateFromPFLAndSearch() {
    withXSessionPro { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        xSessionPacket(
            [0x90, 58, 127, 44, 127, 70, 127, 0x80, 58, 64, 0x90, 59, 127, 45, 127, 69, 127, 59, 0], to: input)
        #expect(
            events.map { $0.0.action } == [
                .cuePreviewA, .cueA, .playA, .cuePreviewA, .cuePreviewB, .cueB, .playB, .cuePreviewB,
            ])
        #expect(events.map { $0.1 } == [1, 1, 1, 0, 1, 1, 1, 0])
        events.removeAll()
        xSessionPacket([0x90, 46, 127, 43, 127, 56, 127, 57, 127, 0x91, 70, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueXSessionProIgnoresInvertedCrossfaderDuplicateAndBalance() {
    withXSessionPro { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        xSessionPacket([0xB0, 17, 0, 20, 127, 32, 127], to: input)
        #expect(events.count == 1 && events.first?.0.action == .crossfader && events.first?.1 == 0)
        xSessionPacket([0xB0, 17, 127, 20, 0], to: input)
        #expect(events.count == 2 && events.last?.1 == 1)
    }
}

@Test @MainActor func controllerCatalogueXSessionProTempoHasExactCentreAndPickup() {
    withXSessionPro { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { events.append(($0, $1)) }
        xSessionPacket([0xB0, 12, 0], to: input)
        #expect(events.isEmpty)
        xSessionPacket([0xB0, 12, 64], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 0.5)
        xSessionPacket([0xB0, 12, 127], to: input)
        #expect(events.last?.1 == 0)
    }
}
