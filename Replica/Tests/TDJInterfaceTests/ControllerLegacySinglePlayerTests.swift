import Foundation
import TDJCore
import Testing

@testable import TDJInterface
private let singlePlayerModels = ["Audiophony CDX6", "CITRONIC MPCD-X3", "Stanton CMP.800", "Synq DMC-1000"]

@MainActor private func withSinglePlayer(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "single-player-\(UUID().uuidString)"; let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    var writes = 0
    let input = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { _, _ in
            writes += 1; return true
        },
        factoryInputConnector: { _ in true })
    input.sources = [10, 11].map { id in
        .init(id: id, reference: UInt32(id), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
    }
    input.reconcileFactoryProfiles()
    let p = try #require(ControllerFactoryProfile.matching([name]))
    if !p.selectsAutomatically {
        #expect(!input.isInputActive(10) && !input.isInputActive(11))
        for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(p) }
        #expect(input.bindingCount == p.bindings(source: 10).count * 2)
    }
    #expect(writes == 0); try body(input)
}
@MainActor private func singlePlayerPacket(_ bytes: [UInt8], _ input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source); input.flushPendingActions()
}

@Test(arguments: singlePlayerModels) @MainActor
func controllerCatalogueLegacySinglePlayerIndependentIdentityAndNoSetup(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let d = try #require(p.definition)
    #expect(d.isValid && d.inputs.count == (name.hasPrefix("Synq") ? 68 : 66) && d.outputs.count == 8)
    #expect(d.inputProtocol == .legacySinglePlayer && d.startup.isEmpty && d.shutdown.isEmpty && d.audioOutput == nil)
    #expect(p.selectsAutomatically == name.hasPrefix("Synq"))
    #expect(ControllerFactoryProfile.matching(["MIDI"]) != p && ControllerFactoryProfile.matching(["MIDI B"]) != p)
    if name.hasPrefix("Synq") {
        for suffix in ["", "B", "C", "D", "E", "F", "G", "H"] {
            #expect(ControllerFactoryProfile.matching(["DMC1K" + suffix]) == p)
        }
    }
    for other in singlePlayerModels where other != name { #expect(ControllerFactoryProfile.matching([other]) != p) }
    try withSinglePlayer(name) { _ in }
}

@Test(arguments: singlePlayerModels) @MainActor
func controllerCatalogueLegacySinglePlayerCueReleaseFormsAndSourceOwnedBankShiftCleanup(_ name: String) throws {
    try withSinglePlayer(name) { input in
        var events: [(DeckID?, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target.deck, value)) }
        }
        for channel: UInt8 in [0, 1] {
            for off: UInt8 in [0x80 + channel, 0x90 + channel] {
                events.removeAll()
                singlePlayerPacket([0x90 + channel, 46, 127, 46, 127, off, 109, off < 0x90 ? 127 : 0], input)
                #expect(events.map(\.1) == [1, 0])
            }
        }
        events.removeAll(); singlePlayerPacket([0x90, 46, 127], input)
        singlePlayerPacket([0x90, 46, 127], input, source: 11)
        singlePlayerPacket([0x91, 46, 127], input)
        #expect(events.map(\.1) == [1, 1] && events.last?.0 == .b)
        singlePlayerPacket([0x90, 69, 127], input, source: 11)
        #expect(events.map(\.1) == [1, 1, 0] && events.last?.0 == .a)
        singlePlayerPacket([0x81, 46, 127], input)
        #expect(events.map(\.1) == [1, 1, 0, 0])
        events.removeAll(); singlePlayerPacket([0x90, 46, 127], input)
        singlePlayerPacket([0x90, 69, 127], input); #expect(events.map(\.1) == [1, 0])
        singlePlayerPacket([0x90, 46, 127], input); singlePlayerPacket([0x80, 69, 127], input)
        #expect(events.map(\.1) == [1, 0, 1, 0])
        singlePlayerPacket([0x90, 46, 127], input); singlePlayerPacket([0x90, 36, 127], input)
        #expect(events.suffix(2).map(\.1) == [1, 0])
        singlePlayerPacket([0x90, 46, 127], input); input.stop(); #expect(events.suffix(2).map(\.1) == [1, 0])
    }
}

@Test(arguments: singlePlayerModels) @MainActor
func controllerCatalogueLegacySinglePlayerNormalButtonsRearmAcrossAlternateReleases(_ name: String) throws {
    try withSinglePlayer(name) { input in
        let p = try #require(ControllerFactoryProfile.matching([name]));
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { events.append(($0, $1)) }
        for binding in p.bindings(source: 10).filter({
            $0.kind == .note && $0.releaseOnly != true && $0.pulse != true && !$0.action.isJog
                && $0.action != .jogTouchA && $0.action != .jogTouchB
        }) {
            events.removeAll(); let ch = binding.channel; let n = binding.number
            singlePlayerPacket([0x90 + ch, n, 127, 0x80 + ch, n + 63, 127], input)
            singlePlayerPacket([0x90 + ch, n, 127, n, 0], input)
            #expect(events.filter { $0.0 == binding.target && $0.1 > 0 }.count == 2)
        }
        events.removeAll();
        singlePlayerPacket(
            [0x90, 7, 127, 17, 127, 20, 127, 26, 127, 32, 127, 38, 127, 40, 127, 0x92, 2, 127, 46, 127], input)
        #expect(events.isEmpty)
    }
}

@Test(arguments: singlePlayerModels) @MainActor
func controllerCatalogueLegacySinglePlayerCCAndRepeatedNoteBrowserFormats(_ name: String) throws {
    try withSinglePlayer(name) { input in
        var events: [(ControllerAction, Double)] = []; input.onTargetAction = { events.append(($0.action, $1)) }
        singlePlayerPacket([0xB0, 51, 67], input); singlePlayerPacket([0xB0, 49, 49], input)
        #expect(events.map(\.0) == [.browse, .browseGroups] && events.map(\.1) == [0.5 + 3.0 / 126, 0.5 - 15.0 / 126])
        events.removeAll(); singlePlayerPacket([0x90, 51, 127, 51, 127, 52, 127, 49, 127, 50, 127], input)
        #expect(events.map(\.0) == [.browseNext, .browseNext, .browsePrevious, .browseNextGroup, .browsePreviousGroup])
    }
}

@Test(arguments: singlePlayerModels) @MainActor
func controllerCatalogueLegacySinglePlayerJogFormatsRequireOwnedContactAnd1024Counts(_ name: String) throws {
    try withSinglePlayer(name) { input in
        var jogs: [ControllerMIDIValue] = []
        input.onJogAction = { target, value in
            #expect(target.argument == 1024); jogs.append(value)
        }
        singlePlayerPacket([0xB0, 53, 67, 0x90, 53, 127, 54, 127], input); #expect(jogs.isEmpty)
        singlePlayerPacket([0x90, 19, 127], input)
        singlePlayerPacket([0xB0, 53, 67], input); singlePlayerPacket([0xB0, 53, 49], input)
        for n: UInt8 in [53, 53, 54] { singlePlayerPacket([0x90, n, 127], input) }
        singlePlayerPacket([0x90, 54, 0], input)
        #expect(jogs == [.relative(3), .relative(-15), .relative(1), .relative(1), .relative(-1)])
        singlePlayerPacket([0xB0, 53, 65], input, source: 11); #expect(jogs.count == 5)
        singlePlayerPacket([0x80, 82, 127, 0xB0, 53, 65], input); #expect(jogs.count == 5)
    }
}

@Test(arguments: singlePlayerModels) @MainActor
func controllerCatalogueLegacySinglePlayerOwnNoteLampsAndQualifiedSynqPitch(_ name: String) throws {
    let p = try #require(ControllerFactoryProfile.matching([name])); let lamps = p.feedback(destination: 20)
    #expect(lamps.count == 8)
    for lamp in lamps {
        #expect([UInt8(2), 46, 30, 48].contains(lamp.number) && lamp.channel <= 1)
        #expect(lamp.message(value: 1) == [0x90 + lamp.channel, lamp.number, 127])
        #expect(lamp.message(value: 0) == [0x90 + lamp.channel, lamp.number, 0])
    }
    try withSinglePlayer(name) { input in
        input.currentTargetValue = { _ in 0.5 }; var values: [Double] = []
        input.onTargetAction = { target, value in
            if [.tempoA, .tempoB].contains(target.action) { values.append(value) }
        }
        singlePlayerPacket([0xE0, 0, 64], input); singlePlayerPacket([0xE0, 0, 0], input)
        #expect(values == (name.hasPrefix("Synq") ? [0.5, 1] : []))
    }
}
