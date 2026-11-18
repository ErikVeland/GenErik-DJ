"""Pioneer pad accessory core facts from factory MIDI tables."""
from curated import BASE, add, profile

PAD_REFERENCES = {
    "Pioneer DDJ-XP2": {
        "url": BASE + "dj-controllers/DDJ-XP2/DDJ-XP2_MIDI_Message_List_E1.pdf",
        "sha256": "d637c3f5206a475988e6fb98dadbf7bec4abb7ee59b2654671ea3a6aebeb8be6", "pages": [1, 2, 3, 4],
    },
    "Pioneer DDJ-XP1": {
        "url": BASE + "dj-controllers/DDJ-XP1/DDJ-XP1_List_of_MIDI_Message_E1.pdf",
        "sha256": "ff0e7c6f5a28a729036f959336bbb583739fb5fad7a92def07ffb0b29a136dfa", "pages": [1, 2, 3, 4, 5, 6],
    },
    "Pioneer DDJ-SP1": {
        "url": BASE + "dj-controllers/DDJ-SP1/DDJ-SP1_List_of_MIDI_Messages_E.pdf",
        "sha256": "97e2eae5bc98467bfaf19a131fd99df3086f770c84c6ff841145ad08e2d9b3fe", "pages": [1, 2, 3, 4],
    },
}


def pad_accessory_profiles():
    results = []
    for name, source in PAD_REFERENCES.items():
        sp1 = name.endswith("SP1")
        xp2 = name.endswith("XP2")
        result = profile(name, source["url"])
        result["role"] = "accessory"
        result["scope"] = "Automatic native accessory controls in the published MIDI mode. Eight Hot Cues per deck, loops, Sync, Load and browsing. Remaining pad modes, FX and complete feedback remain open."
        if sp1:
            result["startup"] = [[0x9B, 9, 127]]
        else:
            result["hardwareMode"] = "MIDI controller mode for other DJ software; automatic mode selection is not implemented."
        for channel, deck in enumerate("abcd"):
            add(result, "sync", channel, 88, deck=deck, feedback=True)
            if sp1:
                add(result, "loop", channel, 85, deck=deck)
                add(result, "loopSize", channel, 23, "control", "twosComplement", deck)
            else:
                add(result, "keylock", channel, 26, deck=deck, feedback=True)
                add(result, "loop", channel, 20, deck=deck, feedback=True)
                result["inputs"][-1]["argument"] = 4
                for action, number in [("loopDown" if xp2 else "loopIn", 16), ("loopUp" if xp2 else "loopOut", 17)]:
                    add(result, action, channel, number, deck=deck)
            add(result, "load", 6, 70 + channel, deck=deck)
            pad_channel = 7 + channel if sp1 else 7 + 2 * channel
            numbers = [12, 13, 14, 15, 8, 9, 10, 11] if xp2 else list(range(8))
            for slot, number in enumerate(numbers, 1):
                add(result, f"hotcue{slot}", pad_channel, number, deck=deck)
            if not sp1:
                for output in result["outputs"]:
                    output["offUsesNoteOn"] = False
        add(result, "browse", 6, 64, "control", "twosComplement")
        for number in [65, 101 if sp1 else 66]:
            add(result, "openGroup", 6, number)
        result["gaps"] = ["Accessory controls complement the app or another controller. Remaining pad modes, cue deletion, pad lights, full mode feedback, shifted alternate functions, key controls, slip/censor, FX and lifecycle cleanup remain unimplemented. The app currently exposes eight Hot Cues per deck. XP1 lower pads and XP2 sampler pads are not remapped to unrelated actions. Physical mode selection and acceptance remain open."]
        if not sp1:
            result["gaps"].append("XP automatic software-mode negotiation is not implemented. Use the published MIDI controller mode for other DJ software. No undocumented connect packet is sent. XP1 IN/OUT buttons retain manual loop actions; contextual half/double behaviour remains open.")
        results.append(result)
    return results
