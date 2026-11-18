"""Discover Pro normal-mode core from its pinned mapping and author guide."""
from curated import add, profile
from numark import UPSTREAM

DISCOVER_PRO_SOURCES = [
    ("Ion-Discover-DJ-Pro.midi.xml", "e85e5257bf44bd544b7ad7ab2090b24e9a62fd901109f0c2881a33b42feea7df"),
    ("Ion-Discover-DJ-Pro-scripts.js", "0854d2baef6fcb69369231c72ab6d08051854e7e9b98520aabcaa386b54b561a"),
]
DISCOVER_PRO_GUIDE = "https://manual.mixxx.org/2.5/en/hardware/controllers/ion_discover_dj_pro"
DISCOVER_PRO_REFERENCES = {"Ion Discover DJ Pro": {
    "url": UPSTREAM + DISCOVER_PRO_SOURCES[0][0], "sha256": DISCOVER_PRO_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name, "sha256": digest} for name, digest in DISCOVER_PRO_SOURCES]
        + [{"url": DISCOVER_PRO_GUIDE}],
    "review": "Pinned XML supplies separate Pro Play/Cue/Sync, direct Load, PFL, Key Lock, held pitch bend, pitch sliders and three-band mixer addresses. The source normal wheel mode is signed; native wheel nudge/paused seek retains the source's 128-count scale without synthetic scratch timers. The CC touch handler refers to uninitialised state, uses a conflicting 512-count scale and contains a misspelled engine setter; no reliable physical touch contract is inferred. The author guide lists AutoLoop, Stutter, All Mute and iPod as unfinished. Source three-button manual-loop remapping is not treated as a factory four-button AutoLoop table. These inputs remain inactive, with their reviewed light addresses cleared. Native pitch retains exact centre and inverse Mixxx rate polarity. The source zero-range LED conditions invert Play/Cue/Sync/PFL/Key Lock: native on100/off0. Browser press enters a native group as labelled; source latched directory selection remains open. A complete 68-address source shutdown exceeds the lifecycle bound; the native union of thirty reviewed light addresses fits sixty setup/shutdown messages. Split audio channel assignment, Scratch, other modes, full feedback, calibration and physical acceptance remain open. Original Discover remains separate.",
}}


def discover_pro_profiles():
    result = profile("Ion Discover DJ Pro", DISCOVER_PRO_REFERENCES["Ion Discover DJ Pro"]["url"])
    result["hardwareMode"] = "Native normal wheel mode. Scratch mode switching is not implemented."
    result["scope"] = "Automatic Pro normal-mode core with held Cue/bend, pitch sliders, three-band mixer, native wheel seek/nudge, direct Load and browsing. Scratch/contact, AutoLoop, Stutter, EQ kill, iPod, full feedback/audio routing and physical calibration remain open."
    for side, deck in enumerate("ab"):
        for action, numbers in [("play", [0x3B, 0x42]), ("cuePreview", [0x33, 0x3C]),
                                ("sync", [0x40, 0x47]), ("cue", [0x65, 0x66]),
                                ("keylock", [0x51, 0x52]), ("load", [0x4B, 0x34]),
                                ("pitchBendDown", [0x43, 0x45]), ("pitchBendUp", [0x44, 0x46])]:
            add(result, action, 0, numbers[side], deck=deck, feedback=action in {"play", "cuePreview", "sync", "cue", "keylock"})
            if action in {"play", "cuePreview", "sync", "cue", "keylock"}:
                result["outputs"][-1]["onValue"] = 100
        for action, number in [("level", 0x08), ("high", 0x10), ("mid", 0x12), ("low", 0x14), ("tempo", 0x0D)]:
            add(result, action, 0, number + side, "control", "centreDetent" if action == "tempo" else "absolute", deck)
            if action == "tempo":
                result["inputs"][-1]["inverted"] = True
        add(result, "wheelJog", 0, 0x19 - side, "control", "twosComplement", deck)
        result["inputs"][-1]["argument"] = 128
    for action, number in [("crossfader", 0x0A), ("cueMix", 0x0C), ("monitor", 0x0B), ("master", 0x17)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 0x1A, "control", "twosComplement")
    add(result, "openGroup", 0, 0x4F)
    unsupported = {0x5A, 0x5B, 0x5C, 0x5E, 0x5F, 0x60, 0x63, 0x64, 0x70, 0x71,
                   0x48, 0x50, 0x61, 0x62, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58}
    numbers = sorted({output["number"] for output in result["outputs"]} | unsupported)
    result["startup"] = [[0x90, number, 0] for number in numbers]
    result["shutdown"] = list(result["startup"])
    return [result]
