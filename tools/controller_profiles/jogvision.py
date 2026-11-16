"""Jogvision core MIDI facts from the factory command list and pinned mapping."""
from curated import add, profile
from numark import UPSTREAM

JOGVISION_SOURCES = [
    ("Hercules_DJControl_Jogvision.midi.xml", "8e0499c69c0b91494b8af06da6c722d80c39efc978d7f56c8536c47fc226c7fe"),
    ("Hercules_DJControl_Jogvision-scripts.js", "5cc5b31d7ad135a30762c6c6e55c82d0e26fd8b645306068ccef98a5ffb5384a"),
]
JOGVISION_TABLE = "https://ts.hercules.com/download/sound/manuals/DJC_Jogvision/DJCJogvision_MIDI_Commands.pdf"
JOGVISION_REFERENCES = {"Hercules DJControl Jogvision": {
    "url": JOGVISION_TABLE, "sha256": "a9ecc66294baaa6492ed812109335318bec386dabd4977d9c4ebfa7345f9baf7",
    "pages": [2, 3, 4, 5, 6, 10, 11, 12, 14, 15, 16, 26, 27, 28, 29, 35, 36, 37],
    "relatedSources": [{"url": UPSTREAM + path, "sha256": digest} for path, digest in JOGVISION_SOURCES],
    "review": "Normal deck channels 0/1. The native recipe combines Shift and Mode as guards for unsupported alternatives, without copying script backspin, slip, eject or quantise changes. The pinned scratch resolution is 400. Normal platter/rim CCs are 65/64 and shifted CCs are 67/66. Factory pad pages have distinct note ranges for cues and samples. CC 126 controls Scratch mode; CC 127 requests analogue and keypad-mode reports. The source's LED-clear comments for CC 127 are not followed. Shutdown does not eject tracks. Shift+Browse is a relative encoder used for custom gain by the source; the device has no dedicated gain knob, so that customisation is not imported. AIR filter, remaining modes, rings, full feedback, cleanup, routing and physical calibration remain open.",
}}


def jogvision_profiles():
    result = profile("Hercules DJControl Jogvision", JOGVISION_TABLE)
    result["definition"] = "reviewed:hercules-jogvision"
    result["scope"] = "Automatic native core MIDI on default channels 0/1. Source-derived 400-count jogs, held Cue, Load, loops and separate Hot Cue pages. Scratch mode stays enabled. Shift and Mode guard unsupported alternatives. AIR filter, remaining modes, rings, full feedback, cleanup, routing and physical calibration remain open."
    result["startup"] = [[0xB0, 126, 127], [0x90, 70, 127], [0xB0, 127, 127]]
    result["shutdown"] = [[0xB0, 126, 0], [0x90, 70, 0]]
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 50), ("cuePreview", 49), ("sync", 48), ("cue", 51), ("keylock", 52),
                               ("load", 81), ("jogTouch", 85), ("loop", 1), ("loopDown", 0), ("loopUp", 2)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue", "keylock", "loop"})
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
        add(result, "cuePreview", channel, 54, deck=deck)
        result["inputs"][-1].update(shifted=True, shiftChannel=channel, releaseOnly=True)
        for number in [86, 87]:
            add(result, "shift", channel, number)
            result["inputs"][-1]["shiftChannel"] = channel
        add(result, "tempo", channel, 2, "control", "paired14Bit", deck)
        result["inputs"][-1]["inverted"] = True
        for action, number in [("level", 1), ("high", 3), ("mid", 4), ("low", 5)]:
            add(result, action, channel, number, "control", deck=deck)
        for action, number in [("jog", 65), ("wheelJog", 64), ("loopSize", 68)]:
            add(result, action, channel, number, "control", "twosComplement", deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
            if action != "loopSize":
                result["inputs"][-1]["argument"] = 400
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", channel, 16 + slot, deck=deck, feedback=True)
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
            result["outputs"][-1]["onValue"] = 126
    add(result, "crossfader", 0, 0, "control")
    add(result, "browse", 0, 78, "control", "twosComplement")
    add(result, "openGroup", 0, 79)
    return [result]
