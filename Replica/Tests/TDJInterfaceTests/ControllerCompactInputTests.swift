import Foundation
import Testing

@testable import TDJInterface

private func compactInput(_ value: [String: Any]) throws -> ControllerProfileData.Input {
    try JSONDecoder().decode(ControllerProfileData.Input.self, from: JSONSerialization.data(withJSONObject: value))
}

@Test func controllerCatalogueCompactInputsDefaultToNormalNotesWithoutChangingFullRows() throws {
    let compact = try compactInput(["a": "playA", "c": 0, "n": 52, "d": "a"])
    let full = try compactInput([
        "action": "playA", "channel": 0, "number": 52, "kind": "note", "encoding": "absolute", "inverted": false,
        "targetDeck": "a",
    ])
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    #expect(try encoder.encode(compact.binding(source: 10)) == encoder.encode(full.binding(source: 10)))
    #expect(compact.kind == .note && compact.encoding == .absolute && !compact.inverted && compact.shifted == nil)
}

@Test func controllerCatalogueCompactInputsRetainEveryOptionalValue() throws {
    let full: [String: Any] = [
        "action": "playA", "kind": "control", "channel": 3, "number": 9, "encoding": "paired14Bit", "inverted": true,
        "targetDeck": "d", "anyChannel": true, "argument": 2.5, "releaseOnly": true, "requiredMode": 4,
        "shifted": false, "shiftInput": 2, "holdInput": 6, "shiftChannel": 1, "lowNumber": 59, "pulse": true,
        "requiresTouch": true, "directionStep": 0.01, "deckBank": 1,
    ]
    let compact: [String: Any] = [
        "a": "playA", "k": "control", "c": 3, "n": 9, "e": "paired14Bit", "i": true, "d": "d", "w": true, "g": 2.5,
        "r": true, "m": 4, "s": false, "t": 2, "h": 6, "z": 1, "l": 59, "p": true, "u": true, "v": 0.01, "b": 1,
    ]
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    #expect(
        try encoder.encode(compactInput(compact).binding(source: 10))
            == encoder.encode(compactInput(full).binding(source: 10)))
}

@Test func controllerCatalogueCompactInputsRejectMixedMissingAndInvalidFields() {
    let invalid: [[String: Any]] = [
        ["a": "playA", "c": 0, "n": 52, "kind": "control"],
        ["action": "playA", "channel": 0, "number": 52],
        ["a": "playA", "c": 0],
        ["a": "playA", "c": 256, "n": 52],
        ["a": "playA", "c": 0, "n": 52, "e": "unknown"],
        ["a": "playA", "c": 0, "n": 52, "i": "false"],
        ["a": "playA", "c": 0, "n": 52, "k": NSNull()],
        ["a": "playA", "action": "cuePreviewA", "c": 0, "n": 52],
    ]
    for row in invalid { #expect(throws: (any Error).self) { _ = try compactInput(row) } }
}

@Test func controllerCatalogueCompactInputsMatchEveryReviewedNativeBinding() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let data = try Data(
        contentsOf: root.appendingPathComponent("Sources/TDJInterface/Resources/factory-controller-profiles.json"))
    let reviewed = try JSONDecoder().decode(ControllerProfileCatalogue.self, from: data)
    let bundled = ControllerProfileCatalogue.shared
    #expect(reviewed.profiles.map(\.id) == bundled.profiles.map(\.id))
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    var count = 0
    for (full, compact) in zip(reviewed.profiles, bundled.profiles) {
        #expect(full.isValid && compact.isValid)
        #expect(
            try encoder.encode(full.inputs.map { $0.binding(source: 10) })
                == encoder.encode(compact.inputs.map { $0.binding(source: 10) }))
        count += compact.inputs.count
    }
    #expect(count == reviewed.profiles.reduce(0) { $0 + $1.inputs.count } && count > 24000)
}

@Test func controllerCatalogueCompactResourceUsesTheGeneratedFile() throws {
    let url = try #require(Bundle.module.url(forResource: "factory-controller-profiles.compact", withExtension: "json"))
    #expect(try Data(contentsOf: url).count < 3 * 1024 * 1024)
}
