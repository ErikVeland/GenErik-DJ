import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private let loopPadCases: [(name: String, mode: UInt8, sizes: [Double])] = [
    ("Party Mix", 11, [4, 8, 16, 32]),
    ("Party Mix II", 14, [2, 4, 8, 16]),
    ("Mixtrack Pro FX", 13, [0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8]),
]

@MainActor private func withLoopPads(_ name: String, body: (ControllerMIDIConnection) throws -> Void) rethrows {
    let suite = "loop-pads-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let input = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in true })
    input.sources = [.init(id: 10, reference: 100, name: name, identity: .init(id: 10, device: 1, names: [name]))]
    input.destinations = [.init(id: 20, reference: 200, name: name, identity: .init(id: 20, device: 1, names: [name]))]
    input.reconcileFactoryProfiles()
    try body(input)
}

@MainActor private func loopPadPacket(_ bytes: [UInt8], to input: ControllerMIDIConnection) {
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append(bytes) { input.receive(message, source: 10) }
}

@Test @MainActor func controllerCatalogueLoopPadModesRetainDistinctSizesAndKeepCueStateSeparate() {
    for item in loopPadCases {
        withLoopPads(item.name) { input in
            var targets: [ControllerActionTarget] = []
            input.onTargetAction = { target, _ in targets.append(target) }
            loopPadPacket([0x94, item.mode, 127], to: input)
            for slot in item.sizes.indices {
                loopPadPacket([0x94, UInt8(20 + slot), 127], to: input)
                #expect(targets.last == .init(.toggleFixedLoopA, deck: .a, argument: item.sizes[slot]))
            }
            #expect(targets.count == item.sizes.count)
            loopPadPacket([0x95, 20, 127], to: input)
            #expect(targets.last == .init(.hotcue1B, deck: .b))
            loopPadPacket([0x94, 0, 127, 0x84, 20, 0, 0x94, 20, 127], to: input)
            #expect(targets.last == .init(.hotcue1A, deck: .a))
        }
    }
}

@Test @MainActor func controllerCatalogueLoopPadModeBlocksUnsupportedHeldAndShiftedRollGestures() {
    withLoopPads("Party Mix II") { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        loopPadPacket([0x94, 14, 127, 0x9F, 50, 127, 0x94, 20, 127], to: input)
        #expect(actions.isEmpty)
        loopPadPacket([0x8F, 50, 0, 0x84, 20, 0, 0x94, 20, 127], to: input)
        #expect(actions == [.toggleFixedLoopA])
    }
    withLoopPads("Mixtrack Pro FX") { input in
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in actions.append(action) }
        loopPadPacket([0x94, 13, 127, 28, 127, 35, 127], to: input)
        #expect(actions.isEmpty)
    }
}

@Test @MainActor func controllerCatalogueLoopPadSwitchesSizeKeepsSyncAndExitsOnlyTheMatchingActiveLoop() async throws {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    let sync = try #require(model.playbackSnapshot?.a.synced as Bool?)
    let grid = try #require(model.timing(.a))
    withLoopPads("Party Mix II") { input in
        input.onTargetAction = { target, value in
            model.applyController(target.action, value: value, targetDeck: target.deck, argument: target.argument)
        }
        loopPadPacket([0x94, 14, 127, 20, 127], to: input)
        #expect(model.performance.loopBeats(for: .a) == 2)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        loopPadPacket([0x94, 21, 127], to: input)
        #expect(model.performance.loopBeats(for: .a) == 4)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        loopPadPacket([0x84, 21, 0, 0x94, 21, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == false)
        loopPadPacket([0x84, 21, 0, 0x94, 21, 127], to: input)
        let start = model.playbackSnapshot?.a.loopStart ?? 0
        model.setLoop(start: start, end: start + grid.span(beats: 6, from: start), deck: .a)
        loopPadPacket([0x84, 21, 0, 0x94, 21, 127], to: input)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
        let span = (model.playbackSnapshot?.a.loopEnd ?? 0) - (model.playbackSnapshot?.a.loopStart ?? 0)
        #expect(abs(span - grid.span(beats: 4, from: start)) <= 1)
        #expect(model.playbackSnapshot?.a.synced == sync)
        model.applyController(.toggleFixedLoopA, value: 1, argument: 3)
        model.applyController(.toggleFixedLoopA, value: 1, argument: .nan)
        #expect(model.performance.loopBeats(for: .a) == 4)
        #expect(model.playbackSnapshot?.a.loopEnabled == true)
    }
}

@Test func controllerCatalogueLoopPadRequiresAValidBoundedBeatArgument() throws {
    #expect(!ControllerAction.toggleFixedLoopA.isLearnable)
    #expect(!ControllerAction.toggleFixedLoopB.isLearnable)
    for beats in [0.0, 0.03125, 0.0625, 3, 4, 32, 64] {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "profiles": [
                [
                    "id": "loop fixture", "aliases": ["loop fixture"],
                    "inputs": [
                        [
                            "action": "toggleFixedLoopA", "kind": "note", "channel": 4, "number": 20,
                            "encoding": "absolute", "inverted": false, "argument": beats,
                        ]
                    ],
                    "outputs": [], "startup": [], "shutdown": [], "autoSelect": true, "scope": "fixture",
                    "source": "fixture",
                ]
            ],
        ])
        if PerformancePreparation.loopSizes.contains(beats) {
            #expect(try ControllerProfileCatalogue.decode(data).profiles.count == 1)
        } else {
            #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
        }
    }
}
