import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withSMK25(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "smk25-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [10, 11].map { id in
        .init(
            id: Int32(id), reference: UInt32(id * 10), name: "SMK-25 II",
            identity: .init(id: Int32(id), device: UInt32(id), names: ["SMK-25 II"]))
    }
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10) && input.isInputActive(11))
    try body(input)
}

private func smk25Button(_ number: UInt8, _ value: UInt8 = 127) -> [UInt8] {
    [0xF0, 0x35, 0x59, 0x10, number, value, 0xF7]
}

@Test @MainActor func controllerCatalogueSMK25RequiresItsVendorProtocolAndKeepsSiblingBoundaries() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["SMK-25 II"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputProtocol == .smk25II && data.inputs.count == 43)
    #expect(data.outputs.isEmpty && data.startup.isEmpty && data.shutdown.isEmpty && !profile.hasAutomaticSplitOutput)
    for name in ["SMK-25", "SMC-Mixer", "SMK-25 Mini", "USB MIDI"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) != profile)
    }
}

@Test @MainActor func controllerCatalogueSMK25RoutesFragmentsAndClearsOwnedCueBeforeBankedPlay() {
    withSMK25 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        #expect(input.receiveBytes([0xF0, 0x35, 0x59], source: 10) == 0)
        input.receiveBytes([0x10, 93, 127, 0xF7], source: 10)
        input.receiveBytes(smk25Button(47, 0) + smk25Button(94), source: 10)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewA, .playB])
        #expect(events.map(\.1) == [1, 0, 1])
        input.receiveBytes([0xB0, 30, 127], source: 10)
        input.flushPendingActions()
        #expect(events.last?.0 == .init(.gainB, deck: .b) && events.last?.1 == 1)
    }
}

@Test @MainActor func controllerCatalogueSMK25RetainsOtherSourceOwnershipAndResetsBankOnReconnect() {
    withSMK25 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        input.receiveBytes(smk25Button(93), source: 10)
        input.receiveBytes(smk25Button(93), source: 11)
        input.receiveBytes(smk25Button(47, 0), source: 10)
        #expect(events.map(\.1) == [1])
        input.receiveBytes(smk25Button(93, 0), source: 11)
        #expect(events.map(\.1) == [1, 0])
        let sources = input.sources
        input.sources.removeAll { $0.id == 10 }
        input.reconcileFactoryProfiles()
        input.sources = sources
        input.reconcileFactoryProfiles()
        input.receiveBytes(smk25Button(94), source: 10)
        #expect(events.last?.0 == .init(.playA, deck: .a))
    }
}

@Test @MainActor func controllerCatalogueSMK25DoesNotTreatSamplerOrOrdinaryNotesAsDeckSysex() {
    withSMK25 { input in
        var events: [ControllerAction] = []
        input.onAction = { action, _ in events.append(action) }
        input.receiveBytes([0x99, 40, 127, 0x90, 94, 127], source: 10)
        input.receiveBytes([0xF0, 0x35, 0x58, 0x10, 94, 127, 0xF7], source: 10)
        input.receiveBytes(smk25Button(95), source: 10)
        input.flushPendingActions()
        #expect(events.isEmpty)
        input.receiveBytes(smk25Button(94), source: 10)
        #expect(events == [.playA])
    }
}

@Test @MainActor func controllerCatalogueSMK25RejectsOverloadBeforePartialDispatchAndReleasesCue() {
    withSMK25 { input in
        var events: [(ControllerAction, Double)] = []
        input.onAction = { events.append(($0, $1)) }
        input.receiveBytes(smk25Button(93), source: 10)
        #expect(input.receiveBytes(smk25Button(94) + smk25Button(94, 0), source: 10, limit: 1) == nil)
        #expect(events.filter { $0.0 == .playA }.isEmpty)
        #expect(events.filter { $0.0 == .cuePreviewA }.map(\.1) == [1, 0])
        #expect(!input.isInputActive(10))
    }
}

@Test @MainActor func controllerCatalogueSMK25SysexCannotChangeAnOrdinaryFactoryController() {
    let suite = "smk25-isolation-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [
        .init(id: 10, reference: 100, name: "CMD MM-1", identity: .init(id: 10, device: 1, names: ["CMD MM-1"]))
    ]
    input.reconcileFactoryProfiles()
    var events: [ControllerAction] = []
    input.onAction = { action, _ in events.append(action) }
    input.receiveBytes(smk25Button(94), source: 10)
    input.flushPendingActions()
    #expect(events.isEmpty)
    #expect(input.receiveBytes([0xB4, 49], source: 10) == 0)
    input.receiveBytes([127], source: 10)
    input.flushPendingActions()
    #expect(events == [.levelA])
    events.removeAll()
    input.receiveBytes([0x94, 49, 127], source: 10)
    #expect(events == [.cueA])
}
