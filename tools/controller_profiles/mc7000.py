"""MC7000 core protocol facts from the pinned Mixxx mapping."""
from curated import add, profile
from numark import UPSTREAM

MC7000_SOURCES = [
    ("Denon-MC7000.midi.xml", "d12a96a48aad17be649c914a61a341303c0d7b43ac5bee37158bc0c61e1db09a"),
    ("Denon-MC7000-scripts.js", "5d2b24a7c36a3e5e7886e43b7e4fd83378ca5857c48beb7ba99b47ef26bda2a3"),
]
MC7000_REFERENCES = {"Denon MC7000": {
    "url": UPSTREAM + MC7000_SOURCES[1][0], "sha256": MC7000_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + path, "sha256": digest} for path, digest in MC7000_SOURCES],
    "review": "Native actions replace script execution. The jog rule is exactly value < 0x64 ? value : value - 128. Its unusual threshold remains explicit and needs physical calibration. Tempo pairs MSB 9 with LSB 119; source rate inversion cancels rate_dir -1. Shift follows the source per-deck state. Advanced modes, full feedback and audio routing remain open."}}


def mc7000_profiles():
    result = profile("Denon MC7000", MC7000_REFERENCES["Denon MC7000"]["url"])
    result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
    result["aliases"].append("Denon DJ MC7000")
    result["scope"] = "Automatic native core controls from pinned source facts. Per-deck Shift guards unsupported functions. Jog calibration, pad modes, screens and audio routing remain open."
    result["startup"] = [[0xF0, 0, 32, 127, 3, 1, 0xF7], [0x90, 8, 127], [0x91, 8, 127]]
    result["startup"] += [[0x90 + channel, 7, 127] for channel in range(4)]
    result["shutdown"] = [[0x90 + channel, 7, 1] for channel in range(4)]
    for channel, deck in enumerate("abcd"):
        start = len(result["inputs"])
        for action, number in [("play", 0), ("cueReturn", 1), ("sync", 2), ("keylock", 13), ("jogTouch", 6)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "keylock"})
        add(result, "load", 15, 2 + channel, deck=deck)
        add(result, "jog", channel, 6, "control", "mc7000Jog", deck)
        for action, number in [("loop", 50), ("loopDown", 52), ("loopUp", 53)]:
            add(result, action, channel + 4, number, deck=deck, feedback=action == "loop")
        for binding in result["inputs"][start:]:
            binding.update(shifted=False, shiftChannel=channel)
        for action, number in [("loopIn", 56), ("loopOut", 57), ("reloop", 51)]:
            add(result, action, channel + 4, number, deck=deck)
            result["inputs"][-1].update(shifted=True, shiftChannel=channel)
        add(result, "shift", channel, 50)
        result["inputs"][-1]["shiftChannel"] = channel
        add(result, "tempo", channel, 9, "control", "paired14Bit", deck)
        result["inputs"][-1]["lowNumber"] = 119
        for action, number in [("gain", 22), ("high", 23), ("mid", 24), ("low", 25), ("filterKnob", 26), ("level", 28)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "cue", channel, 27, deck=deck, feedback=True)
    add(result, "crossfader", 15, 8, "control")
    add(result, "browse", 15, 0, "control", "twosComplement")
    for number in [31, 7, 6]:
        add(result, "openGroup", 15, number)
    for output in result["outputs"]:
        output["offValue"] = 1
    result["gaps"] = ["The pinned jog threshold is 0x64, not the usual signed midpoint. This implementation preserves that published rule; independent byte-range confirmation and physical calibration remain open. Pad modes, Vinyl toggle, deck-selection LEDs, platter rings, extra shifted functions, FX, meters, screens, full lifecycle reset and audio routing remain unimplemented. Shift state follows the pinned per-deck mapping; bank changes while held need physical verification. Source reuse/distribution review remains open."]
    return [result]
