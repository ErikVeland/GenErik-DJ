"""Independent S7/S5 factory facts and the verified shared paired-mixer contract."""
from curated import add, profile

MIXER_BASE = "https://downloads.support.alphatheta.com/software_info/dj-mixers/"
MIXER_SOURCES = [
    ("DJM-S7-MIDI.pdf", "f345cf74d993288f7a2a6552a9d9af8c4d2bb03bac6440981281530cd85cd028"),
    ("DJM-S5-MIDI.pdf", "dbef5bbafbc3cc433171927b4293bb779373fcd70b5e31ba810206908df55dc0"),
]
MIXER_REFERENCES = {"Pioneer DJM-" + model: {
    "url": MIXER_BASE + "DJM-" + model + "/DJM-" + model + "_MIDI_Message_v100_E.pdf", "sha256": digest, "pages": [2,5] if model == "S7" else [2],
    "review": "Independent factory table review confirms the same16 paired MIDI mirror controls as S11: A/B trim4/36, high7/39, mid11/43, low15/47, filter1/33 and level19/51 on channels0/1; global6 master8/40, headphone13/45, cue-mix12/44 and crossfader31/63. Both normal Load70 addresses and shifted71 releases are explicit on channels0/1. Native shared builder expresses these verified facts without aliasing models. Positive shifted Load remains inactive and releases rearm normal Load. " + (
        "S7 browser rows print channel7 but Bn/9n status; browser channels and modifier-dependent FX dispatch remain unqualified. No browser address is guessed." if model == "S7" else
        "S5 independently specifies global channel6/statusB6 browserCC64, signed counts1..30 clockwise and127..98 counterclockwise. Browse press65 enters native Open Group; shifted66 is release-only. Shifted rotationCC100 and FX-modified rotations80..85 remain inactive.") + " These are manual MIDI mirrors for a separate software audio path. Hardware mixing, external deck audio routing/bypass, PFL cue-fader semantics, shared pads, fader-start gestures, hardware FX/microphone controls, complete output/lifecycle and physical acceptance remain open. No lamp/setup packet or automatic selection is inferred.",
} for model, (_, digest) in zip(["S7", "S5"], MIXER_SOURCES)}


def add_paired_mixer_inputs(result):
    for channel, deck in enumerate("ab"):
        for action, number in [("gain",4),("high",7),("mid",11),("low",15),("filterKnob",1),("level",19)]:
            add(result, action, channel, number, "control", "paired14Bit", deck)
            result["inputs"][-1]["lowNumber"] = number + 32
    for action, number in [("master",8),("monitor",13),("cueMix",12),("crossfader",31)]:
        add(result, action, 6, number, "control", "paired14Bit")
        result["inputs"][-1]["lowNumber"] = number + 32


def manual_mixer_profiles():
    results = []
    for model in ["S7", "S5"]:
        name = "Pioneer DJM-" + model
        result = profile(name, MIXER_REFERENCES[name]["url"])
        result["autoSelect"] = False
        result["hardwareMode"] = "Manual MIDI mirror for a separate software audio path. Enable input separately; external hardware mixer routing and bypass remain unavailable."
        result["scope"] = "Manual paired A/B mixer and normal Load. " + ("Source-confirmed signed browsing and Open Group. " if model == "S5" else "Browser channel ambiguity remains unresolved. ") + "External audio, shared pads/modes, lights, lifecycle and physical acceptance remain open."
        result["excludedAliases"] = ["DJM-" + other for other in ["S11", "S9", "A9", "S5" if model == "S7" else "S7"]]
        add_paired_mixer_inputs(result)
        for channel, deck in enumerate("ab"):
            add(result, "load", channel, 70, deck=deck)
            add(result, "load", channel, 71, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        if model == "S5":
            add(result, "browse", 6, 64, "control", "twosComplement")
            add(result, "openGroup", 6, 65)
            add(result, "openGroup", 6, 66)
            result["inputs"][-1]["releaseOnly"] = True
        result["gaps"] = ["Manual MIDI mirror only; use with a separate software audio path. External deck routing and hardware/software mixer bypass remain unavailable. Automatic selection stays off. Shared pads, FX/microphone, fader-starts, PFL cue-fader ownership, lights, full lifecycle and physical acceptance remain open. " + ("S7 browser channel/status notation conflicts; no browser binding is inferred." if model == "S7" else "Shifted and FX-modified browsing remains inactive.")]
        results.append(result)
    return results
