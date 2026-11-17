import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withVCI100(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "original-vci100-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [
        .init(id: 10, reference: 100, name: "VCI-100", identity: .init(id: 10, device: 1, names: ["VCI-100"]))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func vci100Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueOriginalVCI100KeepsCueButtonsAndFirmwareIdentitiesSeparate() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["VCI-100"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 42 && data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(!profile.hasAutomaticSplitOutput)
    for variant in ["VCI-100 3DEX", "VCI-100-hile", "Vestax VCI-100 Hile Mod"] {
        #expect(ControllerFactoryProfile.matching(["VCI-100", variant], automaticOnly: true) == nil)
    }
    #expect(ControllerFactoryProfile.matching(["VCI-100MKII"], automaticOnly: true) != profile)
    withVCI100 { input in
        #expect(input.isInputActive(10))
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        vci100Packet(
            [
                0x90, 50, 127, 54, 127, 51, 127, 55, 127, 53, 127, 57, 127, 52, 127, 52, 0, 56, 127,
                0x80, 56, 127, 0x90, 96, 127, 97, 127, 92, 127, 93, 127, 98, 127, 99, 127, 100, 127,
            ], to: input)
        #expect(
            actions == [
                .playA, .playB, .cueGotoA, .cueGotoB, .cueSetA, .cueSetB,
                .cuePreviewA, .cuePreviewA, .cuePreviewB, .cuePreviewB, .loadA, .loadB, .browsePrevious, .browseNext,
            ])
    }
}

@Test @MainActor func controllerCatalogueOriginalVCI100RetainsSeparatePlatterAndRingDispatch() {
    withVCI100 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        var contacts: [Double] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        input.onTargetAction = { target, value in if target.action == .jogTouchA { contacts.append(value) } }
        vci100Packet([0xB0, 16, 65, 17, 65, 18, 65, 19, 63], to: input)
        #expect(Set(jogs.map { $0.0.action }) == [.wheelJogA, .wheelJogB])
        jogs.removeAll()
        vci100Packet([0x90, 48, 127, 0xB0, 16, 67, 17, 65, 0x80, 48, 127, 0xB0, 16, 65], to: input)
        #expect(contacts == [1, 0])
        #expect(jogs.count == 1 && jogs.first?.0.action == .jogA && jogs.first?.1 == .relative(3))
        #expect(jogs.allSatisfy { $0.0.argument == 518.4 })
    }
}

@Test func controllerCatalogueOriginalVCI100Normalises45RPMToNativeScratchTime() throws {
    let data = try #require(ControllerFactoryProfile.matching(["VCI-100"])?.definition)
    let resolution = try #require(data.inputs.first { $0.action == .jogA }?.argument)
    var motion = try #require(
        ControllerCountJogMotion(
            frame: 100, generation: 1, sampleRate: 1000,
            limit: 10000, resolution: resolution, time: 10))
    motion.move(counts: 384, time: 11)
    #expect(abs(motion.frame - (100 + 1000 * 60 / 45)) < 0.001)
}

@Test @MainActor func controllerCatalogueOriginalVCI100TempoKeepsCentrePolarityAndPickup() {
    withVCI100 { input in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        vci100Packet([0xB0, 14, 0], to: input)
        #expect(values.isEmpty)
        vci100Packet([0xB0, 14, 64], to: input)
        vci100Packet([0xB0, 14, 127], to: input)
        #expect(values == [0.5, 1])
    }
}

@Test @MainActor func controllerCatalogueOriginalVCI100DisconnectReleasesPitchButtons() {
    withVCI100 { input in
        var holds: [(ControllerAction, Double)] = []
        input.onTargetAction = { target, value in if target.action.isMomentary { holds.append((target.action, value)) }
        }
        vci100Packet([0x90, 58, 127, 61, 127], to: input)
        input.sources = []
        input.reconcileFactoryProfiles()
        #expect(holds.prefix(2).map { $0.0 } == [.pitchBendUpA, .pitchBendDownB])
        #expect(Set(holds.filter { $0.1 == 0 }.map { $0.0 }) == [.pitchBendUpA, .pitchBendDownB])
    }
}
