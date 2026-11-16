"""DDJ-S1 MIDI facts, including its signed high-resolution jog pairs."""
from curated import BASE, add, profile

S1_REFERENCES = {
    "Pioneer DDJ-S1": {
        "url": BASE + "dj-controllers/DDJ-S1/DDJ-S1_MIDI_Messages_2.pdf",
        "sha256": "61f299828b2abfa5cdc1b09a3b4253d4b99b9c17c53b2f387293754448a1ad7b",
        "pages": [1, 2, 3, 4],
    },
}


def s1_profiles():
    result = profile("Pioneer DDJ-S1", S1_REFERENCES["Pioneer DDJ-S1"]["url"])
    result["scope"] = "Automatic core MIDI controls. Remaining shifted modes, FX, jog illumination and audio routing remain open."
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 11), ("cueReturn", 12), ("sync", 27), ("keylock", 26),
                               ("load", 61), ("loop", 20), ("loopIn", 16), ("loopOut", 17), ("reloop", 18)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "keylock"})
        add(result, "loopSize", channel, 19, "control", "twosComplement", deck)
        for number in [2, 7]:
            add(result, "jog", channel, number, "control", "paired14BitRelative", deck)
        for number in [1, 6]:
            add(result, "wheelJog", channel, number, "control", "paired14BitRelative", deck)
        for number in [54, 104]:
            add(result, "jogTouch", channel, number, deck=deck)
        add(result, "tempo", channel, 0, "control", "paired14Bit", deck)
        add(result, "seek", channel, 3, "control", "needlePosition", deck)
        for slot in range(5):
            add(result, f"hotcue{slot + 1}", channel, 42 + slot, deck=deck, feedback=True)
        for action, number in [("gain", channel), ("high", 2 + channel), ("mid", 4 + channel),
                               ("low", 6 + channel), ("level", 8 + channel)]:
            add(result, action, 4, number, "control", deck=deck)
        add(result, "cue", 4, 84 + channel, deck=deck, feedback=True)
    add(result, "crossfader", 4, 10, "control")
    add(result, "browse", 4, 64, "control", "twosComplement")
    for number in [65, 66]:
        add(result, "openGroup", 4, number)
    result["gaps"] = ["Shifted delete/mode functions, FX, hardware audio controls and jog/position illumination remain unimplemented. Jog response needs physical calibration. No application-connect packet is documented."]
    return [result]
