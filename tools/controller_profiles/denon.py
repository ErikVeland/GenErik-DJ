"""Denon core protocol facts checked against factory and pinned working sources."""
from curated import add, profile
from numark import UPSTREAM

MC4000_SOURCES = [
    ("Denon MC4000.midi.xml", "c3e48e924916e3bd982b70f755853385f400e4c4e77c035432c93f83c7cab570"),
    ("Denon-MC4000-scripts.js", "dbfbd0f0307e891e0f4a8f93eae93ff445c5aa7a97c5ff58670331c663127e70"),
]
MC4000_MANUAL = "https://cdn.inmusicbrands.com/denondj/MC4000/MC4000-User-Guide-v1.2_00.pdf"


def denon_references():
    return {"Denon MC4000": {"url": MC4000_MANUAL,
            "sha256": "afe48b9f4f71be813dd233985375a4405cd284b0ce225d644ba56735664847d6",
            "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in MC4000_SOURCES],
            "review": "Factory pages 30–31 specify controls and LED echo. The table labels pitch CC 9/41 as LSB/MSB. The pinned working XML instead pairs MSB 9 with LSB 41; this recipe follows that working order and rate_dir -1. Physical verification remains open."}}


def denon_profiles():
    result = profile("Denon MC4000", MC4000_MANUAL)
    result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
    result["aliases"].append("Denon DJ MC4000")
    result["scope"] = "Automatic native core controls. Global Shift guards unsupported combinations. Pad modes, Vinyl toggle, FX, meters and audio routing remain open."
    result["startup"] = [[0xF0, 0, 2, 11, 127, 1, 96, 0, 4, 4, 1, 0, 0, 0xF7],
                         [0x90, 7, 127], [0x91, 7, 127]]
    result["shutdown"] = [[0x90, 7, 0], [0x91, 7, 0]]
    for channel, deck in enumerate("ab"):
        start = len(result["inputs"])
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 2), ("keylock", 13), ("cue", 27), ("jogTouch", 6)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "keylock", "cue"})
        add(result, "load", 15, 2 + channel, deck=deck)
        add(result, "jog", channel, 6, "control", "twosComplement", deck)
        add(result, "tempo", channel, 9, "control", "paired14Bit", deck)
        result["inputs"][-1]["inverted"] = True
        for action, number in [("gain", 22), ("high", 23), ("mid", 24), ("low", 25), ("filterKnob", 26), ("level", 28)]:
            add(result, action, channel, number, "control", deck=deck)
        for action, number in [("loop", 50), ("reloop", 51), ("loopDown", 52), ("loopUp", 53)]:
            add(result, action, channel + 4, number, deck=deck, feedback=action == "loop")
        for binding in result["inputs"][start:]:
            binding["shifted"] = False
        for action, number in [("loopIn", 56), ("loopOut", 57)]:
            add(result, action, channel + 4, number, deck=deck)
            result["inputs"][-1]["shifted"] = True
    for action, number in [("crossfader", 8), ("monitor", 12), ("cueMix", 13)]:
        add(result, action, 15, number, "control")
    add(result, "browse", 15, 0, "control", "twosComplement")
    add(result, "openGroup", 15, 31)
    add(result, "openGroup", 15, 7)
    add(result, "shift", 15, 50)
    result["gaps"] = ["The factory table reverses pitch byte labels compared with the pinned working mapping. Pads and advanced pad modes, Vinyl toggle, additional shifted functions, pitch-bend buttons, FX, meters and complete audio routing remain unimplemented. Jog calibration and source reuse/distribution review remain open."]
    return [result]
