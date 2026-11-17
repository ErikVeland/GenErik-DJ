"""VCI-400 four-target core from pinned dispatch and control handlers."""
from curated import add, profile
from numark import UPSTREAM

VCI400_SOURCES = [
    ("Vestax VCI-400.midi.xml", "2ef6df3e503b96811382d71e11b7010569eca084ba6efbe6d1fa2911f9387450"),
    ("Vestax-VCI-400-scripts.js", "2b44136e2949374bafcf47d7a887d337cb01007aade8b7af07a2407282b7f19e"),
]
VCI400_REFERENCES = {"Vestax VCI-400": {
    "url": UPSTREAM + VCI400_SOURCES[0][0].replace(" ", "%20"), "sha256": VCI400_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in VCI400_SOURCES],
    "review": "XML supplies direct A/B/C/D Load and transport channels two through five. Script handlers supply 4096-count centre-64 jogs, pad modes and fixed Loop sizes 1/8 through 16 beats. Native startup selects Hot Cue rather than the source's unsupported initial Roll page. Mode guards block shared pads in Roll/Sampler modes. Loop pads enable fixed sizes without toggling off. Positive loop-encoder packets halve once and negative packets double once, regardless of magnitude. Native loop-size preselection also works before activation. Note34 bank loss/selection resets only that physical side and retains global Shift. Known transport-note variants retain held Cue releases. Undefined beatLoop, CC transport aliases, shared bank-dependent Key Lock, scratch-button contact, source brake/inertia code, full feedback, cleanup, EGE firmware, master/headphone controls, audio routing and physical calibration remain open.",
}}


def vci400_profiles():
    result = profile("Vestax VCI-400", VCI400_REFERENCES["Vestax VCI-400"]["url"])
    result["excludedAliases"] = ["VCI-400 EGE", "VCI-400 Ean Golden Edition"]
    result["scope"] = "Automatic four-target native core with direct Load, 4096-count touch jogs, guarded eight-cue/fixed-loop pages and mode-light lifecycle. EGE firmware, remaining modes, full feedback, cleanup, audio routing and physical calibration remain open."
    result["inputModes"] = [{"channel": ch, "initial": 21, "numbers": [21, 22, 23, 24], "onValue": 127, "offValue": 0} for ch in range(2, 6)]
    result["startup"] = [[0x90 + ch, note, 127 if note == 21 else 0] for ch in range(2, 6) for note in [22, 23, 24, 21]]
    result["shutdown"] = [[0x90 + ch, note, 0] for ch in range(2, 6) for note in [21, 22, 23, 24]]
    result["bankChanges"] = [{"channel": ch, "number": 34, "onValue": 127,
                               "decks": ["a", "c"] if ch % 2 == 0 else ["b", "d"],
                               "releaseShiftChannels": []} for ch in range(2, 6)]
    add(result, "shift", 0, 1)
    for channel, deck in enumerate("abcd", 2):
        for action, number in [("sync", 1), ("cue", 5), ("play", 26), ("play", 28),
                               ("cuePreview", 25), ("cuePreview", 27), ("load", 2), ("reloop", 20)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"sync", "cue", "play"})
            if action in {"play", "load"}:
                result["inputs"][-1]["shifted"] = False
        add(result, "jogTouch", channel, 39, deck=deck)
        add(result, "jog", channel, 19, "control", "binaryOffset", deck)
        result["inputs"][-1]["argument"] = 4096
        for action, number in [("tempo", 18), ("level", 17)]:
            add(result, action, channel, number, "control", "paired14Bit", deck)
            if action == "tempo":
                result["inputs"][-1].update(inverted=True, shifted=False)
        for action, number in [("gain", 12), ("high", 13), ("mid", 14), ("low", 15)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "loopSize", channel, 6, "control", "binaryDirection", deck)
        result["inputs"][-1].update(inverted=True, shifted=False)
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", channel, 7 + slot, deck=deck)
            result["inputs"][-1].update(requiredMode=21, shifted=False)
            add(result, "fixedLoop", channel, 7 + slot, deck=deck)
            result["inputs"][-1].update(requiredMode=22, argument=2 ** (slot - 3))
    add(result, "crossfader", 0, 20, "control")
    add(result, "browse", 14, 40, "control", "twosComplement")
    add(result, "openGroup", 14, 113)
    return [result]
