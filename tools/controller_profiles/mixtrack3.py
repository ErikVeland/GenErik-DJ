"""Shared Mixtrack 3 and Pro 3 protocol facts from the pinned Mixxx mapping."""
from curated import add, profile
from numark import UPSTREAM

MIXTRACK3_SOURCES = [
    ("Numark-Mixtrack-3.midi.xml", "f1624e28b10047d64044684599badea8ae1624d70329dceb62721ea454d1125d"),
    ("Numark-Mixtrack-3-scripts.js", "c24139a51fbcdf0b334c29c8706e17981c5dc45e333e29665c177acc791f80c6"),
]


def mixtrack3_references():
    return {name: {"url": UPSTREAM + MIXTRACK3_SOURCES[1][0], "sha256": MIXTRACK3_SOURCES[1][1],
                   "relatedSources": [{"url": UPSTREAM + path, "sha256": digest} for path, digest in MIXTRACK3_SOURCES],
                   "review": "The pinned XML explicitly covers both models. The Pro adds audio hardware. Native core actions replace script execution."}
            for name in ["Numark Mixtrack Pro 3", "Numark Mixtrack 3"]}


def mixtrack3_profiles():
    results = []
    for name, source in mixtrack3_references().items():
        result = profile(name, source["url"])
        result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
        result["scope"] = "Automatic native core controls. Per-deck Shift blocks unsupported combinations. Pad modes, Scratch toggle, FX and audio routing remain open."
        result["startup"] = [[0x91, 6, 127], [0x92, 6, 127]]
        result["shutdown"] = [[0x81, 6, 0], [0x82, 6, 0]]
        for index, deck in enumerate("ab"):
            channel = index + 1
            start = len(result["inputs"])
            for action, number in [("play", 1), ("cueReturn", 3), ("sync", 2), ("loopIn", 19), ("loopOut", 20), ("reloop", 21), ("loopDown", 22)]:
                add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync"})
            add(result, "jogTouch", channel, 12, deck=deck)
            add(result, "jog", channel, 17, "control", "twosComplement", deck)
            add(result, "tempo", channel, 24, "control", "paired14Bit", deck)
            result["inputs"][-1]["inverted"] = False
            for action, number in [("high", 1), ("mid", 2), ("low", 3), ("filterKnob", 4), ("level", 5)]:
                add(result, action, channel, number, "control", deck=deck)
            add(result, "load", 0, 16 + index, deck=deck)
            add(result, "cue", 0, 14 + index, deck=deck, feedback=True)
            for binding in result["inputs"][start:]:
                binding.update(shifted=False, shiftChannel=channel)
            add(result, "shift", channel, 11)
            result["inputs"][-1]["shiftChannel"] = channel
        for action, number in [("crossfader", 7), ("master", 10), ("monitor", 8), ("cueMix", 9)]:
            add(result, action, 0, number, "control")
        add(result, "browse", 0, 23, "control", "twosComplement")
        add(result, "openGroup", 0, 18)
        for output in result["outputs"]:
            output["offUsesNoteOn"] = False
        result["gaps"] = ["Pad/sample modes, shifted functions, deck switching, Scratch toggle, FX and complete audio routing remain unimplemented. Platter touch uses native Scratch mode and lights the published jog indicator. Physical calibration and source reuse/distribution review remain open."]
        results.append(result)
    return results
