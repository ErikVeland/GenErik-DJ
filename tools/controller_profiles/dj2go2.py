"""DJ2GO2 Touch core facts from pinned MIDI sources and factory control labels."""
from curated import add, profile
from numark import UPSTREAM

DJ2GO2_SOURCES = [
    ("Numark_DJ2GO2_Touch.midi.xml", "30807f8e574e857149c4e5b3f79e2d07ab8a841e159c040852a8c5d7b1641990"),
    ("Numark_DJ2GO2_Touch_scripts.js", "8c39e503fcd2c1c6be23c997d7c092b58ee91aec22d32fa1fa7392e1f1fd900f"),
    ("midi-components-0.0.js", "f15845d0b3fa10609aedc2fb74a9067d0f1d89387f011de72c3301799003f026"),
]
GUIDE = "https://www.numark.com/images/product_downloads/DJ2GO2Touch-UserGuide-v1.0.pdf"
DJ2GO2_REFERENCES = {"Numark DJ2GO2 Touch": {
    "url": UPSTREAM + DJ2GO2_SOURCES[1][0], "sha256": DJ2GO2_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + path, "sha256": digest} for path, digest in DJ2GO2_SOURCES] +
        [{"url": GUIDE, "sha256": None, "evidence": "Official indexed Features text reviewed 16 November 2026. Gain controls channel audio, and Browse press enters folders. Direct original and newer CDN guide downloads returned 404; no PDF content hash is available."}],
    "review": "Native controls reuse exact MIDI addresses, 236 jog counts, raw-64-positive jog decoding, 1/127-only browser steps and status query. Factory labels replace the source's Gain-to-filter and Browse-to-preview choices. Pot invert and native tempo direction agree. Distinct pad note ranges separate cues, automatic loops and manual loops. Cue deletion, reloop-and-stop, samplers, preview mode, full feedback and audio routing remain open. The non-Touch DJ2GO2 does not inherit this recipe.",
}}


def dj2go2_profiles():
    result = profile("Numark DJ2GO2 Touch", DJ2GO2_REFERENCES["Numark DJ2GO2 Touch"]["url"])
    result["definition"] = "reviewed:numark-dj2go2-touch"
    result["aliases"].extend(["DJ2GO2 Touch MIDI", "Numark DJ2GO2 Touch MIDI"])
    result["scope"] = "Automatic native core controls, four Hot Cues, automatic loop pads and basic manual loops. Factory Gain and Browse meanings replace source customisations. Cue preview/deletion, reloop-and-stop, sampler, full feedback and audio routing remain open."
    result["startup"] = [[0xF0, 0, 1, 0x3F, 0x3C, 0x48, 0xF7]]
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 0), ("cueReturn", 1), ("sync", 2), ("cue", 27), ("jogTouch", 6)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue"})
        add(result, "jog", channel, 6, "control", "dj2go2Jog", deck)
        result["inputs"][-1]["argument"] = 236
        add(result, "tempo", channel, 9, "control", deck=deck)
        add(result, "gain", channel, 22, "control", deck=deck)
        add(result, "load", 15, 2 + channel, deck=deck)
        for slot in range(1, 5):
            add(result, f"hotcue{slot}", 4 + channel, slot, deck=deck, feedback=True)
            add(result, "toggleFixedLoop", 4 + channel, 16 + slot, deck=deck)
            result["inputs"][-1]["argument"] = 2 ** (slot - 1)
        for action, number in [("loopIn", 33), ("loopOut", 34), ("reloop", 35)]:
            add(result, action, 4 + channel, number, deck=deck)
    for action, number in [("crossfader", 8), ("master", 10), ("monitor", 12)]:
        add(result, action, 15, number, "control")
    add(result, "browse", 15, 0, "control", "signedStep")
    add(result, "openGroup", 15, 6)
    result["shutdown"] = [[0x90 + output["channel"], output["number"], 0] for output in result["outputs"]]
    return [result]
