"""Reviewed VCI-300 dispatch, paired counters and native core controls."""
from curated import add, profile
from numark import UPSTREAM

VCI300_SOURCES = [
    ("Vestax VCI-300.midi.xml", "f6efbd83c4bfc47c68fbb7eba594951357b906e627c2d920a9e32fe88035b54c"),
    ("Vestax-VCI-300-scripts.js", "36150baffe7f4d8b047fa84b8b361452ff318626a8f61cb42882410070fc18e2"),
]
VCI300_REFERENCES = {"Vestax VCI-300": {
    "url": UPSTREAM + VCI300_SOURCES[0][0].replace(" ", "%20"), "sha256": VCI300_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in VCI300_SOURCES],
    "review": "XML dispatch and script handlers define distinct two-deck addresses on channel zero. Jogs consume a fresh high/low pair, prime a cyclic fourteen-bit counter, wrap at half range and retain 1600 counts per revolution. Tempo packs nine bits with exact centre 256 and unequal 256/255 endpoint ranges. Native fixed touch scratching replaces source mode toggles and nonlinear nudge curves. Scroll plus PFL loads. Composed Shift/Scroll scopes block unsupported jog search and browsing without changing transport on the other deck. Shift guards tempo and rearms native pickup. Core LEDs retain direction-specific output addresses. Other modes, full feedback, cleanup, routing and physical calibration remain open.",
}}


def vci300_profiles():
    result = profile("Vestax VCI-300", VCI300_REFERENCES["Vestax VCI-300"]["url"])
    result["scope"] = "Automatic two-deck native core with cyclic jogs, nine-bit tempo, three cues, native loops and Scroll/PFL loading. Other modes, full feedback, cleanup, routing and physical calibration remain open."
    result["startup"] = [[0x90, n, v] for n, v in [(38, 127), (56, 127), (39, 0), (55, 0), (47, 0)]]
    result["shutdown"] = [[0x90, n, 0] for n in [38, 56, 39, 55, 47]]
    for number, scopes in [(49, [0, 3]), (68, [1, 4]), (82, [2, 3, 4])]:
        for scope in scopes:
            add(result, "shift", 0, number)
            result["inputs"][-1]["shiftChannel"] = scope
    for side, deck in enumerate("ab"):
        offset = 19 * side

        def control(action, number, kind="note", encoding="absolute", scope=None, shifted=False, **extra):
            add(result, action, 0, number, kind, encoding, deck)
            result["inputs"][-1].update(shiftChannel=side if scope is None else scope, shifted=shifted, **extra)

        for action, number in [("play", 37), ("cuePreview", 36), ("sync", 41), ("keylock", 38),
                               ("loopIn", 46), ("loopOut", 47), ("reloop", 48)]:
            control(action, number + offset)
        control("tempoReset", 38 + offset, shifted=True)
        control("loop", 51 + offset, argument=4)
        for action, number in [("loopDown", 52), ("loopUp", 53)]:
            control(action, number + offset, scope=3 + side)
        for slot in range(3):
            control("hotcue" + str(slot + 1), 42 + offset + slot)
        control("cue", 54 + offset, scope=2)
        control("load", 54 + offset, scope=2, shifted=True)
        control("jogTouch", 83 + side, scope=3 + side)
        control("jog", 28 + side, "control", "cyclic14BitJog", scope=3 + side,
                lowNumber=60 + side, argument=1600)
        control("tempo", 13 + 6 * side, "control", "vci300Tempo", lowNumber=45 + 6 * side)
        for action, number in [("gain", 14), ("level", 12), ("high", 15), ("mid", 16), ("low", 17)]:
            add(result, action, 0, number + 6 * side, "control", deck=deck)
        for action, numbers in [("cue", [45 + 4 * side]), ("play", [114 + 2 * side]),
                                ("keylock", [36 + 15 * side]), ("sync", [37 + 20 * side]),
                                ("loop", [76 + 12 * side, 70 + 12 * side])]:
            for number in numbers:
                result["outputs"].append({"action": action + deck.upper(), "targetDeck": deck, "kind": "note",
                                          "channel": 0, "number": number, "onValue": 127, "offValue": 0,
                                          "offUsesNoteOn": True})
        for slot in range(3):
            for number in [65 + 12 * side + 2 * slot, 71 + 12 * side + 2 * slot]:
                result["outputs"].append({"action": "hotcue" + str(slot + 1) + deck.upper(), "targetDeck": deck,
                                          "kind": "note", "channel": 0, "number": number, "onValue": 127,
                                          "offValue": 0, "offUsesNoteOn": True})
    for action, number in [("crossfader", 24), ("cueMix", 25)]:
        add(result, action, 0, number, "control")
    for action, number in [("browsePrevious", 77), ("browseNext", 78),
                           ("browsePreviousGroup", 79), ("browseNextGroup", 80)]:
        add(result, action, 0, number)
    return [result]
