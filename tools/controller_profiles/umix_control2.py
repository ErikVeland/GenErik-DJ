"""Original non-Pro U-Mix Control 2 core with factory encoder and LED facts."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

UMIX2_XML = "MixVibes U-Mix Control 2.midi.xml"
UMIX2_SHA = "89a62e4ba79ded920dca67e16b2632b1e9020bdd7a79d78cb5f2feecdefa7b0a"
UMIX2_GUIDE = "https://manuals.plus/m/534f13fed15e77a7709306d246918757539a81c8a352f65475210943d6a927f9.pdf"
UMIX2_REFERENCES = {"MixVibes U-Mix Control 2": {
    "url": UPSTREAM + UMIX2_XML.replace(" ", "%20"), "sha256": UMIX2_SHA,
    "relatedSources": [{"url": UMIX2_GUIDE, "pages": [121, 122, 123, 124, 125, 126]}],
    "review": "Factory guide explicitly distinguishes non-touch Control2 from original touch Pro; Pro2 is another model. Control2 wheels are centre64 CC22, with no contact or rim messages. Native unheld wheel behaviour uses default calibration. Factory relative loop/browser encoding is signed127/1 with64 negative. Published six cue addresses, direct source Note Load5/6, native held Cue/bend, source keylock on PitchMode8, inverse centred pitch, mixer and loop controls retain source facts. Factory table calls LoadA CC5 while the pinned mapping uses Note5; this recipe follows the working Note form and leaves CC5 inactive. Factory Loop push Note13 and rotation CC13 correct the source's incomplete/asymmetric loop mapping. Global Shift2 on mixer channel2 blocks unsupported layers; shifted release-only contacts cannot trigger normal actions and rearm every normal button. Feedback uses steady127/0, not source beat/clip animation. Setup/shutdown own62 messages. Full three-state pitch/Vinyl/FX/EQ-kill modes, held Hot Cue preview, complete feedback/reset and physical calibration remain open. No audio interface, Pro touch or Pro2 340-count scale is inferred.",
}}


def umix2_profiles():
    result = profile("MixVibes U-Mix Control 2", UMIX2_REFERENCES["MixVibes U-Mix Control 2"]["url"])
    result["aliases"] = ["MixVibes U-Mix Control 2", "U-MIX CONTROL 2"]
    result["scope"] = "Automatic non-Pro two-deck core: unheld wheels, centred pitch, six cues, held Cue/bend, source Load, mixer, signed loop/browser and steady feedback. Full modes/feedback, default jog calibration and physical acceptance remain open."
    result["gaps"] = ["Factory LoadA CC5 conflicts with the working Note5 mapping; CC5 stays inactive. Full three-state PitchMode/Vinyl/FX/EQ-kill modes, Tap, held Hot Cue preview, clip/end animation, complete feedback/reset and calibration remain open. No audio interface, Pro touch/rim or Pro2 sensor scale is inferred."]
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 2), ("cuePreview", 1), ("sync", 3), ("cue", 16),
                               ("keylock", 8), ("pitchBendUp", 5), ("pitchBendDown", 4)]:
            add(result, action, channel, number, deck=deck, feedback=True)
        add(result, "load", 2, 5 + channel, deck=deck)
        add(result, "wheelJog", channel, 22, "control", "binaryOffset", deck)
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1]["inverted"] = True
        for action, number in [("gain", 17), ("high", 18), ("mid", 19), ("low", 20), ("level", 21)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "loop", channel, 13, deck=deck, feedback=True)
        add(result, "loopSize", channel, 13, "control", "twosComplement", deck)
        for slot, number in enumerate([10, 11, 12, 24, 25, 26], 1):
            add(result, f"hotcue{slot}", channel, number, deck=deck, feedback=True)
    for action, number in [("crossfader", 1), ("master", 3)]:
        add(result, action, 2, number, "control")
    add(result, "browse", 2, 4, "control", "twosComplement")
    add(result, "openGroup", 2, 4)
    normal = list(result["inputs"])
    for row in normal:
        row["shifted"] = False
        if row["kind"] == "note":
            release = deepcopy(row)
            release.update(channel=row["channel"] + 3, releaseOnly=True)
            release.pop("shifted")
            result["inputs"].append(release)
            if row["action"].startswith("hotcue6"):
                alias = deepcopy(release)
                alias["number"] = 127
                result["inputs"].append(alias)
    add(result, "shift", 2, 2)
    result["startup"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
    result["startup"] += [[0x92, 3, 0], [0x90, 7, 0], [0x91, 7, 0]]
    result["shutdown"] = [row.copy() for row in result["startup"]]
    return [result]
