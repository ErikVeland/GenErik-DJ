"""Original Mixtrack generation facts from separate pinned mappings."""
from curated import add, profile
from numark import UPSTREAM

ORIGINAL_MIXTRACK_SOURCES = {
    "Numark MIXTRACK": [
        ("Numark MIXTRACK.midi.xml", "027be45a6c6f33dc9169ea963ca8f50b552bd1091ec76cdb3af7b08795a4f88d"),
        ("Numark-MixTrack-scripts.js", "a8c5ad998b4cc87674bc939173183b603b0dc036663796dbf7526adebe3d24c8"),
    ],
    "Numark Mixtrack Pro": [
        ("Numark Mixtrack Pro.midi.xml", "bd1947f6dc97ce042250d044f3009ca6435d5124aba6c522d64656c9a7c4e879"),
        ("Numark-Mixtrack-Pro-scripts.js", "80e19306ce9bc88f369bca5424ac56288119044504723baab2a04b73d57d24cc"),
    ],
}


def original_mixtrack_references():
    return {name: {"url": UPSTREAM + sources[1][0], "sha256": sources[1][1],
                   "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in sources],
                   "review": "Separate pinned mappings retain original-generation levels and touch notes. Native core transport and fixed manual loops replace script modes. Original XML rate inversion and Pro centred script rate have distinct polarities; neither borrows Mixtrack II tempo behaviour. Physical direction and calibration remain open."}
            for name, sources in ORIGINAL_MIXTRACK_SOURCES.items()}


def original_mixtrack_profiles():
    results = []
    for name, source in original_mixtrack_references().items():
        pro = name.endswith(" Pro")
        result = profile(name, source["url"])
        if not pro:
            result["aliases"] = [name]
        result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
        result["scope"] = "Automatic native core controls and fixed manual loops. Mode toggles, advanced functions and audio routing remain open."
        result["startup"] = [[0x90, 114, 100], [0x90, 72, 100], [0x90, 80, 100], [0x90, 97, 0], [0x90, 98, 0]]
        result["shutdown"] = [[0x90, number, 0] for number in [114, 72, 80]]
        for index, deck in enumerate("ab"):
            for action, numbers in {"play": [59, 66], "cuePreview": [51, 60], "sync": [64, 71], "keylock": [81, 82],
                                    "cue": [101, 102], "load": [75, 52], "jogTouch": [78, 77],
                                    "loopIn": [83, 86], "loopOut": [84, 87], "reloop": [85, 88]}.items():
                add(result, action, 0, numbers[index], deck=deck, feedback=action in {"play", "sync", "keylock", "cue"})
            for action, numbers in {"level": [8, 9], "high": [16, 17], "mid": [18, 19], "low": [20, 21]}.items():
                add(result, action, 0, numbers[index], "control", deck=deck)
            add(result, "tempo", 0, 13 + index, "control", "cdjTempo" if pro else "absolute", deck)
            result["inputs"][-1]["inverted"] = pro
            add(result, "jog", 0, 25 - index, "control", "twosComplement", deck)
        for action, number in [("crossfader", 10), ("master", 23), ("monitor", 11), ("cueMix", 12)]:
            add(result, action, 0, number, "control")
        next(binding for binding in result["inputs"] if binding["action"] == "crossfader")["inverted"] = True
        add(result, "browse", 0, 26, "control", "twosComplement")
        add(result, "openGroup", 0, 105)
        for output in result["outputs"]:
            output["onValue"] = 100
        result["gaps"] = ["Native core transport and fixed manual loops replace source script modes. Manual/auto loop toggles, directory latch, Delete/Hot Cue or EQ-kill modes, Scratch toggle, pitch-bend buttons, FX and full audio routing remain unimplemented. Native Scratch lights use the published LED addresses. Source-specific tempo direction, jog calibration, complete shutdown feedback and source reuse/distribution review remain open."]
        results.append(result)
    return results
