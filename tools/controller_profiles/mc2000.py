"""MC2000 native core facts from the manufacturer's own MIDI table."""
from curated import add, profile
from mc6000 import feedback

MC2000_GUIDE = "https://cdn.inmusicbrands.com/denondj/legacy/mc2000/MC2000EM_ENG_CD-ROM_IM_v00.pdf"
MC2000_REVISION = "f75f0e8ab5d4ebe342af03e8370c0101af4e9af2"
MC2000_BASE = "https://raw.githubusercontent.com/gThomas99/MIXXX_Denon_MC-2000_Controller/" + MC2000_REVISION + "/"
MC2000_REFERENCES = {"Denon MC2000": {
    "url": MC2000_GUIDE, "sha256": "796085f033f552c6669c85ea5421ba0b5977e22797d328483cbeab5a8f293834",
    "pages": [20, 21, 22, 23, 24],
    "relatedSources": [{"url": MC2000_BASE + "Denon-MC2000-scripts.js", "sha256": "bdd4cded5c1f2ed6bd117d65544ecfb18acb8279f40daebeecccf9131757b289", "revision": MC2000_REVISION}],
    "review": "Factory pages 20-22 and the channel-range diagram establish input addresses and separate LED trigger commands. The right gain is CC 12 on channel 1, not the community XML's CC 1. Jog touch is Note 81, not the CSV's conflicting Note 82. The factory's hexadecimal master/Play LED addresses take precedence over misprinted decimal columns. Pitch remains native 14-bit and retains the reviewed source Pot direction after Mixxx rate translation. No arbitrary source 125-count sensitivity, gain-as-filter, shift lock, crossfader Sync, startup mixer-level changes or forced PFL is copied. Manual and adjustable loop boundaries, mode toggles, extra functions, complete feedback, cleanup, routing and physical calibration remain open.",
}}


def mc2000_profiles():
    result = profile("Denon MC2000", MC2000_GUIDE)
    result["aliases"].append("Denon DJ MC2000")
    result["scope"] = "Automatic two-deck native core MIDI with factory channel ranges, held Cue, 14-bit tempo, four Hot Cues, preset loops and separate LED trigger commands. Sensitivity uses the native default pending calibration. Manual loop boundaries, extra modes, full feedback, cleanup, routing and physical acceptance remain open."
    result["startup"] = [[0xB0 + channel, 74, value] for channel in range(2) for value in [6, 57]]
    result["shutdown"] = [[0xB0 + channel, 75, 6] for channel in range(2)]
    add(result, "shift", 0, 96)
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 67), ("cuePreview", 66), ("sync", 107), ("keylock", 6),
                               ("loop", 29), ("loopDown", 105), ("loopUp", 106), ("cue", 1 if channel == 0 else 5)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1]["shifted"] = False
        add(result, "load", 0, 98 + channel, deck=deck)
        result["inputs"][-1]["shifted"] = False
        for number in [81, 86, 87]:
            add(result, "jogTouch", channel, number, deck=deck)
            result["inputs"][-1]["shifted"] = False
            if number != 81:
                result["inputs"][-1]["releaseOnly"] = True
        for action, number in [("jog", 81), ("wheelJog", 82)]:
            add(result, action, channel, number, "control", "denonJog", deck)
            result["inputs"][-1]["shifted"] = False
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1].update(inverted=True, shifted=False)
        for action, number in [("gain", 1), ("high", 2), ("mid", 3), ("low", 4), ("level", 5)]:
            add(result, action, channel, number + 11 * channel, "control", deck=deck)
        for slot, number in enumerate([23, 24, 25, 32], 1):
            add(result, f"hotcue{slot}", channel, number, deck=deck)
            result["inputs"][-1]["shifted"] = False
            feedback(result, f"hotcue{slot}", channel, [17, 19, 21, 23][slot - 1], deck)
        for action, identifier in [("play", 39), ("sync", 9), ("keylock", 8), ("loop", 43)]:
            feedback(result, action, channel, identifier, deck)
        feedback(result, "cue", channel, 69 if channel == 0 else 81, deck, regular=True)
    for action, number in [("crossfader", 22), ("master", 25), ("cueMix", 67), ("monitor", 68)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 84, "control", "signedStep")
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 0, 40)
    result["inputs"][-1]["shifted"] = False
    return [result]
