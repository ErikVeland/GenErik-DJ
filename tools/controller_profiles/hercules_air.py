"""Original AIR factory core and eight-bit pitch, with fixed pressure scratching."""
from curated import add, profile
from numark import UPSTREAM

AIR_GUIDE = "https://ts.hercules.com/download/sound/manuals/DJ_AIR/DJUCED/DJUCED_Manual_v1_ENG.pdf"
AIR_SOURCES = [
    ("Hercules DJ Control AIR.midi.xml", "a9f2441243b8645751b5c2a56e64adc0f0ba8cf10078a34829d0851beb5a1125"),
    ("Hercules-DJ-Control-AIR-scripts.js", "6cd67a03b59b1d17967e51585890cb06ccb62ca4ecf6d72df5e3ef67414ea8a2"),
]
AIR_REFERENCES = {"Hercules DJ Control AIR": {
    "url": AIR_GUIDE, "sha256": "d3365da72de3b8c4b349a6f2a6e855cbc93b85935e8275787353bbd02823bf40", "pages": [28, 30, 49, 50, 51, 52, 53],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in AIR_SOURCES],
    "review": "Factory tables replace source direction-only jogs, seven-bit pitch and permanent tempo-button changes with full signed normal/pressure movement, explicit eight-bit CC52/88 and53/89 pairs and native owned held bends. The low report is a Boolean bit: zero0/nonzero1, not a seven-bit fraction. Fresh pitch pairs retain source inverse rate and pickup. Native fixed pressure scratch uses128counts, full-value contact notes22/44 and separate gated pressure CC50/51. Loop-page velocity reports trigger on first positive press only; native In/Out/Double/Reloop follows pinned source addresses. FX/sample pages stay separate and inactive. Factory all-LED clearCC127/0 replaces the script's empty startup loop and undefined resetLEDs shutdown. Source beat animation, Magic/FX/sample mappings, Scratch toggle and mode-aware pad lights stay open. Physical HP volume buttons change hardware preamp gain and receive no duplicate software change. Factory master1/2/headphones3/4 uses native route; HP Cue/Mix selection remains open. EQ polarity retains source convention pending calibration. AIR Plus, firmware/device checks and full physical qualification remain separate/open.",
}}


def air_profiles():
    result = profile("Hercules DJ Control AIR", AIR_GUIDE)
    result["aliases"] += ["Hercules DJControl AIR", "DJControl AIR"]
    result["excludedAliases"] = ["DJControl AIR Plus", "Hercules DJControl AIR Plus", "DJControl AIR+", "Hercules DJControl AIR+"]
    result.update(audioOutput="masterAndHeadphones", scope="Automatic original AIR core with factory eight-bit pitch, full signed normal/pressure jogs, native fixed128-count pressure scratch, held bends, manual loop page, transport feedback and documented split audio. Other modes, Cue/Mix selection, full lights, calibration and physical acceptance remain open.")
    for side, deck in enumerate("ab"):
        base = side * 22
        for action, number in [("play", 18), ("cuePreview", 17), ("sync", 19), ("cue", 20), ("load", 21),
                               ("pitchBendDown", 13), ("pitchBendUp", 14)]:
            add(result, action, 0, base + number, deck=deck, feedback=action in {"play", "cuePreview", "sync", "cue"})
        add(result, "jogTouch", 0, base + 22, encoding="fullVelocityGate", deck=deck)
        add(result, "jog", 0, 50 + side, "control", "twosComplement", deck)
        result["inputs"][-1].update(argument=128, requiresTouch=True)
        add(result, "wheelJog", 0, 48 + side, "control", "twosComplement", deck)
        result["inputs"][-1]["argument"] = 128
        add(result, "tempo", 0, 52 + side, "control", "airTempo", deck)
        result["inputs"][-1].update(lowNumber=88 + side, inverted=True)
        for action, number in [("level", 54), ("high", 55), ("mid", 56), ("low", 57)]:
            add(result, action, 0, number + side * 5, "control", deck=deck)
        for action, number in [("loopIn", 9), ("loopOut", 10), ("loopUp", 11), ("reloop", 12)]:
            add(result, action, 0, base + number, deck=deck)
    add(result, "crossfader", 0, 58, "control")
    for action, number in [("browsePrevious", 51), ("browseNext", 52), ("browseNextGroup", 53), ("browsePreviousGroup", 54)]:
        add(result, action, 0, number)
    result["startup"] = [[0xB0, 127, 0], [0x90, 59, 127], [0x90, 60, 127], [0x90, 45, 127]]
    result["shutdown"] = [[0xB0, 127, 0]]
    return [result]
