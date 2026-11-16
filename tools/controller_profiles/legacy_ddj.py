"""Generation-specific ERGO and WeGO facts from published MIDI tables."""
from curated import BASE, add, profile

LEGACY_DDJ_REFERENCES = {
    "Pioneer DDJ-WeGO3": ("DDJ-WeGO3/DDJ-WeGO3_List_of_MIDI_Message_E.pdf", "68de1c9c1195c8aae977da5fd56cd6c14f93e192e3791df3c6c5026d8b58ae03", 4),
    "Pioneer DDJ-WeGO2": ("DDJ-WeGO2/DDJWeGO2ListofMIDIMessageVirtualDJE.pdf", "ff7eb74e03e9a4042d498628ccca8f8dd57b805d03912db7788df886189c3d81", 6),
    "Pioneer DDJ-WeGO": ("DDJ-WeGO/DDJWeGO-ListofMIDIMessagesVirtualDJE.pdf", "e9170291b34e42919b62a672aab80f93f79973592f6208fc570443fb65cefb32", 6),
    "Pioneer DDJ-ERGO": ("DDJ-ERGO-V/DRH1149A_EN.pdf", "fd1fe2600cbbadcaa342e729f513226489a32cbbbe985034e5c7ea2a3b0c66b2", 6),
}


def legacy_ddj_references():
    return {name: {"url": BASE + "dj-controllers/" + path, "sha256": digest, "pages": list(range(1, pages + 1))}
            for name, (path, digest, pages) in LEGACY_DDJ_REFERENCES.items()}


def legacy_ddj_profiles():
    results = []
    for name, source in legacy_ddj_references().items():
        ergo, wego3 = name.endswith("ERGO"), name.endswith("WeGO3")
        result = profile(name, source["url"])
        result["scope"] = "Automatic core MIDI controls. Remaining shifted modes, FX, full feedback and audio routing remain open."
        if not wego3 and not ergo:
            result["hardwareMode"] = "Use the MIDI message mode documented by the factory VirtualDJ table."
        if ergo:
            result["aliases"] += ["DDJ-ERGO-V", "Pioneer DDJ-ERGO-V", "Pioneer DJ DDJ-ERGO-V"]
        for channel, deck in enumerate("ab" if wego3 else "abcd"):
            for action, number in [("play", 8 if wego3 else 11), ("cueReturn", 12), ("sync", 88), ("loop", 20)]:
                add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync"} or (wego3 and action == "loop"))
            add(result, "reloop", channel, 80, deck=deck)
            if wego3:
                add(result, "loopDown", channel, 18, deck=deck)
                add(result, "loopUp", channel, 19, deck=deck)
            else:
                add(result, "loopSize", channel, 19, "control", "twosComplement", deck)
            if ergo:
                for action, number in [("loopIn", 16), ("loopOut", 17), ("keylock", 26)]:
                    add(result, action, channel, number, deck=deck, feedback=action == "keylock")
            for number in [54, 103]:
                add(result, "jogTouch", channel, number, deck=deck)
            if ergo:
                add(result, "jogTouch", channel, 55, deck=deck)
                result["inputs"][-1]["releaseOnly"] = True
            for number in ([34, 35, 39] if ergo else [34, 39]):
                add(result, "jog", channel, number, "control", "twosComplement" if ergo else "binaryOffset", deck)
            for number in [33, 38]:
                add(result, "wheelJog", channel, number, "control", "twosComplement" if ergo else "binaryOffset", deck)
            add(result, "tempo", channel, 0, "control", "paired14Bit", deck)
            for slot in range(4):
                add(result, f"hotcue{slot + 1}", channel, 46 + slot, deck=deck, feedback=True)
            for action, number in [("high", 7 + channel), ("mid", 11 + channel), ("low", 15 + channel), ("level", 19 + 2 * channel)]:
                add(result, action, 6, number, "control", "paired14Bit", deck)
            if ergo:
                add(result, "gain", 6, 3 + channel, "control", "paired14Bit", deck)
                add(result, "filterKnob", 6, 27 + channel, "control", "paired14Bit", deck)
            add(result, "cue", 6, 84 + channel, deck=deck, feedback=True)
            add(result, "load", 6, 70 + channel, deck=deck)
        add(result, "crossfader", 6, 31, "control", "paired14Bit")
        if not wego3:
            add(result, "cueMix", 6, 1, "control", "paired14Bit")
        if ergo:
            add(result, "master", 6, 0, "control", "paired14Bit")
            add(result, "monitor", 6, 2, "control", "paired14Bit")
        for number in [64, 100]:
            add(result, "browse", 6, number, "control", "twosComplement")
        add(result, "openGroup", 6, 65)
        result["gaps"] = ["Remaining shifted controls, delete/sample modes, jog illumination and complete audio routing remain unimplemented. No application-connect command is documented in this table."]
        results.append(result)
    return results
