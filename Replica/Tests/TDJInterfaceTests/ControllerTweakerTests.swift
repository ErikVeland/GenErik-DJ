import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withTweaker(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "tweaker-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Electrix Tweaker"
    input.sources = [
        .init(
            id: 10, reference: 100, name: name,
            identity: .init(id: 10, device: 1, names: [name], portNames: ["Tweaker MIDI 1"]))
    ]
    input.destinations = [
        .init(
            id: 20, reference: 200, name: name,
            identity: .init(id: 20, device: 1, names: [name], portNames: ["Tweaker MIDI 1"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func tweakerPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueTweakerProgramsAbsoluteEQWithoutFactoryResetOrAudioClaim() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Tweaker"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(data.startup.count + data.shutdown.count <= 64)
    for number: UInt8 in 57...62 { #expect(data.startup.contains([0xBF, number, 118])) }
    for number: UInt8 in 79...84 { #expect(data.startup.contains([0xBF, number, 70])) }
    #expect(!data.startup.contains { $0.first == 0xF0 })
    #expect(data.inputs.allSatisfy { $0.targetDeck == nil || DeckID.primary.contains($0.targetDeck!) })
    let eq = try #require(profile.feedback(destination: 20).first { $0.action == .highA })
    #expect(eq.message(value: 0.5) == [0xB0, 57, 64])
    let cue = try #require(profile.feedback(destination: 20).first { $0.action == .hotcue8B })
    #expect(cue.message(value: 1) == [0x90, 16, 32])
}

@Test @MainActor func controllerCatalogueTweakerColdTransportAndLoadStayOnFixedAB() {
    withTweaker { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        tweakerPacket([0x90, 42, 127, 43, 127, 35, 127, 38, 127, 28, 127, 32, 127, 27, 127, 31, 127], to: input)
        #expect(events.map(\.action) == [.loadA, .loadB, .playA, .playB, .syncA, .syncB, .keylockA, .keylockB])
        events.removeAll()
        tweakerPacket([0x90, 20, 127, 24, 127, 33, 127, 36, 127, 35, 0, 38, 0, 35, 127, 38, 127], to: input)
        #expect(events.map(\.action) == [.playA, .playB])
        #expect(events.compactMap(\.deck) == [.a, .b])
    }
}

@Test @MainActor func controllerCatalogueTweakerTopShiftCannotStartCueAndDeckShiftsKeepIndependentPriority() {
    withTweaker { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        tweakerPacket([0x90, 40, 127, 35, 127, 38, 127, 42, 127], to: input)
        #expect(events.isEmpty)
        tweakerPacket([0x90, 35, 0, 19, 127, 35, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA])
        tweakerPacket([0x90, 40, 0, 38, 0, 38, 127], to: input)
        #expect(events.map(\.0) == [.cuePreviewA, .playB])
        tweakerPacket([0x90, 19, 0, 0x80, 35, 127], to: input)
        #expect(events.last?.0 == .cuePreviewA && events.last?.1 == 0)
        tweakerPacket([0x90, 23, 127, 38, 0, 38, 127, 0x80, 38, 127], to: input)
        #expect(events.suffix(2).map(\.0) == [.cuePreviewB, .cuePreviewB])
        #expect(events.suffix(2).map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueTweakerCompositeShiftResetsEQPickupAndHeldTopShiftSurvivesDeckRelease() {
    withTweaker { input in
        var events: [(ControllerAction, Double)] = []
        input.onTargetAction = { events.append(($0.action, $1)) }
        input.currentTargetValue = { $0.action == .highA ? 0.5 : nil }
        tweakerPacket([0xB0, 57, 64], to: input)
        #expect(events.count == 1 && events[0].1 == 0.5)
        events.removeAll()
        tweakerPacket([0x90, 40, 127, 19, 127, 19, 0, 0xB0, 57, 127], to: input)
        #expect(events.isEmpty)
        tweakerPacket([0x90, 40, 0, 0xB0, 57, 127], to: input)
        #expect(events.isEmpty)
        tweakerPacket([0xB0, 57, 64], to: input)
        #expect(events.count == 1 && events[0].0 == .highA)
    }
}

@Test @MainActor func controllerCatalogueTweakerEightCuesAndSourceLoopBoundariesKeepOtherModesInactive() {
    withTweaker { input in
        var events: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in events.append(target) }
        for number: UInt8 in [1, 2, 3, 4, 9, 10, 11, 12] { tweakerPacket([0x90, number, 127, number, 0], to: input) }
        #expect(events.compactMap { $0.action.hotcueSlot } == Array(0..<8))
        events.removeAll()
        tweakerPacket([0x90, 19, 127, 1, 127, 18, 127, 20, 127, 34, 127, 28, 127], to: input)
        #expect(events.map(\.action) == [.loopInA, .loopOutA, .loopDisableA, .tempoResetA])
        events.removeAll()
        tweakerPacket([0x90, 63, 127, 64, 127, 45, 127, 46, 127, 47, 127], to: input)
        #expect(events.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueTweakerJumpArgumentsAndStrictBrowserKeepPublishedDirections() {
    withTweaker { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        tweakerPacket([0x90, 17, 127, 17, 0, 19, 127, 17, 127], to: input)
        #expect(events.map { $0.0.argument } == [4, 1])
        events.removeAll()
        tweakerPacket([0xB0, 56, 1], to: input)
        #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 + 1.0 / 126)
        tweakerPacket([0xB0, 56, 127], to: input)
        #expect(events.last?.0.action == .browse && events.last?.1 == 0.5 - 1.0 / 126)
        let count = events.count
        tweakerPacket([0xB0, 56, 0, 56, 64], to: input)
        #expect(events.count == count)
    }
}

@Test @MainActor func controllerCatalogueTweakerClaimsOnlyUSBPortOneAndRetriesFailedEncoderSetup() throws {
    let suite = "tweaker-ports-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var succeeds = false
    var packets: [[UInt8]] = []
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, id in
            #expect(id == 20)
            packets.append(bytes)
            return succeeds
        })
    let name = "Electrix Tweaker"
    let usb = ControllerMIDIConnection.Source(
        id: 10, reference: 100, name: name,
        identity: .init(id: 10, device: 1, names: [name], portNames: ["Tweaker MIDI 1"]))
    let din = ControllerMIDIConnection.Source(
        id: 11, reference: 101, name: name,
        identity: .init(id: 11, device: 1, names: [name], portNames: ["Tweaker MIDI 2"]))
    input.sources = [usb, din]
    input.destinations = [
        .init(
            id: 21, reference: 201, name: name,
            identity: .init(id: 21, device: 1, names: [name], portNames: ["Tweaker MIDI 2"]))
    ]
    input.reconcileFactoryProfiles()
    #expect(packets.isEmpty && !input.isInputActive(10) && !input.isInputActive(11))
    input.destinations.append(
        .init(
            id: 20, reference: 200, name: name,
            identity: .init(id: 20, device: 1, names: [name], portNames: ["Tweaker MIDI 1"])))
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    succeeds = true
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && !input.isInputActive(11))
    let count = packets.count
    input.reconcileFactoryProfiles()
    #expect(packets.count == count)
    input.sources = [din]
    input.reconcileFactoryProfiles()
    let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
    let shutdown = try #require(profile.definition?.shutdown)
    #expect(Array(packets.suffix(shutdown.count)) == shutdown)
    input.sources = [usb, din]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && !input.isInputActive(11))
}
