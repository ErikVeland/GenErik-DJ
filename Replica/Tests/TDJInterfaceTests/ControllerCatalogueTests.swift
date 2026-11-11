import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func controllerCatalogueLoadsAllBoundedProfiles() {
    #expect(ControllerProfileCatalogue.loadFailure == nil)
    #expect(ControllerProfileCatalogue.shared.profiles.count >= 100)
    #expect(ControllerProfileCatalogue.shared.profiles.allSatisfy { $0.isValid })
    #expect(ControllerFactoryProfile.allCases.count == ControllerProfileCatalogue.shared.profiles.count + 7)
}

@Test func controllerCatalogueRejectsInvalidData() throws {
    for data in [Data(#"{"schemaVersion":2,"profiles":[]}"#.utf8), Data(repeating: 0, count: 4 * 1024 * 1024 + 1)] {
        #expect(throws: (any Error).self) { try ControllerProfileCatalogue.decode(data) }
    }
}

@Test func controllerCatalogueMatchesPopularModelsWithoutGuessingVariants() throws {
    for name in ["XDJ-RR", "OMNIS-DUO", "DDJ-GRV6", "DDJ-SR", "DJControl Inpulse 500"] {
        let profile = try #require(ControllerFactoryProfile.matching([name], automaticOnly: true))
        #expect(profile.definition?.autoSelect == true)
    }
    #expect(ControllerFactoryProfile.matching(["DDJ-GRV6 clone"]) == nil)
    #expect(ControllerFactoryProfile.matching(["Numark"]) == nil)
    #expect(ControllerFactoryProfile.matching(["Numark Mixtrack Pro FX"], automaticOnly: true) == nil)
}

@Test @MainActor func controllerCatalogueKeepsFourDeckTargetsSeparate() throws {
    let profile = try #require(ControllerFactoryProfile.matching(["DDJ-GRV6"]))
    let name = "controller-catalogue-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: name)!
    defer { preferences.removePersistentDomain(forName: name) }
    let controller = ControllerMIDIConnection(preferences: preferences)
    controller.sources = [
        .init(
            id: 10, reference: 100, name: "DDJ-GRV6",
            identity: .init(id: 10, device: 1, names: ["DDJ-GRV6"]))
    ]
    controller.reconcileFactoryProfiles()
    var targets: [ControllerActionTarget] = []
    controller.onTargetAction = { target, _ in targets.append(target) }
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append([0x90, 11, 127, 0x92, 11, 127, 0x91, 11, 127, 0x93, 11, 127]) {
        controller.receive(message, source: 10)
    }
    #expect(
        targets == [.init(.playA, deck: .a), .init(.playA, deck: .c), .init(.playB, deck: .b), .init(.playB, deck: .d)])
    let lights = profile.feedback(destination: 20)
    #expect(Set(lights.map(\.id)).count == lights.count)
    #expect(lights.contains { $0.action == .playA && $0.targetDeck == .c && $0.channel == 2 })
}

@Test @MainActor func controllerCatalogueInitialisesOnlyThePairedOutputAndShutsDown() {
    let name = "controller-mode-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: name)!
    defer { preferences.removePersistentDomain(forName: name) }
    var packets: [[UInt8]] = []
    var outputs: [Int32] = []
    let controller = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, id in
            packets.append(bytes)
            outputs.append(id)
            return true
        })
    let identity = ControllerFactoryEndpoint(id: 10, device: 1, names: ["DJControl Inpulse 500"])
    controller.sources = [.init(id: 10, reference: 100, name: "DJControl Inpulse 500", identity: identity)]
    controller.destinations = [
        .init(
            id: 20, reference: 200, name: "DJControl Inpulse 500",
            identity: .init(id: 20, device: 2, names: identity.names))
    ]
    controller.reconcileFactoryProfiles()
    #expect(packets.isEmpty)
    #expect(!controller.isInputActive(10))
    controller.destinations = [
        .init(
            id: 21, reference: 201, name: "DJControl Inpulse 500",
            identity: .init(id: 21, device: 1, names: identity.names))
    ]
    controller.reconcileFactoryProfiles()
    controller.reconcileFactoryProfiles()
    #expect(packets == [[0xB0, 0x7F, 0x7F]])
    #expect(outputs == [21])
    #expect(controller.isInputActive(10))
    controller.stop()
    #expect(packets == [[0xB0, 0x7F, 0x7F], [0xB0, 0x7F, 0x7E]])
}

@Test @MainActor func controllerCatalogueFailedInitialisationDoesNotActivateControls() {
    let name = "controller-mode-failure-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: name)!
    defer { preferences.removePersistentDomain(forName: name) }
    let controller = ControllerMIDIConnection(preferences: preferences, factoryPacketSender: { _, _ in false })
    controller.sources = [
        .init(
            id: 10, reference: 100, name: "DJControl Inpulse 500",
            identity: .init(id: 10, device: 1, names: ["DJControl Inpulse 500"]))
    ]
    controller.destinations = [
        .init(
            id: 20, reference: 200, name: "DJControl Inpulse 500",
            identity: .init(id: 20, device: 1, names: ["DJControl Inpulse 500"]))
    ]
    controller.reconcileFactoryProfiles()
    #expect(!controller.isInputActive(10))
    #expect(controller.status.contains("could not start"))
}

@Test @MainActor func controllerCatalogueAcceptsTheFirstHeadphoneCCPress() throws {
    let name = "controller-cc-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: name)!
    defer { preferences.removePersistentDomain(forName: name) }
    let controller = ControllerMIDIConnection(preferences: preferences)
    controller.sources = [
        .init(
            id: 10, reference: 100, name: "XDJ-RR",
            identity: .init(id: 10, device: 1, names: ["XDJ-RR"]))
    ]
    controller.reconcileFactoryProfiles()
    var targets: [ControllerActionTarget] = []
    controller.onTargetAction = { target, _ in targets.append(target) }
    var decoder = ControllerMIDIDecoder()
    for message in decoder.append([0xB4, 70, 127, 70, 0, 70, 127]) { controller.receive(message, source: 10) }
    #expect(targets == [.init(.cueA, deck: .a), .init(.cueA, deck: .a)])
}

@Test @MainActor func controllerCatalogueRestartsModeAfterEndpointReplacement() {
    let name = "controller-restart-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: name)!
    defer { preferences.removePersistentDomain(forName: name) }
    var packets: [[UInt8]] = []
    let controller = ControllerMIDIConnection(
        preferences: preferences,
        factoryPacketSender: { bytes, _ in
            packets.append(bytes)
            return true
        })
    controller.sources = [
        .init(
            id: 10, reference: 100, name: "DJControl Inpulse 500",
            identity: .init(id: 10, device: 1, names: ["DJControl Inpulse 500"], reference: 100))
    ]
    controller.destinations = [
        .init(
            id: 20, reference: 200, name: "DJControl Inpulse 500",
            identity: .init(id: 20, device: 1, names: ["DJControl Inpulse 500"], reference: 200))
    ]
    controller.reconcileFactoryProfiles()
    controller.sources = [
        .init(
            id: 10, reference: 101, name: "DJControl Inpulse 500",
            identity: .init(id: 10, device: 1, names: ["DJControl Inpulse 500"], reference: 101))
    ]
    controller.reconcileFactoryProfiles()
    #expect(packets == [[0xB0, 0x7F, 0x7F], [0xB0, 0x7F, 0x7E], [0xB0, 0x7F, 0x7F]])
}

@Test @MainActor func controllerCatalogueLearningAndFeedbackEditsPreserveDeckC() throws {
    let name = "controller-deck-edit-\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: name)!
    defer { preferences.removePersistentDomain(forName: name) }
    let controller = ControllerMIDIConnection(preferences: preferences)
    controller.sources = [
        .init(
            id: 10, reference: 100, name: "DDJ-GRV6",
            identity: .init(id: 10, device: 1, names: ["DDJ-GRV6"]))
    ]
    controller.destinations = [
        .init(
            id: 20, reference: 200, name: "DDJ-GRV6",
            identity: .init(id: 20, device: 1, names: ["DDJ-GRV6"]))
    ]
    controller.reconcileFactoryProfiles()
    controller.select(10)
    controller.learning = .playA
    var decoder = ControllerMIDIDecoder()
    controller.receive(try #require(decoder.append([0x90, 100, 127]).first), source: 10)
    var targets: [ControllerActionTarget] = []
    controller.onTargetAction = { target, _ in targets.append(target) }
    for message in decoder.append([0x90, 11, 127, 0x92, 11, 127]) { controller.receive(message, source: 10) }
    #expect(targets == [.init(.playA, deck: .c)])
    controller.setFeedbackDestination(20)
    controller.setFeedbackBinding(action: .playA, kind: .note, channel: 0, number: 100, offValue: 0, onValue: 127)
    #expect(controller.selectedFeedbackBindings.filter { $0.action == .playA }.count == 2)
    #expect(
        controller.selectedFeedbackBindings.contains { $0.action == .playA && $0.targetDeck == .c && $0.number == 11 })
    #expect(controller.feedbackBindingName(.playA).contains("100"))
}
