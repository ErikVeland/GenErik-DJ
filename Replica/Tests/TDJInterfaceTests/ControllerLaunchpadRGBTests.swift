import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let rgbLaunchpads = ["Launchpad MK2", "Launchpad Mini MK3"]

private func rgbEndpoint(_ id: Int32, _ name: String, port: String? = nil) -> ControllerFactoryEndpoint {
    .init(id: id, device: 1, names: [name], portNames: [port ?? (name.hasSuffix("MK3") ? "LPMiniMK3 MIDI" : name)])
}

@MainActor private func withRGBLaunchpad(
    _ name: String, sender: (([UInt8], Int32) -> Bool)? = nil,
    _ body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "rgb-launchpad-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: sender ?? { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: rgbEndpoint(10, name))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: rgbEndpoint(20, name))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func rgbPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    input.receiveBytes(bytes, source: 10)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRGBLaunchpadsKeepFixedTallABRowsAndArguments() {
    let normal: [(UInt8, ControllerAction)] = [
        (11, .playA), (12, .syncA), (31, .cueA), (42, .keylockA),
        (33, .loopInA), (34, .loopOutA), (43, .reloopA), (53, .loopDownA), (54, .loopUpA),
        (51, .hotcue1A), (52, .hotcue2A), (61, .hotcue3A), (62, .hotcue4A),
    ]
    for name in rgbLaunchpads {
        withRGBLaunchpad(name) { input in
            #expect(input.isInputActive(10))
            var events: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in events.append(target) }
            for deck in DeckID.primary {
                let offset: UInt8 = deck == .a ? 0 : 4
                for (number, action) in normal {
                    events.removeAll()
                    rgbPacket([0x90, number + offset, 127, number + offset, 0], to: input)
                    #expect(events == [.init(action.assigned(to: deck), deck: deck)])
                }
                for (number, beats) in zip([UInt8(63), 64, 73, 74, 83, 84], [0.5, 1, 2, 4, 8, 16]) {
                    events.removeAll()
                    rgbPacket([0x90, number + offset, 127, 0x80, number + offset, 127], to: input)
                    #expect(
                        events == [
                            .init(ControllerAction.toggleFixedLoopA.assigned(to: deck), deck: deck, argument: beats)
                        ])
                }
            }
            events.removeAll()
            rgbPacket([0x90, 41, 127, 45, 127, 0x91, 11, 127], to: input)
            #expect(events.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueRGBLaunchpadCueReleasesKeepOwnershipAcrossBothModifiers() {
    for name in rgbLaunchpads {
        withRGBLaunchpad(name) { input in
            var values: [Double] = []
            var actions: [ControllerAction] = []
            input.onTargetAction = { target, value in
                if target.action == .cuePreviewA { values.append(value) } else { actions.append(target.action) }
            }
            let status: UInt8 = name.hasSuffix("MK3") ? 0xB0 : 0x90
            rgbPacket([0x90, 21, 127, status, 29, 127, 19, 127, 29, 0, 0x80, 21, 127], to: input)
            #expect(values == [1, 0])
            rgbPacket([0x90, 11, 127, 11, 0, 51, 127, 51, 0], to: input)
            #expect(actions.isEmpty)
            rgbPacket([0x90, 53, 127, 53, 0, 54, 127, 54, 0], to: input)
            #expect(actions == [.loopDownA, .loopUpA])
            actions.removeAll()
            rgbPacket([status, 19, 0, 0x90, 11, 127, 11, 0, 21, 127, 21, 0], to: input)
            #expect(actions == [.playA] && values == [1, 0, 1, 0])
        }
    }
}

@Test @MainActor func controllerCatalogueRGBLaunchpadLibraryKeepsItsMessageKindAndIgnoresModifiers() {
    for name in rgbLaunchpads {
        withRGBLaunchpad(name) { input in
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in actions.append(action) }
            let status: UInt8 = name.hasSuffix("MK3") ? 0xB0 : 0x90
            rgbPacket([status, 29, 127], to: input)
            for number: UInt8 in [89, 79, 69, 59, 49] {
                rgbPacket([status, number, 127, number, 0], to: input)
            }
            #expect(actions == [.browsePreviousGroup, .browseNextGroup, .openGroup, .browsePrevious, .browseNext])
            actions.removeAll()
            let foreign: UInt8 = status == 0x90 ? 0xB0 : 0x90
            rgbPacket([foreign, 89, 127, 79, 127, 69, 127, 59, 127, 49, 127], to: input)
            #expect(actions.isEmpty)
        }
    }
}

@Test @MainActor func controllerCatalogueRGBLaunchpadSeparatesMIDIPortsAndRequiresSuccessfulSetup() throws {
    let name = "Launchpad Mini MK3"
    let sessions = ControllerFactorySession.discover(
        sources: [rgbEndpoint(10, name), rgbEndpoint(11, name, port: "LPMiniMK3 DAW")],
        destinations: [rgbEndpoint(20, name), rgbEndpoint(21, name, port: "LPMiniMK3 DAW")], disabled: [])
    #expect(sessions.map(\.source) == [10] && sessions.map(\.destination) == [20])
    for port in ["LPMiniMK3 DAW", "MIDI 1", "Launchpad Mini MK3"] {
        #expect(
            ControllerFactorySession.discover(
                sources: [rgbEndpoint(10, name, port: port)], destinations: [rgbEndpoint(20, name)], disabled: []
            ).isEmpty)
    }
    #expect(
        ControllerFactorySession.discover(
            sources: [rgbEndpoint(10, name), rgbEndpoint(11, name)], destinations: [rgbEndpoint(20, name)], disabled: []
        ).isEmpty)
    for name in rgbLaunchpads {
        withRGBLaunchpad(name, sender: { _, _ in false }) { #expect(!$0.isInputActive(10)) }
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        for foreign in [
            "Launchpad", "Launchpad Mini", "Launchpad X",
            name.hasSuffix("MK3") ? "Launchpad MK2" : "Launchpad Mini MK3",
        ] {
            #expect(ControllerFactoryProfile.matching([foreign], automaticOnly: true) != profile)
        }
    }
}

@Test @MainActor func controllerCatalogueRGBLaunchpadSendsReviewedSetupLampValuesAndMiniLiveCleanup() throws {
    for name in rgbLaunchpads {
        var packets: [[UInt8]] = []
        try withRGBLaunchpad(
            name,
            sender: { bytes, _ in
                packets.append(bytes); return true
            }
        ) { input in
            let definition = try #require(ControllerFactoryProfile.matching([name])?.definition)
            #expect(Array(packets.prefix(definition.startup.count)) == definition.startup)
            #expect(definition.outputs.count == 8)
            #expect(definition.outputs.allSatisfy { $0.onValue == 5 || $0.onValue == 17 })
            let profile = try #require(ControllerFactoryProfile.matching([name]))
            for binding in profile.feedback(destination: 20) {
                let on: UInt8 = [.playA, .playB, .keylockA, .keylockB].contains(binding.action) ? 5 : 17
                let off: UInt8 = [.loopA, .loopB].contains(binding.action) ? 19 : 0
                #expect(binding.message(value: 1) == [0x90, binding.number, on])
                #expect(binding.message(value: 0) == [0x90, binding.number, off])
            }
            input.sources = []
            input.reconcileFactoryProfiles()
            #expect(Array(packets.suffix(definition.shutdown.count)) == definition.shutdown)
            if name.hasSuffix("MK3") { #expect(packets.last == [240, 0, 32, 41, 2, 13, 14, 0, 247]) }
        }
    }
}
