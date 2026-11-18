"""Reloop Ready native core from a pinned, measured hardware reference."""
from copy import deepcopy
from curated import add, profile

READY_REVISION = "077bd47f2d30ce1012cd6bc2e5dd02d8b34b7f61"
READY_BASE = "https://raw.githubusercontent.com/Grizbeard/reloop-ready-mixxx/" + READY_REVISION + "/"
READY_SOURCES = [
    ("docs/protocol.md", "08a9f8c66bef22306066580e3c98b51aeae932c5c1155f5fc4ead517c8617896"),
    ("Reloop-Ready.midi.xml", "32320440001ebece9d924e125c23f9288d0852d038f7a3fba3ce98d1924cbf7b"),
    ("Reloop-Ready-scripts.js", "d89798afbb7ac712ebb5904c955e121ffe3c29a6b4b4f254d81ed348836724a2"),
    ("profile/reloop-ready.json", "3967c648ce6591930a87802262cbd7daed341119fafe82ebd69c5564355cdff8"),
]
READY_REFERENCES = {"Reloop Ready": {
    "url": READY_BASE + READY_SOURCES[0][0], "sha256": READY_SOURCES[0][1], "revision": READY_REVISION,
    "relatedSources": [{"url": READY_BASE + name, "sha256": digest} for name, digest in READY_SOURCES],
    "review": "The author's measured protocol and source profile establish distinct hardware modifier addresses, CC9/63 pitch travel 0..1023, Note Off releases, 1024-count jogs and mode-select pad notes. Native fixed touch scratching is armed at startup. New contacts during unsupported Shift search are blocked; normal contact release remains valid. Fresh pitch pairs preserve the full measured travel, source inversion and pickup without inventing a calibrated midpoint. Hot Cue, fixed Auto Loop and manual loop pages have independent guards. Shifted release aliases rearm normal actions without triggering source clone/censor/key-sync/delete alternatives. Startup clears all sixteen RGB pads; mode LEDs are firmware-owned and receive no guesses. Mode-aware pad feedback, source Vinyl toggle/percentage search, other modes, full lights/cleanup, audio routing and physical acceptance remain open. Buddy is a separate protocol.",
}}


def ready_profiles():
    result = profile("Reloop Ready", READY_REFERENCES["Reloop Ready"]["url"])
    result["scope"] = "Automatic Ready core with measured ten-bit pitch, 1024-count fixed touch scratch, guarded cue/loop pages, browsing and direct Load. Native fixed Vinyl mode. Other modes, pad feedback, Shift search, full cleanup, audio routing and physical acceptance remain open."
    add(result, "shift", 14, 0)

    def button(action, channel, number, deck=None, mode=None, alias=None, feedback=False, argument=None):
        add(result, action, channel, number, deck=deck, feedback=feedback)
        if mode is not None:
            result["inputs"][-1]["requiredMode"] = mode
        if argument is not None:
            result["inputs"][-1]["argument"] = argument
        if alias is not None:
            release = deepcopy(result["inputs"][-1])
            release.update(channel=alias[0], number=alias[1], releaseOnly=True)
            result["inputs"].append(release)

    modes = [0, 5, 14, 11, 15, 9, 8, 18]
    result["inputModes"] = []
    for channel, deck in enumerate("ab"):
        pads = 4 + channel
        result["inputModes"].append({"channel": pads, "initial": 0, "numbers": modes, "onValue": 127, "offValue": 0})
        for action, number, alternate in [("play", 0, 16), ("cuePreview", 1, 5), ("sync", 2, 3),
                                          ("cue", 27, 14), ("keylock", 13, 41)]:
            button(action, channel, number, deck, alias=(channel, alternate), feedback=action != "cuePreview")
        button("load", 14, 2 + channel, deck, alias=(14, 27 if channel == 0 else 16))
        add(result, "jogTouch", channel, 6, deck=deck)
        result["inputs"][-1]["shifted"] = False
        add(result, "jog", channel, 6, "control", "twosComplement", deck)
        result["inputs"][-1]["argument"] = 1024
        add(result, "tempo", channel, 9, "control", "readyTempo", deck)
        result["inputs"][-1].update(lowNumber=63, inverted=True)
        for action, number in [("level", 28), ("gain", 22), ("high", 23), ("low", 25), ("filterKnob", 26)]:
            add(result, action, channel, number, "control", deck=deck)
        button("loop", pads, 64, deck, alias=(8 + channel, 4))
        add(result, "loopSize", pads, 52, "control", "twosComplement", deck)
        for action, number in [("jumpBack", 40), ("jumpForward", 41)]:
            button(action, pads, number, deck, alias=(pads, number + 2))
        for slot in range(8):
            button(f"hotcue{slot + 1}", pads, 20 + slot, deck, mode=0, alias=(pads, 28 + slot))
        for slot, beats in enumerate([1, 2, 4, 8]):
            button("toggleFixedLoop", pads, 20 + slot, deck, mode=5, alias=(pads, 28 + slot), argument=beats)
        for slot, action in enumerate(["loopIn", "loopOut", "reloop"]):
            button(action, pads, 20 + slot, deck, mode=14, alias=(pads, 28 + slot))
        for mode in [5, 14]:
            for action, number in [("loopDown", 25), ("loopUp", 26)]:
                button(action, pads, number, deck, mode=mode, alias=(pads, number + 8))
        result["startup"].extend([[0x90 + pads, 20 + slot, 0] for slot in range(8)])
        result["startup"].append([0x90 + channel, 15, 127])
        result["shutdown"].append([0x90 + channel, 15, 0])
    for action, number in [("master", 10), ("monitor", 12), ("cueMix", 13), ("crossfader", 8)]:
        add(result, action, 14, number, "control")
    add(result, "browse", 14, 0, "control", "twosComplement")
    button("openGroup", 14, 6, alias=(14, 123))
    result["shutdown"].extend([[0x90 + output["channel"], output["number"], 0] for output in result["outputs"]])
    return [result]
