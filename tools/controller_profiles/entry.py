"""Published MIDI facts for common entry-level Pioneer controllers."""
from curated import BASE, add, profile

ENTRY_REFERENCES = {
    "Pioneer DDJ-SB2": ("DDJ-SB2_List_of_MIDI_Messages_E.pdf", "80eab8ee08d43e855b757b46ca6ae7bf5d2b5940b30c07f0566a76efb18e26cb", 3),
    "Pioneer DDJ-SB": ("DDJ-SB_List_of_MIDI_Messages_E.pdf", "2a8e39d6f5e46ed31e1a9ec93b443dabad244a2060f2f751d336120c481d8107", 2),
    "Pioneer DDJ-RB": ("DDJ-RB_MIDI_Message_List_E.pdf", "c774a30945f097806fe715c9d01f1e838a49123944d89080183e4d8fc88a3616", 3),
    "Pioneer DDJ-RR": ("DDJ-RR_MIDI_Message_List_E.pdf", "aae9c77364e453907c4bc30cd35b1dd49a321a05e472cf62005a212113f612e9", 7),
    "Pioneer DDJ-200": ("DDJ-200_MIDI_Message_List_E1.pdf", "8e9c0b076c27a7d47eb7df88409aa3071ddc371ac66d202a0c5141cb1f7e9cf0", 2),
    "Pioneer DDJ-WeGO4": ("DDJ-WeGO4_List_of_MIDI_Message_E.pdf", "9902e9e310a880dd7b356a724e0d80f0f2ab3c06a12341f516af1991b816f106", 2),
}


def entry_references():
    return {name: {"url": BASE + "dj-controllers/" + name.split(" ", 1)[1] + "/" + filename,
                   "sha256": digest, "pages": list(range(1, pages + 1))}
            for name, (filename, digest, pages) in ENTRY_REFERENCES.items()}


def entry_profiles():
    results = []
    for name, source in entry_references().items():
        model = name.split(" ", 1)[1]
        sb = model in {"DDJ-SB", "DDJ-SB2"}
        rr, rb, small, wego = (model == item for item in ["DDJ-RR", "DDJ-RB", "DDJ-200", "DDJ-WeGO4"])
        decks = "abcd" if rr or model == "DDJ-SB2" else "ab"
        result = profile(name, source["url"])
        result["scope"] = "Automatic documented core controls. Remaining pad/FX modes, full feedback and audio routing remain open."
        if sb or rr:
            result["startup"] = [[0x9B, 9, 127]]
        if rr:
            result["hardwareMode"] = "Select the intended deck inputs. PC MIX controls software mixing."
        if small:
            result["gaps"] = ["The hardware has no browser, Load, loop or Keylock buttons. Use the existing app controls. Bluetooth pairing and audio routing remain separate work."]
        for channel, deck in enumerate(decks):
            for action, number in [("play", 11), ("cuePreview", 12), ("sync", 88)]:
                add(result, action, channel, number, deck=deck, feedback=action != "cuePreview")
            if sb or rr:
                add(result, "keylock", channel, 26, deck=deck, feedback=True)
            for number in [54, 103]:
                add(result, "jogTouch", channel, number, deck=deck)
            if sb:
                add(result, "jogTouch", channel, 53, deck=deck)
                result["inputs"][-1]["releaseOnly"] = True
            for number in ([34] if wego else [34, 35]):
                add(result, "jog", channel, number, "control", "binaryOffset", deck)
            for number in ([33] if small else [33, 38]):
                add(result, "wheelJog", channel, number, "control", "binaryOffset", deck)
            add(result, "tempo", channel, 0, "control", "paired14Bit", deck)
            if sb or small or rb or rr:
                for action, number in [("level", 19), ("high", 7), ("mid", 11), ("low", 15)]:
                    add(result, action, channel, number, "control", "paired14Bit", deck)
            else:
                for action, numbers in {"level": [19, 21], "high": [7, 8], "low": [15, 16]}.items():
                    add(result, action, 6, numbers[channel], "control", "paired14Bit", deck)
            if rb or rr or model == "DDJ-SB2":
                add(result, "gain", channel, 4, "control", "paired14Bit", deck)
            add(result, "filterKnob", 6, 23 + channel, "control", "paired14Bit", deck)
            add(result, "cue", 6 if wego else channel, 84 + channel if wego else 84, deck=deck, feedback=True)
            if sb:
                for slot in range(8):
                    add(result, f"hotcue{slot + 1}", 7 + channel, slot if slot < 4 else 60 + slot, deck=deck, feedback=True)
                for action, number in [("loopIn", 32), ("loopOut", 33), ("reloop", 34)]:
                    add(result, action, 7 + channel, number, deck=deck)
            else:
                for slot in range(4 if wego else 8):
                    add(result, f"hotcue{slot + 1}", channel if wego else 7 + (2 * channel if small else channel),
                        46 + slot if wego else slot, deck=deck, feedback=not rr)
            if rb or rr:
                for action, number in [("loopIn", 16), ("loopOut", 17), ("reloop", 77)]:
                    add(result, action, channel, number, deck=deck)
                add(result, "fixedLoop", channel, 69, deck=deck)
                result["inputs"][-1]["argument"] = 4
            if rr:
                add(result, "seek", channel, 3, "control", deck=deck)
            if rr or wego:
                for action, number in [("loop", 20), ("loopDown", 18), ("loopUp", 19), ("reloop", 80)]:
                    add(result, action, channel, number, deck=deck, feedback=rr and action == "loop")
            if wego:
                result["outputs"].append({"action": "loop" + deck.upper(), "targetDeck": deck, "kind": "note",
                                          "channel": 11, "number": 16 + channel, "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
            if not small:
                add(result, "load", 6, 70 + channel, deck=deck)
            if rb or rr:
                add(result, "openGroup", channel, 65)
        add(result, "crossfader", 6, 31, "control", "paired14Bit")
        if rb or rr:
            add(result, "master", 6, 8, "control", "paired14Bit")
            add(result, "monitor", 6, 13, "control", "paired14Bit")
        if sb or rr:
            add(result, "cueMix", 6, 5 if sb else 12, "control", "paired14Bit")
        if not small:
            add(result, "browse", 6, 64, "control", "twosComplement")
        if sb or wego:
            add(result, "openGroup", 6, 65)
        if model in {"DDJ-SB2", "DDJ-WeGO4"}:
            add(result, "openGroup", 6, 66)
        if model == "DDJ-SB" or rr:
            add(result, "openGroup", 6, 101)
        results.append(result)
    return results
