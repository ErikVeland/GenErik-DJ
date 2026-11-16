"""Core controller facts from the linked, hashed factory MIDI tables."""
from curated import BASE, add, profile

CONTROLLER_REFERENCES = {
    "AlphaTheta XDJ-AZ": ("all-in-one-dj-systems/XDJ-AZ/XDJ-AZ_MIDI_Message_List_E1.pdf", "2a56db4cc52c5bbf2371c33cbb0188a15ed28daf841f712cac343f4025f54216", 4),
    "Pioneer XDJ-RX3": ("all-in-one-dj-systems/XDJ-RX3/XDJ-RX3_MIDI_Message_List_E1.pdf", "bd9c747ec65c3910d139d33cbbf08033a9ffd57b548978bf5dd51f2c2cdf9c36", 5),
    "Pioneer XDJ-XZ": ("all-in-one-dj-systems/XDJ-XZ/XDJ-XZ_MIDI_Message_List_E1.pdf", "c0e23435447a5c3f444f55e777e4d7e1b02a0abd6238e8dd0ff1a6a00df867b9", 5),
    "Pioneer DDJ-FLX6": ("dj-controllers/DDJ-FLX6/DDJ-FLX6_MIDI_message_List_E1.pdf", "a12861c81f1550c35ae446a311951ade2a51cecfc2fd07081f5c405a4f3cfbc2", 10),
    "Pioneer DDJ-800": ("dj-controllers/DDJ-800/DDJ-800_MIDI_Message_List_E1.pdf", "1a9ff6d4cb4db440e572cc2736c5c7b20eca054ca2a5ace58065744507a97a3a", 8),
    "Pioneer DDJ-SB3": ("dj-controllers/DDJ-SB3/DDJ-SB3_MIDI_Message_List_E1.pdf", "7dcc8c30cea39597e6b1f9bdd79ec7105a58382bc8e7e89982001bf7714556da", 3),
    "Pioneer XDJ-RX2": ("all-in-one-dj-systems/XDJ-RX2/XDJ-RX2_List_of_MIDI_Message_E3.pdf", "a4a4711cb419052ec93eb06e9ea3573d5c355c15fa555d730a71ae4058ecd497", 7),
}


def controller_references():
    return {name: {"url": BASE + path, "sha256": digest, "pages": list(range(1, pages + 1))}
            for name, (path, digest, pages) in CONTROLLER_REFERENCES.items()}


def controller_profiles():
    results = []
    for name, reference in controller_references().items():
        result = profile(name, reference["url"])
        club = "XDJ-" in name
        az, rx3, sb3, flx6 = (name.endswith(model) for model in ["XDJ-AZ", "XDJ-RX3", "DDJ-SB3", "DDJ-FLX6"])
        rx2 = name.endswith("XDJ-RX2")
        result["scope"] = "Automatic core MIDI controls. Hardware control mode, advanced modes, displays and audio routing remain open."
        if club:
            result["hardwareMode"] = "PC control / MIDI. Select MIDI mixer control where required."
        for channel, deck in enumerate("abcd"):
            for action, number in [("play", 0 if club else 11), ("cuePreview", 1 if club else 12),
                                   ("sync", 31 if club else 88)]:
                add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync"})
            if not flx6:
                add(result, "keylock", channel, 17 if club else 26, deck=deck, feedback=True)
            if az or name.endswith("XDJ-XZ"):
                add(result, "tempoReset", channel, 19, deck=deck)
            add(result, "tempo", channel, 0, "control", "paired14Bit", deck)
            add(result, "jogTouch", channel, 32 if club else 54, deck=deck)
            add(result, "jogTouch", channel, 72 if club else 103, deck=deck)
            for number in ([34] if club else [34, 35]):
                add(result, "jog", channel, number, "control", "binaryOffset", deck)
            add(result, "wheelJog", channel, 33, "control", "binaryOffset", deck)
            add(result, "wheelJog", channel, 38, "control", "binaryOffset", deck)
            add(result, "load", channel if club else 6, 81 if club else 70 + channel, deck=deck)
            if sb3:
                for action, number in [("loop", 20), ("loopDown", 18), ("loopUp", 19), ("reloop", 80)]:
                    add(result, action, channel, number, deck=deck, feedback=action == "loop")
            else:
                for action, number in [("loopIn", 6 if club else 16), ("loopOut", 7 if club else 17),
                                       ("reloop", 8 if club else 77)]:
                    add(result, action, channel, number, deck=deck)
                if az or name.endswith("XDJ-XZ"):
                    for number, beats in [(67, 4), (68, 8)]:
                        add(result, "fixedLoop", channel, number, deck=deck)
                        result["inputs"][-1]["argument"] = beats
                # A long IN press also sends the short IN packet. Keep that sequence explicit.
                add(result, "fixedLoop", channel, 69 if club else 20, deck=deck)
                result["inputs"][-1]["argument"] = 4
            if az:
                add(result, "jumpForward", channel, 22, deck=deck)
                add(result, "jumpBack", channel, 24, deck=deck)
            if club:
                add(result, "seek", channel, 28, "control", "needlePosition", deck)
            for slot in range(8):
                pad_channel = (5 + channel + (4 if slot >= 4 else 0) if az else
                               5 + channel if club else 7 + channel if sb3 else 7 + 2 * channel)
                pad_number = (slot % 4) * 19 if az else slot
                add(result, f"hotcue{slot + 1}", pad_channel, pad_number, deck=deck, feedback=sb3)
            if club:
                for action, numbers in {"level": [17, 18, 19, 20], "gain": [1, 6, 12, 80],
                                        "high": [2, 7, 14, 81], "mid": [3, 8, 15, 92],
                                        "low": [4, 9, 21, 82], "filterKnob": [5, 10, 22, 83]}.items():
                    add(result, action, 4, numbers[channel], "control", deck=deck)
                    if action == "level" and az:
                        result["inputs"][-1]["inverted"] = True
                add(result, "cue", 4, 70 + channel, "control", deck=deck, feedback=rx3 or rx2)
            else:
                for action, number in [("level", 19), ("gain", 4), ("high", 7), ("mid", 11), ("low", 15)]:
                    add(result, action, channel, number, "control", "paired14Bit", deck)
                add(result, "filterKnob", 6, 23 + channel, "control", "paired14Bit", deck)
                add(result, "cue", channel, 84, deck=deck, feedback=True)
        add(result, "crossfader", 4 if club else 6, 11 if club else 31, "control", "absolute" if club else "paired14Bit")
        for action, number in [("master", 24 if club else 8), ("monitor", 26 if club else 13)]:
            add(result, action, 4 if club else 6, number, "control", "absolute" if club else "paired14Bit")
        if not sb3:
            add(result, "cueMix", 4 if club else 6, 27 if club else 12, "control", "absolute" if club else "paired14Bit")
        add(result, "browse", 0 if club else 6, 79 if club else 64, "control", "twosComplement")
        add(result, "openGroup", 0 if club else 6, 51 if club else 65)
        if club or not sb3:
            add(result, "openGroup", 0 if club else 6, 50 if club else 101)
        results.append(result)
    return results
