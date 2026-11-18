"""Original Mini page addresses and setup from its independent pinned source."""
from curated import add, profile
from numark import UPSTREAM

MINI_SOURCES = [
    ("Novation-Launchpad-Mini.midi.xml", "9d4b1b788392e7ba3851d5eba881b175d6c777befd8a9f4a658318bd4e7524f2"),
    ("Novation-Launchpad-Mini-scripts.js", "bef8dfd7ad45b3e71e2f256da7553c731e6f7cfb9a2d2595ccad71a4958800eb"),
]
MINI_REFERENCES = {"Novation Launchpad Mini": {
    "url": UPSTREAM + MINI_SOURCES[1][0], "sha256": MINI_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + MINI_SOURCES[0][0], "sha256": MINI_SOURCES[0][1]},
                       {"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/novation_launchpad_mini"}],
    "review": "Original Mini uses channel0 Note x+16*y for grid/right buttons and CC104..111 for top buttons. Init resets with B0/0/0 and selects buffer0 with B0/104/3. Page0 Play notes are0/32/64/96; cues16..23/48..55/80..87/112..119, fixed A/B/C/D. CC111 Shift changes cue activation to deletion, so native normal cues are guarded. Right-column Note8/24/40/56/72/88/104/120 selects all eight pages. Page7 individual track/group/open and target Load controls retain source addresses. Fast scroll and first-stopped Load remain inactive. Source loop pads toggle on press and conditionally on release; simple native toggle buttons would change that contract and remain inactive. No Mini MK3, MK2 or full-size Launchpad facts are inherited. Complete pages, lamps, lifecycle, calibration and physical/A10X acceptance remain open. No downloaded script executes in the app.",
}}


def mini_profiles():
    result = profile("Novation Launchpad Mini", MINI_REFERENCES["Novation Launchpad Mini"]["url"])
    result.update(definition="reviewed:launchpad-mini", role="accessory",
                  excludedAliases=["Launchpad", "Launchpad MK2", "Launchpad Mini MK3", "Launchpad X", "Launchpad Pro"],
                  hardwareMode="Original Launchpad Mini USB-MIDI channel1. Native setup resets the hardware and selects buffer0. Software page A starts active.",
                  scope="Automatic original Mini page-aware Play/cue and individual library/load core. All eight page selectors block foreign page actions. Other pages, loops, Shift-delete, complete lights and physical acceptance remain open.")
    result["startup"] = [[0xB0, 0, 0], [0xB0, 104, 3]]
    result["inputModes"] = [{"channel": 0, "initial": 8, "numbers": [8, 24, 40, 56, 72, 88, 104, 120]}]
    add(result, "shift", 0, 111, "control")
    for row, deck in enumerate("abcd"):
        add(result, "play", 0, row * 32, deck=deck)
        result["inputs"][-1]["requiredMode"] = 8
        for slot in range(8):
            add(result, f"hotcue{slot+1}", 0, row * 32 + 16 + slot, deck=deck)
            result["inputs"][-1].update(requiredMode=8, shifted=False)
    for deck, number in zip("abcd", [37, 39, 69, 71]):
        add(result, "load", 0, number, deck=deck)
        result["inputs"][-1]["requiredMode"] = 120
    for action, number in [("browsePrevious", 38), ("browseNext", 70), ("browsePreviousGroup", 33),
                           ("browseNextGroup", 65), ("openGroup", 49)]:
        add(result, action, 0, number)
        result["inputs"][-1]["requiredMode"] = 120
    result["gaps"] = ["Original Mini only. Source momentary toggle/roll loop pads, seek/sampler pages, fast scroll, first-stopped Load, zoom and Shift cue deletion remain inactive. Complete lights/page display/lifecycle, port-name variations and physical/A10X acceptance remain open. This accessory has no inferred audio route."]
    return [result]
