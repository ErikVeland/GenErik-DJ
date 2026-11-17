"""Original RMX2 factory pairs, separate wheel streams and CC pad releases."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

RMX2_GUIDE = "https://ts.hercules.com/download/sound/manuals/Rmx2/RMX2_MIDI_Commands.pdf"
RMX2_SOURCES = [
    ("Hercules DJ Console RMX 2.midi.xml", "fc81916d9b3fb2e6df22c17ca5949149fe61df12b03957cd3c36d6c8c6640c32"),
    ("Hercules-DJ-Console-RMX-2-scripts.js", "a891020eac028edfce238d9815f8cefbad8349b12de5d91baad013b02507ac11"),
]
RMX2_REFERENCES = {"Hercules DJ Console RMX2": {
    "url": RMX2_GUIDE, "sha256": "941d120d7e4d9d85ec760e5e8efe4589c33f5f1602fc42df9c58a0069c586d67", "pages": list(range(1, 14)),
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in RMX2_SOURCES],
    "review": "Factory default-channel table qualifies adjacent MSB/LSB pairs for pitch, levels, gain, EQ, main gain, cue mix and crossfader. Explicit low-controller numbers correct coarse legacy gain/EQ. Native pitch inversion retains source rate polarity; EQ rotation retains working source polarity pending calibration. Separate factory normal48/49 and scratch50/51 streams use signed magnitude including negative64, correcting the script's64-forward boundary. Native fixed pressure scratch retains 256 counts and requires full-value physical contact 47/64 on the scratch stream, without source delayed releases or inertia timers. Factory Loop-mode encoder controls native loop size. Native Cue stays separate from PFL. Factory shifted bend notes84/85/88/89 only release existing native holds. Four Cue pads per side and source4/2/1/half-beat loops use distinct hardware mode addresses. Shifted pads report CC releases: only exact zero seven-bit absolute CC rearms the native button; positive shifted delete/roll/pressure values stay inactive. Native feedback uses factory normal-page Cue and transport/PFL LED addresses. Startup clears unsupported loop/kill/source/contact/browser indicators, enables fixed Scratch and requests analogue state with factoryB0/7F; shutdown clears native outputs and Scratch. Hardware headphone gain, microphone, held search, other modes/FX/samplers, full meters/cleanup/routing, calibration and physical acceptance remain open. Original RMX is not an alias.",
}}


def rmx2_profiles():
    result = profile("Hercules DJ Console RMX2", RMX2_GUIDE)
    result["aliases"] += ["Hercules DJConsole Rmx2", "Hercules DJ Console RMX 2", "DJConsole Rmx2", "DJ Console RMX 2"]
    result["excludedAliases"] = ["Hercules DJ Console RMX", "DJ Console RMX"]
    result["scope"] = "Automatic default-channel RMX2 core with adjacent fourteen-bit mixer/pitch pairs, 256-count fixed pressure scratch, native held Cue/bend, four cues, source fixed loops/loop-size encoder and safe shifted CC pad releases. Other modes/feedback/routing, calibration and physical acceptance remain open."
    for side, deck in enumerate("ab"):
        for action, number in [("play", 33), ("cuePreview", 34), ("sync", 35), ("load", 36), ("cue", 46)]:
            add(result, action, 0, number + 17 * side, deck=deck, feedback=action != "load")
        for action, number, alternate in [("pitchBendDown", 44, 84), ("pitchBendUp", 45, 85)]:
            add(result, action, 0, number + 17 * side, deck=deck)
            release = deepcopy(result["inputs"][-1])
            release.update(number=alternate + 4 * side, releaseOnly=True)
            result["inputs"].append(release)
        add(result, "jogTouch", 0, 47 + 17 * side, encoding="fullVelocityGate", deck=deck)
        for action, number in [("wheelJog", 48), ("jog", 50)]:
            add(result, action, 0, number + side, "control", "twosComplement", deck)
            result["inputs"][-1]["argument"] = 256
            if action == "jog":
                result["inputs"][-1]["requiresTouch"] = True
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", 0, 9 + 16 * side + slot, deck=deck, feedback=True)
            release = deepcopy(result["inputs"][-1])
            release.update(kind="control", releaseOnly=True)
            result["inputs"].append(release)
        for slot, beats in enumerate([4, 2, 1, 0.5]):
            add(result, "toggleFixedLoop", 0, 13 + 16 * side + slot, deck=deck)
            result["inputs"][-1]["argument"] = beats
            release = deepcopy(result["inputs"][-1])
            release.update(kind="control", releaseOnly=True)
            result["inputs"].append(release)
        add(result, "loopSize", 0, 52 + side, "control", "twosComplement", deck)
        for action, number in [("tempo", 54 + side * 2), ("level", 58 + side * 16), ("high", 60 + side * 16),
                               ("mid", 62 + side * 16), ("low", 64 + side * 16), ("gain", 66 + side * 16)]:
            add(result, action, 0, number, "control", "paired14Bit", deck)
            result["inputs"][-1].update(lowNumber=number + 1, inverted=action == "tempo")
    for action, number in [("master", 68), ("cueMix", 70), ("crossfader", 72)]:
        add(result, action, 0, number, "control", "paired14Bit")
        result["inputs"][-1]["lowNumber"] = number + 1
    for action, number in [("browsePrevious", 69), ("browseNext", 70), ("browsePreviousGroup", 68), ("browseNextGroup", 67)]:
        add(result, action, 0, number)
    clear = [13, 14, 15, 16, 29, 30, 31, 32, 40, 41, 42, 43, 47, 57, 58, 59, 60, 64, 67, 68]
    result["startup"] = [[0x90, number, 0] for number in clear] + [[0x90, 71, 127], [0xB0, 127, 127]]
    result["shutdown"] = [[0x90, r["number"], 0] for r in result["outputs"]] + [[0x90, 71, 0]]
    return [result]
