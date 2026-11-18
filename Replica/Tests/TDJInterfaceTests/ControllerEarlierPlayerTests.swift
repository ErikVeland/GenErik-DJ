import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let earlierPlayerNames = [
    "XDJ-1000MK2", "XDJ-700", "XDJ-1000", "CDJ-2000", "CDJ-900", "CDJ-850",
    "CDJ-350", "CDJ-400", "CDJ-TOUR1",
]

@MainActor private func withEarlierPlayer(
    _ name: String, body: (ControllerMIDIConnection) throws -> Void
) rethrows {
    let suite = "earlier-player-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences)
    input.sources = [
        .init(id: 10, reference: 100, name: "CDJ-3000", identity: .init(id: 10, device: 1, names: ["CDJ-3000"])),
        .init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 2, names: [name])),
    ]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func earlierPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection, source: Int32 = 20) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: source) }
}

@Test @MainActor func controllerPlayerEarlierProfilesMatchExactModelsAndKeepAbsentControlsUnmapped() throws {
    for name in earlierPlayerNames {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.rawValue == "Pioneer " + name)
        #expect(profile.isPlayer)
        #expect(profile.bindings(source: 20).allSatisfy { $0.anyChannel == true })
        #expect(profile.feedback(destination: 30).isEmpty)
    }
    for name in ["CDJ-1000", "CDJ-800", "CDJ-100", "CDJ-200", "USB Audio Device", "XDJ-1000MK3"] {
        #expect(ControllerFactoryProfile.matching([name], automaticOnly: true) == nil)
    }
    for name in ["CDJ-900", "CDJ-850", "CDJ-350", "CDJ-400"] {
        let profile = try #require(ControllerFactoryProfile.matching([name]))
        #expect(!profile.bindings(source: 20).contains { $0.action.hotcueSlot != nil || $0.action == .seekA })
    }
    let original = try #require(ControllerFactoryProfile.matching(["CDJ-2000"]))
    #expect(ControllerFactoryProfile.matching(["CDJ-400-K"], automaticOnly: true)?.rawValue == "Pioneer CDJ-400")
    #expect(!original.bindings(source: 20).contains { $0.action == .syncA })
    #expect(original.bindings(source: 20).filter { $0.action.hotcueSlot != nil }.count == 3)
}

@Test @MainActor func controllerPlayerEarlierModelsDispatchBesideA3000OnAllChannels() {
    for name in earlierPlayerNames {
        withEarlierPlayer(name) { input in
            #expect(input.playerDeck(source: 10) == .a && input.playerDeck(source: 20) == .b)
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            for channel: UInt8 in 0..<16 {
                earlierPacket(
                    [
                        0x90 | channel, 0, 127, 0, 0, 0x11, 127, 0x11, 0, 0x20, 127, 0x20, 0,
                        6, 127, 6, 0, 7, 127, 7, 0, 8, 127, 8, 0, 0x33, 127, 0x33, 0,
                    ], to: input)
            }
            let reloop: ControllerAction = name == "CDJ-400" ? .reloopOriginalB : .reloopB
            let expected: [ControllerActionTarget] = [
                .init(.playB, deck: .b), .init(.keylockB, deck: .b),
                .init(.jogTouchB, deck: .b), .init(.jogTouchB, deck: .b), .init(.loopInB, deck: .b),
                .init(.loopOutB, deck: .b), .init(reloop, deck: .b), .init(.loadB, deck: .b),
            ]
            #expect(targets == Array(repeating: expected, count: 16).flatMap { $0 })
            earlierPacket([0x90, 0, 127], to: input, source: 10)
            #expect(targets.last == .init(.playA, deck: .a))
        }
    }
}

@Test func controllerPlayerCDJ350ReverseSpeedUsesItsPublishedCurve() throws {
    func decode(_ value: Int) -> ControllerMIDIValue? {
        var state = ControllerMIDIValueState()
        return state.decode(
            .init(kind: .control, channel: 0, number: 16, value: value),
            encoding: .cdj350PlatterSpeed, number: 16)
    }
    #expect(decode(0) == .absolute(0))
    #expect(decode(63) == .absolute(0.4375))
    #expect(decode(64) == .absolute(0.5))
    #expect(decode(65) == .absolute(0.5 + 0.5 / 63))
    #expect(decode(127) == .absolute(1))
    #expect(!ControllerMIDIEncoding.cdj350PlatterSpeed.isRelative)
}

@Test @MainActor func controllerPlayerBrowseUsesTheCorrectEncoderForEachModel() {
    for name in earlierPlayerNames {
        withEarlierPlayer(name) { input in
            var detents: [Int] = []
            var actions: [ControllerAction] = []
            input.onTargetAction = { target, value in
                actions.append(target.action)
                if target.action == .browse { detents.append(Int(((value - 0.5) * 126).rounded())) }
            }
            let forward: UInt8 = name == "CDJ-400" ? 65 : 1
            let reverse: UInt8 = name == "CDJ-400" ? 63 : 127
            earlierPacket(
                [
                    0xBF, 0x4F, forward, 0x9F, 0x33, 127, 0x33, 0,
                    0xBF, 0x4F, reverse, 0x9F, 0x33, 127,
                ], to: input)
            #expect(detents == [1, -1])
            #expect(actions == [.browse, .loadB, .browse, .loadB])
        }
    }
}

@Test @MainActor func controllerPlayerXDJJumpPacketsRetainDifferentBeatCounts() {
    let fixtures: [(String, [UInt8], [Double])] = [
        ("XDJ-1000", [0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D], [1, 2, 4, -1, -2, -4]),
        ("XDJ-1000MK2", [0x38, 0x39, 0x3C, 0x3D, 0x44, 0x45], [1, -1, 2, -2, 32, -32]),
    ]
    for (name, notes, beats) in fixtures {
        withEarlierPlayer(name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            for note in notes { earlierPacket([0x90, note, 127, note, 0], to: input) }
            #expect(targets == beats.map { .init(.fixedJumpB, deck: .b, argument: $0) })
        }
    }
    withEarlierPlayer("XDJ-1000MK2") { input in
        var targets: [ControllerActionTarget] = []
        input.onTargetAction = { target, _ in targets.append(target) }
        earlierPacket([0x90, 0x3A, 127], to: input)
        #expect(targets.isEmpty)
    }
}

@Test @MainActor func controllerPlayerCDJ400BrowsePreservesFullReverseCounts() {
    withEarlierPlayer("CDJ-400") { input in
        var moved = 0
        var actions: [ControllerAction] = []
        input.onTargetAction = { target, value in
            actions.append(target.action)
            if target.action == .browse { moved += Int(((value - 0.5) * 126).rounded()) }
        }
        earlierPacket([0xB0, 0x4F, 0, 0x4F, 0, 0x90, 0x33, 127], to: input)
        #expect(moved == -128)
        #expect(actions.last == .loadB)
        #expect(actions.filter { $0 == .browse }.count == 3)
    }
}

@Test @MainActor func controllerPlayerLoopDivisionUsesOriginalLengthAndPreservesSync() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .b)
    await model.flushWrites()
    let sync = try #require(model.playbackSnapshot).b.synced
    model.applyController(.loopDivideA, value: 1, targetDeck: .b)
    let original = try #require(model.playbackSnapshot).b
    #expect(original.loopEnabled)
    model.applyController(.loopDivideA, value: 1, targetDeck: .b)
    model.applyController(.loopDivideA, value: 1, targetDeck: .b)
    #expect(model.playbackSnapshot?.b.loopEnd == original.loopStart + (original.loopEnd - original.loopStart) / 4)
    model.applyController(.loopRestoreA, value: 1, targetDeck: .b)
    #expect(model.playbackSnapshot?.b.loopEnd == original.loopEnd)
    model.applyController(.loopDivideA, value: 1, targetDeck: .b)
    model.applyController(.reloopOriginalA, value: 1, targetDeck: .b)
    #expect(model.playbackSnapshot?.b.loopEnabled == false)
    model.applyController(.reloopOriginalA, value: 1, targetDeck: .b)
    #expect(model.playbackSnapshot?.b.loopEnabled == true)
    #expect(model.playbackSnapshot?.b.loopEnd == original.loopEnd)
    #expect(model.playbackSnapshot?.b.synced == sync)
    #expect(model.playbackSnapshot?.a.loopEnabled == false)
}
