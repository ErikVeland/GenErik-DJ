"""XDJ-AERO and R1 core controls from their factory operating manuals."""
from curated import add, profile

LEGACY_SYSTEM_REFERENCES = {
    "Pioneer XDJ-AERO": {
        "url": "https://www.recordcase.de/media/94/f5/e0/1745829305/Pioneer-XDJ-AERO-Manual-EN.pdf",
        "sha256": "72e14c9420b09e81fdc790bb00a609ad1f8d197890b4416205c4f98b84d171b3",
        "pages": [23, 26, 29, 30, 31, 32],
        "publisher": "Pioneer Corporation. Factory manual hosted by Recordcase.",
    },
    "Pioneer XDJ-R1": {
        "url": "https://www.uns.nu/pdf/Pioneer_XDJ-R1_Manual.pdf",
        "sha256": "5f41454ad19ac54527dd6f32c9e5e6e4d9812a53be7f6a82829042dbc02ec183",
        "pages": [22, 27, 28, 29, 30, 31, 32, 33, 34],
        "publisher": "Pioneer Corporation. Factory manual hosted by UNS.",
    },
}


def legacy_system_profiles():
    results = []
    for name, source in LEGACY_SYSTEM_REFERENCES.items():
        r1 = name.endswith("R1")
        result = profile(name, source["url"])
        result["scope"] = "Automatic core MIDI controls. Hardware modes, remaining functions, screens and audio routing remain open."
        result["hardwareMode"] = "Select MIDI control and MIXER MODE PC for software mixing."
        for channel, deck in enumerate("abcd"):
            for action, number in [("play", 11), ("cueReturn", 12), ("sync", 88), ("keylock", 26), ("loop", 20), ("reloop", 80), ("load", 66)]:
                add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "keylock", "loop"})
            add(result, "loopSize", channel, 19, "control", "twosComplement", deck)
            for number in [2, 7]:
                add(result, "jog", channel, number, "control", "binaryOffset", deck)
            for number in [1, 6]:
                add(result, "wheelJog", channel, number, "control", "binaryOffset", deck)
            for number in [54, 103]:
                add(result, "jogTouch", channel, number, deck=deck)
            add(result, "tempo", channel, 0, "control", "paired14Bit", deck)
            if r1:
                for slot in range(3):
                    add(result, f"hotcue{slot + 1}", channel, 46 + slot, deck=deck, feedback=True)
            for action, number in [("gain", 3 + channel), ("high", 7 + channel), ("mid", 11 + channel),
                                   ("low", 15 + channel), ("level", 19 + 2 * channel), ("filterKnob", 27 + channel)]:
                add(result, action, 6, number, "control", "paired14Bit", deck)
            add(result, "cue", 6, 84 + channel, deck=deck, feedback=True)
            add(result, "browse", channel, 64, "control", "twosComplement")
            add(result, "openGroup", channel, 68)
        for action, number in [("crossfader", 31), ("master", 0), ("monitor", 2), ("cueMix", 1)]:
            add(result, action, 6, number, "control", "paired14Bit")
        result["gaps"] = ["Shifted modes, FX/samples, deck-bank display feedback, screens and complete audio routing remain unimplemented. No startup packet is documented. Jog response needs physical calibration."]
        results.append(result)
    return results
