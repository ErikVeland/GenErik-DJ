import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withManualIMix(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "imix-manual-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "DJ-Tech i-Mix Reload"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    input.select(10)
    input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching([name])))
    try body(input)
}

@MainActor private func imixPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueIMixKeepsConflictingVariantManualAndSeparateFromMKII() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DJ-Tech i-Mix Reload"]))
    #expect(ControllerFactoryProfile.matching(["DJ-Tech i-Mix Reload"], automaticOnly: true) == nil)
    #expect(ControllerFactoryProfile.matching(["DJ-Tech i-Mix Reload MKII"]) != profile)
    #expect(!profile.hasAutomaticSplitOutput)
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 55 && data.outputs.count == 16)
    #expect(data.startup.count == 36 && data.shutdown.count == 18)
    #expect(data.inputs.filter { $0.action == .loadA || $0.action == .loadB }.map(\.number) == [40, 46])
}

@Test @MainActor func controllerCatalogueIMixNoteStepsAccumulatePreserveDirectionAndRequireTouch() throws {
    try withManualIMix { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        imixPacket([0x90, 96, 127, 97, 127], to: input)
        #expect(jogs.isEmpty)
        imixPacket([0x90, 50, 127, 96, 127, 96, 127, 97, 127, 96, 0, 0x80, 97, 127], to: input)
        #expect(jogs.last?.0 == .init(.jogA, deck: .a, argument: 148))
        #expect(jogs.last?.1 == .relative(1))
        jogs.removeAll()
        imixPacket([0x90, 49, 127, 98, 127, 98, 127, 99, 0, 0x80, 99, 127], to: input)
        #expect(jogs.last?.0 == .init(.jogB, deck: .b, argument: 148) && jogs.last?.1 == .relative(2))
        imixPacket([0x90, 99, 127], to: input)
        #expect(jogs.last?.1 == .relative(-1))
        imixPacket([0x80, 50, 0, 49, 0], to: input)
        let count = jogs.count
        imixPacket([0x90, 96, 127, 98, 127], to: input)
        #expect(jogs.count == count)
    }
}

@Test @MainActor func controllerCatalogueIMixNormalUnheldWheelStepsDoNotRunSearchOrReleaseMotion() throws {
    try withManualIMix { input in
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onJogAction = { jogs.append(($0, $1)) }
        imixPacket([0x90, 114, 127, 114, 127, 115, 127, 114, 0, 112, 127, 113, 127], to: input)
        #expect(jogs.last?.0 == .init(.wheelJogA, deck: .a, argument: 148) && jogs.last?.1 == .relative(1))
        imixPacket([0x90, 119, 127, 118, 0], to: input)
        #expect(jogs.last?.0 == .init(.wheelJogB, deck: .b, argument: 148) && jogs.last?.1 == .relative(-1))
        let count = jogs.count
        input.receive(.init(kind: .note, group: 1, channel: 0, number: 114, value: 127), source: 10)
        input.receive(.init(kind: .note, channel: 0, number: 114, value: 127), source: 11)
        input.receive(.init(kind: .note, channel: 0, number: 114, value: 65535, maximum: 65535), source: 10)
        input.flushPendingActions()
        #expect(jogs.count == count)
    }
}

@Test @MainActor func controllerCatalogueIMixNativeCueAndSetGuardKeepDestructiveActionsInactive() throws {
    try withManualIMix { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        imixPacket([0x90, 11, 127, 11, 0, 41, 127, 0x80, 41, 127], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cuePreviewA, .cuePreviewB, .cuePreviewB])
        #expect(events.map { $0.1 } == [1, 0, 1, 0])
        events.removeAll()
        imixPacket([0x90, 2, 127, 8, 127, 32, 127], to: input)
        #expect(events.map { $0.0.action } == [.hotcue1B])
        imixPacket([0x90, 8, 0, 2, 0, 8, 127], to: input)
        #expect(events.last?.0.action == .hotcue1A)
    }
}

@Test @MainActor func controllerCatalogueIMixSourceMixerLoopsAndDirectLoadKeepWireMeaning() throws {
    try withManualIMix { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        imixPacket(
            [0x90, 40, 127, 46, 127, 5, 127, 35, 127, 1, 127, 25, 127, 7, 127, 13, 127, 31, 127, 37, 127], to: input)
        #expect(
            events.map { $0.0.action } == [
                .loadA, .loadB, .syncA, .syncB, .loopA, .loopB, .loopDownA, .loopUpA, .loopDownB, .loopUpB,
            ])
        events.removeAll()
        imixPacket(
            [
                0xB0, 71, 64, 81, 64, 78, 64, 80, 64, 79, 64, 72, 64, 77, 64, 82, 64, 67, 127, 66, 127, 69, 0, 75, 127,
                65, 0, 73, 127, 74, 127,
            ], to: input)
        #expect(
            Set(events.map { $0.0.action }) == [
                .gainA, .gainB, .highA, .highB, .midA, .midB, .lowA, .lowB, .levelA, .levelB, .tempoA, .tempoB,
                .crossfader, .monitor, .cueMix,
            ])
        #expect(events.first { $0.0.action == .tempoA }?.1 == 1)
        #expect(events.first { $0.0.action == .tempoB }?.1 == 0)
    }
}

@Test func controllerCatalogueIMixNoteStepValidationRejectsNonJogAndNonNoteRecipes() throws {
    func valid(kind: String, action: String) throws -> Bool {
        let data = Data(
            """
            {"id":"step-test","aliases":["step-test"],"inputs":[
              {"action":"\(action)","kind":"\(kind)","channel":0,"number":96,"encoding":"noteStep","inverted":false}
            ],"outputs":[],"startup":[],"shutdown":[],"autoSelect":false,"scope":"test","source":"test"}
            """.utf8)
        return try JSONDecoder().decode(ControllerProfileData.self, from: data).isValid
    }
    #expect(try valid(kind: "note", action: "jogA"))
    #expect(try valid(kind: "note", action: "wheelJogA"))
    #expect(try !valid(kind: "control", action: "jogA"))
    #expect(try !valid(kind: "note", action: "tempoA"))
    #expect(try !valid(kind: "note", action: "playA"))
}
