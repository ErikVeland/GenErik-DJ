"""OPUS-QUAD core MIDI facts from the published factory table."""
from curated import BASE, add, profile

OPUS_REFERENCES = {
    "Pioneer OPUS-QUAD": {
        "url": BASE + "all-in-one-dj-systems/OPUS-QUAD/OPUS-QUAD_MIDI_Message_List_E1.pdf",
        "sha256": "cc65740ff56d1610ea8daa553559cb3d4e4d181754fe424973a2495507f5d695",
        "pages": [1, 2, 3],
    },
}


def opus_profiles():
    result = profile("Pioneer OPUS-QUAD", OPUS_REFERENCES["Pioneer OPUS-QUAD"]["url"])
    result["hardwareMode"] = "Select MIDI / PC control for the intended decks and software mixer control where required."
    result["scope"] = "Automatic core MIDI controls. Screens, complete feedback, advanced modes and audio routing remain open."
    result["gaps"] = ["Colour-coded Cue/Hot Cue lights, jog indicators, FX, input/crossfader assignment, zone/booth audio and screens remain unimplemented."]
    for channel, deck in enumerate("abcd"):
        for action, number in [("play", 0), ("cueReturn", 1), ("sync", 31), ("keylock", 17),
                               ("tempoReset", 19), ("load", 81), ("loopIn", 6), ("loopOut", 7),
                               ("loop", 67), ("reloop", 68), ("jumpForward", 44), ("jumpBack", 45)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "keylock"})
        add(result, "fixedLoop", channel, 69, deck=deck)
        result["inputs"][-1]["argument"] = 4
        add(result, "loopSize", channel, 46, "control", "twosComplement", deck)
        for number in [34, 41]:
            add(result, "jog", channel, number, "control", "binaryOffset", deck)
        for number in [33, 38]:
            add(result, "wheelJog", channel, number, "control", "binaryOffset", deck)
        for number in [32, 72]:
            add(result, "jogTouch", channel, number, deck=deck)
        add(result, "tempo", channel, 0, "control", "paired14Bit", deck)
        add(result, "seek", channel, 28, "control", "needlePosition", deck)
        for slot, number in enumerate([8, 11, 13, 15, 21, 23, 25, 27]):
            add(result, f"hotcue{slot + 1}", channel, number, deck=deck)
        for action, numbers in {"level": [17, 18, 19, 20], "gain": [1, 6, 12, 80],
                                "high": [2, 7, 14, 81], "mid": [3, 8, 15, 92],
                                "low": [4, 9, 21, 82], "filterKnob": [5, 10, 22, 83]}.items():
            add(result, action, 4, numbers[channel], "control", deck=deck)
        add(result, "cue", 4, 70 + channel, "control", deck=deck)
    for action, number in [("crossfader", 11), ("master", 24), ("monitor", 26), ("cueMix", 27)]:
        add(result, action, 4, number, "control")
    for number in [79, 96]:
        add(result, "browse", 0, number, "control", "twosComplement")
    for number in [51, 50]:
        add(result, "openGroup", 0, number)
    return [result]
