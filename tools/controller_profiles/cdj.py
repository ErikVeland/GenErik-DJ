"""Pioneer factory MIDI facts for club players, independent of HID support."""
from curated import add, profile

CDJ_REFERENCES = {
    "Pioneer CDJ-3000": {
        "url": "https://downloads.support.alphatheta.com/software_info/dj-players/CDJ-3000/CDJ3000_MIDI_Message_List_E108.pdf",
        "sha256": "44b7d91661fe4b219ab3ee05719ba7ccf4521b78aa7ee09358b4ec53de98c1aa", "pages": [3, 4, 5]},
    "AlphaTheta CDJ-3000X": {
        "url": "https://downloads.support.alphatheta.com/software_info/dj-players/CDJ-3000X/CDJ3000X_MIDI_Message_List_En.pdf",
        "sha256": "e42a4b576d24543bbf80c0798b75b27490925510a28beb7beead7e48aac1a429", "pages": [3, 4]},
    "Pioneer CDJ-2000NXS2": {
        "url": "https://manuals.plus/m/787a668a0d6bc06e184a4e451d34905d65311bad6c128215e91bf56c6e74e6b3_optim.pdf",
        "sha256": None, "pages": [38], "review": "Factory operating manual, web text. Local download unavailable."},
    "AlphaTheta CDJ-1500X": {
        "url": "https://downloads.support.alphatheta.com/software_info/dj-players/CDJ-1500X/CDJ-1500X_MIDI_Message_List_E1.pdf",
        "sha256": "64581d4eda2ded25baa2d3187e682f19bed7de09078a580cf7dabb418727d017", "pages": [3, 4]},
    "Pioneer CDJ-2000NXS": {
        "url": "https://www.manualslib.com/manual/712075/Pioneer-Cdj-2000nxs.html?page=42",
        "sha256": None, "pages": [42], "review": "Factory operating manual, web text. Local PDF unavailable."},
    "Pioneer CDJ-900NXS": {
        "url": "https://warehousesound.com/r/pioneerCDJ900NXSmanual.pdf",
        "sha256": "54049f095083848e833fddb39142ade205780bea3620d864fe1ee33ec969f97b", "pages": [36]},
}

# This is an implementation order, not a claim of measured global model sales.
CLUB_PRIORITY = ["Pioneer CDJ-3000", "AlphaTheta CDJ-3000X", "Pioneer CDJ-2000NXS2",
                 "AlphaTheta CDJ-1500X", "Pioneer CDJ-2000NXS", "Pioneer CDJ-900NXS"]
CDJ_GAPS = [
    "HID transport, authentication, displays and lighting are not implemented by these MIDI tables.",
    "Automatic routing across multiple player audio interfaces is not implemented.",
    "Tempo range, vinyl mode, brake, Slip, reverse and memory-cue modes need separate native contracts.",
    "Shifted controls, alternate loop modes, hot-cue editing and remaining browser functions are incomplete.",
]


def cdj_profiles():
    results = []
    for name, source in CDJ_REFERENCES.items():
        result = profile(name, source["url"])
        result.update(role="player", scope="Automatic player controls in USB-MIDI mode. HID screens, lights and audio routing remain open.")
        nxs = name.endswith(("NXS2", "NXS"))
        compact = name.endswith("1500X")
        older = name.endswith("NXS")
        if older:
            nexus = name.replace("NXS", "nexus")
            result["aliases"].extend([nexus, nexus.removeprefix("Pioneer "), nexus.replace("Pioneer ", "Pioneer DJ ")])
        add(result, "play", 0, 0, deck="a")
        add(result, "cueReturn", 0, 1, deck="a")
        for action, address in [("keylock", 0x11 if nxs else 0x0B), ("sync", 0x1F if nxs else 0x16),
                                ("jogTouch", 0x20 if nxs else 0x17), ("reloop", 8 if nxs else 0x25),
                                ("loopIn", 6 if nxs else 0x23), ("loopOut", 7 if nxs else 0x24),
                                ("load", 0x33 if nxs else 0x11)]:
            add(result, action, 0, address, deck="a")
        if not name.endswith("900NXS") and not compact:
            add(result, "tempoReset", 0, 0x1D if name.endswith("2000NXS") else 15 if nxs else 9, deck="a")
        add(result, "openGroup", 0, 0x32 if nxs else 0x12)
        add(result, "tempo", 0, 0x1D, "control", "cdjTempo", "a")
        add(result, "jog", 0, 0x10, "control", "cdjPlatterSpeed", "a")
        if compact:
            add(result, "jog", 0, 0x29, "control", "cdjPlatterSpeed", "a")
            add(result, "loop", 0, 3, deck="a")
        add(result, "wheelJog", 0, 0x30, "control", "cdjRingSpeed", "a")
        if not name.endswith("900NXS"):
            add(result, "seek", 0, 0x1C, "control", "needlePosition", "a")
        add(result, "browse", 0, 0x4F, "control", "twosComplement")
        if name.endswith("900NXS"):
            pads = []
        elif name.endswith("2000NXS"):
            pads = [0x18, 0x19, 0x1A]
        elif nxs:
            pads = [0x18, 0x19, 0x1A, 0x1B, 0x14, 0x15, 0x16, 0x17]
        else:
            pads = range(0x1B, 0x23)
        for slot, address in enumerate(pads):
            add(result, f"hotcue{slot + 1}", 0, address, deck="a")
        loop_start = 0x24 if nxs else 0x26
        for slot, beats in enumerate([0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8, 16, 32]):
            if older:
                continue
            if compact and not 0.5 <= beats <= 16:
                continue
            if name.endswith("3000X") and beats < 0.25:
                continue
            add(result, "fixedLoop", 0, loop_start + slot, deck="a")
            result["inputs"][-1]["argument"] = beats
        if not nxs:
            for slot, beats in enumerate([0.5, 1, 2, 4, 8, 16, 32, 64]):
                for direction in [0, 1]:
                    add(result, "fixedJump", 0, 0x38 + slot * 2 + direction, deck="a")
                    result["inputs"][-1]["argument"] = beats * (-1 if direction else 1)
        if name == "Pioneer CDJ-3000":
            for address, beats in [(0x36, 16), (0x37, -16)]:
                add(result, "fixedJump", 0, address, deck="a")
                result["inputs"][-1]["argument"] = beats
        elif not older and not compact:
            add(result, "jumpForward", 0, 0x38 if nxs else 0x36, deck="a")
            add(result, "jumpBack", 0, 0x39 if nxs else 0x37, deck="a")
        if name.endswith("900NXS"):
            add(result, "fixedLoop", 0, 0x2A, deck="a")
            result["inputs"][-1]["argument"] = 4
        for binding in result["inputs"]:
            binding["anyChannel"] = True
        results.append(result)
    return results
