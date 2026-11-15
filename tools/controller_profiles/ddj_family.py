"""Reviewed SX and RX-family MIDI controls, with explicit model differences."""
from curated import BASE, add, profile

DDJ_REFERENCES = {
    "Pioneer DDJ-SX3": ("DDJ-SX3_MIDI_Message_List_E1.pdf", "1cc35dc29a1df56ebb22cc4d19a87913de5d2b95b770d7d93d196a8e755bb41f", 6),
    "Pioneer DDJ-SX2": ("DDJ-SX2_List_of_MIDI_Message_E.pdf", "9f7fe1a7295570071c6bd523d215aa410181aa70cb72ffacf659e1a27ca602d9", 6),
    "Pioneer DDJ-SX": ("DDJ-SX_List_of_MIDI_Messages_E.pdf", "f76c9b061000812be7a54616e021468b6fddca8e0022401b67b8e03da1c7a44a", 5),
    "Pioneer DDJ-RX": ("DDJ-RX_List_of_MIDI_Message_E.pdf", "f3228c2dbf2335ed8be00fb9ba9f3050db350a91d024ece244b0a3abc3bf07b4", 6),
    "Pioneer DDJ-RZ": ("DDJ-RZ_MIDI_Message_List_E.pdf", "d6860c824e9bf825f7609276e332632bf6602a087c6c2afe70325479784e9859", 8),
    "Pioneer DDJ-RZX": ("DDJ-RZX_MIDI_Message_List_E.pdf", "c15554ec850bd041dc171d608ae959e8a74c7af8134b3e48fb3590cbedd87249", 9),
}
PENDING_DDJ = {
    "Pioneer DDJ-SR2": {
        "source": {"url": BASE + "dj-controllers/DDJ-SR2/DDJ-SR2_MIDI_Message_E1.pdf",
                   "sha256": "d7a665835c7278838ba64b1dc4ee7d01a785045e3fe028597c87e104a084356f", "pages": [1, 2, 3, 4, 5, 6]},
        "gap": "Load buttons use shared left/right packets. Implement deck-bank selection and safe initial bank state before automatic selection.",
    },
}


def ddj_references():
    return {name: {"url": BASE + "dj-controllers/" + name.split(" ", 1)[1] + "/" + filename,
                   "sha256": digest, "pages": list(range(1, pages + 1))}
            for name, (filename, digest, pages) in DDJ_REFERENCES.items()}


def ddj_profiles():
    results = []
    for name, source in ddj_references().items():
        result = profile(name, source["url"])
        model = name.split(" ", 1)[1]
        original = model == "DDJ-SX"
        large = model in {"DDJ-RZ", "DDJ-RZX"}
        rzx = model == "DDJ-RZX"
        result["hardwareMode"] = "General MIDI / other DJ software mode. Select PC or USB mixer inputs."
        result["scope"] = "Automatic core MIDI controls. Hardware modes, advanced functions, colour pads, screens and audio routing remain open."
        if original:
            result["gaps"] = ["Deck D filter is unmapped. The factory CC32/64 pair conflicts with browser CC64. Clarify the protocol before enabling it."]
        for channel, deck in enumerate("abcd"):
            for action, number in [("play", 11), ("cueReturn", 12), ("sync", 88), ("keylock", 26),
                                   ("cue", 84), ("loop", 20)]:
                add(result, action, channel, number, deck=deck, feedback=action != "cueReturn")
            for action, number in [("loopIn", 16), ("loopOut", 17), ("loopDown", 18), ("loopUp", 19), ("reloop", 80)]:
                add(result, action, channel, number, deck=deck)
            if model not in {"DDJ-SX", "DDJ-SX2"}:
                add(result, "reloop", channel, 77, deck=deck)
            if not (original or rzx):
                add(result, "fixedLoop", channel, 69, deck=deck)
                result["inputs"][-1]["argument"] = 4
            if rzx:
                add(result, "tempoReset", channel, 33, deck=deck)
            else:
                add(result, "seek", channel, 3, "control", deck=deck)
            for number in [54, 103]:
                add(result, "jogTouch", channel, number, deck=deck)
            for number in [34, 35]:
                add(result, "jog", channel, number, "control", "binaryOffset", deck)
            for number in [33, 38]:
                add(result, "wheelJog", channel, number, "control", "binaryOffset", deck)
            for action, number in [("tempo", 0), ("level", 19), ("gain", 4), ("high", 7), ("mid", 11), ("low", 15)]:
                add(result, action, channel, number, "control", "paired14Bit", deck)
            if not (original and deck == "d"):
                add(result, "filterKnob", 6, 23 + channel, "control", "paired14Bit", deck)
            add(result, "load", 6, 70 + channel, deck=deck)
            for slot in range(8):
                add(result, f"hotcue{slot + 1}", 7 + channel, slot, deck=deck, feedback=original)
            if large:
                add(result, "openGroup", channel, 65)
            if rzx:
                add(result, "master", channel, 8, "control", "paired14Bit")
        add(result, "crossfader", 6, 31, "control", "paired14Bit")
        add(result, "browse", 6, 64, "control", "twosComplement")
        if not large:
            add(result, "openGroup", 6, 65)
        add(result, "openGroup", 6, 101)
        if large:
            add(result, "cueMix", 6, 12, "control", "paired14Bit")
            add(result, "monitor", 6, 13, "control", "paired14Bit")
        if model == "DDJ-RZ":
            add(result, "master", 6, 8, "control", "paired14Bit")
        results.append(result)
    return results
