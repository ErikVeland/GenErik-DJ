"""Compact factory layout with native wheel control and source tempo response."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

COMPACT_GUIDE = "https://ts.hercules.com/download/sound/manuals/DJC_Compact/DJC_Compact_MIDI_Mapping.pdf"
HERCULES_COMPACT_SOURCES = [
    ("Hercules DJControl Compact.midi.xml", "a598e43feda6b1d48efda26e33a41fa258e88bc15b4100ec6fae399dac1374dd"),
    ("Hercules-DJControl-Compact-scripts.js", "17ba587adeccad7d91f13bede5c97a50dde8514ed45156277319d0407efe9bd0"),
]
HERCULES_COMPACT_REFERENCES = {"Hercules DJControl Compact": {
    "url": COMPACT_GUIDE, "sha256": "3c42f8172aac1568a95df90cfba998180131dd0e888113a2592ad28ce1c887c2", "pages": [1, 2, 3, 4, 5],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in HERCULES_COMPACT_SOURCES],
    "review": "Factory channel-zero layout uses distinct hardware pad/mode and Shift addresses. Factory VOL controls deck level, correcting the community pregain assignment. Two-band Mid/Low remains physical, without an invented High control. Normal jogs use native wheel nudge/paused seek, without a fabricated touch sensor or source scratch timers. Shift jog preserves source signed-square tempo increments and inverse Mixxx rate polarity through a factory-only codec. The source state query explicitly corrupts tempo and resets both decks, so native startup omits it and keeps pickup. Cue and shifted cue releases share momentary ownership. Cue pads, eight-beat loop, reloop/half/double follow the pinned source. Play/Sync feedback has distinct normal/shift LED addresses. Native startup/shutdown clears only reviewed feedback plus unsupported Auto/Record indicators. Source synthetic scratch, shifted start/stop, recording, AutoDJ, rolls, FX/samples, full feedback/cleanup, EQ direction calibration and physical acceptance remain open. No Load/browser/PFL or audio interface is invented.",
}}


def hercules_compact_profiles():
    result = profile("Hercules DJControl Compact", COMPACT_GUIDE)
    result["scope"] = "Automatic Compact core with native wheel jogs, source accelerated Shift tempo, four cue pads, fixed/manual loop controls and factory two-band mixer. No synthetic touch. Source scratch, remaining modes/feedback, calibration and physical acceptance stay open."
    for side, deck in enumerate("ab"):
        base = side * 0x30
        for action, number in [("play", 0x21), ("cuePreview", 0x22), ("sync", 0x23)]:
            add(result, action, 0, base + number, deck=deck, feedback=action != "cuePreview")
            release = deepcopy(result["inputs"][-1])
            release.update(number=base + number + 3, releaseOnly=True)
            result["inputs"].append(release)
            if action != "cuePreview":
                alternate = deepcopy(result["outputs"][-1])
                alternate["number"] += 3
                result["outputs"].append(alternate)
        add(result, "wheelJog", 0, 0x30 + side, "control", "twosComplement", deck)
        result["inputs"][-1]["argument"] = 256
        add(result, "tempo", 0, 0x37 + side, "control", "compactTempo", deck)
        result["inputs"][-1]["inverted"] = True
        for action, number in [("level", 0x39), ("mid", 0x3B), ("low", 0x3C)]:
            add(result, action, 0, number + side * 4, "control", deck=deck)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", 0, base + 1 + slot, deck=deck)
            release = deepcopy(result["inputs"][-1])
            release.update(number=base + 5 + slot, releaseOnly=True)
            result["inputs"].append(release)
        for action, number in [("reloop", 0x19), ("toggleFixedLoop", 0x1A), ("loopDown", 0x1B), ("loopUp", 0x1C)]:
            add(result, action, 0, base + number, deck=deck)
            if action == "toggleFixedLoop":
                result["inputs"][-1]["argument"] = 8
            release = deepcopy(result["inputs"][-1])
            release.update(number=base + number + 4, releaseOnly=True)
            result["inputs"].append(release)
    add(result, "crossfader", 0, 0x36, "control")
    notes = sorted({r["number"] for r in result["outputs"]} | {0x2B, 0x2C, 0x2D, 0x2E})
    result["startup"] = [[0x90, number, 0] for number in notes]
    result["shutdown"] = list(result["startup"])
    return [result]
