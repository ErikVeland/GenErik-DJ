import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private func withFactoryCue(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "factory-cue-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { DeckID.allCases })
    let ports = ControllerFactoryProfile.matching([name])?.definition?.portAliases?.prefix(1).map { $0 } ?? []
    input.sources = [
        .init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name], portNames: ports))
    ]
    input.destinations = [
        .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name], portNames: ports))
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func factoryCuePacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCatalogueFactoryCueBindingsKeepBothReleaseFormsAcrossReviewedModels() throws {
    let profiles = ControllerFactoryProfile.allCases.filter { $0.selectsAutomatically }
    var covered = 0
    for profile in profiles {
        let cues = profile.bindings(source: 10, playerDeck: profile.isPlayer ? .a : nil).filter {
            [.cuePreviewA, .cuePreviewB].contains($0.action) && !$0.isShifted && $0.releaseOnly != true
        }
        if cues.isEmpty { continue }
        covered += 1
        withFactoryCue(profile.rawValue) { input in
            #expect(input.isInputActive(10), "Profile: \(profile.rawValue)")
            for cue in cues {
                #expect(cue.kind == .note && cue.encoding == .absolute && cue.inverted != true)
                #expect(cue.action.isMomentary)
                var events: [(ControllerActionTarget, Double)] = []
                input.onTargetAction = { target, value in events.append((target, value)) }
                factoryCuePacket(
                    [
                        0x90 + cue.channel, cue.number, 127, cue.number, 0,
                        cue.number, 127, 0x80 + cue.channel, cue.number, 0,
                    ], to: input)
                #expect(
                    events.map(\.0) == [cue.target, cue.target, cue.target, cue.target], "Profile: \(profile.rawValue)")
                #expect(events.map(\.1) == [1, 0, 1, 0], "Profile: \(profile.rawValue)")
            }
        }
    }
    #expect(covered == 145)
}

@Test @MainActor func controllerCataloguePioneerPlayerCueReassignmentReleasesThePreviousDeck() throws {
    try withFactoryCue("Pioneer CDJ-3000") { input in
        let profile = try #require(ControllerFactoryProfile.matching(["Pioneer CDJ-3000"]))
        let cue = try #require(profile.bindings(source: 10).first { $0.action == .cuePreviewA })
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target, value)) }
        }
        factoryCuePacket([0x90 + cue.channel, cue.number, 127], to: input)
        input.setPlayerDeck(.c, source: 10)
        #expect(events.map(\.0.deck) == [.a, .a])
        #expect(events.map(\.1) == [1, 0])
        events.removeAll()
        factoryCuePacket([0x90 + cue.channel, cue.number, 127, 0x80 + cue.channel, cue.number, 0], to: input)
        #expect(events.map(\.0.deck) == [.c, .c])
        #expect(events.map(\.1) == [1, 0])
    }
}

@Test @MainActor func controllerCatalogueFactoryCueKeepsUnverifiedControlChangeCueBindingsUnchanged() throws {
    let profile = try #require(
        ControllerFactoryProfile.matching(["Hercules DJ Console Mac Edition"], automaticOnly: true))
    let cues = profile.bindings(source: 10).filter { [.cueReturnA, .cueReturnB].contains($0.action) }
    #expect(cues.count == 2)
    #expect(cues.allSatisfy { $0.kind == .control && !$0.action.isMomentary })
    #expect(!profile.bindings(source: 10).contains { [.cuePreviewA, .cuePreviewB].contains($0.action) })
}
