import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withClassicNumark(_ model: String, body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "classic-numark-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Numark \(model) Control"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func classicNumarkPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueClassicNumarkSelectsOnlyExactModelsAndRetainsCoreBindings() throws {
    for model in ["Total", "Omni"] {
        let name = "Numark \(model) Control"
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        let data = try #require(profile.definition)
        #expect(data.inputs.count == 31)
        #expect(data.startup.isEmpty)
        #expect(data.shutdown.count == 6)
        #expect(!data.inputs.contains { $0.action == .jogTouchA || $0.action == .cueReturnA })
        #expect(profile.feedback(destination: 20).count == 6)
        withClassicNumark(model) { input in
            #expect(input.isInputActive(10))
            var actions: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in actions.append(target) }
            classicNumarkPacket([0x90, 67, 127, 76, 127, 75, 127, 52, 127, 48, 127, 55, 127], to: input)
            #expect(
                actions == [
                    .init(.playA, deck: .a), .init(.playB, deck: .b), .init(.loadA, deck: .a),
                    .init(.loadB, deck: .b), .init(.cueA, deck: .a), .init(.cueB, deck: .b),
                ])
        }
    }
    #expect(ControllerFactoryProfile.matching(["Numark Control"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["Numark Total Control 2"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueClassicNumarkKeepsOppositeWheelAddressesAndAllCounts() {
    for (model, left, right) in [("Total", UInt8(25), UInt8(24)), ("Omni", 24, 25)] {
        withClassicNumark(model) { input in
            var counts: [ControllerAction: Double] = [:]
            input.onJogAction = { target, motion in
                #expect(target.argument == 128)
                if case .relative(let value) = motion { counts[target.action] = value }
            }
            classicNumarkPacket([0xB0, left, 63, left, 1, right, 127], to: input)
            input.flushPendingActions()
            #expect(counts[.wheelJogA] == 64)
            #expect(counts[.wheelJogB] == -1)
        }
    }
}

@Test @MainActor func controllerCatalogueClassicNumarkKeepsBrowserPitchDirectionAndUnmappedModes() {
    for model in ["Total", "Omni"] {
        withClassicNumark(model) { input in
            var values: [(ControllerAction, Double)] = []
            input.onAction = { action, value in values.append((action, value)) }
            classicNumarkPacket([0xB0, 26, 127, 11, 0], to: input)
            input.flushPendingActions()
            #expect(values.first { $0.0 == .browse }?.1 == 0.5 - 1.0 / 126)
            #expect(values.first { $0.0 == .tempoA }?.1 == 1)
            values.removeAll()
            classicNumarkPacket([0x90, 50, 127, 72, 127, 49, 127, 73, 127, 74, 127], to: input)
            input.flushPendingActions()
            #expect(values.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueClassicNumarkUsesPublishedOutputAddresses() throws {
    for model in ["Total", "Omni"] {
        let profile = try #require(ControllerFactoryProfile.matching(["Numark \(model) Control"]))
        let play = try #require(profile.feedback(destination: 20).first { $0.target.action == .playA })
        #expect(play.message(value: 1) == [0x90, 62, 100])
        #expect(play.message(value: 0) == [0x90, 62, 0])
        #expect(profile.definition?.shutdown.contains([0x90, 62, 0]) == true)
        #expect(profile.definition?.shutdown.allSatisfy { $0.count == 3 && $0[0] == 0x90 && $0[2] == 0 } == true)
    }
}

@Test @MainActor func controllerCatalogueClassicNumarkCuePreviewRetainsPressAndReleaseEdges() {
    for model in ["Total", "Omni"] {
        withClassicNumark(model) { input in
            var events: [(ControllerAction, Double)] = []
            input.onAction = { action, value in events.append((action, value)) }
            classicNumarkPacket([0x90, 51, 127, 60, 127, 0x80, 51, 0, 60, 0], to: input)
            #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewB, .cuePreviewA, .cuePreviewB])
            #expect(events.map(\.1) == [1, 1, 0, 0])
        }
    }
}
