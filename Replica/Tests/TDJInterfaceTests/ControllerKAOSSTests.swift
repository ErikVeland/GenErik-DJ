import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withKAOSS(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "kaoss-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Korg KAOSS DJ"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func kaossPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueKAOSSSeparatesNormalAudioAndManualAudiolessWithoutProprietarySetup() throws {
    let normal = try #require(ControllerFactoryProfile.matching(["Korg KAOSS DJ"], automaticOnly: true))
    let manual = try #require(ControllerFactoryProfile.matching(["KAOSS DJ Audioless"]))
    #expect(ControllerFactoryProfile.matching(["KAOSS DJ Audioless"], automaticOnly: true) == nil)
    let data = try #require(normal.definition)
    #expect(data.inputs.count == 84 && data.outputs.count == 20)
    #expect(data.startup.count == 14 && data.shutdown.count == 34)
    #expect((data.startup + data.shutdown).allSatisfy { $0.count == 3 })
    #expect(normal.hasAutomaticSplitOutput && !manual.hasAutomaticSplitOutput)
    #expect(manual.definition?.startup.isEmpty == true && manual.definition?.shutdown.isEmpty == true)
    let feedback = normal.feedback(destination: 20)
    #expect(feedback.first { $0.action == .cuePreviewA }?.message(value: 1) == [0x97, 30, 127])
    #expect(feedback.first { $0.action == .hotcue3B }?.message(value: 0) == [0x98, 20, 0])
}

@Test @MainActor func controllerCatalogueKAOSSNormalOmitsHardwareMainKnobsAndManualVariantAddsThem() throws {
    try withKAOSS { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        kaossPacket([0xB6, 20, 127, 21, 127, 22, 127], to: input)
        #expect(events.isEmpty)
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["KAOSS DJ Audioless"])))
        events.removeAll()
        kaossPacket([0xB6, 20, 127, 21, 127, 22, 127], to: input)
        #expect(Set(events.map { $0.0.action }) == [.monitor, .cueMix, .master], "Received \(events)")
        #expect(events.allSatisfy { $0.1 == 1 })
    }
}

@Test @MainActor func controllerCatalogueKAOSSGlobalShiftRoutesLoadWhileLocalShiftKeepsOppositeTransportAvailable() {
    withKAOSS { input in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        kaossPacket([0x97, 26, 127, 0x98, 14, 127, 27, 127, 14, 0, 0x97, 26, 0, 0x98, 14, 127], to: input)
        #expect(actions == [.browseNextGroup, .playB, .loadB])
    }
}

@Test @MainActor func controllerCatalogueKAOSSBothShiftInputsKeepGlobalLayerUntilFinalRelease() {
    withKAOSS { input in
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, _ in actions.append(target.action) }
        kaossPacket([0x97, 26, 127, 0x98, 26, 127, 0x97, 26, 0, 14, 127, 14, 0, 0x98, 26, 0, 0x97, 14, 127], to: input)
        #expect(actions == [.browsePreviousGroup, .loadA])
    }
}

@Test @MainActor func controllerCatalogueKAOSSFixedTouchScratchUsesBothNormalAndScratchStreamsAndFourTimesShift() {
    withKAOSS { input in
        var touches: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .jogTouchA { touches.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        kaossPacket([0xB7, 16, 1, 15, 1, 14, 127], to: input)
        #expect(jogs.count == 1 && jogs.first?.1 == .relative(-1) && jogs.first?.0.argument == 128)
        kaossPacket([0x97, 31, 126, 0xB7, 16, 3], to: input)
        #expect(touches.isEmpty && jogs.count == 1)
        kaossPacket([0x97, 31, 127, 0xB7, 16, 3], to: input)
        #expect(touches == [1] && jogs.last?.1 == .relative(3) && jogs.last?.0.argument == 128)
        kaossPacket([0xB7, 15, 1], to: input)
        #expect(jogs.last?.1 == .relative(1) && jogs.last?.0.argument == 32)
        kaossPacket([0x87, 31, 127], to: input)
        #expect(touches == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueKAOSSShiftedCueReleasesAndKeyLockDoNotRetriggerHeldPlay() {
    withKAOSS { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        kaossPacket([0x97, 18, 127, 30, 127, 26, 127, 43, 0, 30, 0, 27, 127, 26, 0, 27, 127], to: input)
        #expect(events.map { $0.0.action } == [.hotcue1A, .cuePreviewA, .cuePreviewA, .keylockA])
        kaossPacket([0x97, 27, 0, 27, 127, 18, 127], to: input)
        #expect(events.suffix(2).map { $0.0.action } == [.playA, .hotcue1A])
    }
}

@Test @MainActor func controllerCatalogueKAOSSShiftSeekIsGuardedAndKeepsZeroPosition() {
    withKAOSS { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        kaossPacket([0xB7, 33, 127], to: input)
        #expect(events.isEmpty)
        kaossPacket([0x97, 26, 127, 0xB7, 33, 0], to: input)
        #expect(events.last?.0.action == .seekA && events.last?.1 == 0)
        kaossPacket([0xB7, 33, 127], to: input)
        #expect(events.last?.1 == 1)
        kaossPacket([0x97, 26, 0], to: input)
        #expect(events.count == 2)
    }
}

@Test @MainActor func controllerCatalogueKAOSSLoopPagesAndNativePitchPickupUseFactoryAddresses() {
    withKAOSS { input in
        var actions: [ControllerAction] = []
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoB ? 0.5 : nil }
        input.onTargetAction = { target, value in
            if target.action == .tempoB { values.append(value) } else { actions.append(target.action) }
        }
        kaossPacket([0x98, 15, 127, 16, 127, 17, 127, 26, 127, 40, 127, 42, 127, 0xB8, 25, 0], to: input)
        #expect(actions == [.loopDownB, .loopB, .loopUpB, .loopInB, .loopOutB])
        #expect(values.isEmpty)
        kaossPacket([0xB8, 25, 64], to: input)
        #expect(values == [0.5])
    }
}
