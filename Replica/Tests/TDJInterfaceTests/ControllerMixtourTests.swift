import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withMixtour(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "mixtour-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Mixtour"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func mixtourPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueMixtourKeepsProSeparateAndFactoryColours() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Mixtour"], automaticOnly: true))
    #expect(profile.rawValue == "Reloop Mixtour")
    #expect(ControllerFactoryProfile.matching(["Mixtour Pro"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["Mixtour", "Mixtour Pro"], automaticOnly: true) == nil)
    #expect(profile.hasAutomaticSplitOutput)
    let bindings = profile.bindings(source: 10)
    #expect(!bindings.contains { $0.action.isJog || $0.action == .tempoA || $0.action == .tempoB })
    let play = try #require(profile.feedback(destination: 20).first { $0.action == .playA })
    let hotcue = try #require(profile.feedback(destination: 20).first { $0.action == .hotcue4B })
    #expect(play.message(value: 1) == [0x90, 12, 64])
    #expect(play.message(value: 0) == [0x90, 12, 0])
    #expect(hotcue.message(value: 1) == [0x91, 16, 32])
    #expect(hotcue.message(value: 0) == [0x91, 16, 0])
}

@Test @MainActor func controllerCatalogueMixtourColdTransportAndCuePageKeepDistinctTargets() {
    withMixtour { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        mixtourPacket([0x90, 2, 127, 12, 127, 10, 127, 9, 127, 0x91, 2, 127, 12, 127], to: input)
        #expect(events.map(\.action) == [.loadA, .playA, .syncA, .loopA, .loadB, .playB])
        #expect(events.compactMap(\.deck) == [.a, .a, .a, .a, .b, .b])
        events.removeAll()
        for channel: UInt8 in 0...1 {
            for number: UInt8 in 13...16 { mixtourPacket([0x90 + channel, number, 90, number, 0], to: input) }
        }
        #expect(events.compactMap { $0.action.hotcueSlot } == [0, 1, 2, 3, 0, 1, 2, 3])
        #expect(events.compactMap(\.deck) == [.a, .a, .a, .a, .b, .b, .b, .b])
    }
}

@Test @MainActor func controllerCatalogueMixtourShiftedReleaseRearmsButtonsAndCannotStartCue() {
    withMixtour { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        mixtourPacket([0x90, 11, 127, 12, 127, 13, 127, 6, 127, 74, 127, 75, 127, 76, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .playA, .hotcue1A])
        mixtourPacket([0x90, 74, 0, 0x80, 75, 127, 76, 127, 0x90, 6, 0, 11, 127, 12, 127, 13, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .playA, .hotcue1A, .cuePreviewA, .cuePreviewA, .playA, .hotcue1A])
        #expect(events.filter { $0.0 == .cuePreviewA }.map(\.1) == [1, 0, 1])
    }
}

@Test @MainActor func controllerCatalogueMixtourHardwareModeChangeReleasesOnlyItsDeck() {
    withMixtour { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        mixtourPacket([0x90, 11, 127, 0x91, 11, 127, 0x90, 5, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .cuePreviewB, .cuePreviewA])
        #expect(events.map(\.1) == [1, 1, 0])
        mixtourPacket([0x91, 11, 0, 0x90, 11, 127], to: input)
        #expect(events.suffix(2).map(\.0) == [.cuePreviewB, .cuePreviewA])
        #expect(events.suffix(2).map(\.1) == [0, 1])
    }
}

@Test @MainActor func controllerCatalogueMixtourSignedBrowserDoesNotUseCentre64AndShiftGuardsMixerPickup() {
    withMixtour { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        input.currentTargetValue = { $0.action == .highA ? 0.5 : nil }
        mixtourPacket([0xB0, 7, 1], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        mixtourPacket([0xB0, 7, 127], to: input)
        #expect(events.last?.0 == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        mixtourPacket([0xB0, 1, 127], to: input)
        #expect(events.count == 2)
        mixtourPacket([0xB0, 1, 64], to: input)
        #expect(events.last?.0 == .highA)
        events.removeAll()
        mixtourPacket([0x90, 6, 127, 0xB0, 1, 127, 65, 127, 7, 1, 71, 1, 0x90, 6, 0, 0xB0, 1, 127], to: input)
        #expect(events.isEmpty)
        mixtourPacket([0xB0, 1, 64, 0xB4, 0, 80, 1, 100], to: input)
        #expect(Set(events.map(\.0)) == Set([.highA, .master, .monitor]))
    }
}

@Test @MainActor func controllerCatalogueMixtourShiftedLoopsRetainNormalDebounceAndUnsupportedInputsStayInactive() {
    withMixtour { input in
        var events: [ControllerAction] = []
        input.onTargetAction = { target, _ in events.append(target.action) }
        mixtourPacket(
            [0x90, 9, 127, 10, 127, 6, 127, 72, 127, 73, 127, 72, 0, 73, 0, 6, 0, 9, 127, 10, 127], to: input)
        #expect(events == [.loopA, .syncA, .loopDownA, .loopUpA, .loopA, .syncA])
        events.removeAll()
        mixtourPacket([0x90, 19, 127, 20, 127, 1, 127, 17, 127, 18, 127, 0xB0, 9, 1], to: input)
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 12, value: 127), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 12, value: 127), source: 11)
        input.flushPendingActions()
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueMixtourDemoHandshakeRequiresPairedOutputAndRepeatsOnlyAfterReconnect() throws {
    let suite = "mixtour-lifecycle-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var packets: [[UInt8]] = []
    var succeeds = false
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, id in
            #expect(id == 20)
            packets.append(bytes)
            return succeeds
        })
    let name = "Mixtour"
    let source = ControllerMIDIConnection.Source(
        id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))
    input.sources = [source]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10) && packets.isEmpty)
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    #expect(packets.first == [0xF0, 0x26, 0x2D, 0x65, 0x22, 0xF7])
    succeeds = true
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    let count = packets.count
    input.reconcileFactoryProfiles()
    #expect(packets.count == count)
    input.sources = []
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
    let shutdown = try #require(profile.definition?.shutdown)
    #expect(Array(packets.suffix(shutdown.count)) == shutdown)
    input.sources = [source]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    #expect(packets.filter { $0 == [0xF0, 0x26, 0x2D, 0x65, 0x22, 0xF7] }.count == 3)
}
