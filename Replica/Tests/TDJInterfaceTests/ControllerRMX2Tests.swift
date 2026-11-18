import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRMX2(_ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "rmx2-core-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    let name = "Hercules DJConsole Rmx2"
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    #expect(input.isInputActive(10))
    try body(input)
}

@MainActor private func rmx2Packet(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRMX2RetainsFactoryPairsAndSeparateOriginalIdentity() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["Hercules DJConsole Rmx2"], automaticOnly: true))
    let data = try #require(profile.definition)
    #expect(data.inputs.count == 77 && data.outputs.count == 16)
    #expect(data.startup.count == 22 && data.shutdown.count == 17)
    #expect(data.startup.last == [0xB0, 127, 127])
    #expect(!profile.hasAutomaticSplitOutput)
    #expect(ControllerFactoryProfile.matching(["Hercules DJ Console RMX"], automaticOnly: true) != profile)
    #expect(data.inputs.filter { $0.encoding == .paired14Bit }.allSatisfy { $0.lowNumber == $0.number + 1 })
}

@Test @MainActor func controllerCatalogueRMX2UsesAdjacentLowBytesForGainEQAndMaster() {
    withRMX2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rmx2Packet([0xB0, 67, 1, 61, 1, 69, 1], to: input)
        #expect(events.isEmpty)
        rmx2Packet([0xB0, 66, 64, 67, 1, 60, 64, 61, 2, 68, 64, 69, 3], to: input)
        #expect(events.first { $0.0.action == .gainA }?.1 == 8193.0 / 16383)
        #expect(events.first { $0.0.action == .highA }?.1 == 8194.0 / 16383)
        #expect(events.first { $0.0.action == .master }?.1 == 8195.0 / 16383)
    }
}

@Test @MainActor func controllerCatalogueRMX2PitchKeepsPickupAndLowByteResolution() {
    withRMX2 { input in
        var values: [Double] = []
        input.currentTargetValue = { $0.action == .tempoA ? 0.5 : nil }
        input.onTargetAction = { target, value in if target.action == .tempoA { values.append(value) } }
        rmx2Packet([0xB0, 54, 0, 55, 0], to: input)
        #expect(values.isEmpty)
        rmx2Packet([0xB0, 54, 64, 55, 1], to: input)
        #expect(values.last == 1 - 8193.0 / 16383)
        rmx2Packet([0xB0, 54, 64, 55, 2], to: input)
        #expect(values.last == 1 - 8194.0 / 16383)
    }
}

@Test @MainActor func controllerCatalogueRMX2UsesSeparateSignedWheelAndGatedScratchStreams() {
    withRMX2 { input in
        var touches: [Double] = []
        var jogs: [(ControllerActionTarget, ControllerMIDIValue)] = []
        input.onTargetAction = { target, value in if target.action == .jogTouchA { touches.append(value) } }
        input.onJogAction = { jogs.append(($0, $1)) }
        rmx2Packet([0xB0, 50, 1, 48, 2], to: input)
        #expect(jogs.count == 1 && jogs.first?.0.action == .wheelJogA && jogs.first?.1 == .relative(2))
        rmx2Packet([0x90, 47, 126, 0xB0, 50, 3], to: input)
        #expect(touches.isEmpty && jogs.count == 1)
        rmx2Packet([0x90, 47, 127, 0xB0, 50, 64], to: input)
        #expect(touches == [1])
        #expect(jogs.last?.0.action == .jogA && jogs.last?.0.argument == 256 && jogs.last?.1 == .relative(-64))
        rmx2Packet([0x80, 47, 127], to: input)
        #expect(touches == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueRMX2ShiftCCReleaseRearmsPadsWithoutDeleteOrRollPresses() {
    withRMX2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rmx2Packet([0x90, 9, 127, 13, 127, 0xB0, 9, 127, 13, 127, 0x90, 9, 127, 13, 127], to: input)
        #expect(events.map { $0.0.action } == [.hotcue1A, .toggleFixedLoopA])
        rmx2Packet([0xB0, 9, 0, 13, 0, 0x90, 9, 127, 13, 127], to: input)
        #expect(events.map { $0.0.action } == [.hotcue1A, .toggleFixedLoopA, .hotcue1A, .toggleFixedLoopA])
        #expect(events.last?.0.argument == 4)
    }
}

@Test @MainActor func controllerCatalogueRMX2CCReleaseRequiresExactSevenBitZeroAndMatchingSource() {
    withRMX2 { input in
        var pads = 0
        input.onTargetAction = { target, _ in if target.action == .hotcue1A { pads += 1 } }
        rmx2Packet([0x90, 9, 127], to: input)
        input.receive(.init(kind: .control, channel: 0, number: 9, value: 0, maximum: 65535), source: 10)
        input.receive(.init(kind: .control, group: 1, channel: 0, number: 9, value: 0), source: 10)
        input.receive(.init(kind: .control, channel: 0, number: 9, value: 0), source: 11)
        rmx2Packet([0xB0, 9, 1, 0x90, 9, 127], to: input)
        #expect(pads == 1)
        rmx2Packet([0xB0, 9, 0, 0x90, 9, 127], to: input)
        #expect(pads == 2)
    }
}

@Test @MainActor func controllerCatalogueRMX2CopiedFactoryBindingsRetainCCReleaseMetadata() throws {
    try withRMX2 { input in
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["Hercules DJConsole Rmx2"])))
        var pads = 0
        input.onTargetAction = { target, _ in if target.action == .hotcue4B { pads += 1 } }
        rmx2Packet([0x90, 28, 127, 0xB0, 28, 0, 0x90, 28, 127], to: input)
        #expect(pads == 2)
    }
}

@Test @MainActor func controllerCatalogueRMX2ShiftedBendReleasesStayIndependentOfHeadphoneCue() {
    withRMX2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rmx2Packet([0x90, 34, 127, 46, 127, 44, 127, 84, 127, 84, 0, 34, 0], to: input)
        #expect(events.map { $0.0.action } == [.cuePreviewA, .cueA, .pitchBendDownA, .pitchBendDownA, .cuePreviewA])
        #expect(events.map { $0.1 } == [1, 1, 1, 0, 0])
    }
}

@Test func controllerCatalogueCCReleaseValidationRejectsRelativeContinuousAndNonCCInputs() throws {
    func valid(kind: String, encoding: String, action: String) throws -> Bool {
        let data = Data(
            """
            {"id":"release-test","aliases":["release-test"],"inputs":[
              {"action":"\(action)","kind":"\(kind)","channel":0,"number":9,"encoding":"\(encoding)","inverted":false,"releaseOnly":true}
            ],"outputs":[],"startup":[],"shutdown":[],"autoSelect":false,"scope":"test","source":"test"}
            """.utf8)
        return try JSONDecoder().decode(ControllerProfileData.self, from: data).isValid
    }
    #expect(try valid(kind: "control", encoding: "absolute", action: "hotcue1A"))
    #expect(try !valid(kind: "control", encoding: "twosComplement", action: "hotcue1A"))
    #expect(try !valid(kind: "control", encoding: "absolute", action: "levelA"))
    #expect(try !valid(kind: "pitch", encoding: "absolute", action: "hotcue1A"))
    #expect(try !valid(kind: "control", encoding: "absolute", action: "shift"))
}

@Test @MainActor func controllerCatalogueRMX2LoopEncoderUsesOnlyItsDocumentedModeAddress() {
    withRMX2 { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        rmx2Packet([0xB0, 52, 0, 90, 1, 84, 1, 86, 1], to: input)
        #expect(events.isEmpty)
        rmx2Packet([0xB0, 52, 2, 53, 127], to: input)
        #expect(events.map { $0.0.action } == [.loopSizeA, .loopSizeB])
        #expect(events.first!.1 > 0.5 && events.last!.1 < 0.5)
    }
}
