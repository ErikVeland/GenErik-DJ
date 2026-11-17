import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMix101(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "mix101-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Mix-101 MIDI 1"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func mix101Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMix101KeepsManualModesAndDistinctPlayLightAddress() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Mix-101 MIDI 1"]))
    #expect(ControllerFactoryProfile.matching(["Mix-101 MIDI 1"], automaticOnly: true) == nil)
    #expect(profile != ControllerFactoryProfile.matching(["DJ-Tech DJM-101"]))
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 22 && data.outputs.count == 4)
    #expect(data.startup.count == 4 && data.shutdown.count == 4)
    #expect(data.inputs.first { $0.action == .playA }?.number == 9)
    #expect(profile.feedback(destination: 20).first { $0.action == .playA }?.message(value: 1) == [0x90, 10, 127])
    #expect(
        !data.inputs.contains {
            $0.action.hotcueSlot != nil || [.loadA, .loadB, .jogTouchA, .jogTouchB].contains($0.action)
        })
}

@Test @MainActor func controllerCatalogueMix101FastEncodersAccumulateFromCurrentValuesAndClamp() throws {
    try withMix101 { input in
        var values: [ControllerAction: Double] = [.master: 0.5, .monitor: 0.25]
        var events: [(ControllerAction, Double)] = []
        input.currentTargetValue = { values[$0.action] }
        input.onTargetAction = { target, value in
            values[target.action] = value; events.append((target.action, value))
        }
        mix101Packet([0xB0, 16, 65, 16, 66, 16, 63, 18, 63], to: input)
        #expect(abs((values[.monitor] ?? -1) - (0.25 + 3.0 / 127)) < 0.0000001)
        #expect(abs((values[.master] ?? -1) - (0.5 - 1.5 / 127)) < 0.0000001)
        #expect(events.count == 2)
        values[.monitor] = 0.99
        values[.master] = 0.01
        mix101Packet([0xB0, 16, 127, 18, 0], to: input)
        #expect(values[.monitor] == 1 && values[.master] == 0)
        let count = events.count
        mix101Packet([0xB0, 16, 64, 18, 64], to: input)
        #expect(events.count == count)
        values[.master] = .nan
        mix101Packet([0xB0, 18, 65], to: input)
        #expect(events.count == count)
    }
}

@Test @MainActor func controllerCatalogueMix101CueReleasesAndSourceWheelDirectionsStaySeparate() throws {
    try withMix101 { input in
        var events: [(ControllerAction, Double)] = []
        var jogs: [(ControllerAction, ControllerMIDIValue)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        input.onJogAction = { jogs.append(($0.action, $1)) }
        mix101Packet([0x90, 3, 127, 3, 0, 4, 127, 0x80, 4, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewA, .cuePreviewB, .cuePreviewB])
        #expect(events.map(\.1) == [1, 0, 1, 0])
        mix101Packet([0xB0, 19, 65, 21, 63], to: input)
        #expect(jogs.contains { $0.0 == .wheelJogA && $0.1 == .relative(1) })
        #expect(jogs.contains { $0.0 == .wheelJogB && $0.1 == .relative(-1) })
        let count = events.count
        mix101Packet([0x90, 11, 127, 12, 127, 13, 127, 0xB1, 16, 65], to: input)
        #expect(events.count == count)
    }
}

@Test func controllerCatalogueMix101FastEncoderFactoryValidationLimitsActionAndWireKind() throws {
    func valid(_ action: String, _ kind: String) throws -> Bool {
        let data = Data(
            """
            {"id":"fast-test","aliases":["fast-test"],"inputs":[
            {"action":"\(action)","kind":"\(kind)","channel":0,"number":16,"encoding":"rot64Fast","inverted":false}],
            "outputs":[],"startup":[],"shutdown":[],"autoSelect":false,"scope":"test","source":"test"}
            """.utf8)
        return try JSONDecoder().decode(ControllerProfileData.self, from: data).isValid
    }
    #expect(try valid("master", "control"))
    #expect(try valid("monitor", "control"))
    #expect(try !valid("master", "note"))
    #expect(try !valid("playA", "control"))
    #expect(try !valid("jogA", "control"))
}
