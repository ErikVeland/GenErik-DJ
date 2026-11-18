"""Mixon 4 core facts from the factory MIDI table and published mapping."""
from curated import add, profile

MIXON4_TABLE = "https://www.reloop.com/media/custom/upload/Reloop-Mixon4_MIDI-Map.pdf"
MIXON4_MAPPING = "https://www.reloop.com/media/custom/upload/Reloop-Mixon4_Traktor_Mapping_v1.1.zip"
MIXON4_REFERENCES = {"Reloop Mixon 4": {
    "url": MIXON4_TABLE, "sha256": "3d2db919c1fdc80f1d7b92c6321e4fb1907969f8965c8cba354e43eca6a45050",
    "pages": [1, 2, 4, 5],
    "relatedSources": [{"url": MIXON4_MAPPING, "sha256": "71892b8e2549e0c02d997769ae7ce703a0b79a42b702887ed1378e59890bf31d",
         "archiveMember": {"path": "Mixon 4 Traktor Mapping + Settings v1.1.tsi", "sha256": "221acd12f2a4865069111bdb1dbeae9a4552926513494e7f9397733bd080641c"}},
        {"url": "https://www.reloop.com/media/custom/upload/Reloop-Mixon4_Firmware_Utility_V2.pdf",
         "sha256": "f15ba0362aefc22e8c203848e0a5fe02d1b1a8a39c79843b3aecbd5a3c03160b"}],
    "review": "Factory deck controls use channels 4-7, Hot Cue pads use 0-3, and global controls use 10. The published TSI confirms four unflipped absolute PitchBend inputs and the normal jog/touch addresses. Only protocol facts are reused. Factory state query does not change the deck restriction or any firmware setting. Global Shift guards unsupported alternatives and rearms pitch pickup. Explicit deck reports release old contacts and reset the selected side. Full blue and dim blue Hot Cue feedback use values 3 and 67 from the RGB table. Master and booth are hardware controls. Jog sensitivity uses the native default pending calibration. Other pad modes, FX, macro controls, assignments, full feedback, cleanup, routing and physical direction/calibration remain open. Mixon 8 Pro is not an alias.",
}}


def mixon4_profiles():
    result = profile("Reloop Mixon 4", MIXON4_TABLE)
    result["scope"] = "Automatic four-target native core MIDI with distinct mixer/pad/global channels, held Cue, 14-bit pitch, eight Hot Cues, loops and documented RGB feedback. C/D retain the app opt-in. Master/booth remain hardware controls. Additional modes, feedback, cleanup, routing and physical calibration remain open."
    result["startup"] = [[0xF0, 0, 32, 127, 3, 1, 0xF7]]
    result["bankChanges"] = [{"channel": channel, "number": 18, "onValue": 127,
                              "decks": ["a", "c"] if channel in {4, 6} else ["b", "d"]}
                             for channel in range(4, 8)]
    add(result, "shift", 10, 3)
    for index, deck in enumerate("abcd"):
        channel = index + 4
        for action, number in [("play", 12), ("cuePreview", 13), ("sync", 14), ("cue", 3),
                               ("load", 2), ("keylock", 16), ("loop", 8)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync", "cue", "keylock", "loop"})
            result["inputs"][-1]["shifted"] = False
            if action in {"play", "cuePreview", "sync", "keylock"}:
                add(result, action, channel, number + 64, deck=deck)
                result["inputs"][-1].update(shifted=True, releaseOnly=True)
        add(result, "jogTouch", channel, 7, deck=deck)
        result["inputs"][-1]["shifted"] = False
        add(result, "jog", channel, 6, "control", "binaryOffset", deck)
        result["inputs"][-1]["shifted"] = False
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1]["shifted"] = False
        add(result, "loopSize", channel, 8, "control", "binaryStep", deck)
        result["inputs"][-1]["shifted"] = False
        for action, number in [("gain", 0), ("high", 1), ("mid", 2), ("low", 3), ("filterKnob", 4), ("level", 5)]:
            add(result, action, channel, number, "control", deck=deck)
            result["inputs"][-1]["shifted"] = False
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", index, slot, deck=deck, feedback=True)
            result["inputs"][-1]["shifted"] = False
            result["outputs"][-1].update(onValue=3, offValue=67)
            add(result, f"hotcue{slot + 1}", index, slot + 64, deck=deck)
            result["inputs"][-1].update(shifted=True, releaseOnly=True)
    for action, number in [("crossfader", 0), ("cueMix", 3), ("monitor", 7)]:
        add(result, action, 10, number, "control")
        result["inputs"][-1]["shifted"] = False
    add(result, "browse", 10, 4, "control", "binaryOffset")
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 10, 0)
    result["inputs"][-1]["shifted"] = False
    return [result]
