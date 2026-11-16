"""Original Party Mix core facts from the pinned Mixxx component mapping."""
from curated import add, profile
from numark import UPSTREAM

PARTY_MIX_SOURCES = [
    ("Numark-Party-Mix.midi.xml", "8745faac533e58e2a23699bfb365442564876226aee98ab12570b01efe84136b"),
    ("Numark-Party-Mix.scripts.js", "f6a918228964c90105a47a9faa109a0dc80935cb269d0495054ab04712997132"),
]
PARTY_MIX_REFERENCES = {"Numark Party Mix": {
    "url": UPSTREAM + PARTY_MIX_SOURCES[1][0], "sha256": PARTY_MIX_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + path, "sha256": digest} for path, digest in PARTY_MIX_SOURCES],
    "review": "The original model has no platter touch sensor. Native wheel-side jogging replaces the source default pitch-bend mode. Timed Scratch remains unimplemented. Hot Cues follow the source mode latch; other pad modes block cue actions. XML Load notes 2/3 govern input, not the component constructor output addresses. Tempo uses the non-inverted source rate Pot and rate_dir -1."}}


def party_mix_profiles():
    result = profile("Numark Party Mix", PARTY_MIX_REFERENCES["Numark Party Mix"]["url"])
    result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
    result["scope"] = "Automatic native core controls and mode-gated Hot Cues. Wheels use native pitch bend. Timed Scratch, remaining pad modes, full shutdown feedback and audio routing remain open."
    result["startup"] = [[0xB0, number, 0] for number in [64, 66, 67]] + [[0xF0, 0, 1, 63, 56, 72, 0xF7]]
    result["shutdown"] = [[0x80 + channel, 7, 0] for channel in range(2)]
    for channel, deck in enumerate("ab"):
        for action, number in [("play", 0), ("cueReturn", 1), ("sync", 2), ("cue", 27)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue"})
        add(result, "load", 15, 2 + channel, deck=deck)
        for action, number in [("gain", 23), ("high", 24), ("low", 25), ("level", 28), ("tempo", 9)]:
            add(result, action, channel, number, "control", deck=deck)
            if action == "tempo":
                result["inputs"][-1]["inverted"] = True
        add(result, "wheelJog", channel, 6, "control", "twosComplement", deck)
        result["startup"].append([0x90 + channel, 7, 1])
        numbers = [0, 11, 14, 24]
        result.setdefault("inputModes", []).append({"channel": 4 + channel, "initial": 0,
                                                   "numbers": numbers, "onValue": 127, "offValue": 1})
        result["startup"].extend([[0x94 + channel, number, 127 if number == 0 else 1] for number in numbers])
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", 4 + channel, 20 + slot, deck=deck)
            result["inputs"][-1]["requiredMode"] = 0
    for action, number in [("master", 10), ("cueMix", 13), ("monitor", 12), ("crossfader", 8)]:
        add(result, action, 15, number, "control")
    add(result, "browse", 15, 0, "control", "twosComplement")
    add(result, "openGroup", 15, 0)
    for output in result["outputs"]:
        output["offValue"] = 1
        if output["action"] in {"cueA", "cueB"}:
            output["offUsesNoteOn"] = False
    result["gaps"] = ["Hot Cue pad lights, timed sensorless Scratch, Loop/Sampler/FX pad modes, browser hold/focus gestures, party-light animation, full shutdown LED cleanup and audio routing remain unimplemented. Other pad modes block Hot Cues. Native wheel-side jogging keeps signed counts; physical response and source reuse/distribution review remain open. This recipe applies only to the original Party Mix, not II, III, Live or Pro."]
    return [result]
