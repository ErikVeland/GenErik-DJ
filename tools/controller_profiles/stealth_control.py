"""Stealth Control facts from Numark's map and independent MADRIX wire definitions."""
from curated import add, profile

STEALTH_SOURCE = "https://www.numark.com/images/product_downloads/numark_stealth_control_xml_file_for_cue_5_and_virtual_vinyl_5.zip"
STEALTH_MADRIX = "https://www.madrix.com/download/m5/LegacyMADRIX5MIDIMaps.zip"
STEALTH_SOURCES = [
    ("stealth-control.zip", "5429b3d5a0d3340664f7982a74bd78f261ac2ca1461a1949d7c59dada34c7b17"),
    ("stealth_control_cue.xml", "fb961915199268c46c201ae84c1e2e595a40ff72b922c462d43cb69da8258dc1"),
    ("LegacyMADRIX5MIDIMaps.zip", "51d319a701242cf53b5f077bb1f91b3ac1b62beb3cbe29ba35656b2882de7fee"),
    ("Numark StealthControl.mmrx", "e0a5d5df6baa350aa44862d2f58cb65e81c363542ab9f65581aa51085af1e2a6"),
]
STEALTH_REFERENCES = {"Numark Stealth Control": {
    "url": STEALTH_SOURCE, "sha256": STEALTH_SOURCES[0][1],
    "archiveMember": "Numark Stealth Control/stealth_control_cue.xml", "memberSha256": STEALTH_SOURCES[1][1],
    "relatedSources": [{"url": STEALTH_MADRIX, "sha256": STEALTH_SOURCES[2][1],
                        "archiveMember": "LegacyMADRIX5MIDIMaps/Numark-StealthControl/Numark StealthControl.mmrx", "memberSha256": STEALTH_SOURCES[3][1]},
                       {"url": "https://www.numark.com/product/stealthcontrol"}],
    "review": "Numark's model-specific Cue5 factory XML governs input addresses and absolute slider direction. Its chan fields choose software decks, not wire channels. MADRIX5.4a's52-entry Stealth XML independently confirms wire channel0 and two's-complement browser/jog encoders. MADRIX's Total-style opposite jog addresses do not override Numark's Stealth-specific A24/B25. Source Play67/76, held Cue51/68, Sync64/71, Keylock56/63, PFL48/55, Load75/52, bends65/66 and69/70, manual loop In73/77 and Out74/78 remain distinct. The factory map assigns B60 to Pause and B68 to Cue Stop; native Cue follows that explicit source choice, with physical label acceptance open. Smart Cue59 and source Pause60 stay inactive. Native manual In clears an old loop before recording the boundary; Out sets the boundary or exits. Source pitchCC11/12 and crossfaderCC10 are inverted. GainCC13/14, level8/9, high16/17, mid18/19, low20/21, master23, monitor15 and cue-mix22 remain seven-bit. Source browser press79 enters native Open Group. Wheels remain sensorless native nudge/paused seek; source software Vinyl72 is not converted to a synthetic contact. No Total/Omni fine-tempo assignments, LED addresses/values, setup or audio route is inherited. Native calibration, full browser/loop semantics, scratch, EQ kills, samples/FX, lights and physical acceptance remain open. No downloaded controller code runs in the app.",
}}


def stealth_profiles():
    result = profile("Numark Stealth Control", STEALTH_SOURCE)
    result["definition"] = "reviewed:numark-stealth-control"
    result["excludedAliases"] = ["Numark Total Control", "Total Control", "Numark Omni Control", "Omni Control"]
    result["scope"] = "Automatic independent input core with source transport, held Cue/bend, sensorless wheel nudge/seek, mixer/pitch and browsing. Scratch, full modes/lights, calibration and physical acceptance remain open."
    for side, deck in enumerate("ab"):
        notes = [("play", [67,76]), ("cuePreview", [51,68]), ("sync", [64,71]), ("keylock", [56,63]),
                 ("cue", [48,55]), ("load", [75,52]), ("pitchBendDown", [65,69]), ("pitchBendUp", [66,70])]
        for action, numbers in notes:
            add(result, action, 0, numbers[side], deck=deck)
        add(result, "loopDisable", 0, 73 + side * 4, deck=deck)
        add(result, "loopIn", 0, 73 + side * 4, deck=deck)
        add(result, "loopOutOrExit", 0, 74 + side * 4, deck=deck)
        for action, number in [("level",8),("gain",13),("tempo",11),("high",16),("mid",18),("low",20)]:
            add(result, action, 0, number + side, "control", deck=deck)
            if action == "tempo":
                result["inputs"][-1]["inverted"] = True
        add(result, "wheelJog", 0, 24 + side, "control", "twosComplement", deck)
    for action, number in [("crossfader",10),("master",23),("monitor",15),("cueMix",22)]:
        add(result, action, 0, number, "control")
        if action == "crossfader":
            result["inputs"][-1]["inverted"] = True
    add(result, "browse", 0, 26, "control", "twosComplement")
    add(result, "openGroup", 0, 79)
    result["gaps"] = ["Numark's factory Cue B68 choice differs from source Pause60; physical labels and response require acceptance. Native jog calibration, source stutter/Smart Cue, full manual-loop/browser semantics, sensorless Scratch/Vinyl toggle, EQ kills, samples/FX and all light/lifecycle values remain open. Separate audio hardware is required; no audio route or Total/Omni lamp assignment is inferred."]
    return [result]
