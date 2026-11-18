"""MC6000MK2 core protocol facts from the factory command workbook and pinned mapping."""
from curated import add, profile
from numark import UPSTREAM

MC6000_SOURCES = [
    ("Denon-MC6000MK2.midi.xml", "09dcf2480361a4ba4c4a209535ef388e02cf3897e5b25cbe2786495035e062d0"),
    ("Denon-MC6000MK2-scripts.js", "efdfda0fe1ad915725d0c46b791c9e81d9bb11879a90532d6390c4819c1fdd3f"),
]
MC6000_COMMANDS = "https://cdn.inmusicbrands.com/denondj/MC6000Mk2/MC6000MK2_MIDI_Command_List.zip"
MC6000_REFERENCES = {"Denon MC6000MK2": {
    "url": MC6000_COMMANDS,
    "sha256": "a5feb276ac1050b93dc598622b7a197b02a63241f66a43d0e2bb385062e4ab72",
    "archiveMember": {"path": "MC6000MK2 MIDI COMMAND LIST.xlsx", "sha256": "22da751c9328ffb6ca41c85e199d408bbba10029016ba6e1d6ed88f2dfe1c09c"},
    "relatedSources": [{"url": UPSTREAM + path, "sha256": digest} for path, digest in MC6000_SOURCES],
    "review": "Factory sheet MC6000MK2 rows 6–174 specify inputs; rows 182–240 specify LED trigger controllers and identifiers. The pinned script confirms side-wide Shift, zero/127 browser counts and jog zero as neutral. Filters, pad banks, FX and meters remain open."}}


def mc6000_profiles():
    result = profile("Denon MC6000MK2", MC6000_COMMANDS)
    result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
    result["aliases"].append("Denon DJ MC6000MK2")
    result["scope"] = "Automatic native core controls. Deck channels follow A/C/B/D. Shift follows each physical side across deck banks. Advanced modes and audio routing remain open."
    result["startup"] = [[0xB0 + channel, 74, 6] for channel in range(4)]
    result["shutdown"] = [[0xB0 + channel, 75, 6] for channel in range(4)]
    for channel, deck in enumerate("acbd"):
        side = 0 if deck in "ac" else 1
        start = len(result["inputs"])
        for action, number in [("play", 67), ("cuePreview", 66), ("sync", 107), ("keylock", 6),
                               ("loop", 29), ("loopIn", 55), ("loopOut", 57), ("loopDown", 105), ("loopUp", 106)]:
            add(result, action, channel, number, deck=deck)
        add(result, "load", channel, 98 + side, deck=deck)
        add(result, "jogTouch", channel, 81, deck=deck)
        add(result, "jogTouch", channel, 86, deck=deck)
        result["inputs"][-1]["releaseOnly"] = True
        add(result, "jog", channel, 81, "control", "denonJog", deck)
        add(result, "wheelJog", channel, 82, "control", "denonJog", deck)
        add(result, "tempo", channel, 0, "pitch", deck=deck)
        result["inputs"][-1]["inverted"] = True
        for binding in result["inputs"][start:]:
            binding.update(shifted=False, shiftChannel=side)
        add(result, "shift", channel, 96 + side)
        result["inputs"][-1].update(shiftChannel=side, shiftInput=side)
        for action, identifier in [("play", 39), ("sync", 9), ("keylock", 8), ("loop", 43)]:
            feedback(result, action, channel, identifier, deck)
    for index, deck in enumerate("abcd"):
        add(result, "cue", 0, [1, 2, 5, 7][index], deck=deck)
        for action, numbers in {"gain": [1, 7, 12, 17], "high": [2, 8, 13, 18], "mid": [3, 9, 14, 19],
                                "low": [4, 10, 15, 20], "level": [5, 11, 16, 21]}.items():
            add(result, action, 0, numbers[index], "control", deck=deck)
        feedback(result, "cue", 0, [69, 75, 81, 87][index], deck, regular=True)
    for action, number in [("crossfader", 22), ("master", 25), ("cueMix", 67), ("monitor", 68)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 84, "control", "zeroForward")
    result["gaps"] = ["Hot Cue/sample banks, side-selected filters, browser buttons, Vinyl toggle, additional shifted functions, FX, meters and full audio routing remain unimplemented. Jog calibration and source reuse/distribution review remain open. The command workbook corrects filter input addresses in the older manual; filters stay unmapped until side routing is implemented."]
    return [result]


def feedback(result, action, channel, identifier, deck, regular=False):
    suffix = "A" if deck in "ac" else "B"
    result["outputs"].append({"action": action + suffix, "kind": "control", "channel": channel,
                              "number": 80 if regular else 74, "offNumber": 81 if regular else 75,
                              "onValue": identifier, "offValue": identifier, "offUsesNoteOn": True, "targetDeck": deck})
