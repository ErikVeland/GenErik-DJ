import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func controllerCatalogueTempoEndpointsUseNativeDirectionForReviewedAndConvertedProfiles() throws {
    for name in [
        "Mixtrack Pro FX", "Mixtrack Platinum FX", "Mixtrack 3", "Mixtrack Pro 3", "Mixtrack Platinum",
        "Hercules DJControl Inpulse 200",
    ] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        let binding = try #require(profile.bindings(source: 10).first { $0.action == .tempoB && $0.targetDeck == .b })
        #expect(binding.inverted == name.hasPrefix("Hercules"))
        let suite = "tempo-polarity-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
        input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
        input.destinations = [
            .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))
        ]
        input.reconcileFactoryProfiles()
        var values: [Double] = []
        input.onTargetAction = { target, value in if target.action == .tempoB { values.append(value) } }
        for raw: UInt8 in [0, 127] {
            var bytes = [0xB0 | binding.channel, binding.number, raw]
            if let low = binding.lowControllerNumber { bytes += [low, raw] }
            var decoder = ControllerMIDIDecoder()
            for message in decoder.append(bytes) { input.receive(message, source: 10) }
            input.flushPendingActions()
        }
        #expect(values == (name.hasPrefix("Hercules") ? [1, 0] : [0, 1]))
    }
}
