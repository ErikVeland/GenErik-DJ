import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@MainActor private final class TimedSetupProbe {
    struct Packet {
        let bytes: [UInt8]
        let destination: Int32
        let began: UInt64
        let ended: UInt64
    }
    var now: UInt64 = 0
    var sendCost: UInt64 = 0
    var failAt: Int?
    var canConnect = true
    var packets: [Packet] = []
    private var counts: [Int32: Int] = [:]

    func send(_ bytes: [UInt8], destination: Int32) -> Bool {
        let began = now
        now += sendCost
        packets.append(.init(bytes: bytes, destination: destination, began: began, ended: now))
        counts[destination, default: 0] += 1
        return destination != 20 || counts[destination] != failAt
    }

    func tick(_ input: ControllerMIDIConnection, milliseconds: UInt64 = 20) {
        now += milliseconds * 1_000_000
        input.advanceFactorySetups()
    }

    func finish(_ input: ControllerMIDIConnection) {
        for _ in 0..<20 { tick(input) }
    }
}

@MainActor private func withTimedSetup(
    paired: Bool = true, twoSources: Bool = false, failAt: Int? = nil, canConnect: Bool = true,
    sendCost: UInt64 = 0, _ body: (ControllerMIDIConnection, TimedSetupProbe) throws -> Void
) rethrows {
    let suite = "timed-setup-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let probe = TimedSetupProbe()
    probe.failAt = failAt
    probe.canConnect = canConnect
    probe.sendCost = sendCost
    let input = ControllerMIDIConnection(
        preferences: preferences, factoryPacketSender: { probe.send($0, destination: $1) },
        factoryInputConnector: { _ in probe.canConnect }, factorySetupClock: { probe.now })
    input.sources = [
        .init(
            id: 10, reference: 100, name: "Stanton SCS.3m",
            identity: .init(id: 10, device: 1, names: ["Stanton SCS.3m"]))
    ]
    if paired {
        input.destinations = [
            .init(
                id: 20, reference: 200, name: "Stanton SCS.3m",
                identity: .init(id: 20, device: 1, names: ["Stanton SCS.3m"]))
        ]
    }
    if twoSources {
        input.sources.append(
            .init(
                id: 11, reference: 101, name: "Stanton SCS.3m",
                identity: .init(id: 11, device: 2, names: ["Stanton SCS.3m"])))
        input.destinations.append(
            .init(
                id: 21, reference: 201, name: "Stanton SCS.3m",
                identity: .init(id: 21, device: 2, names: ["Stanton SCS.3m"])))
    }
    input.reconcileFactoryProfiles()
    try body(input, probe)
}

@Test @MainActor func controllerTimedSetupWaitsAfterSendCompletionAndAfterTheLastModePair() {
    withTimedSetup(sendCost: 3_000_000) { input, probe in
        #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20))
        #expect(probe.packets.map(\.bytes) == [[0xF0, 0, 1, 96, 21, 1, 0xF7]])
        for _ in 0..<10 where probe.packets.count < 9 { probe.tick(input) }
        #expect(probe.packets.count == 9 && !input.isInputActive(10))
        for index in [1, 3, 5, 7] {
            #expect(probe.packets[index].began >= probe.packets[index - 1].ended + 20_000_000)
        }
        let ready = (probe.packets.last?.ended ?? 0) + 20_000_000
        probe.now = ready - 1
        input.advanceFactorySetups()
        #expect(!input.isInputActive(10))
        probe.now = ready
        input.advanceFactorySetups()
        #expect(input.isInputActive(10) && input.factoryOutputIsReady(20))
    }
}

@Test @MainActor func controllerTimedSetupLatePollingCannotBurstThroughWaitsOrDispatchEarlyFrames() {
    withTimedSetup { input, probe in
        input.select(10)
        #expect(!input.isInputActive(10))
        probe.tick(input, milliseconds: 500)
        #expect(probe.packets.count == 3 && !input.isInputActive(10))
        input.advanceFactorySetups()
        #expect(probe.packets.count == 3)
        for _ in 0..<3 { probe.tick(input) }
        #expect(probe.packets.count == 9 && !input.isInputActive(10))
        let ready = (probe.packets.last?.ended ?? 0) + 20_000_000
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        #expect(input.receiveBytes([0x90, 8, 127], source: 10, timestamp: ready - 1) == 0)
        probe.now = ready + 500_000_000
        input.advanceFactorySetups()
        #expect(input.isInputActive(10))
        #expect(input.receiveBytes([0x90, 8, 127], source: 10, timestamp: ready - 1) == 0)
        input.receiveBytes([0x90, 8, 127, 8, 0], source: 10, timestamp: ready + 1)
        input.flushPendingActions()
        #expect(actions == [.cueA])
    }
}

@Test @MainActor func controllerTimedSetupEverySendFailureStaysInactiveUntilExplicitRetry() {
    for failure in 1...9 {
        withTimedSetup(failAt: failure) { input, probe in
            input.select(10)
            probe.finish(input)
            #expect(probe.packets.count == failure)
            #expect(!input.isInputActive(10) && !input.factoryOutputIsReady(20))
            var actions: [ControllerAction] = []
            input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
            input.receiveBytes([0x90, 8, 127, 8, 0], source: 10)
            input.flushPendingActions()
            #expect(actions.isEmpty)
            input.reconcileFactoryProfiles()
            probe.finish(input)
            #expect(input.isInputActive(10))
            #expect(probe.packets.count == failure + 9)
        }
    }
}

@Test @MainActor func controllerTimedSetupSourcesRemainIndependentWhenOneOutputFails() {
    withTimedSetup(twoSources: true, failAt: 3) { input, probe in
        probe.finish(input)
        #expect(!input.isInputActive(10) && input.isInputActive(11))
        #expect(!input.factoryOutputIsReady(20) && input.factoryOutputIsReady(21))
        #expect(probe.packets.filter { $0.destination == 20 }.count == 3)
        #expect(probe.packets.filter { $0.destination == 21 }.count == 9)
    }
}

@Test @MainActor func controllerTimedSetupCancelsOnDisconnectDisableAndStopAndRestartsFromFlatMode() {
    withTimedSetup { input, probe in
        probe.tick(input)
        let sources = input.sources
        input.sources = []
        input.reconcileFactoryProfiles()
        let count = probe.packets.count
        probe.finish(input)
        #expect(probe.packets.count == count && !input.factoryOutputIsReady(20))
        input.sources = sources
        input.reconcileFactoryProfiles()
        #expect(probe.packets.last?.bytes == [0xF0, 0, 1, 96, 21, 1, 0xF7])
        input.setInputActive(10, active: false)
        let disabledCount = probe.packets.count
        probe.finish(input)
        #expect(probe.packets.count == disabledCount && !input.isInputActive(10))
        input.setInputActive(10, active: true)
        #expect(!input.isInputActive(10))
        probe.finish(input)
        #expect(input.isInputActive(10))
    }
    withTimedSetup { input, probe in
        input.select(10)
        input.stop()
        let count = probe.packets.count
        probe.finish(input)
        #expect(probe.packets.count == count && !input.isInputActive(10))
    }
}

@Test @MainActor func controllerTimedSetupRequiresAConnectedInputAndPairedAutomaticOutput() throws {
    try withTimedSetup(paired: false) { input, probe in
        input.select(10)
        input.applyFactoryProfile(try #require(ControllerFactoryProfile.matching(["Stanton SCS.3m"])))
        #expect(probe.packets.isEmpty && !input.isInputActive(10))
        #expect(input.status.lowercased().contains("setup"))
    }
    withTimedSetup(canConnect: false) { input, probe in
        #expect(probe.packets.isEmpty && !input.isInputActive(10))
        probe.canConnect = true
        input.reconcileFactoryProfiles()
        probe.finish(input)
        #expect(input.isInputActive(10))
    }
}

@Test @MainActor func controllerTimedSetupSCS3mRoutesAllFixedMixerInputsAndGuardsEveryModifier() {
    withTimedSetup { input, probe in
        probe.finish(input)
        input.currentTargetValue = { _ in 0.5 }
        var actions: [ControllerAction] = []
        input.onAction = { action, _ in if !action.isJog { actions.append(action) } }
        let controls: [(UInt8, ControllerAction)] = [
            (0, .filterKnobA), (1, .filterKnobB), (2, .lowA), (3, .lowB), (4, .midA),
            (5, .midB), (6, .highA), (7, .highB), (8, .levelA), (9, .levelB), (10, .crossfader),
        ]
        for (number, action) in controls {
            actions.removeAll()
            input.receiveBytes([0xB0, number, 64], source: 10)
            input.flushPendingActions()
            #expect(actions == [action])
        }
        for note: UInt8 in [0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15, 16] {
            actions.removeAll()
            input.receiveBytes([0x90, note, 127, 0xB0, 8, 127], source: 10)
            input.flushPendingActions()
            #expect(actions.isEmpty)
            input.receiveBytes([0x80, note, 127, 0xB0, 8, 64], source: 10)
            input.flushPendingActions()
            #expect(actions == [.levelA])
        }
        actions.removeAll()
        input.receiveBytes([0x90, 8, 127, 8, 0, 9, 127, 9, 0], source: 10)
        input.flushPendingActions()
        #expect(actions == [.cueA, .cueB])
    }
}

@Test func controllerTimedSetupRejectsUnboundedOrMismatchedDelayMetadata() throws {
    func valid(_ delays: [Int]) throws -> Bool {
        let data = try JSONSerialization.data(withJSONObject: [
            "id": "delay-test", "aliases": ["delay-test"],
            "inputs": [
                [
                    "action": "master", "kind": "control", "channel": 0, "number": 1, "encoding": "absolute",
                    "inverted": false,
                ]
            ],
            "outputs": [], "startup": [[0xB0, 1, 0], [0xB0, 2, 0]], "shutdown": [],
            "autoSelect": true, "scope": "test", "source": "test", "startupDelaysMilliseconds": delays,
        ])
        return try JSONDecoder().decode(ControllerProfileData.self, from: data).isValid
    }
    #expect(try valid([0, 20]))
    #expect(try !valid([]))
    #expect(try !valid([20]))
    #expect(try !valid([20, 1001]))
}
