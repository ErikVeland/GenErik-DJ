import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func controllerCDJSpeedAndNeedleDecodePublishedBoundaries() throws {
    func decode(_ value: UInt8, _ encoding: ControllerMIDIEncoding) throws -> ControllerMIDIValue? {
        var decoder = ControllerMIDIDecoder()
        var state = ControllerMIDIValueState()
        return state.decode(try #require(decoder.append([0xBF, 16, value]).first), encoding: encoding, number: 16)
    }
    for encoding in [ControllerMIDIEncoding.cdjPlatterSpeed, .cdjRingSpeed, .cdjTempo] {
        #expect(try decode(0, encoding) == .absolute(0))
        #expect(try decode(64, encoding) == .absolute(0.5))
        #expect(try decode(127, encoding) == .absolute(1))
        #expect(!encoding.isRelative)
    }
    #expect(try decode(65, .cdjRingSpeed) == .absolute(0.5625))
    #expect(try decode(63, .cdjRingSpeed) == .absolute(0.4375))
    #expect(try decode(65, .cdjPlatterSpeed) == .absolute(0.5 + 0.5 / 63))
    #expect(try decode(63, .cdjPlatterSpeed) == .absolute(0.5 - 0.5 / 64))
    #expect(try decode(0, .needlePosition) == nil)
    #expect(try decode(1, .needlePosition) == .absolute(0))
    #expect(try decode(64, .needlePosition) == .absolute(0.5))
    #expect(try decode(127, .needlePosition) == .absolute(1))
}

@Test func controllerCDJAssignmentsKeepConnectedDecksAndBoundCapacity() {
    let allocate = ControllerPlayerAssignment.allocate
    #expect(allocate([20, 10], [:], [:], [.a, .b]) == [10: .a, 20: .b])
    #expect(allocate([5, 20], [20: .b], [5: .b], [.a, .b]) == [5: .a, 20: .b])
    #expect(allocate([20], [20: .b], [:], [.a, .b]) == [20: .b])
    #expect(allocate([10, 20, 30], [:], [:], [.a, .b]) == [10: .a, 20: .b])
    #expect(allocate([10, 20, 30, 40], [:], [:], DeckID.allCases) == [10: .a, 20: .b, 30: .c, 40: .d])
    #expect(allocate([10, 20], [:], [10: .b, 20: .a], [.a, .b]) == [10: .b, 20: .a])
    #expect(allocate([10], [:], [10: .d], [.a, .b]) == [10: .a])
}

@MainActor private func cdjSource(_ id: Int32, _ name: String = "CDJ-3000") -> ControllerMIDIConnection.Source {
    .init(id: id, reference: UInt32(id * 10), name: name, identity: .init(id: id, device: UInt32(id), names: [name]))
}

@MainActor private func withCDJs(_ body: (ControllerMIDIConnection, UserDefaults) throws -> Void) rethrows {
    let suite = "cdj-profile-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let controller = ControllerMIDIConnection(preferences: preferences)
    controller.sources = [cdjSource(10), cdjSource(20)]
    controller.reconcileFactoryProfiles()
    try body(controller, preferences)
}

@MainActor private func sendCDJ(_ bytes: [UInt8], source: Int32, to controller: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { controller.receive(message, source: source) }
}

@Test @MainActor func controllerCDJMatchesExactModelsAndKeepsTheirNoteTablesSeparate() throws {
    for name in ["CDJ-3000", "CDJ-3000X", "CDJ-2000NXS2", "CDJ-1500X", "CDJ-2000NXS", "CDJ-900NXS"] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.isPlayer)
        #expect(profile.definition?.outputs.isEmpty == true)
        #expect(profile.bindings(source: 10).allSatisfy { $0.anyChannel == true })
    }
    #expect(ControllerFactoryProfile.matching(["CDJ-3000 clone"], automaticOnly: true) == nil)
    #expect(
        ControllerFactoryProfile.matching(["Pioneer CDJ-2000nexus"], automaticOnly: true)?.rawValue
            == "Pioneer CDJ-2000NXS")
    #expect(ControllerFactoryProfile.matching(["CDJ-900nexus"], automaticOnly: true)?.rawValue == "Pioneer CDJ-900NXS")
    let modern = try #require(ControllerFactoryProfile.matching(["CDJ-3000"]))
    let older = try #require(ControllerFactoryProfile.matching(["CDJ-2000NXS2"]))
    #expect(modern.bindings(source: 10).first { $0.action == .jogTouchA }?.number == 0x17)
    #expect(older.bindings(source: 10).first { $0.action == .jogTouchA }?.number == 0x20)
    #expect(modern.bindings(source: 10).first { $0.action == .hotcue6A }?.number == 0x20)
    #expect(older.bindings(source: 10).first { $0.action == .hotcue6A }?.number == 0x15)
    let compact = try #require(ControllerFactoryProfile.matching(["CDJ-900NXS"]))
    #expect(
        !compact.bindings(source: 10).contains {
            $0.action.hotcueSlot != nil || $0.action == .tempoResetA || $0.action == .seekA
        })
    let nxs = try #require(ControllerFactoryProfile.matching(["CDJ-2000NXS"]))
    #expect(nxs.bindings(source: 10).filter { $0.action.hotcueSlot != nil }.count == 3)
    let latest = try #require(ControllerFactoryProfile.matching(["CDJ-1500X"]))
    #expect(latest.bindings(source: 10).filter { $0.action == .fixedLoopA }.map(\.argument) == [0.5, 1, 2, 4, 8, 16])
    #expect(
        !latest.bindings(source: 10).contains { $0.action == .tempoResetA || ($0.kind == .note && $0.number == 0x2F) })
}

@Test @MainActor func controllerCDJSameChannelPlayersControlSeparateDecksOnAllChannels() {
    withCDJs { controller, _ in
        var targets: [ControllerActionTarget] = []
        controller.onTargetAction = { target, _ in targets.append(target) }
        for channel in UInt8(0)..<16 {
            for source: Int32 in [10, 20] {
                sendCDJ([0x90 | channel, 0, 127, 0, 0, 0x11, 127, 0x11, 0], source: source, to: controller)
            }
        }
        let pair: [ControllerActionTarget] = [
            .init(.playA, deck: .a), .init(.loadA, deck: .a),
            .init(.playB, deck: .b), .init(.loadB, deck: .b),
        ]
        #expect(targets == Array(repeating: pair, count: 16).flatMap { $0 })
    }
}

@Test @MainActor func controllerCDJFactoryPacketsDispatchForEachGeneration() {
    let fixtures: [(String, [UInt8])] = [
        ("CDJ-3000", [0x0B, 0x16, 0x17, 0x23, 0x24, 0x11]),
        ("CDJ-3000X", [0x0B, 0x16, 0x17, 0x23, 0x24, 0x11]),
        ("CDJ-2000NXS2", [0x11, 0x1F, 0x20, 0x06, 0x07, 0x33]),
        ("CDJ-1500X", [0x0B, 0x16, 0x17, 0x23, 0x24, 0x11]),
        ("CDJ-2000NXS", [0x11, 0x1F, 0x20, 0x06, 0x07, 0x33]),
        ("CDJ-900NXS", [0x11, 0x1F, 0x20, 0x06, 0x07, 0x33]),
    ]
    for (name, notes) in fixtures {
        withCDJs { controller, _ in
            controller.sources = [cdjSource(10, name)]
            controller.reconcileFactoryProfiles()
            var targets: [ControllerActionTarget] = []
            controller.onTargetAction = { target, _ in targets.append(target) }
            for note in notes { sendCDJ([0x9F, note, 127, note, 0], source: 10, to: controller) }
            #expect(
                targets == [
                    .init(.keylockA, deck: .a), .init(.syncA, deck: .a),
                    .init(.jogTouchA, deck: .a), .init(.jogTouchA, deck: .a),
                    .init(.loopInA, deck: .a), .init(.loopOutA, deck: .a), .init(.loadA, deck: .a),
                ])
        }
    }
}

@Test @MainActor func controllerCDJReconnectAndSavedAssignmentsKeepDeckB() {
    withCDJs { controller, preferences in
        controller.sources = [cdjSource(20)]
        controller.reconcileFactoryProfiles()
        #expect(controller.playerDeck(source: 20) == .b)
        controller.sources = [cdjSource(10), cdjSource(20)]
        controller.reconcileFactoryProfiles()
        #expect(controller.playerDeck(source: 10) == .a)
        #expect(controller.playerDeck(source: 20) == .b)
        controller.setPlayerDeck(.b, source: 10)
        #expect(controller.playerDeck(source: 10) == .b)
        #expect(controller.playerDeck(source: 20) == .a)
        let reopened = ControllerMIDIConnection(preferences: preferences)
        reopened.sources = controller.sources
        reopened.reconcileFactoryProfiles()
        #expect(reopened.playerDeck(source: 10) == .b)
        #expect(reopened.playerDeck(source: 20) == .a)
        reopened.sources.append(cdjSource(30))
        reopened.reconcileFactoryProfiles()
        #expect(!reopened.isInputActive(30))
    }
}

@Test @MainActor func controllerCDJDeckSwapReleasesHeldTouchAndAcceptsTheNextPress() {
    withCDJs { controller, _ in
        var events: [(ControllerActionTarget, Double)] = []
        controller.onTargetAction = { events.append(($0, $1)) }
        sendCDJ([0x90, 0x17, 127, 0, 127], source: 10, to: controller)
        controller.setPlayerDeck(.b, source: 10)
        #expect(events.contains { $0.0 == .init(.jogTouchA, deck: .a) && $0.1 == 0 })
        #expect(events.contains { $0.0 == .init(.wheelJogA, deck: .a) && $0.1 == 0.5 })
        events.removeAll()
        sendCDJ([0x90, 0x17, 127, 0, 127], source: 10, to: controller)
        #expect(events.map(\.0) == [.init(.jogTouchB, deck: .b), .init(.playB, deck: .b)])
        controller.sources = [cdjSource(20)]
        controller.reconcileFactoryProfiles()
        #expect(events.contains { $0.0 == .init(.jogTouchB, deck: .b) && $0.1 == 0 })
    }
}

@Test @MainActor func controllerCDJFixedButtonsCarryTheirOwnBeatCount() throws {
    try withCDJs { controller, _ in
        var targets: [ControllerActionTarget] = []
        controller.onTargetAction = { target, _ in targets.append(target) }
        sendCDJ([0x90, 0x2C, 127, 0x36, 127, 0x37, 127, 0x46, 127], source: 20, to: controller)
        #expect(
            targets == [
                .init(.fixedLoopB, deck: .b, argument: 4), .init(.fixedJumpB, deck: .b, argument: 16),
                .init(.fixedJumpB, deck: .b, argument: -16), .init(.fixedJumpB, deck: .b, argument: 64),
            ])
        let x = try #require(ControllerFactoryProfile.matching(["CDJ-3000X"]))
        #expect(!x.bindings(source: 10).contains { $0.kind == .note && [0x26, 0x27].contains($0.number) })
    }
}

@Test @MainActor func controllerCDJDisablingOnePlayerPreservesItsPartnerAndSavedChoice() {
    withCDJs { controller, preferences in
        controller.setInputActive(10, active: false)
        #expect(!controller.isInputActive(10))
        #expect(controller.isInputActive(20))
        #expect(controller.playerDeck(source: 20) == .b)
        let reopened = ControllerMIDIConnection(preferences: preferences)
        reopened.sources = controller.sources
        reopened.reconcileFactoryProfiles()
        #expect(!reopened.isInputActive(10))
        #expect(reopened.playerDeck(source: 20) == .b)
        reopened.setInputActive(10, active: true)
        #expect(reopened.isInputActive(10))
        #expect(reopened.playerDeck(source: 10) == .a)
    }
}

@Test @MainActor func controllerCDJLearningReplacesWildcardWithoutASecondAction() {
    withCDJs { controller, preferences in
        controller.select(20)
        controller.learning = .cueReturnB
        sendCDJ([0x94, 0, 127], source: 20, to: controller)
        var targets: [ControllerActionTarget] = []
        controller.onTargetAction = { target, _ in targets.append(target) }
        sendCDJ([0x94, 0, 0, 0, 127], source: 20, to: controller)
        #expect(targets == [.init(.cueReturnB)])
        #expect(controller.bindingName(.playB) == "Unassigned")
        #expect(!ControllerAction.fixedLoopA.isLearnable && !ControllerAction.fixedJumpB.isLearnable)
        let reopened = ControllerMIDIConnection(preferences: preferences)
        reopened.sources = controller.sources
        reopened.reconcileFactoryProfiles()
        var restored: [ControllerActionTarget] = []
        reopened.onTargetAction = { target, _ in restored.append(target) }
        sendCDJ([0x90, 0, 127], source: 10, to: reopened)
        sendCDJ([0x94, 0, 127], source: 20, to: reopened)
        #expect(restored == [.init(.playA, deck: .a), .init(.cueReturnB)])
    }
}

@Test @MainActor func controllerCDJLearnedProfileDefaultsFollowADeckSwap() {
    withCDJs { controller, _ in
        controller.select(20)
        controller.learning = .cueReturnB
        sendCDJ([0x94, 100, 127], source: 20, to: controller)
        controller.setPlayerDeck(.a, source: 20)
        var targets: [ControllerActionTarget] = []
        controller.onTargetAction = { target, _ in targets.append(target) }
        sendCDJ([0x90, 0, 127], source: 20, to: controller)
        sendCDJ([0x94, 100, 0, 100, 127], source: 20, to: controller)
        #expect(targets == [.init(.playA, deck: .a), .init(.cueReturnB)])
    }
}

@Test func controllerCDJRejectsUnsafeProfileArgumentsAndChannelWildcards() throws {
    let base: [String: Any] = [
        "kind": "note", "channel": 0, "encoding": "absolute", "inverted": false,
        "anyChannel": true, "targetDeck": "a",
    ]
    let inputs = [
        base.merging(["action": "fixedLoopA", "number": 1, "argument": 4]) { _, new in new },
        base.merging(["action": "fixedJumpA", "number": 2, "argument": 16]) { _, new in new },
    ]
    let player: [String: Any] = [
        "id": "CDJ fixture", "aliases": ["CDJ fixture"], "role": "player", "inputs": inputs,
        "outputs": [], "startup": [], "shutdown": [], "autoSelect": true,
        "scope": "Protocol fixture", "source": "manufacturer",
    ]
    let valid = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [player]])
    #expect(try ControllerProfileCatalogue.decode(valid).profiles.count == 1)
    for mutation in ["unknown-role", "unscoped-channel", "missing-loop-argument", "unbounded-jump"] {
        var bad = player
        var inputs = try #require(bad["inputs"] as? [[String: Any]])
        switch mutation {
        case "unknown-role": bad["role"] = "unknown"
        case "unscoped-channel": bad.removeValue(forKey: "role")
        case "missing-loop-argument":
            let index = try #require(inputs.firstIndex { $0["action"] as? String == "fixedLoopA" })
            inputs[index].removeValue(forKey: "argument")
        default:
            let index = try #require(inputs.firstIndex { $0["action"] as? String == "fixedJumpA" })
            inputs[index]["argument"] = 65
        }
        bad["inputs"] = inputs
        let encoded = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [bad]])
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(encoded) }
    }
}

@Test @MainActor func controllerCDJFixedLoopAndJumpUseNativeTimingWithoutChangingSync() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first, "\(model.status). Fixture root: \(base.path)")
    model.load(trackID: track.id, deck: .b)
    await model.flushWrites()
    let sync = try #require(model.playbackSnapshot).b.synced
    let grid = try #require(model.grid(.b))
    let start = try #require(model.playbackSnapshot?.b.sourceFrame)
    model.setLoopSize(1, deck: .b)
    model.applyController(.fixedJumpA, value: 1, targetDeck: .b, argument: 4)
    #expect(abs((model.playbackSnapshot?.b.sourceFrame ?? 0) - start - 4 * grid.framesPerBeat) < 1)
    model.applyController(.fixedLoopA, value: 1, targetDeck: .b, argument: 4)
    #expect(model.performance.loopBeats(for: .b) == 4)
    #expect(model.playbackSnapshot?.b.loopEnabled == true)
    model.applyController(.fixedLoopA, value: 1, targetDeck: .b, argument: 8)
    #expect(model.playbackSnapshot?.b.loopEnabled == true)
    #expect(model.performance.loopBeats(for: .b) == 8)
    model.applyController(.tempoResetA, value: 1, targetDeck: .b)
    #expect(model.playbackSnapshot?.b.synced == sync)
    #expect(model.playbackSnapshot?.a.loopEnabled == false)
    model.toggleLoop(deck: .b)
    model.applyController(.seekA, value: 0.25, targetDeck: .b)
    let loopStart = try #require(model.playbackSnapshot?.b.sourceFrame)
    model.applyController(.loopInA, value: 1, targetDeck: .b)
    model.applyController(.fixedJumpA, value: 1, targetDeck: .b, argument: 2)
    model.applyController(.loopOutA, value: 1, targetDeck: .b)
    let loop = try #require(model.playbackSnapshot).b
    #expect(loop.loopEnabled)
    #expect(abs(loop.loopStart - loopStart) < 1)
    #expect(abs(loop.loopEnd - loopStart - 2 * grid.framesPerBeat) < 1)
    #expect(loop.synced == sync)
    model.applyController(.reloopA, value: 1, targetDeck: .b)
    #expect(model.playbackSnapshot?.b.loopEnabled == false)
    model.applyController(.reloopA, value: 1, targetDeck: .b)
    #expect(model.playbackSnapshot?.b.loopEnabled == true)
    #expect(model.playbackSnapshot?.b.loopStart == loop.loopStart)
    #expect(model.playbackSnapshot?.b.loopEnd == loop.loopEnd)
    model.applyController(.reloopA, value: 1, targetDeck: .b)
    model.controllerLoopStarts[.b] = (loop.generation + 1, 0)
    model.applyController(.loopOutA, value: 1, targetDeck: .b)
    #expect(model.playbackSnapshot?.b.loopEnabled == false)
}
