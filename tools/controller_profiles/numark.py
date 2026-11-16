"""Native core control facts reviewed in the pinned Mixxx FX mappings."""
from curated import add, profile

REVISION = "20f2c218ae1b762ac39fd76ff408c8428056f4f7"
UPSTREAM = "https://github.com/mixxxdj/mixxx/blob/" + REVISION + "/res/controllers/"
NUMARK_SOURCES = {
    "Numark Mixtrack Pro FX": [
        ("Numark Mixtrack Pro FX.midi.xml", "b96f810a2c6e2fdd5f3c4c7bf15c566ed1d9c86fb1c97fe782e3eb1e85f7e2c8"),
        ("Numark-Mixtrack-Pro-FX-scripts.js", "0eea844813e09d906b9abe99e487669a0530759bf5ebb47919d3fad64ba61889"),
    ],
    "Numark Mixtrack Platinum FX": [
        ("Numark Mixtrack Platinum FX.midi.xml", "673a924d86c3abcb316ffc8986430540c8ed1d4283540ea5fe38a6a9b5ff3e94"),
        ("Numark-Mixtrack-Platinum-FX-scripts.js", "91921759bdeaeb0d966d6255af97f86b3881233e8b4ccf343e384b03466428de"),
    ],
}


def numark_references():
    return {name: {"url": UPSTREAM + sources[1][0], "sha256": sources[1][1],
                   "relatedSources": [{"url": UPSTREAM + path.replace(" ", "%20"), "sha256": digest} for path, digest in sources],
                   "review": "MIDI addresses and protocol facts reviewed in the pinned Mixxx XML and script. Native app actions replace script execution."}
            for name, sources in NUMARK_SOURCES.items()}


def numark_profiles():
    results = []
    for name, source in numark_references().items():
        platinum = "Platinum" in name
        result = profile(name, source["url"])
        result["definition"] = result["definition"].replace("manufacturer:", "reviewed:")
        result["scope"] = "Automatic native core controls from pinned Mixxx facts. Pad modes, Scratch toggle, FX, screens and audio routing remain open."
        result["startup"] = [[0xF0, 0x7E, 0, 6, 1, 0xF7],
                             [0xF0, 0, 0x20, 0x7F, 0x13 if platinum else 3, 0xF7],
                             [0xF0, 0, 0x20, 0x7F, 3, 1, 0xF7]]
        result["shutdown"] = [[0xF0, 0, 0x20, 0x7F, 2, 0xF7]]
        for channel, deck in enumerate("abcd" if platinum else "ab"):
            for action, number in [("play", 0), ("cueReturn", 1), ("sync", 2), ("cue", 27)]:
                add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue"})
            add(result, "jogTouch", channel, 6, deck=deck)
            add(result, "jog", channel, 6, "control", "twosComplement", deck)
            add(result, "tempo", channel, 9, "control", "paired14Bit", deck)
            result["inputs"][-1]["inverted"] = False
            for action, number in [("gain", 22), ("high", 23), ("mid", 24), ("low", 25), ("filterKnob", 26), ("level", 28)]:
                add(result, action, channel, number, "control", deck=deck)
            if not platinum:
                numbers = [0, 13, 7, 11, 2, 15]
                result.setdefault("inputModes", []).append({"channel": 4 + channel, "initial": 0,
                                                           "numbers": numbers, "onValue": 127, "offValue": 1})
                result["startup"].extend([[0x94 + channel, number, 127 if number == 0 else 1] for number in numbers])
                for slot in range(8):
                    add(result, f"hotcue{slot + 1}", 4 + channel, 20 + slot, deck=deck)
                    result["inputs"][-1]["requiredMode"] = 0
                for slot, beats in enumerate([0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8]):
                    add(result, "toggleFixedLoop", 4 + channel, 20 + slot, deck=deck)
                    result["inputs"][-1].update(argument=beats, requiredMode=13)
            add(result, "load", 15, 2 + channel, deck=deck)
            for action, number in [("loop", 64), ("loopDown", 52), ("loopUp", 53), ("loopIn", 54), ("loopOut", 55)]:
                add(result, action, 4 + channel, number, deck=deck, feedback=action == "loop")
        add(result, "crossfader", 15, 8, "control")
        add(result, "master", 14, 35, "control")
        add(result, "monitor", 15 if platinum else 14, 12 if platinum else 47, "control")
        add(result, "cueMix", 15 if platinum else 14, 13 if platinum else 39, "control")
        add(result, "browse", 15, 0, "control", "twosComplement")
        add(result, "openGroup", 15, 7)
        for output in result["outputs"]:
            output["offValue"] = 1
        result["gaps"] = ["Pad modes, Scratch toggle, shifted functions, FX, meters, screens and full audio routing remain unimplemented. Jog response needs physical calibration. Source reuse and distribution review remain open."]
        if not platinum:
            result["scope"] = "Automatic native core controls and mode-gated Hot Cues/loops. Other pad modes, Scratch toggle, complete feedback and audio routing remain open."
            result["gaps"] = ["Sampler/cuts/beat-jump and shifted roll modes, pad lights, Scratch toggle, shifted functions, FX, meters and full audio routing remain unimplemented. Other pad modes block Hot Cues and loop pads. Jog calibration and source reuse/distribution review remain open."]
        results.append(result)
    return results
