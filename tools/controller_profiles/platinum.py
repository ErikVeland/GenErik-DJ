"""Original Mixtrack Platinum facts from the pinned XML and script."""
from curated import add, profile
from numark import UPSTREAM

PLATINUM_SOURCES = [
    ("Numark Mixtrack Platinum.midi.xml", "22155364f8a6f981d38198b4b67e929f517057c38745586de7087e34b7f8840a"),
    ("Numark-Mixtrack-Platinum-scripts.js", "937259197d877cba7b921cc4ca6cae89ad9e93911e7b54d3ad72cb9c441e358a"),
]
PLATINUM_REFERENCES = {
    "Numark Mixtrack Platinum": {
        "url": UPSTREAM + PLATINUM_SOURCES[1][0], "sha256": PLATINUM_SOURCES[1][1],
        "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in PLATINUM_SOURCES],
        "review": "Pinned Mixxx MIDI and script facts. Native controls replace script execution. This is the original Platinum, not Platinum FX.",
    },
}


def platinum_profiles():
    result = profile("Numark Mixtrack Platinum", PLATINUM_REFERENCES["Numark Mixtrack Platinum"]["url"])
    result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
    result["scope"] = "Automatic native core controls. Explicit tempo pair and wrapped jog counts. Pads, advanced modes, screens and audio routing remain open."
    result["startup"] = [[0xF0, 0, 1, 0x3F, 0x7F, 0x3A, 0x60, 0, 4, 4, 1, 0, 0, 0xF7]]
    result["shutdown"] = [[0xF0, 0, 0x20, 0x7F, 2, 0xF7]]
    for channel, deck in enumerate("abcd"):
        start = len(result["inputs"])
        for action, number in [("play", 0), ("cueReturn", 1), ("sync", 2), ("cue", 27), ("load", 16)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue"})
        add(result, "jogTouch", channel, 6, deck=deck)
        add(result, "jog", channel, 6, "control", "numarkPlatinumJog", deck)
        add(result, "tempo", channel, 9, "control", "paired14Bit", deck)
        result["inputs"][-1].update(lowNumber=119, inverted=False)
        for action, number in [("gain", 22), ("high", 23), ("mid", 24), ("low", 25), ("filterKnob", 26), ("level", 28)]:
            add(result, action, channel, number, "control", deck=deck)
        for action, number in [("loop", 50), ("loopDown", 52), ("loopUp", 53)]:
            add(result, action, 4 + channel, number, deck=deck, feedback=action == "loop")
        for binding in result["inputs"][start:]:
            binding["shifted"] = False
        for action, number in [("loopIn", 56), ("loopOut", 57)]:
            add(result, action, 4 + channel, number, deck=deck)
            result["inputs"][-1]["shifted"] = True
        result["startup"].append([0x90 | channel, 7, 127])
    for action, number in [("crossfader", 8), ("master", 10), ("monitor", 12), ("cueMix", 13)]:
        add(result, action, 15, number, "control")
        if action == "monitor":
            result["inputs"][-1]["shifted"] = False
    add(result, "shift", 15, 50)
    add(result, "browse", 15, 0, "control", "twosComplement")
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 15, 31)
    result["inputs"][-1]["shifted"] = False
    for output in result["outputs"]:
        output["offValue"] = 1
    result["gaps"] = ["Pad/sample modes, Scratch toggle, advanced shifted functions, FX, meters, screens and full audio routing remain unimplemented. The wrapped-jog rule follows the pinned script and still needs physical calibration. Source reuse/distribution review remains open."]
    return [result]
