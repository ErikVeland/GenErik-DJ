import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withFixedMixer(
    _ name: String, decks: [DeckID] = DeckID.allCases, _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "fixed-mixer-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true }, deckAvailability: { decks })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func fixedMixerPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueFixedMixersKeepSeparateNamedIdentitiesAndNoUnqualifiedOutput() throws {
    for (name, count) in [("SMC-Mixer", 25), ("iControls", 26)] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == count && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
        #expect(!profile.hasAutomaticSplitOutput)
        #expect(
            !data.inputs.contains { [.playA, .playB, .cuePreviewA, .cuePreviewB, .loadA, .loadB].contains($0.action) })
        for other in ["iControls Pro", "SMK-25 II", "USB MIDI", name == "iControls" ? "SMC-Mixer" : "iControls"] {
            #expect(ControllerFactoryProfile.matching([other], automaticOnly: true) != profile)
        }
    }
}

@Test @MainActor func controllerCatalogueFixedMixersUseEightPitchFadersAndKeepCDOptIn() {
    let order: [DeckID] = [.c, .a, .b, .d]
    for name in ["SMC-Mixer", "iControls"] {
        for decks in [DeckID.primary, DeckID.allCases] {
            withFixedMixer(name, decks: decks) { input in
                var events: [(ControllerActionTarget, Double)] = []
                input.onTargetAction = { events.append(($0, $1)) }
                for (strip, deck) in order.enumerated() {
                    for offset in [0, 4] {
                        events.removeAll()
                        fixedMixerPacket([0xE0 + UInt8(strip + offset), 127, 127], to: input)
                        if decks.contains(deck) {
                            let action: ControllerAction =
                                offset == 0
                                ? (strip == 0 || strip == 1 ? .levelA : .levelB)
                                : (strip == 0 || strip == 1 ? .tempoA : .tempoB)
                            #expect(events.count == 1 && events.first?.0 == .init(action, deck: deck))
                            #expect(events.first?.1 == (offset == 0 ? 1 : 0))
                        } else {
                            #expect(events.isEmpty)
                        }
                    }
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueFixedMixersKeepExactSourceEncoderDirectionAndMagnitude() {
    for name in ["SMC-Mixer", "iControls"] {
        withFixedMixer(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.currentTargetValue = { _ in 0.5 }
            input.onTargetAction = { events.append(($0, $1)) }
            for number: UInt8 in 16...19 {
                for raw: UInt8 in [0, 1, 2, 63, 64, 65, 127] {
                    events.removeAll()
                    fixedMixerPacket([0xB0, number, raw], to: input)
                    let counts =
                        name == "SMC-Mixer" ? (raw == 65 ? -1.0 : 1) : Double(raw <= 64 ? Int(raw) : Int(raw) - 128)
                    if counts == 0 {
                        #expect(events.isEmpty)
                    } else {
                        #expect(events.count == 1)
                        #expect(abs((events.first?.1 ?? -1) - min(1, max(0, 0.5 + counts / 100))) < 0.000001)
                    }
                }
            }
            if name == "iControls" {
                for number: UInt8 in 20...23 {
                    events.removeAll()
                    fixedMixerPacket([0xB0, number, 2], to: input)
                    #expect(events.first?.0.action == (number < 22 ? .filterKnobA : .filterKnobB))
                    #expect(abs((events.first?.1 ?? 0) - 0.52) < 0.000001)
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueFixedMixersKeepIndependentGlobalButtonsAndInactiveSharedModes() {
    for name in ["SMC-Mixer", "iControls"] {
        withFixedMixer(name) { input in
            var events: [(ControllerActionTarget, Double)] = []
            input.currentTargetValue = { _ in 0.5 }
            input.onTargetAction = { events.append(($0, $1)) }
            let first: UInt8 = name == "SMC-Mixer" ? 28 : 8
            for note in first...first + 3 {
                fixedMixerPacket([0x90, note, 127, note, 0, note, 127, 0x80, note, 127], to: input)
            }
            #expect(events.count == 8 && events.allSatisfy { [.cueA, .cueB].contains($0.0.action) })
            events.removeAll()
            if name == "SMC-Mixer" {
                for (number, action) in [(UInt8(20), ControllerAction.master), (22, .monitor), (23, .cueMix)] {
                    events.removeAll()
                    fixedMixerPacket([0xB0, number, 65], to: input)
                    #expect(events.first?.0.action == action)
                    #expect(abs((events.first?.1 ?? 0) - 0.49) < 0.000001)
                }
                events.removeAll()
                fixedMixerPacket([0x90, 96, 127, 97, 127], to: input)
                #expect(events.map { $0.0.action } == [.browsePrevious, .browseNext])
            } else {
                fixedMixerPacket([0xB0, 12, 64, 12, 127], to: input)
                #expect(events.last?.0.action == .master && events.last?.1 == 1)
                events.removeAll()
                fixedMixerPacket([0xE8, 0, 64, 127, 127], to: input)
                #expect(events.last?.0.action == .crossfader && events.last?.1 == 1)
            }
            events.removeAll()
            fixedMixerPacket([0x90, 94, 127, 93, 127, 48, 127, 49, 127, 0xB1, 16, 1, 0xE9, 127, 127], to: input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueFixedMixersRejectEncoderUseForButtonsJogAndForeignKinds() throws {
    for (name, encoding) in [("SMC-Mixer", "smcMixerEncoder"), ("iControls", "iconVelocity")] {
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json")
        let catalogue = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let profiles = try #require(catalogue["profiles"] as? [[String: Any]])
        var object = try #require(profiles.first { ($0["id"] as? String) == profile.rawValue })
        let inputs = try #require(object["inputs"] as? [[String: Any]])
        let index = try #require(inputs.firstIndex { ($0["encoding"] as? String) == encoding })
        for replacement in [["kind": "note"], ["action": "playA"], ["action": "jogA"]] {
            var changed = inputs
            changed[index].merge(replacement) { _, new in new }
            object["inputs"] = changed
            let invalid = try JSONDecoder().decode(
                ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: object))
            #expect(!invalid.isValid)
        }
    }
}
