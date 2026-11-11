import Foundation
import TDJCore
import Testing

@testable import TDJInterface

private func endpoint(_ id: Int32, device: UInt32 = 1, name: String = "DDJ-FLX4") -> ControllerFactoryEndpoint {
    .init(id: id, device: device, names: [name])
}

@Test func controllerFactoryMatchingPreservesModelBoundaries() {
    #expect(ControllerFactoryProfile.matching(["Pioneer DJ DDJ-FLX4"]) == .flx4)
    #expect(ControllerFactoryProfile.matching(["AlphaTheta DDJ-FLX2"]) == .flx2)
    #expect(ControllerFactoryProfile.matching(["DDJ-1000SRT"]) == nil)
    #expect(ControllerFactoryProfile.matching(["DDJ-FLX4 simulator"]) == nil)
    #expect(ControllerFactoryProfile.matching(["DDJ-FLX4", "DDJ-FLX2"]) == nil)
}

@Test func controllerFactoryPairsPortsOnTheSamePhysicalDevice() {
    let sessions = ControllerFactorySession.discover(
        sources: [endpoint(10), endpoint(20, device: 2)],
        destinations: [endpoint(30, device: 2), endpoint(40)], disabled: [])
    #expect(sessions.map(\.source) == [10, 20])
    #expect(sessions.map(\.destination) == [40, 30])
}

@Test func controllerFactoryRejectsVirtualAndAmbiguousInputs() {
    for sources in [[endpoint(10, device: 0)], [endpoint(10), endpoint(11)]] {
        #expect(ControllerFactorySession.discover(sources: sources, destinations: [], disabled: []).isEmpty)
    }
    #expect(
        ControllerFactorySession.discover(
            sources: [endpoint(10)], destinations: [], disabled: [.flx4]
        ).isEmpty)
}

@Test func controllerFactoryDoesNotGuessFeedbackPorts() {
    let ambiguous = ControllerFactorySession.discover(
        sources: [endpoint(10)], destinations: [endpoint(20), endpoint(21)], disabled: [])
    #expect(ambiguous.first?.destination == nil)
    let otherDevice = ControllerFactorySession.discover(
        sources: [endpoint(10)], destinations: [endpoint(20, device: 2)], disabled: [])
    #expect(otherDevice.first?.destination == nil)
    #expect(
        ControllerFactorySession.discover(
            sources: [endpoint(10)], destinations: [endpoint(20, name: "DDJ-FLX2")], disabled: []
        ).isEmpty)
}

@MainActor private func withController(_ body: (ControllerMIDIConnection, UserDefaults) throws -> Void) rethrows {
    let name = "controller-factory-test-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: name)!
    defer { preferences.removePersistentDomain(forName: name) }
    let controller = ControllerMIDIConnection(preferences: preferences)
    controller.sources = [.init(id: 10, reference: 100, name: "DDJ-FLX4", identity: endpoint(10))]
    controller.destinations = [.init(id: 20, reference: 200, name: "DDJ-FLX4", identity: endpoint(20))]
    controller.reconcileFactoryProfiles()
    try body(controller, preferences)
}

@Test @MainActor func controllerFactoryWorksWithoutASelectedInputAndRebindsAfterReconnect() throws {
    try withController { controller, _ in
        #expect(controller.selected == nil)
        #expect(controller.isInputActive(10))
        var actions: [ControllerAction] = []
        controller.onAction = { action, _ in actions.append(action) }
        var decoder = ControllerMIDIDecoder()
        let play = try #require(decoder.append([0x90, 11, 127]).first)
        controller.receive(play, source: 10)
        #expect(actions == [.playA])
        controller.sources = [.init(id: 11, reference: 101, name: "DDJ-FLX4", identity: endpoint(11))]
        controller.destinations = [.init(id: 21, reference: 201, name: "DDJ-FLX4", identity: endpoint(21))]
        controller.reconcileFactoryProfiles()
        #expect(!controller.isInputActive(10))
        #expect(controller.isInputActive(11))
        controller.receive(play, source: 10)
        controller.receive(play, source: 11)
        #expect(actions == [.playA, .playA])
        controller.sources = []
        controller.destinations = []
        controller.reconcileFactoryProfiles()
        #expect(!controller.isInputActive(11))
    }
}

@Test @MainActor func controllerFactoryPreservesCustomInputAndFeedbackBindings() throws {
    try withController { controller, preferences in
        let custom = ControllerBinding(
            source: 10, group: 0, channel: 0, kind: .note, number: 11,
            parameter: nil, noteNumber: nil, action: .playB, encoding: .absolute, inverted: false, shifted: false)
        preferences.set(try JSONEncoder().encode([custom]), forKey: "controllers.midiBindings.v1")
        let restored = ControllerMIDIConnection(preferences: preferences)
        restored.sources = controller.sources
        restored.destinations = controller.destinations
        restored.reconcileFactoryProfiles()
        var actions: [ControllerAction] = []
        restored.onAction = { action, _ in actions.append(action) }
        var decoder = ControllerMIDIDecoder()
        restored.receive(try #require(decoder.append([0x90, 11, 127]).first), source: 10)
        #expect(actions == [.playB])
        restored.setFeedbackDestination(20)
        restored.setFeedbackBinding(action: .playA, kind: .note, channel: 5, number: 99, offValue: 0, onValue: 42)
        restored.reconcileFactoryProfiles()
        #expect(restored.selectedFeedbackBindings.count == 22)
        #expect(restored.selectedFeedbackBindings.first { $0.action == .playA }?.number == 99)
    }
}

@Test @MainActor func controllerFactoryKeepsTheRestOfTheProfileWhenLearningOneControl() throws {
    try withController { controller, _ in
        controller.select(10)
        controller.learning = .playA
        var decoder = ControllerMIDIDecoder()
        controller.receive(try #require(decoder.append([0x90, 100, 127]).first), source: 10)
        #expect(controller.bindingName(.playA).contains("100"))
        #expect(controller.bindingName(.playB).contains("11"))
        #expect(controller.bindingName(.levelA).contains("19"))
        #expect(controller.bindingCount > 40)
    }
}

@Test @MainActor func controllerFactoryRetainsExplicitDisableChoices() {
    withController { controller, preferences in
        controller.setInputActive(10, active: false)
        #expect(!controller.isInputActive(10))
        let restored = ControllerMIDIConnection(preferences: preferences)
        restored.sources = controller.sources
        restored.reconcileFactoryProfiles()
        #expect(!restored.isInputActive(10))
        restored.setInputActive(10, active: true)
        #expect(restored.isInputActive(10))
        controller.setEnabled(false)
        #expect(!ControllerMIDIConnection(preferences: preferences).shouldStartAutomatically)
    }
}

@Test @MainActor func controllerFactoryFeedbackCanBeDisabledAndRestored() {
    withController { controller, preferences in
        controller.setFeedbackDestination(20)
        #expect(controller.isSelectedFeedbackEnabled)
        #expect(controller.selectedFeedbackBindings.count == 22)
        controller.setMIDIFeedbackEnabled(false)
        #expect(!controller.isSelectedFeedbackEnabled)
        #expect(controller.selectedFeedbackBindings.count == 22)
        let restored = ControllerMIDIConnection(preferences: preferences)
        restored.sources = controller.sources
        restored.destinations = controller.destinations
        restored.reconcileFactoryProfiles()
        restored.setFeedbackDestination(20)
        #expect(!restored.isSelectedFeedbackEnabled)
        #expect(restored.selectedFeedbackBindings.count == 22)
        restored.setMIDIFeedbackEnabled(true)
        #expect(restored.isSelectedFeedbackEnabled)
    }
}

@Test @MainActor func controllerFactoryCustomMappingsSurviveNewEndpointIDs() throws {
    try withController { controller, preferences in
        controller.select(10)
        controller.learning = .playA
        var decoder = ControllerMIDIDecoder()
        controller.receive(try #require(decoder.append([0x90, 100, 127]).first), source: 10)
        controller.setFeedbackDestination(20)
        controller.setFeedbackBinding(action: .playA, kind: .note, channel: 5, number: 99, offValue: 0, onValue: 42)
        let restored = ControllerMIDIConnection(preferences: preferences)
        restored.sources = [.init(id: 11, reference: 101, name: "DDJ-FLX4", identity: endpoint(11))]
        restored.destinations = [.init(id: 21, reference: 201, name: "DDJ-FLX4", identity: endpoint(21))]
        restored.reconcileFactoryProfiles()
        restored.select(11)
        #expect(restored.bindingName(.playA).contains("100"))
        #expect(restored.bindingName(.playB).contains("11"))
        restored.setFeedbackDestination(21)
        #expect(restored.selectedFeedbackBindings.count == 22)
        #expect(restored.selectedFeedbackBindings.first { $0.action == .playA }?.number == 99)
        #expect(restored.selectedFeedbackBindings.first?.destination == 21)
    }
}

@Test @MainActor func controllerFactoryFLX2UsesItsPublishedTempoFilterAndShiftAddresses() throws {
    let bindings = ControllerFactoryProfile.flx2.bindings(source: 42)
    #expect(bindings.allSatisfy { $0.source == 42 })
    #expect(!bindings.contains { [.gainA, .gainB, .cueMix].contains($0.action) })
    let tempo = try #require(bindings.first { $0.action == .tempoA && !$0.isShifted })
    #expect(tempo.channel == 0 && tempo.number == 0 && tempo.mode == .paired14Bit)
    let filter = try #require(bindings.first { $0.action == .filterKnobB })
    #expect(filter.channel == 6 && filter.number == 24 && filter.mode == .paired14Bit)
    #expect(bindings.filter { $0.action == .shift }.map(\.channel) == [0, 1])
    let feedback = ControllerFactoryProfile.flx2.feedback(destination: 43)
    #expect(feedback.count == 22)
    #expect(feedback.allSatisfy { $0.destination == 43 })
}

@Test @MainActor func controllerFactoryFLX4And400CoverBrowsingTempoFilterAndLoops() throws {
    for profile in [ControllerFactoryProfile.flx4, .ddj400] {
        let bindings = profile.bindings(source: 1)
        for (action, channel, number) in [
            (ControllerAction.tempoA, UInt8(0), UInt8(0)), (.filterKnobB, 6, 24),
            (.browse, 6, 64), (.openGroup, 6, 65), (.loadA, 6, 70), (.loadB, 6, 71),
            (.loopA, 0, 77), (.loopDownA, 0, 81), (.loopUpB, 1, 83),
        ] {
            let binding = try #require(bindings.first { $0.action == action && !$0.isShifted })
            #expect(binding.channel == channel && binding.number == number)
        }
        #expect(bindings.filter { $0.action == .shift }.map(\.channel) == [0, 1])
    }
}

@Test @MainActor func controllerFactoryReleasesJogTouchAfterTheShiftLayerChanges() throws {
    try withController { controller, _ in
        var touches: [Double] = []
        controller.onAction = { action, value in if action == .jogTouchA { touches.append(value) } }
        var decoder = ControllerMIDIDecoder()
        for message in decoder.append([0x90, 54, 127, 63, 127, 54, 0, 63, 0]) {
            controller.receive(message, source: 10)
        }
        #expect(touches == [1, 0])
    }
}

@Test func controllerFactorySplitAudioOnlyUsesDocumentedRoutes() {
    #expect(AudioOutputDevice(name: "DDJ-FLX4", wired: true).automaticSplitOutputName == "DDJ-FLX4")
    #expect(AudioOutputDevice(name: "Pioneer DDJ-400", wired: true).automaticSplitOutputName == "DDJ-400")
    #expect(AudioOutputDevice(name: "DDJ-FLX10", wired: true).automaticSplitOutputName == nil)
    #expect(AudioOutputDevice(name: "DDJ-1000SRT", wired: true).automaticSplitOutputName == nil)
    #expect(AudioOutputDevice(name: "DDJ-FLX4", wired: false).automaticSplitOutputName == nil)
}

@Test @MainActor func controllerFactoryFilterKnobWorksWithoutAnExtraEnableStep() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    model.setMixer(.filterY, value: 0.3, deck: .a)
    model.applyController(.filterKnobA, value: 0.8)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == true)
    #expect(abs((model.playbackSnapshot?.a.mixer.filterX ?? 0) - 0.6) < 0.00001)
    #expect(model.playbackSnapshot?.a.mixer.filterY == 0.3)
    model.applyController(.filterKnobA, value: 0.5)
    #expect(model.playbackSnapshot?.a.mixer.filterEnabled == false)
    #expect(model.playbackSnapshot?.a.mixer.filterX == 0)
    #expect(model.playbackSnapshot?.a.mixer.filterY == 0.3)
    #expect(model.playbackSnapshot?.b.mixer.filterEnabled == false)
}

@Test @MainActor func controllerFactoryAppliesBrowseMovementBeforeALoadInTheSameDrain() {
    withController { controller, _ in
        var actions: [ControllerAction] = []
        var detents = 0
        controller.onAction = { action, value in
            actions.append(action)
            if action == .browse { detents += Int(((value - 0.5) * 126).rounded()) }
        }
        var decoder = ControllerMIDIDecoder()
        for message in decoder.append([0xB6, 64, 1, 64, 1, 0x96, 70, 127]) {
            controller.receive(message, source: 10)
        }
        #expect(actions == [.browse, .loadA])
        #expect(detents == 2)
    }
}

@Test @MainActor func controllerFactoryBrowseUsesBothFactoryDirections() {
    withController { controller, _ in
        var detents: [Int] = []
        controller.onAction = { action, value in
            if action == .browse { detents.append(Int(((value - 0.5) * 126).rounded())) }
        }
        var decoder = ControllerMIDIDecoder()
        for message in decoder.append([0xB6, 64, 1, 0x96, 70, 127, 70, 0, 0xB6, 64, 127, 0x96, 70, 127]) {
            controller.receive(message, source: 10)
        }
        #expect(detents == [1, -1])
    }
}
