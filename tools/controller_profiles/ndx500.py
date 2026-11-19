"""NDX500 player input facts from PCDJ's public supported mapping."""
from curated import add, profile

NDX500_SOURCE = "https://pcdj.com/downloads/djcontrollers/Numark__NDX500.zip"
NDX500_DISCUSSION = "https://pcdj.com/dj-controllers-numark-ndx500-now-dex-3-and-dex-3-re-dj-software-supported/"
NDX500_SOURCES = [
    ("Numark-NDX500.zip", "adff75f290d0db8a18f022f0d4baadd619eec2744f94fca8e5698af9934c72d8"),
    ("Numark__NDX500.js", "c7d36ce862abc263dfe5e8473fc43042dba805f4dc4f5fc5cc23d569fa1d4173"),
]
NDX500_REFERENCES = {"Numark NDX500": {
    "url": NDX500_SOURCE, "sha256": NDX500_SOURCES[0][1],
    "relatedSources": [{"url": NDX500_DISCUSSION}, {"url": "https://www.numark.com/product/ndx500"}],
    "review": "PCDJ's supported source identifies USB15E4:0034 andMIDI transport. Independent native player assignment replaces its hard-coded software channel/deck association. Explicit source channels0..3 each supply Play6, held Cue5, direct Load3, Keylock21, held bends23/24, contact25, three cues11..13, loop In7/Out8/Reloop9 and folder2. The normal physical In/Out actions use native boundaries; source combined-loop/edit variations remain open. PlatterCC34 follows literal source63-minus-raw, not a guessed inverted centre64 encoder. BrowserCC33 follows literal source value1 forward, all other seven-bit values backward. Typed NDX500 decoders retain both rules and reject foreign/high-resolution packets. Standard pitch-bend input uses native linear14-bit normalization and source inversion; the source itself reads its MSB, so finer hardware resolution is not claimed. Native fixed touch scratch replaces software-only Scratch toggle16. Source scratch/bend denominators600/300 are app-specific, not a measured revolution resolution; default native calibration remains open. Source startup configures lamps/LCD without input negotiation. No feedback or lifecycle packet is emitted until active wire-channel ownership is qualified. Full LCD/text, light modes, record/brake/reverse, pitch ranges, full lifecycle/audio routing and physical acceptance remain open. NDX900 and Radius are not aliases. No downloaded code runs in the app.",
}}


def ndx500_profiles():
    result = profile("Numark NDX500", NDX500_SOURCE)
    result["role"] = "player"
    result["excludedAliases"] = ["Numark NDX900", "NDX900", "Numark NDX400", "NDX400"]
    result["hardwareMode"] = "USB-MIDI. Native fixed touch scratch on source channels1..4. Scratch toggle, displays and hardware output remain inactive."
    result["scope"] = "Automatic player input core with separate native deck assignment, held Cue/bend, fixed touch scratch, source pitch, three cues, loops, Load and browsing. Output, full modes/lifecycle, calibration and audio routing remain open."
    result["gaps"] = ["Output channel ownership, full LCD/text, lights, source software Scratch toggle, combined loop/edit variations, reverse/brake/record, pitch ranges, full lifecycle, audio routing and physical acceptance remain open. No Sync button is invented. Native default jog calibration is unverified. Pitch uses standard MIDI normalization; source MSB handling does not prove finer hardware resolution."]
    for channel in range(4):
        for action, number in [("play", 6), ("cuePreview", 5), ("keylock", 21), ("load", 3),
                               ("jogTouch", 25), ("pitchBendDown", 23), ("pitchBendUp", 24),
                               ("loopIn", 7), ("loopOut", 8), ("reloop", 9)]:
            add(result, action, channel, number, deck="a")
        for slot in range(3):
            add(result, f"hotcue{slot + 1}", channel, 11 + slot, deck="a")
        add(result, "jog", channel, 34, "control", "ndx500Jog", "a")
        add(result, "tempo", channel, 0, "pitch", deck="a")
        result["inputs"][-1]["inverted"] = True
        add(result, "browse", channel, 33, "control", "ndx500Browse")
        add(result, "openGroup", channel, 2)
    return [result]
