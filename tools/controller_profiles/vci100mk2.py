"""VCI-100MKII core from pinned XML dispatch and script handlers."""
from curated import add, profile
from numark import UPSTREAM

VCI100MK2_SOURCES = [
    ("Vestax VCI-100MKII.midi.xml", "ca8cd77428b7cf6133158b048a002e77f5db43a3aa27ab7e8195c71df35b9677"),
    ("Vestax-VCI-100MKII-scripts.js", "ac8e4211219dabb7b653514b4ea7e0d174082ac6595dadb20d12d388f670ece4"),
]
VCI100MK2_REFERENCES = {"Vestax VCI-100MKII": {
    "url": UPSTREAM + VCI100MK2_SOURCES[0][0].replace(" ", "%20"), "sha256": VCI100MK2_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in VCI100MK2_SOURCES],
    "review": "XML dispatch defines four target channels, fixed physical Shift notes and explicit A/C and B/D bank reports. Normal pitch high/low addresses differ by sixteen, not the MIDI standard thirty-two. The source rate expression is centred at raw 8192 and translates once through Mixxx rate_dir. A fresh pair produces native raw/16384, retaining exact centre and source endpoint asymmetry. Native fixed touch scratching retains 2400 counts per revolution. Shifted release aliases preserve ordinary buttons and held Cue. Both physical Shift keys guard loop-size functions because the source changes their meaning under either hold. Shift plus the navigation/load button loads. Source library focus changes, brake/slip timers, quantised pitch, pitch adjustment, alternate functions, full lights, cleanup, routing and physical calibration remain open.",
}}


def vci100mk2_profiles():
    result = profile("Vestax VCI-100MKII", VCI100MK2_REFERENCES["Vestax VCI-100MKII"]["url"])
    result["aliases"] += ["Vestax VCI-100 mk II", "VCI-100 mk II"]
    result["scope"] = "Automatic four-target native core with 2400-count touch jogs, exact-centre paired tempo, two Hot Cues, guarded loops and bank/Shift continuity. Quantised pitch, alternate functions, full feedback, cleanup, routing and physical calibration remain open."
    result["bankChanges"] = [{"channel": side, "number": number, "onValue": 127,
                               "decks": ["a", "c"] if side == 0 else ["b", "d"]}
                              for side in range(2) for number in [52, 53]]
    for side, number in enumerate([36, 52]):
        for scope in [side, 2]:
            add(result, "shift", 4, number)
            result["inputs"][-1]["shiftChannel"] = scope
    for channel, deck in enumerate("abcd"):
        side = channel % 2
        for action, number in [("play", 34), ("cuePreview", 35), ("sync", 36), ("keylock", 45),
                               ("cue", 54), ("loop", 38 if side == 0 else 51),
                               ("loopDown", 51 if side == 0 else 41), ("loopUp", 41 if side == 0 else 38),
                               ("hotcue1", 42), ("hotcue2", 43)]:
            add(result, action, channel, number, deck=deck,
                feedback=action not in {"cuePreview", "loopDown", "loopUp"})
            scope = 2 if action in {"loopDown", "loopUp"} else side
            result["inputs"][-1].update(shifted=False, shiftChannel=scope)
            add(result, action, channel, number + 32, deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=scope, releaseOnly=True)
        add(result, "load", channel, 55, deck=deck)
        result["inputs"][-1].update(shifted=True, shiftChannel=side)
        add(result, "jogTouch", channel, 59, deck=deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=side)
        add(result, "jog", channel, 16, "control", "binaryOffset", deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=side, argument=2400)
        add(result, "tempo", channel, 27 if side == 0 else 17, "control", "vci100MK2Tempo", deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=side, lowNumber=43 if side == 0 else 33)
        for action, number in [("gain", 21), ("high", 17 if side == 0 else 20),
                               ("mid", 18 if side == 0 else 28), ("low", 19)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "level", channel, 28 if side == 0 else 22, "control", "paired14Bit", deck)
        result["inputs"][-1]["lowNumber"] = 44 if side == 0 else 38
        result["shutdown"] += [[0x90 + channel, number, 0] for number in [34, 36, 45, 54]]
    add(result, "crossfader", 4, 16, "control", "paired14Bit")
    result["inputs"][-1]["lowNumber"] = 32
    for action, number in [("monitor", 18), ("cueMix", 19), ("master", 20)]:
        add(result, action, 4, number, "control")
    for action, number in [("browsePrevious", 55), ("browseNext", 56)]:
        add(result, action, 4, number)
    return [result]
