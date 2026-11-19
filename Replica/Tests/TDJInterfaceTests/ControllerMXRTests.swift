import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let mxrModels = ["American Audio 10MXR", "American Audio 14MXR", "American Audio 19MXR"]

@Test func controllerCatalogueMXRSourceDefinitionsUseNativeActions() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json"))
    let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let records = try #require(raw["profiles"] as? [[String: Any]])
    for record in records where mxrModels.contains(record["id"] as? String ?? "") {
        let profile = try JSONDecoder().decode(
            ControllerProfileData.self, from: JSONSerialization.data(withJSONObject: record))
        #expect(profile.isValid, "Invalid MXR profile: \(profile.id)")
    }
}

@MainActor private func withMXR(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "mxr-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        }, deckAvailability: { DeckID.allCases }, factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    if name == mxrModels[0] {
        #expect(!input.isInputActive(10) && !input.isInputActive(11))
        let p = try #require(ControllerFactoryProfile.matching([name]))
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
        #expect(input.bindingCount == 102)
    }
    #expect(input.isInputActive(10) && input.isInputActive(11) && writes == 0)
    try body(input)
}
@MainActor private func mxrPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: mxrModels) @MainActor func controllerCatalogueMXRIndependentIdentityAndCrossFamilySourceOwnedCue(
    _ name: String
) throws {
    let index = try #require(mxrModels.firstIndex(of: name));
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(
        p.selectsAutomatically == (index != 0) && d.inputs.count == [51, 75, 71][index]
            && d.outputs.count == [8, 14, 10][index])
    #expect(d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil && d.inputProtocol == nil)
    for other in mxrModels where other != name { #expect(ControllerFactoryProfile.matching([other]) != p) }
    try withMXR(name) { input in
        let ch: UInt8 = index == 0 ? 0 : 2; var values: [Double] = []
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        for off: UInt8 in [0x80 + ch, 0x90 + ch, 0x81 + ch, 0x91 + ch] {
            values.removeAll(); mxrPacket([0x90 + ch, 12, 127, 12, 127], input)
            mxrPacket([0x90 + ch, 12, 127], input, source: 11)
            mxrPacket([off, 12, off < 0x90 ? 127 : 0], input); #expect(values == [1])
            mxrPacket([off, 12, off < 0x90 ? 127 : 0], input, source: 11); #expect(values == [1, 0])
        }
        values.removeAll(); mxrPacket([0x90 + ch, 12, 127, 109, 127], input); #expect(values == [1, 0])
        values.removeAll(); mxrPacket([0x91 + ch, 12, 127, 12, 0], input); #expect(values.isEmpty)
        mxrPacket([0x80 + ch, 109, 127, 0x90 + ch, 12, 127, 12, 0], input); #expect(values == [1, 0])
    }
}

@Test(arguments: mxrModels) @MainActor func controllerCatalogueMXRPrimarySyncMixerAndStrictBrowserOverrideScripts(
    _ name: String
) throws {
    try withMXR(name) { input in
        let small = name == mxrModels[0]; let ch: UInt8 = small ? 0 : 2
        input.currentTargetValue = { _ in 0.5 }; var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        let sync: UInt8 = small ? 54 : 55
        mxrPacket([0x90 + ch, sync, 127, sync, 0], input);
        #expect(events.count == 1 && events.first?.0.action == .syncB)
        for (n, deck): (UInt8, DeckID) in (small ? [(0, .a), (5, .b)] : [(0, .c), (5, .a), (10, .b), (15, .d)]) {
            events.removeAll(); mxrPacket([0xB0 + ch, n, 64], input);
            #expect(events.count == 1 && events.first?.0 == .init(.gainA.assigned(to: deck), deck: deck))
        }
        events.removeAll(); for v: UInt8 in [0, 1, 2, 64, 126, 127] { mxrPacket([0xB0 + ch, 52, v], input) };
        #expect(events.isEmpty)
        mxrPacket([0xB0 + ch, 52, 65], input); mxrPacket([0xB0 + ch, 52, 63], input)
        #expect(events.map(\.1) == [0.5 + 1.0 / 126, 0.5 - 1.0 / 126])
        events.removeAll(); mxrPacket([0xB1 + ch, 0, 64, 0x90 + (small ? 2 : 0), 13, 127], input);
        #expect(events.isEmpty)
        if name == mxrModels[2] { mxrPacket([0xB2, 37, 64, 39, 64], input); #expect(events.isEmpty) }
    }
}

@Test(arguments: ["American Audio 14MXR", "American Audio 19MXR"]) @MainActor
func controllerCatalogueMXRControllerSourceSelectorsKeepStripOwnership(_ name: String) throws {
    try withMXR(name) { input in
        var values: [Double] = [];
        input.onTargetAction = { target, value in if target.action == .cuePreviewA { values.append(value) } }
        mxrPacket([0x92, 12, 127, 89, 127], input); #expect(values == [1])
        mxrPacket([0x92, 90, 127], input); #expect(values == [1, 0])
        values.removeAll(); mxrPacket([0x92, 12, 127, 108, 127], input); #expect(values == [1, 0])
    }
}

@Test(arguments: mxrModels) @MainActor func controllerCatalogueMXRSteadyLampPacketsKeepOriginalOutputChannel(
    _ name: String
) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let lamps = p.feedback(destination: 20)
    for lamp in lamps {
        #expect(lamp.kind == .note && lamp.channel == 0)
        #expect(
            lamp.message(value: 1) == [0x90, lamp.number, 127] && lamp.message(value: 0) == [0x90, lamp.number, 0])
        #expect(lamp.target.action != .syncA && lamp.target.action != .syncB)
    }
}
