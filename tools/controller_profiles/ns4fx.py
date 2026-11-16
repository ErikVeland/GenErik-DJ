"""NS4FX core MIDI facts from the pinned four-deck mapping."""
from curated import add, profile
from numark import UPSTREAM

NS4FX_SOURCES = [
    ("Numark NS4FX.midi.xml", "abdfd3f892fef1ddf682582160bd63c72a61af6a8c1b2f70e5ab871a74ebd543"),
    ("Numark-NS4FX-scripts.js", "6f4e07324eb6116d10e2d1196cc4258abb1f0738c1e48c1402d2c2cb94e44a5e"),
    ("midi-components-0.0.js", "f15845d0b3fa10609aedc2fb74a9067d0f1d89387f011de72c3301799003f026"),
]
NS4FX_REFERENCES = {"Numark NS4FX": {
    "url": UPSTREAM + NS4FX_SOURCES[1][0], "sha256": NS4FX_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in NS4FX_SOURCES],
    "review": "Four deck channels 0–3 select A/B/C/D without enabling the native trial. Jog wrap logic matches the existing Platinum decoder and uses 1240 counts. Tempo is paired CC 9/41 with source inversion and rate_dir -1. The script routes mixer controls by deck component despite XML gain group typos. The native receiver combines the labelled 9/41 pitch pair instead of copying the script's high-byte input/inputMSB routing error. Shift suppresses unsupported Load, rate-range, scratch-search and head-gain alternatives, and rearms pickup when the layer changes. Active bank reports reset pickup and held contacts on that side. Demo exit and Vinyl messages are reused; screens, pads, full cleanup, FX and audio routing remain open.",
}}


def ns4fx_profiles():
    result = profile("Numark NS4FX", NS4FX_REFERENCES["Numark NS4FX"]["url"])
    result["definition"] = "reviewed:numark-ns4fx"
    result["scope"] = "Automatic four-deck core controls with bank pickup reset, conventional Cue and published jog resolution. The native four-deck opt-in remains required. Pads, pitch/key buttons, Vinyl toggle, shifted alternatives, full feedback, screens, FX and audio routing remain open."
    result["startup"] = [[0xF0, 0, 1, 0x3F, 0x7F, 0x3A, 0x60, 0, 4, 4, 1, 0, 0, 0xF7]]
    result["bankChanges"] = []
    for channel, deck in enumerate("abcd"):
        for action, number in [("play", 0), ("cuePreview", 1), ("sync", 2), ("cue", 27), ("jogTouch", 6)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue"})
            if action != "cue":
                result["inputs"][-1]["shifted"] = False
        add(result, "jog", channel, 6, "control", "numarkPlatinumJog", deck)
        result["inputs"][-1].update(argument=1240, shifted=False)
        add(result, "tempo", channel, 9, "control", "paired14Bit", deck)
        result["inputs"][-1]["shifted"] = False
        for action, number in [("gain", 22), ("high", 23), ("mid", 24), ("low", 25), ("filterKnob", 26), ("level", 28)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "load", 15, 2 + channel, deck=deck)
        result["inputs"][-1]["shifted"] = False
        result["bankChanges"].append({"channel": channel, "number": 8, "onValue": 127,
                                      "decks": ["a", "c"] if channel % 2 == 0 else ["b", "d"]})
        result["startup"].append([0x90 + channel, 7, 127])
        result["shutdown"].append([0x90 + channel, 7, 1])
    for channel in [0, 1]:
        add(result, "shift", channel, 32)
    for action, number in [("crossfader", 8), ("master", 10), ("monitor", 12), ("cueMix", 13)]:
        add(result, action, 15, number, "control")
        if action == "monitor":
            result["inputs"][-1]["shifted"] = False
    add(result, "browse", 15, 0, "control", "signedStep")
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 15, 6)
    result["inputs"][-1]["shifted"] = False
    for output in result["outputs"]:
        output["offValue"] = 1
    return [result]
