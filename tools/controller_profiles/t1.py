"""DDJ-T1 MIDI facts from the original Pioneer operating manual."""
from curated import add, profile

T1_REFERENCES = {"Pioneer DDJ-T1": {
    "url": "https://jpn.pioneer/ja/support/manual/manual_pdf.php?m_id=5799",
    "sha256": "143d6f700323457b7acec969de1467d6b9783e64efe33e0fba49e362e41ca9b2",
    "pages": [28, 29, 30, 31],
    "review": "Original Japanese manual. Deck channels 1–4, global mixer/browser channel 7. Jog uses signed CC 1/33 or shifted 6/38 pairs, not DDJ-S1 platter CC 2/34. Deck/Shift buttons emit no MIDI. The needle table contradicts its own endpoint range, and mixer LED output uses an unresolved channel variable; those outputs remain unmapped."}}


def t1_profiles():
    result = profile("Pioneer DDJ-T1", T1_REFERENCES["Pioneer DDJ-T1"]["url"])
    result["scope"] = "Automatic native core MIDI controls from the factory manual. Move/Hot Cue modes, needle position, full feedback, FX and audio routing remain open."
    for channel, deck in enumerate("abcd"):
        for action, number in [("play", 11), ("cueReturn", 12), ("keylock", 26),
                               ("loop", 20), ("loopIn", 16), ("loopOut", 17), ("reloop", 18), ("filterToggle", 69)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "keylock"})
        add(result, "loopSize", channel, 19, "control", "twosComplement", deck)
        for number in [1, 6]:
            add(result, "jog", channel, number, "control", "paired14BitRelative", deck)
            result["inputs"][-1]["argument"] = 2430
        for number in [54, 103]:
            add(result, "jogTouch", channel, number, deck=deck)
        for number in [0, 5]:
            add(result, "tempo", channel, number, "control", "paired14Bit", deck)
        for number in [4, 9]:
            add(result, "filterKnob", channel, number, "control", deck=deck)
        for action, number in [("load", 70 + channel), ("cue", 84 + channel), ("sync", 88 + channel)]:
            add(result, action, 6, number, deck=deck)
        for action, number in [("gain", 3 + channel), ("high", 7 + channel), ("mid", 11 + channel),
                               ("low", 15 + channel), ("level", 19 + 2 * channel)]:
            add(result, action, 6, number, "control", deck=deck)
    for action, number in [("master", 0), ("cueMix", 1), ("monitor", 2), ("crossfader", 31)]:
        add(result, action, 6, number, "control")
    add(result, "browse", 6, 64, "control", "twosComplement")
    for number in [65, 66]:
        add(result, "openGroup", 6, number)
    result["gaps"] = ["Move/Hot Cue/Delete modes, shifted alternate functions, needle position, mixer feedback channel, full loop/transport feedback, FX and audio routing remain unimplemented. The needle table gives 1–127 but labels its right endpoint 27. Mixer LED output uses 9n without resolving n for that block. These ambiguous facts stay unmapped. No application-connect packet is documented. Jog calibration and physical acceptance remain open."]
    return [result]
