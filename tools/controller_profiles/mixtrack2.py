"""Mixtrack II family protocol facts from the pinned shared mapping."""
from curated import add, profile
from numark import UPSTREAM

MIXTRACK2_SOURCES = [
    ("Numark Mixtrack 2.midi.xml", "7550d413ea9c7e17ec0de63bdae4642759552ae2f25b69404feb6e0bae524d4f"),
    ("Numark-Mixtrack-2-scripts.js", "f09ef1d27db619a79eb2e889221b58e56855c5f6ff8a27004d4b5d03e00ee354"),
]


def mixtrack2_references():
    return {name: {"url": UPSTREAM + MIXTRACK2_SOURCES[1][0], "sha256": MIXTRACK2_SOURCES[1][1],
                   "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in MIXTRACK2_SOURCES],
                   "review": "The pinned XML names MixTrack (Pro) II. Native actions replace the script. Audio hardware and routing remain model-specific."}
            for name in ["Numark Mixtrack Pro II", "Numark Mixtrack II"]}


def mixtrack2_profiles():
    results = []
    for name, source in mixtrack2_references().items():
        result = profile(name, source["url"])
        result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
        result["scope"] = "Automatic native core controls. Independent deck Shift on shared MIDI channel 1. Pad/delete modes, Scratch toggle, FX and audio routing remain open."
        result["startup"] = [[0x90, 72, 100], [0x90, 73, 100]]
        for index, deck in enumerate("ab"):
            start = len(result["inputs"])
            for action, numbers in {"play": [59, 66], "cuePreview": [51, 60], "sync": [64, 71],
                                    "load": [75, 52], "cue": [81, 82], "jogTouch": [77, 78],
                                    "loopIn": [83, 86], "loopOut": [84, 87], "reloop": [85, 88],
                                    "loopDown": [99, 100]}.items():
                add(result, action, 0, numbers[index], deck=deck, feedback=action in {"play", "sync", "cue"})
            for action, numbers in {"level": [22, 7], "high": [16, 17], "mid": [18, 19], "low": [20, 21], "tempo": [13, 14]}.items():
                add(result, action, 0, numbers[index], "control", deck=deck)
                if action == "tempo":
                    result["inputs"][-1]["inverted"] = True
            add(result, "jog", 0, 25 - index, "control", "twosComplement", deck)
            for binding in result["inputs"][start:]:
                binding.update(shifted=False, shiftChannel=index + 1)
            for action, number in [("loopUp", 99 + index), ("keylock", 67 + index * 2)]:
                add(result, action, 0, number, deck=deck)
                result["inputs"][-1].update(shifted=True, shiftChannel=index + 1)
            add(result, "shift", 0, 97 + index)
            result["inputs"][-1]["shiftChannel"] = index + 1
            result["outputs"].append({"action": "loop" + deck.upper(), "kind": "note", "channel": 0,
                                      "number": 85 + 3 * index, "targetDeck": deck,
                                      "onValue": 100, "offValue": 0, "offUsesNoteOn": True})
        for action, number in [("crossfader", 10), ("master", 23), ("monitor", 11), ("cueMix", 12)]:
            add(result, action, 0, number, "control")
        add(result, "browse", 0, 26, "control", "twosComplement")
        for number in [118, 119]:
            add(result, "openGroup", 0, number)
        for output in result["outputs"]:
            output["onValue"] = 100
        result["shutdown"] = [[0x90, 72, 0], [0x90, 73, 0]] + [[0x90, item["number"], 0] for item in result["outputs"]]
        result["gaps"] = ["Pad/delete modes, Scratch toggle, pitch-bend buttons, additional shifted functions, FX and full audio routing remain unimplemented. Platter touch uses native Scratch mode and the source jog indicators. Calibration and source reuse/distribution review remain open."]
        results.append(result)
    return results
