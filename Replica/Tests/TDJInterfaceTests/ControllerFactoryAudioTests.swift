import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func controllerFactoryAudioUsesOnlyDocumentedWiredModelLayouts() {
    for name in ["Scratch", "Numark Scratch", "NUMARK SCRATCH"] {
        #expect(AudioOutputDevice(name: name, wired: true).automaticSplitOutputName == "Numark Scratch")
        #expect(AudioOutputDevice(name: name, wired: false).automaticSplitOutputName == nil)
    }
    for name in ["Numark Scratch MK2", "Scratch 2", "NS6II", "RP-8000", "Reloop NEON", "Other interface"] {
        #expect(AudioOutputDevice(name: name, wired: true).automaticSplitOutputName == nil)
    }
}

@Test @MainActor func controllerFactoryAudioScratchRejectsAmbiguousOutputsAndPreservesManualChoices() throws {
    let controller = try PlaybackController(offline: true)
    let scratch = AudioOutputDevice(name: "Scratch", wired: true)
    let speaker = AudioOutputDevice(name: "iPad Speaker", wired: false)
    controller.updateOutputDevice([scratch])
    #expect(controller.automaticOutputDevice == "Numark Scratch" && controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([scratch, speaker])
    #expect(controller.automaticOutputDevice == nil && controller.outputRoute == .stereoMaster)
    try controller.setOutputRoute(.masterAndHeadphones)
    controller.updateOutputDevice([scratch])
    controller.updateOutputDevice([AudioOutputDevice(name: "Other interface", wired: true)])
    #expect(controller.automaticOutputDevice == nil && controller.outputRoute == .masterAndHeadphones)
}

@Test func controllerFactoryAudioSchemaAcceptsOnlyAutomaticMasterAndHeadphoneLayouts() throws {
    func decode(_ route: String, automatic: Bool) throws -> ControllerProfileCatalogue {
        let profile: [String: Any] = [
            "id": "audio fixture", "aliases": ["audio fixture"],
            "inputs": [
                [
                    "action": "playA", "kind": "note", "channel": 0, "number": 1, "encoding": "absolute",
                    "inverted": false,
                ]
            ],
            "outputs": [], "startup": [], "shutdown": [], "autoSelect": automatic, "scope": "fixture",
            "source": "fixture",
            "audioOutput": route,
        ]
        return try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [profile]]))
    }
    #expect(try decode("masterAndHeadphones", automatic: true).profiles.count == 1)
    #expect(throws: (any Error).self) { try decode("masterAndHeadphones", automatic: false) }
    for value in ["stereoMaster", "unknown", "", "master3Headphones1"] {
        #expect(throws: (any Error).self) { try decode(value, automatic: true) }
    }
}
