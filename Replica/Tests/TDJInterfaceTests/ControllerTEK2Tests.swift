import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withTEK2(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "tek2-preset-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "TEK2"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func tek2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test func controllerCatalogueTEK2RequiresExplicitPresetAndInventsNoOtherKeysOrAudio() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["TEK2"]))
    #expect(ControllerFactoryProfile.matching(["TEK2"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["Intech Grid"]) != profile)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 10 && data.outputs.isEmpty)
    #expect(data.startup.isEmpty && data.shutdown.isEmpty)
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(data.inputs.filter { $0.requiresTouch == true }.map(\.argument) == [100, 100])
    #expect(data.inputs.filter { [.wheelJogA, .wheelJogB].contains($0.action) }.map(\.argument) == [160, 160])
}

@Test @MainActor func controllerCatalogueTEK2FullVelocityTouchGatesOnlyTheIntendedScratchPath() throws {
    try withTEK2 { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        tek2Packet([0x90, 40, 126, 0xB0, 8, 65], to: input)
        #expect(jogs.map { $0.0.action } == [.wheelJogA])
        #expect(jogs.first?.1 == .relative(1))
        jogs.removeAll()
        tek2Packet([0x90, 40, 127, 0xB0, 8, 66, 9, 63], to: input)
        #expect(jogs.contains { $0.0 == .init(.jogA, deck: .a, argument: 100) && $0.1 == .relative(2) })
        #expect(!jogs.contains { $0.0.action == .jogB })
        #expect(jogs.contains { $0.0.action == .wheelJogB && $0.1 == .relative(-1) })
        jogs.removeAll()
        tek2Packet([0x80, 40, 127, 0xB0, 8, 63], to: input)
        #expect(jogs.filter { $0.0.action == .jogA }.allSatisfy { $0.1 == .absolute(0.5) })
        #expect(jogs.contains { $0.0.action == .wheelJogA && $0.1 == .relative(-1) })
    }
}

@Test @MainActor func controllerCatalogueTEK2CueReleasesAndUnmappedBottomKeysStayIndependent() throws {
    try withTEK2 { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        tek2Packet([0x90, 32, 127, 33, 127, 33, 0, 34, 127, 35, 127, 0x80, 35, 127], to: input)
        #expect(events.map(\.0) == [.playA, .cuePreviewA, .cuePreviewA, .playB, .cuePreviewB, .cuePreviewB])
        #expect(events.map(\.1) == [1, 1, 0, 1, 1, 0])
        let count = events.count
        tek2Packet([0x90, 36, 127, 37, 127, 38, 127, 39, 127, 0x91, 33, 127], to: input)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 33, value: 127), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 33, value: 127), source: 11)
        input.flushPendingActions()
        #expect(events.count == count)
    }
}
