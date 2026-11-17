"""Original VCI-100 native core from pinned XML and script facts."""
from curated import add, profile
from numark import UPSTREAM

VCI100_SOURCES = [
    ("Vestax VCI-100.midi.xml", "3e18272c9b3ec6dfd823cc80f9c2762e81612aa071e95f752b1a6df5c4fc668f"),
    ("Vestax-VCI-100-scripts.js", "0d7e9682fd37e8db31e18611f065ad22f151f31cd6b43f0ceb078ea9b29b799e"),
]
VCI100_REFERENCES = {"Vestax VCI-100": {
    "url": UPSTREAM + VCI100_SOURCES[0][0].replace(" ", "%20"), "sha256": VCI100_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in VCI100_SOURCES],
    "review": "Original XML separates Cue Goto, Preview and Set, direct Load, held pitch buttons, platter CC16/17 and ring CC18/19. Script scratch calibration is 384 ticks at 45 RPM, equivalent to 518.4 ticks at the native 33 1/3 RPM reference. Native fixed touch scratching keeps that time scale; the ring uses native nudging. Source rate inversion is applied once with exact centre. Shared loop/hotcue selector keys, source jog acceleration, FX, balance, lights/cleanup, routing and physical calibration remain open. Hile, 3DEX and MKII are not aliases for this recipe.",
}}


def vci100_profiles():
    result = profile("Vestax VCI-100", VCI100_REFERENCES["Vestax VCI-100"]["url"])
    result["excludedAliases"] = ["VCI-100 3DEX", "VCI-100-hile", "Vestax VCI-100 Hile Mod",
                                 "Vestax VCI-100 (MixVibes 3DEX Editon)", "Vestax VCI-100 (MixVibes 3DEX Edition)"]
    result["scope"] = "Automatic original VCI-100 two-deck core with fixed touch scratch, separate Cue Set/Goto/Preview and held pitch buttons. Shared loop/hotcue selectors, FX, lights/cleanup, audio routing and physical calibration remain open."
    for side, deck in enumerate("ab"):
        for action, number in [("play", 50 + 4 * side), ("cueGoto", 51 + 4 * side),
                               ("cuePreview", 52 + 4 * side), ("cueSet", 53 + 4 * side),
                               ("sync", 70 + side), ("cue", 72 + side), ("load", 96 + side),
                               ("pitchBendUp", 58 + 2 * side), ("pitchBendDown", 59 + 2 * side),
                               ("jogTouch", 48 + side)]:
            add(result, action, 0, number, deck=deck)
        add(result, "jog", 0, 16 + side, "control", "binaryOffset", deck)
        result["inputs"][-1].update(argument=518.4, requiresTouch=True)
        add(result, "wheelJog", 0, 18 + side, "control", "binaryOffset", deck)
        result["inputs"][-1]["argument"] = 518.4
        add(result, "tempo", 0, 14 + side, "control", "centreDetent", deck)
        for action, number in [("level", 12 + side), ("gain", 20 + 4 * side),
                               ("high", 21 + 4 * side), ("mid", 22 + 4 * side), ("low", 23 + 4 * side)]:
            add(result, action, 0, number, "control", deck=deck)
    for action, number in [("crossfader", 8), ("master", 7), ("monitor", 88), ("cueMix", 89)]:
        add(result, action, 0, number, "control")
    for action, number in [("browsePrevious", 92), ("browseNext", 93)]:
        add(result, action, 0, number)
    return [result]
