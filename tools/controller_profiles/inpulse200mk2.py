"""Inpulse 200 MK2 hardware facts from separate published mappings."""
from curated import add, profile

INPULSE200_REVISION = "bc57e5500ac19f203cee140bb007424661be821d"
INPULSE200_BASE = "https://raw.githubusercontent.com/CyrilGendarme/DJControl-Inpulse-200-Mk2-to-Rekordbox/" + INPULSE200_REVISION + "/"
INPULSE200_MAPPING = "https://community.algoriddim.com/uploads/short-url/daBCK3nvI2D88xIu8YCbdp2Culv.djayMidiMa"
INPULSE200_GUIDE = "https://ts.hercules.com/download/sound/manuals/DJC_Inpulse_200_MK2/DJControl_Inpulse_200_MK2_User_Manual_EN.pdf"
INPULSE200_SOURCES = [
    ("djcontrol_specific/controller_notes.py", "ba763bac95e975bdd4c1d4b0a18b8c16d9ecff0215401e98f8369535af74b028"),
    ("functions/jog_incremental.py", "64b657740fb343939061dbcc066b61660fc0aba198fc2d707f568b46b5fb9e2b"),
    ("functions/tempo_reverse.py", "0e19c2ed18a4d47acf3ff484dd76526a3a40de752e27bc43ed1def24809e2a54"),
    ("pioneer_mappings/parts/main%20buttons.csv", "11dc16e4526ad7dee43bc1a1c13d849ff026440ec9571aa2e746dfd78417783a"),
]
INPULSE200_REFERENCES = {"Hercules DJControl Inpulse 200 MK2": {
    "url": INPULSE200_MAPPING, "sha256": "4e2005fa6c7d53df1eb70d728f9e6d84d7c7269f2169023ee1a3b0a07a0d7ddd",
    "relatedSources": [{"url": INPULSE200_BASE + path, "sha256": digest, "revision": INPULSE200_REVISION}
                       for path, digest in INPULSE200_SOURCES] + [{
        "url": INPULSE200_GUIDE, "sha256": "f5d762172bc4a158888296c6fcca2cc7e63d15972fbb8011ff154bee84447c55",
        "pages": [9, 10, 11, 12, 44],
    }],
    "review": "Only hardware-address facts are reused. The published iOS mapping supplies normal controls, two-band EQ, pad pages and flipped seven-bit tempo. The second author's definitions confirm normal transport, Shift and 1/127 jog direction. Its custom three-band EQ, software banks, packet throttling and jog gain are not copied. Shift guards normal controls and tempo. Shifted delete releases rearm Hot Cues without deleting or firing a cue. Manual and adjustable loop boundaries, shifted seek scale, jog calibration, high-resolution tempo, remaining modes, full feedback, cleanup and audio routing remain open. No required startup exchange is established. Source reuse review remains open.",
}}


def inpulse200mk2_profiles():
    result = profile("Hercules DJControl Inpulse 200 MK2", INPULSE200_MAPPING)
    result["definition"] = "reviewed:hercules-inpulse-200-mk2"
    result["scope"] = "Automatic two-deck native core MIDI with held Cue, seven-bit tempo, separate Hot Cue pages and the physical two-band EQ. Jog sensitivity uses the native default pending calibration. Manual loop boundaries, shifted seeking, cue deletion, additional modes, complete feedback, routing and physical acceptance remain open."
    for channel, deck in enumerate("ab", 1):
        pad_channel = channel + 5
        add(result, "shift", channel, 4)
        result["inputs"][-1]["shiftChannel"] = channel
        for action, number in [("play", 7), ("cuePreview", 6), ("sync", 5), ("cue", 12), ("load", 13), ("jogTouch", 8), ("loop", 3)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue", "loop"})
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
        for action, number in [("loopDown", 9), ("loopUp", 10)]:
            add(result, action, channel + 3, number, deck=deck)
        for action, number in [("level", 0), ("filterKnob", 1), ("low", 2), ("high", 4), ("gain", 5)]:
            add(result, action, channel, number, "control", deck=deck)
        add(result, "tempo", channel, 8, "control", "centreDetent", deck)
        result["inputs"][-1].update(inverted=True, shifted=False, shiftChannel=channel)
        for action, number in [("jog", 10), ("wheelJog", 9)]:
            add(result, action, channel, number, "control", "signedStep", deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", pad_channel, slot, deck=deck, feedback=True)
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
            add(result, f"hotcue{slot + 1}", pad_channel, slot + 8, deck=deck)
            result["inputs"][-1].update(shifted=True, shiftChannel=channel, releaseOnly=True)
    for action, number in [("crossfader", 0), ("master", 3), ("monitor", 4)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 1, "control", "twosComplement")
    result["inputs"][-1].update(inverted=True)
    add(result, "openGroup", 0, 0)
    return [result]
