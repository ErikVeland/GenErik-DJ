"""BCD3000 standard-mode core from the factory MIDI and audio tables."""
from curated import add, profile
from numark import UPSTREAM

BCD3000_GUIDE = "https://img.musicworld.bg/pdf/i/6/0/2/20206/BCD3000_Manual_EN.pdf"
BCD3000_SOURCES = [
    ("Behringer BCD3000.midi.xml", "7d844f064886cfb937f3ffbaf29506846265c42be6eb946e2204c6c9ab19b2d1"),
    ("Behringer-BCD3000-scripts.js", "0036f216b58ed62c0422f9b005bd6adb0722b57cd6dbc9f8be5ee419f4325e3c"),
]
BCD3000_REFERENCES = {"Behringer BCD3000": {
    "url": BCD3000_GUIDE, "sha256": "eb486ba4d851bdc0e9c3eb19d99bed91196a84d0b50732c5c7e632af3075b101", "pages": [9, 13, 14, 15],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in BCD3000_SOURCES],
    "review": "Factory standard-mode Note On/Off buttons, CC faders/EQ and separate CC LED addresses define this native core. The guide establishes standard mode and fixed master1/2/headphones3/4 on Mac. Native wheel jogs retain source 100-count scale and factory binary-offset movement with source acceleration enabled. No physical touch or source latched scratch is invented. Startup clears only documented LEDs1..25, enables factory accelerationCC99 and queries only analogue controlsCC100. Native held pitch bends use owned four-percent rate. SET CUE uses native cue-set, separate from held CUE preview. Reloop uses native loop state and factory loop indicator. Factory DATA4 is not Master/Balance; source assignments atCC16 are omitted. Physical Master/Phones gain stays hardware-owned. BCD2000 requires its own non-class-compliant USB driver and is not an alias. Advanced Windows toggle mode, Set Loop hold/release, Search, EQ kill, common Key, FX, latched scratch, passthrough, full feedback/routing, calibration and physical acceptance remain open.",
}}


def bcd3000_profiles():
    result = profile("Behringer BCD3000", BCD3000_GUIDE)
    result["aliases"].append("BCD3000 MIDI 1")
    result["hardwareMode"] = "Standard MIDI mode. Windows Advanced toggle mode is not implemented."
    result.update(audioOutput="masterAndHeadphones", scope="Automatic BCD3000 standard-mode core with held Cue/bend, cue-set, native wheels, three-band mixer, pitch, reloop and factory CC feedback. BCD2000, Windows Advanced mode, latched scratch, remaining controls and physical acceptance stay separate/open.")
    for side, deck in enumerate("ab"):
        for action, number in [("play", 18 + 8 * side), ("cuePreview", 19 + 8 * side), ("sync", 16 + 8 * side),
                               ("cue", 35 + side), ("cueSet", 4 + 6 * side), ("pitchBendDown", 2 + 6 * side),
                               ("pitchBendUp", 3 + 6 * side), ("reloop", 5 + 6 * side)]:
            add(result, action, 0, number, deck=deck)
        for action, number in [("low", 3), ("mid", 4), ("high", 5), ("gain", 6)]:
            add(result, action, 0, number + side * 4, "control", deck=deck)
        add(result, "level", 0, side * 2, "control", deck=deck)
        add(result, "tempo", 0, 11 + side, "control", deck=deck)
        result["inputs"][-1]["inverted"] = True
        add(result, "wheelJog", 0, 19 - side, "control", "binaryOffset", deck)
        result["inputs"][-1]["argument"] = 100
        for action, number in [("play", 18), ("sync", 20), ("loop", 21), ("cue", 2 if side == 0 else 9)]:
            result["outputs"].append({"action": action + deck.upper(), "targetDeck": deck, "kind": "control", "channel": 0,
                                      "number": number - side * 8, "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
    add(result, "crossfader", 0, 1, "control")
    add(result, "cueMix", 0, 17, "control")
    result["startup"] = [[0xB0, number, 0] for number in range(1, 26)] + [[0xB0, 99, 127], [0xB0, 100, 127]]
    result["shutdown"] = [[0xB0, number, 0] for number in range(1, 26)]
    return [result]
