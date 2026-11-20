import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let reviewedLegacyLampNames = ["DJ-Tech DRAGON TWO", "DJ-Tech 4MIX", "Gemini GMX"]

@Test(arguments: reviewedLegacyLampNames) @MainActor
func controllerCatalogueReviewedLegacyLampsKeepOwnNotesTargetsAndValues(name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let lamps = p.feedback(destination: 20)
    let gmx = name == "Gemini GMX", dragon = name == "DJ-Tech DRAGON TWO"
    #expect(lamps.count == (gmx ? 8 : dragon ? 32 : 28))
    #expect(Set(lamps.map(\.id)).count == lamps.count)
    for lamp in lamps {
        let deck = try #require(lamp.targetDeck)
        let index = try #require(DeckID.allCases.firstIndex(of: deck))
        #expect(lamp.channel == UInt8(index + (gmx ? 0 : 1)))
        let base = String(lamp.action.rawValue.dropLast())
        let basic: [String: UInt8] =
            gmx
            ? ["play": 1, "cuePreview": 2, "keylock": 19, "cue": 34]
            : dragon
                ? ["play": 23, "cuePreview": 22, "sync": 16, "cue": 9] : ["play": 12, "cuePreview": 11, "sync": 5]
        if let n = basic[base] {
            #expect(lamp.number == n)
        } else {
            let slot = try #require(lamp.action.hotcueSlot)
            #expect(!gmx && slot < 4 && lamp.number == UInt8((dragon ? 17 : 6) + slot))
        }
        #expect(lamp.isValid && lamp.kind == .note && lamp.destination == 20)
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
        #expect(lamp.message(value: Double.nan) == nil)
    }
}

@Test(arguments: reviewedLegacyLampNames) @MainActor
func controllerCatalogueReviewedLegacyLampsMatchFullAndCompiledResources(name: String) throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let reviewed = try JSONDecoder().decode(
        ControllerProfileCatalogue.self,
        from: Data(
            contentsOf: root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json")))
    let full = try #require(reviewed.profiles.first { $0.id == name })
    let compact = try #require(ControllerProfileCatalogue.shared.profiles.first { $0.id == name })
    #expect(full.outputs.map { $0.binding(destination: 20) } == compact.outputs.map { $0.binding(destination: 20) })
}

@Test(arguments: reviewedLegacyLampNames) @MainActor
func controllerCatalogueReviewedLegacyLampsNeedExplicitOutputAndEnablement(name: String) throws {
    let suite = "legacy-lamps-\(UUID().uuidString)"; let prefs = UserDefaults(suiteName: suite)!
    defer { prefs.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: prefs,
        factoryPacketSender: { _, _ in
            Issue.record("Manual lamp selection must not run hardware setup."); return false
        }, factoryInputConnector: { _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles(); #expect(!input.isInputActive(10) && !input.midiFeedbackEnabled)
    let p = try #require(ControllerFactoryProfile.matching([name])); input.select(10); input.applyFactoryProfile(p)
    #expect(input.selectedFeedbackBindings.isEmpty && !input.midiFeedbackEnabled)
    input.setFeedbackDestination(20); input.applyFactoryFeedbackProfile(p)
    #expect(input.selectedFeedbackBindings == p.feedback(destination: 20))
    #expect(!input.midiFeedbackEnabled)
}
