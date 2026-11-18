"""Original DDJ-1000 facts from its own factory tables."""
from curated import BASE, add, profile

DDJ1000_TABLE = BASE + "dj-controllers/DDJ-1000/DDJ-1000_MIDI_Message_List_E1.pdf"
DDJ1000_DIAGRAM = BASE + "dj-controllers/DDJ-1000/DDJ-1000_HardwareDiagram_rekordboxdj_E1.pdf"
DDJ1000_REFERENCES = {"DDJ-1000": {
    "url": DDJ1000_TABLE, "sha256": "28d68d514774daa81e603d9a8709105283f38fbc944650671971ecf57cb95d11",
    "pages": [1, 2, 4, 5, 6, 7, 8],
    "relatedSources": [{"url": DDJ1000_DIAGRAM, "sha256": "97e025df9c835194993c11792edbd71300e0b7a2c69abc2dbe094f1cc9ce714c", "pages": [2]}],
    "review": "Original DDJ-1000 alone. The 1000SRT retains a separate recipe. Normal Sync is Note 88, tempo CC 0/32 and four-beat loop Note 20. Earlier code used shifted addresses 92, 5/37 and 80. The factory table confirms four transport channels 0/1/2/3 and normal pad channels 7/9/11/13. Note 114 on channel 2 reports either left-bank change; channel 3 reports either right-bank change. These are switch events, not active-deck queries. Loop In/Out set boundaries while no loop is active and halve/double an active loop. Shifted jogs edit the grid. Screens, remaining modes, full feedback, cleanup, audio routing and physical jog calibration remain open.",
}}


def ddj1000_profiles():
    result = profile("Pioneer DDJ-1000", DDJ1000_TABLE)
    result.update(id="DDJ-1000", catalogueName="Pioneer DDJ-1000")
    result["aliases"].append("AlphaTheta DDJ-1000")
    result["scope"] = "Original DDJ-1000 four-deck core MIDI with normal Sync/tempo, keylock, held Cue, context-dependent loops, Load and Hot Cues. Four decks retain the app opt-in. The SRT has a separate recipe. Grid editing, remaining modes, screens, full feedback, cleanup, routing and jog calibration remain open."
    result["bankChanges"] = [{"channel": 2 + side, "number": 114, "onValue": 127,
                              "decks": ["a", "c"] if side == 0 else ["b", "d"]} for side in range(2)]
    for channel, deck in enumerate("abcd"):
        scope = channel % 2
        for action, number in [("play", 11), ("cuePreview", 12), ("sync", 88), ("keylock", 26),
                               ("loopInOrHalve", 16), ("loopOutOrDouble", 17), ("toggleFixedLoop", 20)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "keylock"})
            result["inputs"][-1].update(shifted=False, shiftChannel=scope)
            if action == "toggleFixedLoop":
                result["inputs"][-1]["argument"] = 4
        for number, shifted in [(0, False), (5, True)]:
            add(result, "tempo", channel, number, "control", "paired14Bit", deck)
            result["inputs"][-1].update(shifted=shifted, shiftChannel=scope)
        for action, number in [("gain", 4), ("high", 7), ("mid", 11), ("low", 15), ("level", 19)]:
            add(result, action, channel, number, "control", "paired14Bit", deck)
        add(result, "cue", channel, 84, deck=deck, feedback=True)
        result["inputs"][-1].update(shifted=False, shiftChannel=scope)
        for action, number in [("jog", 34), ("wheelJog", 35), ("wheelJog", 33)]:
            add(result, action, channel, number, "control", "binaryOffset", deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=scope)
        add(result, "jogTouch", channel, 54, deck=deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=scope)
        add(result, "jogTouch", channel, 103, deck=deck)
        result["inputs"][-1].update(shifted=True, shiftChannel=scope, releaseOnly=True)
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", 7 + 2 * channel, slot, deck=deck, feedback=True)
            result["inputs"][-1].update(shifted=False, shiftChannel=scope)
        add(result, "load", 6, 70 + channel, deck=deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=scope)
        add(result, "shift", channel, 63)
        result["inputs"][-1].update(shiftChannel=scope, shiftInput=scope)
    for action, number in [("crossfader", 31), ("master", 8), ("cueMix", 12), ("monitor", 13)]:
        add(result, action, 6, number, "control", "paired14Bit")
    add(result, "browse", 6, 64, "control", "twosComplement")
    return [result]
