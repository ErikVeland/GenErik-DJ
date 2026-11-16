"""Inpulse 300 MK2 core facts, separate from the first-generation controller."""
from curated import add, profile

MK2_REVISION = "2acfb3506a6dab38a47c47b93ee653cdb5f393c7"
MK2_BASE = "https://raw.githubusercontent.com/DCinAC/mixxx-inpulse-300-mk2/" + MK2_REVISION + "/"
MK2_SOURCES = [
    ("Hercules%20DJControl%20Inpulse%20300mk2%20-%204%20deck.midi.xml", "1f54a216135719cf94d334d0c780816eaa03b1bf2be5056475298a80d8f65cc5"),
    ("v2_Hercules-DJControl-Inpulse-300mk2-script.js", "cb88254849ee1ea88afb235edcdafe0286f3e84af359b2071c69e0cff33c1d01"),
]
MK2_GUIDE = "https://ts.hercules.com/download/sound/manuals/DJC_Inpulse_300_MK2/DJControl_Inpulse_300_MK2_User_Manual_EN.pdf"
MK2_REFERENCES = {"Hercules DJControl Inpulse 300 MK2": {
    "url": MK2_BASE + MK2_SOURCES[0][0], "sha256": MK2_SOURCES[0][1], "revision": MK2_REVISION,
    "relatedSources": [{"url": MK2_BASE + path, "sha256": digest} for path, digest in MK2_SOURCES] +
        [{"url": MK2_GUIDE, "sha256": "5db936903afd65d0cff534b4e7da90f8a433efaca03311f52b3d58a6778afce9", "pages": [12, 50, 52, 53, 54]}],
    "review": "Only hardware-address facts and the 248-count scratch scale are reused. The community fork's Assistant-controlled software four-deck bank and stem/FX code are not copied. The XML assigns pad address 0 on channel 6 to Hot Cue 1, an effect selector and Beat Jump. All pads remain unmapped until the conflicting facts are resolved. Native two-deck transport uses channels 1/2, with hardware shifted messages on 4/5. Shifted scratch uses four times the count scale. The manufacturer guide gives manual IN/OUT and active-loop boundary adjustment; the fork's IN-to-four-beat customisation is not copied. Those boundary buttons remain unmapped. Core loop toggle and shifted loop sizing remain available. Remaining modes, complete feedback, cleanup, audio routing and physical calibration stay open. Source reuse review remains open.",
}}


def inpulse300mk2_profiles():
    result = profile("Hercules DJControl Inpulse 300 MK2", MK2_REFERENCES["Hercules DJControl Inpulse 300 MK2"]["url"])
    result["definition"] = "reviewed:hercules-inpulse-300-mk2"
    result["scope"] = "Automatic two-deck native core MIDI with normal/shifted scratch, 248-count source resolution, held Cue, Load, loop toggle and loop sizing. The first-generation 300 has a separate recipe. Conflicting pads, manual/adjustable loop boundaries, Assistant software banking, extra modes, full feedback, cleanup, routing and calibration remain open."
    result["startup"] = [[0x94, 1, 127], [0x95, 1, 127], [0x90, 4, 5], [0xB0, 127, 127]]
    result["shutdown"] = [[0x94, 1, 0], [0x95, 1, 0], [0x90, 4, 0]]
    for channel, deck in enumerate("ab", 1):
        shifted = channel + 3
        for action, number in [("play", 7), ("cuePreview", 6), ("sync", 5), ("cue", 12), ("load", 13), ("jogTouch", 8), ("loop", 3)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue", "loop"})
        add(result, "cuePreview", shifted, 6, deck=deck)
        result["inputs"][-1].update(shifted=True, releaseOnly=True)
        add(result, "jogTouch", shifted, 8, deck=deck)
        for action, number in [("keylock", 2), ("loopDown", 9), ("loopUp", 10)]:
            add(result, action, shifted, number, deck=deck, feedback=action == "keylock")
        for action, number in [("level", 0), ("filterKnob", 1), ("low", 2), ("mid", 3), ("high", 4), ("gain", 5)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "tempo", channel, 8, "control", "paired14Bit", deck)
        result["inputs"][-1]["inverted"] = True
        for action, ch, number, resolution in [("jog", channel, 10, 248), ("wheelJog", channel, 9, 248), ("jog", shifted, 10, 62)]:
            add(result, action, ch, number, "control", "signedStep", deck)
            result["inputs"][-1]["argument"] = resolution
    add(result, "crossfader", 0, 0, "control")
    add(result, "browse", 0, 1, "control", "twosComplement")
    add(result, "openGroup", 0, 0)
    return [result]
