"""Original ION Discover native core, separate from Discover Pro."""
from curated import add, profile
from numark import UPSTREAM

DISCOVER_SOURCES = [
    ("Ion Discover DJ.midi.xml", "84afadae9e064fce2e44b0cb7b597de0ce946620bb3a260e75dd6fced72d130d"),
    ("Ion-Discover-DJ-scripts.js", "474c10819937ff03eb2ff895ca49d66c6971bf6ba0a55f528863fd476ab62623"),
]
DISCOVER_GUIDE = "https://manual.mixxx.org/2.5/en/hardware/controllers/ion_discover_dj"
DISCOVER_REFERENCES = {"Ion Discover DJ": {
    "url": UPSTREAM + DISCOVER_SOURCES[0][0].replace(" ", "%20"), "sha256": DISCOVER_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in DISCOVER_SOURCES]
        + [{"url": DISCOVER_GUIDE}],
    "review": "Pinned XML and script give original transport, touch, signed jogs, direct Load, permanent tempo buttons and LED addresses. The mapping author identifies physical Volume reassigned as Low and Bass reassigned as Mid. Native controls restore labelled Volume and two-band Bass/Treble, without an invented Mid control. Permanent tempo buttons use the existing native UI step of 0.1 percentage points per fresh press, not temporary bend or the source application's configurable coarse step. Native fixed touch scratch preserves the source's 128-count, 45RPM, tick-divided-by-three response through effective native resolution 518.4 (native 1.8 seconds per turn). This is a source response conversion, not a factory physical-count claim. The source LED show and unowned Load light mutation are omitted. Fixed Scratch indication stays on; mode switching, reverse, library expansion and beat flashes remain open. The original has no audio interface or PFL buttons. Pro remains a distinct protocol. Full controls/feedback, calibration and physical acceptance remain open.",
}}


def discover_profiles():
    result = profile("Ion Discover DJ", DISCOVER_REFERENCES["Ion Discover DJ"]["url"])
    result["excludedAliases"] = ["Discover DJ Pro", "Ion Discover DJ Pro"]
    result["scope"] = "Automatic original Discover core with physical volume/two-band EQ, permanent native tempo steps, held Cue, fixed source-scaled touch scratch, direct Load and browsing. Scratch mode switching, reverse, full lights, calibration and physical acceptance remain open."
    for side, deck in enumerate("ab"):
        for action, numbers in [("play", [0x4A, 0x4C]), ("cuePreview", [0x3B, 0x42]),
                                ("sync", [0x40, 0x47]), ("load", [0x4B, 0x34]),
                                ("tempoDown", [0x43, 0x45]), ("tempoUp", [0x44, 0x46])]:
            add(result, action, 0, numbers[side], deck=deck, feedback=action in {"play", "cuePreview", "sync"})
        add(result, "jogTouch", 0, 0x4D + side, deck=deck)
        add(result, "jog", 0, 0x19 - side, "control", "twosComplement", deck)
        result["inputs"][-1]["argument"] = 518.4
        for action, number in [("level", 0x08), ("low", 0x14), ("high", 0x10)]:
            add(result, action, 0, number + side, "control", deck=deck)
    add(result, "master", 0, 0x17, "control")
    add(result, "crossfader", 0, 0x0A, "control")
    result["inputs"][-1]["inverted"] = True
    add(result, "browse", 0, 0x1A, "control", "twosComplement")
    clear = [[0x90, output["number"], 0] for output in result["outputs"]]
    clear.extend([[0x90, number, 0] for number in [0x33, 0x3C, 0x48]])
    result["startup"] = clear[:-1] + [[0x90, 0x48, 127]]
    result["shutdown"] = clear
    return [result]
