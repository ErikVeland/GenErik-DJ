import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withRDJ2Master(_ body: (ControllerMIDIConnection) throws -> Void) throws {
    let suite = "rdj2-master-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    let name = "Reloop Digital Jockey 2 Master Edition"
    input.sources = [
        .init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name])),
        .init(id: 11, reference: 101, name: name, identity: .init(id: 11, device: 2, names: [name])),
    ]
    input.reconcileFactoryProfiles()
    #expect(!input.isInputActive(10))
    let profile = try #require(ControllerFactoryProfile.matching([name]))
    #expect(!profile.selectsAutomatically)
    for source: Int32 in [10, 11] { input.select(source); input.applyFactoryProfile(profile) }
    try body(input)
}

@MainActor private func masterPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 10) {
    input.receiveBytes(bytes, source: source)
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueRDJ2MasterNormalButtonsKeepBothDecksAndReleaseForms() throws {
    try withRDJ2Master { input in
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (side, deck) in DeckID.primary.enumerated() {
            let base = UInt8(side * 60)
            for (number, action): (UInt8, ControllerAction) in [
                (25, .playA), (24, .cuePreviewA), (1, .syncA), (2, .keylockA), (5, .cueA), (19, .loadA),
                (3, .pitchBendDownA), (4, .pitchBendUpA), (15, .loopInA), (16, .loopOutA), (17, .loopEnableA),
            ] {
                for release: UInt8 in [0x80, 0x90] {
                    events.removeAll()
                    masterPacket(
                        [0x90, base + number, 127, release, base + number, release == 0x80 ? 127 : 0], to: input)
                    #expect(events.count == (action.isMomentary ? 2 : 1))
                    #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
                    #expect(events.map(\.1) == (action.isMomentary ? [1, 0] : [1]))
                }
            }
        }
    }
}

@Test @MainActor func controllerCatalogueRDJ2MasterMixerAndBrowserUseIndependentManufacturerCCs() throws {
    try withRDJ2Master { input in
        input.currentTargetValue = { _ in 0.5 }
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in if !target.action.isJog { events.append((target, value)) } }
        for (side, deck) in DeckID.primary.enumerated() {
            for (number, action): (UInt8, ControllerAction) in [
                (2, .gainA), (3, .highA), (4, .midA), (5, .lowA), (6, .levelA),
            ] {
                events.removeAll()
                masterPacket([0xB0, UInt8(side * 60) + number, 64], to: input)
                masterPacket([0xB0, UInt8(side * 60) + number, 127], to: input)
                #expect(events.map(\.1) == [64.0 / 127, 1])
                #expect(events.allSatisfy { $0.0 == .init(action.assigned(to: deck), deck: deck) })
            }
        }
        for (number, action): (UInt8, ControllerAction) in [
            (15, .master), (16, .monitor), (17, .cueMix), (18, .crossfader),
        ] {
            events.removeAll()
            masterPacket([0xB0, number, 64], to: input)
            masterPacket([0xB0, number, 0], to: input)
            #expect(events.map(\.1) == [64.0 / 127, 0])
            #expect(events.allSatisfy { $0.0.action == action })
        }
        events.removeAll()
        masterPacket([0xB0, 19, 64], to: input)
        #expect(events.isEmpty)
        for value: UInt8 in [65, 63, 66, 62] { masterPacket([0xB0, 19, value], to: input) }
        #expect(events.map(\.1) == [1, -1, 2, -2].map { 0.5 + Double($0) / 126 })
        #expect(events.allSatisfy { $0.0.action == .browse })
    }
}

@Test @MainActor func controllerCatalogueRDJ2MasterIndependentShiftsRearmWithoutCrossSourceCueRelease() throws {
    try withRDJ2Master { input in
        var actions: [ControllerAction] = []
        var values: [Double] = []
        input.onAction = { action, value in
            if !action.isJog { actions.append(action) }
            if action == .cuePreviewA { values.append(value) }
        }
        masterPacket([0x90, 24, 127], to: input)
        masterPacket([0x90, 24, 127], to: input, source: 11)
        masterPacket([0x90, 10, 127, 70, 127, 0x80, 24, 127, 10, 127], to: input)
        #expect(values == [1])
        actions.removeAll()
        masterPacket([0x90, 25, 127, 25, 0, 85, 127, 85, 0, 0xB0, 3, 127, 19, 65], to: input)
        #expect(actions.isEmpty)
        masterPacket([0x80, 24, 127], to: input, source: 11)
        #expect(values == [1, 0])
        masterPacket([0x80, 70, 127, 0x90, 25, 127, 25, 0], to: input)
        #expect(actions.last == .playA)
        actions.removeAll()
        masterPacket([0x90, 25, 127, 10, 127, 0x80, 25, 127, 10, 127, 0x90, 25, 127, 25, 0], to: input)
        #expect(actions == [.playA, .playA])
    }
}

@Test @MainActor func controllerCatalogueRDJ2MasterUnqualifiedDriverModesAndSiblingProfilesStaySeparate() throws {
    try withRDJ2Master { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        for base: UInt8 in [0, 60] {
            for number: UInt8 in [6, 7, 8, 9, 11, 12, 13, 14, 18, 20, 21, 22, 23, 26, 27, 28, 29] {
                masterPacket([0x90, base + number, 127, base + number, 0], to: input)
            }
        }
        masterPacket([0x90, 30, 127, 30, 0, 0xB0, 7, 65, 10, 65, 11, 65, 0xE0, 127, 127, 0xE1, 127, 127], to: input)
        masterPacket([0x91, 25, 127, 0xB1, 6, 127, 0xB0, 21, 127, 22, 127, 23, 127, 24, 127], to: input)
        #expect(actions.isEmpty)
    }
    let profile = try #require(ControllerFactoryProfile.matching(["Digital Jockey 2 Master Edition"]))
    #expect(profile.definition?.startup.isEmpty == true && profile.definition?.outputs.isEmpty == true)
    #expect(profile.definition?.shutdown.isEmpty == true && profile.definition?.audioOutput == nil)
    for name in ["DIGITALJOCKEY2", "Digital Jockey 2 Interface Edition", "Digital Jockey 2 Controller Edition"] {
        #expect(ControllerFactoryProfile.matching([name]) != profile)
    }
}
