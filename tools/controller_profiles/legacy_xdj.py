"""Original XDJ-RX facts, kept separate from its later relative-jog models."""
from copy import deepcopy
from curated import BASE, add, profile

LEGACY_XDJ_REFERENCES = {
    "Pioneer XDJ-RX legacy 7-bit": {
        "url": BASE + "all-in-one-dj-systems/XDJ-RX/XDJ-RX_List_of_MIDI_Message_E.pdf",
        "sha256": "c997e8a1e293c0d7eb6c03d6332bf8aa61f88c0fdba0fd11f7b3a5d2afccdf1c", "pages": [1, 2, 3, 4, 5, 6]},
    "Pioneer XDJ-RX": {
        "url": BASE + "all-in-one-dj-systems/XDJ-RX/XDJ-RX_List_of_MIDI_Message_E_Ver221.pdf",
        "sha256": "b51d2a0d32ba16d841fd35130d0a9cabb318ce927ea4cfb2023347298832a4d3", "pages": [2, 3, 4, 5, 6, 7],
        "review": "Firmware2.21 factory revision adds direct Load note81, normal tempo29/61 and shifted tempo52/84 fourteen-bit pairs, transport/PFL feedback and status reports. Earlier seven-bit recipe remains manual. The revised native core keeps absolute speed jogs, fixed Vinyl indication, four unambiguous Hot Cues per target and alternate release aliases. Startup/shutdown clears native lights and sets fixed Vinyl within56messages. Shifted speed jogs retain the same published speed scale. The second Hot Cue bank has conflicting decimal/hex addresses, so it stays unmapped. No HID, display, ring, live meters, full pad modes or automatic audio routing is inferred. Mixer must use MIDI CONTROL, PC control must be selected and firmware2.21 is required. Physical calibration and acceptance remain open."},
}


def legacy_xdj_profiles():
    result = profile("Pioneer XDJ-RX", LEGACY_XDJ_REFERENCES["Pioneer XDJ-RX legacy 7-bit"]["url"])
    result.update(autoSelect=False, hardwareMode="PC / MIDI control",
                  scope="Partial original RX controls. The factory table has no Load message or MIDI output.",
                  gaps=["Load buttons have no published MIDI message. Complete a documented loading route before automatic selection.",
                        "The factory table specifies no MIDI output. Screens and feedback need another documented protocol."])
    for channel, deck in enumerate("abcd"):
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 31), ("keylock", 17),
                               ("jogTouch", 32), ("jogTouch", 72), ("loopIn", 6), ("loopOut", 7), ("reloop", 8)]:
            add(result, action, channel, number, deck=deck)
        add(result, "tempo", channel, 29, "control", "cdjTempo", deck)
        add(result, "jog", channel, 16, "control", "cdjPlatterSpeed", deck)
        add(result, "wheelJog", channel, 48, "control", "cdjPlatterSpeed", deck)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", channel, 24 + slot, deck=deck)
        for action, numbers in {"level": [17, 18, 19, 20], "gain": [1, 6, 12, 80],
                                "high": [2, 7, 14, 81], "mid": [3, 8, 15, 92],
                                "low": [4, 9, 21, 82], "filterKnob": [5, 10, 22, 83]}.items():
            add(result, action, 4, numbers[channel], "control", deck=deck)
        add(result, "cue", 4, 70 + channel, "control", deck=deck)
    for action, number in [("crossfader", 11), ("master", 24), ("monitor", 26), ("cueMix", 27)]:
        add(result, action, 4, number, "control")
    add(result, "browse", 0, 79, "control", "twosComplement")
    for number in [50, 51]:
        add(result, "openGroup", 0, number)
    legacy = deepcopy(result)
    legacy.update(id="Pioneer XDJ-RX legacy 7-bit", aliases=["Pioneer XDJ-RX legacy 7-bit", "XDJ-RX legacy 7-bit"],
                  definition="manufacturer:pioneerxdjrxlegacy7bit", catalogueName="Pioneer XDJ-RX")
    result.update(autoSelect=True, source=LEGACY_XDJ_REFERENCES["Pioneer XDJ-RX"]["url"],
                  hardwareMode="Firmware 2.21; PC/MIDI control; MIXER MODE MIDI CONTROL; inputs set to DECK. Earlier firmware uses the separate manual seven-bit recipe.",
                  scope="Automatic firmware-2.21 original RX core with direct Load, fourteen-bit normal/Shift tempo, fixed Vinyl, native transport/PFL lights and four Hot Cues. HID/screens, full pad modes/feedback/audio routing, calibration and physical acceptance remain open.",
                  gaps=["HID, screens, rings, live meters, full pad modes/feedback and automatic audio routing remain unimplemented.",
                        "The second cue bank has conflicting decimal/hex addresses in the factory table. Qualify the actual wire addresses before mapping it."])
    for item in result["inputs"]:
        if item["action"] in {"tempoA", "tempoB"}:
            item["encoding"] = "paired14Bit"
    for channel, deck in enumerate("abcd"):
        add(result, "load", channel, 81, deck=deck)
        add(result, "tempo", channel, 52, "control", "paired14Bit", deck)
        result["inputs"][-1]["lowNumber"] = 84
        for action, number in [("jog", 51), ("wheelJog", 54)]:
            add(result, action, channel, number, "control", "cdjPlatterSpeed", deck)
        for action, number in [("play", 52), ("cuePreview", 53), ("sync", 71), ("keylock", 66),
                               ("loopIn", 58), ("loopOut", 59), ("reloop", 60)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", channel, 99 + slot, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 31), ("keylock", 17), ("loop", 8)]:
            result["outputs"].append({"action": action + ("A" if deck in "ac" else "B"), "kind": "note",
                                      "channel": channel, "number": number, "targetDeck": deck,
                                      "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
        result["outputs"].append({"action": "cue" + ("A" if deck in "ac" else "B"), "kind": "control",
                                  "channel": 4, "number": 70 + channel, "targetDeck": deck,
                                  "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
    clear = [[(0x90 if row["kind"] == "note" else 0xB0) + row["channel"], row["number"], 0] for row in result["outputs"]]
    result["startup"] = clear + [[0x90 + channel, 18, 127] for channel in range(4)]
    result["shutdown"] = clear + [[0x90 + channel, 18, 0] for channel in range(4)]
    result["bankChanges"] = [{"kind": "control", "channel": channel, "number": 102,
                              "decks": list("abcd")} for channel in range(4)]
    result["bankChanges"].extend([{"kind": "control", "channel": channel, "number": 100, "onValue": 0,
                                   "decks": [deck]} for channel, deck in enumerate("abcd")])
    return [legacy, result]
