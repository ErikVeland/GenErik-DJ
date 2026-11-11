"""Independent MIDI facts checked against the linked manufacturer tables."""
from sources import canonical

BASE = "https://downloads.support.alphatheta.com/software_info/"
REFERENCES = {
    "Pioneer XDJ-RR": ("all-in-one-dj-systems/XDJ-RR/XDJ-RR_List_of_MIDI_Message_ver101_e.pdf", "46d82ff4c6e8822d39fa91aca217d237065c0f39adcbc2f726ca5b1ca5b210ce"),
    "AlphaTheta OMNIS-DUO": ("all-in-one-dj-systems/OMNIS-DUO/OMNIS-DUO_MIDI_Message_List_E1.pdf", "eb4c914d644be58fd3fd91555c1b5a5db027e8c70e534f9a6233ef375cd4b06a"),
    "AlphaTheta DDJ-GRV6": ("dj-controllers/DDJ-GRV6/DDJ-GRV6_MIDI_Message_List_E1.pdf", "211c4221a8a0cc0c4615ed397b73c0b89242a43c1c4ca4ba0f00e57b708ddb3e"),
    "Pioneer DDJ-SR": ("dj-controllers/DDJ-SR/DDJ-SR_List_of_MIDI_Messages_E.pdf", "d25e32be6e436c9def8891b216082b40e63052a2900f7b7fc9ee0dbb8c9d3138"),
}
HERCULES_SOURCE = "https://ts.hercules.com/download/sound/manuals/DJC_Inpulse500/DJControlInpulse500_MIDI_Commands.pdf"


def profile(name, source):
    model = name.split(" ", 1)[1]
    return {"id": name, "aliases": [name, model, "Pioneer DJ " + model] if name.startswith("Pioneer ") else [name, model],
            "definition": "manufacturer:" + canonical(name), "inputs": [], "outputs": [],
            "startup": [], "shutdown": [], "autoSelect": True,
            "scope": "Core controls. Additional hardware modes and physical acceptance remain open.", "source": source}


def add(result, action, channel, number, kind="note", encoding="absolute", deck=None, feedback=False):
    suffix = "A" if deck in {"a", "c"} else "B" if deck else ""
    record = {"action": action + suffix, "kind": kind, "channel": channel, "number": number,
              "encoding": encoding, "inverted": False}
    if deck:
        record["targetDeck"] = deck
    result["inputs"].append(record)
    if feedback:
        output = {key: value for key, value in record.items() if key not in {"encoding", "inverted"}}
        output.update(onValue=127, offValue=0, offUsesNoteOn=True)
        result["outputs"].append(output)


def pioneer_profiles():
    results = []
    for name, (path, _) in REFERENCES.items():
        result = profile(name, BASE + path)
        club = name in {"Pioneer XDJ-RR", "AlphaTheta OMNIS-DUO"}
        grv = name == "AlphaTheta DDJ-GRV6"
        # Four target channels are explicitly specified in each factory table.
        for channel, deck in enumerate("abcd"):
            add(result, "play", channel, 0 if club else 11, deck=deck, feedback=True)
            add(result, "cueReturn", channel, 1 if club else 12, deck=deck)
            add(result, "sync", channel, 31 if club else 88, deck=deck, feedback=not name.endswith("OMNIS-DUO"))
            if club or grv:
                add(result, "keylock", channel, 17 if club else 26, deck=deck, feedback=grv)
            add(result, "tempo", channel, 0, "control", "paired14Bit", deck)
            add(result, "jogTouch", channel, 32 if club else 54, deck=deck)
            add(result, "jog", channel, 34, "control", "binaryOffset", deck)
            add(result, "wheelJog", channel, 33, "control", "binaryOffset", deck)
            if club:
                add(result, "load", channel, 81, deck=deck)
            else:
                add(result, "load", 6, 70 + channel, deck=deck)
            if name == "Pioneer XDJ-RR":
                add(result, "loop", channel, 8, deck=deck, feedback=True)
            elif not club:
                add(result, "loop", channel, 77, deck=deck)
            if name == "AlphaTheta OMNIS-DUO":
                add(result, "jumpBack", channel, 45, deck=deck)
                add(result, "jumpForward", channel, 44, deck=deck)
            pad_channel = 5 + channel if club else (7 + 2 * channel if grv else 7 + channel)
            for slot in range(4 if name == "Pioneer XDJ-RR" else 8):
                add(result, f"hotcue{slot + 1}", pad_channel, slot, deck=deck, feedback=True)
            if club:
                for action, values in {"level": [17, 18, 19, 20], "gain": [1, 6, 12, 80],
                                       "high": [2, 7, 14, 81], "mid": [3, 8, 15, 92], "low": [4, 9, 21, 82]}.items():
                    add(result, action, 4, values[channel], "control", deck=deck)
                add(result, "cue", 4, 70 + channel, "control", deck=deck, feedback=True)
                if name == "Pioneer XDJ-RR":
                    add(result, "filterKnob", 4, [5, 10, 22, 83][channel], "control", deck=deck)
            else:
                for action, address in [("level", 19), ("gain", 4), ("high", 7), ("mid", 11), ("low", 15)]:
                    add(result, action, channel, address, "control", "paired14Bit", deck)
                add(result, "cue", channel, 84, deck=deck, feedback=True)
        add(result, "crossfader", 4 if club else 6, 11 if club else 31, "control", "absolute" if club else "paired14Bit")
        if club or grv:
            for action, address in [("cueMix", 27 if club else 12), ("monitor", 26 if club else 13), ("master", 24 if club else 8)]:
                add(result, action, 4 if club else 6, address, "control", "absolute" if club else "paired14Bit")
        add(result, "browse", 0 if club else 6, 79 if club else 64, "control", "twosComplement")
        add(result, "openGroup", 0 if club else 6, 51 if club else 65)
        results.append(result)
    return results


def hercules_profile():
    result = profile("Hercules DJControl Inpulse 500", HERCULES_SOURCE)
    result["startup"] = [[0xB0, 0x7F, 0x7F]]
    result["shutdown"] = [[0xB0, 0x7F, 0x7E]]
    result["aliases"].append("DJControl Inpulse 500")
    for channel, deck in [(1, "a"), (2, "b")]:
        for action, address in [("play", 7), ("cueReturn", 6), ("sync", 5), ("cue", 12), ("load", 13), ("loop", 44), ("jogTouch", 8)]:
            add(result, action, channel, address, deck=deck, feedback=action in {"play", "sync", "cue"})
        for action, address in [("level", 0), ("filterKnob", 1), ("low", 2), ("mid", 3), ("high", 4), ("gain", 5), ("tempo", 8)]:
            add(result, action, channel, address, "control", "paired14Bit", deck)
        add(result, "jog", channel, 10, "control", "twosComplement", deck)
        add(result, "wheelJog", channel, 9, "control", "twosComplement", deck)
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", channel + 5, slot, deck=deck, feedback=True)
    add(result, "crossfader", 0, 0, "control", "paired14Bit")
    add(result, "browse", 0, 1, "control", "twosComplement")
    add(result, "openGroup", 0, 0)
    # Headphone and master knobs control the hardware audio circuit directly.
    return result


def curated_profiles():
    return pioneer_profiles() + [hercules_profile()]
