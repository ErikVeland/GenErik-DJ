"""Separate Total/Omni layouts from pinned sources and the fixed Total MIDI chart."""
from curated import add, profile
from numark import UPSTREAM

TOTAL_GUIDE = "https://www.numark.com/images/product_downloads/totalcontrol_midimap.pdf"
TOTAL_OMNI_SOURCES = {
    "Numark Total Control": [
        ("Numark Total Control.midi.xml", "be7294d8711be9f935ccbf61f06890cb18efbc3f6c0564850b72c3c97f1df173"),
        ("Numark-Total-Control-scripts.js", "1630779e5dfd5cc6f00233633987928f8f3929f761932aa70b97405618deca59"),
    ],
    "Numark Omni Control": [
        ("Numark Omni Control.midi.xml", "76213e3911df592e11c42dce1ea7f4f24803e0bd09d464eaa5f1edbf3a9c8e8e"),
        ("Numark-Omni-Control-scripts.js", "7665ba5762f35a31c0699bdd50cc279cf1405fca06a4295baba0123d3fc37035"),
    ],
}
TOTAL_OMNI_REFERENCES = {name: {
    "url": UPSTREAM + sources[0][0].replace(" ", "%20"), "sha256": sources[0][1],
    "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in sources[1:]] +
        ([{"url": TOTAL_GUIDE, "sha256": "8c10fd1a4fc10d3a22ef88e93c3d530316aef1d1f39734bd43d7e8c3b95db468", "pages": [1]}] if name == "Numark Total Control" else []),
    "review": "Model-specific XML separates opposite jog assignments: Total A25/B24, Omni A24/B25. Factory Total chart confirms fixed controls, including its jog order. Native wheel nudge/paused seek uses source128-count scale without synthetic scratch contacts/timers or gamma curve. Full signed fine-tempo steps preserve source rate increments1/512 through a factory-only relative codec and native inverse polarity. Cue Set stays separate from source-default held Cue preview. Manual In first disables an old loop, then records a new start; Out sets the end or exits an active loop through native contracts. Native held pitch bend replaces source extended-loop overloads. Browser uses native track movement and immediate Open Group; source directory toggle remains open. Source LED addresses differ from input addresses. Native steady Sync replaces beat pulses, PFL negative conditions resolve to on100/off0, and Play/Key Lock retain source100-on values. Startup clears source LED range48..86; shutdown clears eight native outputs. Simple Cue, scratch, extended loops, Tap, EQ kill, FX, source animations, full browser/loop semantics, audio routing, calibration and physical acceptance remain open. Stealth is not inferred as an alias.",
} for name, sources in TOTAL_OMNI_SOURCES.items()}


def total_omni_profiles():
    results = []
    for name in TOTAL_OMNI_SOURCES:
        result = profile(name, TOTAL_OMNI_REFERENCES[name]["url"])
        result["scope"] = "Automatic model-specific Total/Omni core with signed wheel jogs, source fine-tempo steps, held Cue/bend, separate Cue Set, manual loop workflow, mixer/pitch pickup and source-addressed transport feedback. Source advanced modes, full feedback/routing, calibration and physical acceptance remain open."
        for side, deck in enumerate("ab"):
            buttons = [[("play", 67), ("cuePreview", 51), ("sync", 64), ("cueSet", 59), ("cue", 48), ("keylock", 56), ("load", 75), ("pitchBendDown", 65), ("pitchBendUp", 66)],
                       [("play", 76), ("cuePreview", 60), ("sync", 71), ("cueSet", 68), ("cue", 55), ("keylock", 63), ("load", 52), ("pitchBendDown", 69), ("pitchBendUp", 70)]]
            for action, number in buttons[side]:
                add(result, action, 0, number, deck=deck)
            add(result, "loopDisable", 0, 73 + side * 4, deck=deck)
            add(result, "loopIn", 0, 73 + side * 4, deck=deck)
            add(result, "loopOutOrExit", 0, 74 + side * 4, deck=deck)
            for action, number in [("level", 8), ("gain", 13), ("tempo", 11)]:
                add(result, action, 0, number + side, "control", "centreDetent" if action == "tempo" else "absolute", deck)
                if action == "tempo":
                    result["inputs"][-1]["inverted"] = True
            for action, number in [("high", 16), ("mid", 18), ("low", 20)]:
                add(result, action, 0, number + side, "control", deck=deck)
            jog = 25 - side if name == "Numark Total Control" else 24 + side
            add(result, "wheelJog", 0, jog, "control", "twosComplement", deck)
            result["inputs"][-1]["argument"] = 128
            add(result, "tempo", 0, 3 + side * 4, "control", "fineTempo512", deck)
            result["inputs"][-1]["inverted"] = True
            for action, number in [("play", 62 + side * 16), ("cue", 53 + side * 11), ("keylock", 54 + side * 11), ("sync", 55 + side * 11)]:
                result["outputs"].append({"action": action + deck.upper(), "targetDeck": deck, "kind": "note", "channel": 0,
                                          "number": number, "onValue": 100, "offValue": 0, "offUsesNoteOn": True})
        for action, number in [("crossfader", 10), ("master", 23), ("monitor", 15), ("cueMix", 22)]:
            add(result, action, 0, number, "control")
            if action == "crossfader":
                result["inputs"][-1]["inverted"] = True
        add(result, "browse", 0, 26, "control", "twosComplement")
        add(result, "openGroup", 0, 72)
        result["startup"] = [[0x90, number, 0] for number in range(48, 87)]
        result["shutdown"] = [[0x90, r["number"], 0] for r in result["outputs"]]
        results.append(result)
    return results
