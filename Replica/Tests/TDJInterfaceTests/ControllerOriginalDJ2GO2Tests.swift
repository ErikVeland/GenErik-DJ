import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withOriginalDJ2GO2(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original-dj2go2-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DJ2GO2 (DJ2GO2)"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func originalDJ2GO2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalDJ2GO2KeepsFactoryIdentityWithoutTouchQueryOrAudioRoute() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJ2GO2 (DJ2GO2)"], automaticOnly: true))
    #expect(profile.rawValue == "Numark DJ2GO2")
    #expect(profile != ControllerFactoryProfile.matching(["DJ2GO2 Touch MIDI"], automaticOnly: true))
    #expect(ControllerFactoryProfile.matching(["DJ2GO2", "DJ2GO2 Touch MIDI"], automaticOnly: true) == nil)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 43 && data.outputs.count == 16)
    #expect(data.startup.count == 16 && data.startup == data.shutdown)
    #expect(data.startup.allSatisfy { $0.count == 3 && $0[0] >= 0x90 && $0[0] < 0xA0 && $0[2] == 0 })
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(!data.inputs.contains { $0.action == .jogTouchA || $0.action == .jogTouchB })
    let light = try #require(profile.feedback(destination: 20).first { $0.action == .hotcue4B })
    #expect(light.message(value: 1) == [0x95, 4, 127])
    #expect(light.message(value: 0) == [0x95, 4, 0])
}

@Test @MainActor func controllerCatalogueOriginalDJ2GO2KeepsBothCueReleaseFormsAndDirectLoadEdges() {
    withOriginalDJ2GO2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        originalDJ2GO2Packet([0x90, 1, 127, 1, 0, 1, 127, 0x80, 1, 127, 0x91, 1, 127, 1, 0], to: input)
        #expect(
            events.map { $0.0.action } == [
                .cuePreviewA, .cuePreviewA, .cuePreviewA, .cuePreviewA, .cuePreviewB, .cuePreviewB,
            ])
        #expect(events.map { $0.1 } == [1, 0, 1, 0, 1, 0])
        events.removeAll()
        originalDJ2GO2Packet([0x9F, 2, 127, 2, 127, 3, 127], to: input)
        #expect(events.map { $0.0.action } == [.loadA, .loadB])
    }
}

@Test @MainActor func controllerCatalogueOriginalDJ2GO2UsesFactorySignedEncodersWithoutTouchCalibration() {
    withOriginalDJ2GO2 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var events: [ControllerActionTarget] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, _ in events.append(target) }
        originalDJ2GO2Packet([0x90, 6, 127, 0x91, 6, 127, 0xB0, 6, 0], to: input)
        #expect(jogs.isEmpty && events.isEmpty)
        originalDJ2GO2Packet([0xB0, 6, 1], to: input)
        #expect(jogs.last?.0.action == .wheelJogA && jogs.last?.1 == .relative(1))
        #expect(jogs.last?.0.argument == nil)
        originalDJ2GO2Packet([0xB1, 6, 127], to: input)
        #expect(jogs.last?.0.action == .wheelJogB && jogs.last?.1 == .relative(-1))
        originalDJ2GO2Packet([0xB0, 6, 64], to: input)
        #expect(jogs.last?.1 == .relative(-64))
        originalDJ2GO2Packet([0xBF, 0, 1], to: input)
        #expect(events == [.init(.browse)])
    }
}

@Test @MainActor func controllerCatalogueOriginalDJ2GO2RetainsPhysicalGainPitchAndBrowseMeanings() {
    withOriginalDJ2GO2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { events.append(($0, $1)) }
        originalDJ2GO2Packet([0xB0, 9, 0], to: input)
        #expect(events.isEmpty)
        originalDJ2GO2Packet([0xB0, 9, 64, 9, 127], to: input)
        #expect(events.last?.0.action == .tempoA && events.last?.1 == 1)
        events.removeAll()
        originalDJ2GO2Packet([0xB0, 22, 127, 0xB1, 22, 0, 9, 0, 0xBF, 8, 0, 10, 127, 12, 127, 0x9F, 6, 127], to: input)
        #expect(
            Set(events.map { $0.0.action }) == [.gainA, .gainB, .tempoB, .crossfader, .master, .monitor, .openGroup])
        #expect(!events.contains { $0.0.action == .levelA || $0.0.action == .filterKnobA })
    }
}

@Test @MainActor func controllerCatalogueOriginalDJ2GO2KeepsFactoryPadPagesAndBlocksSamplerRetrigger() {
    withOriginalDJ2GO2 { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        originalDJ2GO2Packet([0x94, 1, 127, 17, 127, 18, 127, 19, 127, 20, 127, 33, 127, 34, 127, 35, 127], to: input)
        #expect(
            events.map(\.action) == [
                .hotcue1A, .toggleFixedLoopA, .toggleFixedLoopA, .toggleFixedLoopA, .toggleFixedLoopA, .loopInA,
                .loopOutA, .loopA,
            ])
        #expect(events.filter { $0.action == .toggleFixedLoopA }.compactMap(\.argument) == [1, 2, 4, 8])
        events.removeAll()
        originalDJ2GO2Packet([0x95, 4, 127, 35, 127], to: input)
        #expect(events.map(\.action) == [.hotcue4B, .loopB])
        events.removeAll()
        originalDJ2GO2Packet(
            [0x94, 36, 127, 49, 127, 50, 127, 51, 127, 52, 127, 0x95, 36, 127, 49, 127, 50, 127, 51, 127, 52, 127],
            to: input)
        #expect(events.isEmpty)
    }
}
