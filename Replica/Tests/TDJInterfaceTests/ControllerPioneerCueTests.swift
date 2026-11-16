import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let pioneerCodeCueProfiles: Set<ControllerFactoryProfile> = [
    .flx4, .flx2, .ddj400, .flx10, .rev1, .rev5, .ddj1000,
]

@MainActor private func withPioneerCue(_ name: String, _ body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "pioneer-cue-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { _, _ in true },
        deckAvailability: { DeckID.allCases })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func pioneerCuePacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
    input.flushPendingActions()
}

@Test @MainActor func controllerCataloguePioneerCueBindingsKeepBothReleaseFormsAcrossReviewedModels() throws {
    let profiles = ControllerFactoryProfile.allCases.filter {
        $0.selectsAutomatically
            && (pioneerCodeCueProfiles.contains($0)
                || $0.rawValue.hasPrefix("Pioneer ") || $0.rawValue.hasPrefix("AlphaTheta "))
    }
    var covered = 0
    for profile in profiles {
        let cues = profile.bindings(source: 10, playerDeck: profile.isPlayer ? .a : nil).filter {
            [.cuePreviewA, .cuePreviewB].contains($0.action) && !$0.isShifted
        }
        if cues.isEmpty { continue }
        covered += 1
        withPioneerCue(profile.rawValue) { input in
            #expect(input.isInputActive(10), "Profile: \(profile.rawValue)")
            for cue in cues {
                #expect(cue.kind == .note && cue.encoding == .absolute)
                #expect(cue.action.isMomentary)
                var events: [(ControllerActionTarget, Double)] = []
                input.onTargetAction = { target, value in events.append((target, value)) }
                pioneerCuePacket(
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
    #expect(covered == 57)
}

@Test @MainActor func controllerCataloguePioneerPlayerCueReassignmentReleasesThePreviousDeck() throws {
    try withPioneerCue("Pioneer CDJ-3000") { input in
        let profile = try #require(ControllerFactoryProfile.matching(["Pioneer CDJ-3000"]))
        let cue = try #require(profile.bindings(source: 10).first { $0.action == .cuePreviewA })
        var events: [(ControllerActionTarget, Double)] = []
        input.onTargetAction = { target, value in
            if [.cuePreviewA, .cuePreviewB].contains(target.action) { events.append((target, value)) }
        }
        pioneerCuePacket([0x90 + cue.channel, cue.number, 127], to: input)
        input.setPlayerDeck(.c, source: 10)
        #expect(events.map(\.0.deck) == [.a, .a])
        #expect(events.map(\.1) == [1, 0])
        events.removeAll()
        pioneerCuePacket([0x90 + cue.channel, cue.number, 127, 0x80 + cue.channel, cue.number, 0], to: input)
        #expect(events.map(\.0.deck) == [.c, .c])
        #expect(events.map(\.1) == [1, 0])
    }
}
