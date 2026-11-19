import Foundation
import Testing

@testable import TDJInterface

@Test func controllerCatalogueManualUnbankedTwoDeckCoreHasBoundedSchema() throws {
    let roles: [(String, String?, String, Int)] = [
        ("playA", "a", "note", 10), ("playB", "b", "note", 20),
        ("cuePreviewA", "a", "note", 11), ("cuePreviewB", "b", "note", 21),
        ("levelA", "a", "control", 2), ("levelB", "b", "control", 3), ("crossfader", nil, "control", 4),
    ]
    let inputs: [[String: Any]] = roles.map { action, deck, kind, number in
        var r: [String: Any] = [
            "action": action, "kind": kind, "channel": 0, "number": number, "encoding": "absolute",
            "inverted": action == "crossfader", "anyChannel": true,
        ]
        if let deck { r["targetDeck"] = deck }; return r
    }
    let fixture: [String: Any] = [
        "id": "manual dual deck", "aliases": ["manual dual deck"], "autoSelect": false, "source": "fixture",
        "scope": "fixture", "inputs": inputs, "outputs": [], "startup": [], "shutdown": [],
    ]
    func decode(_ row: [String: Any]) throws -> ControllerProfileCatalogue {
        try ControllerProfileCatalogue.decode(
            JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "profiles": [row]]))
    }
    #expect(try decode(fixture).profiles.count == 1)
    for (key, value): (String, Any) in [
        ("autoSelect", true), ("role", "accessory"), ("role", "mixer"),
        ("startup", [[0x90, 1, 0]]), ("shutdown", [[0x80, 1, 0]]),
        ("inputModes", []), ("bankChanges", []), ("portAliases", ["port"]), ("unbankedGlobalInputs", true),
        (
            "outputs",
            [
                [
                    "action": "playA", "kind": "note", "channel": 0, "number": 10, "onValue": 127, "offValue": 0,
                    "targetDeck": "a",
                ]
            ]
        ),
    ] {
        var row = fixture; row[key] = value
        #expect(throws: (any Error).self) { try decode(row) }
    }
    for (key, value): (String, Any) in [
        ("action", "cueStateA"), ("action", "jogA"), ("kind", "pitch"), ("targetDeck", "c"),
        ("channel", 1), ("anyChannel", false), ("encoding", "binaryOffset"), ("inverted", true),
        ("shifted", false), ("requiredMode", 1), ("shiftChannel", 0), ("holdInput", 1),
        ("releaseOnly", true), ("pulse", true), ("lowNumber", 42), ("argument", 330), ("deckBank", 0),
    ] {
        var row = fixture; var copy = inputs; copy[0][key] = value; row["inputs"] = copy
        #expect(throws: (any Error).self) { try decode(row) }
    }
    var row = fixture; row["inputs"] = Array(inputs.dropLast())
    #expect(throws: (any Error).self) { try decode(row) }
    var repeated = inputs; repeated[1]["number"] = 10; row = fixture; row["inputs"] = repeated
    #expect(throws: (any Error).self) { try decode(row) }
    repeated = inputs; var extra = inputs[0]; extra["number"] = 12; repeated.append(extra); row["inputs"] = repeated
    #expect(throws: (any Error).self) { try decode(row) }
    repeated = inputs; repeated[6]["targetDeck"] = "a"; row["inputs"] = repeated
    #expect(throws: (any Error).self) { try decode(row) }
    repeated = inputs; repeated[4]["inverted"] = true; row["inputs"] = repeated
    #expect(throws: (any Error).self) { try decode(row) }
}
