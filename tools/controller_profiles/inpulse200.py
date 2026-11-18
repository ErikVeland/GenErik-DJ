"""Original Inpulse 200 core, keeping factory facts separate from MK2."""
from curated import add, profile
from numark import UPSTREAM

ORIGINAL200_GUIDE = "https://ts.hercules.com/download/sound/manuals/DJC_Inpulse200/DJControlInpulse200_MIDI_Commands_V_1_0.pdf"
ORIGINAL200_MANUAL = "https://www.djuced.com/kb/hercules-djcontrol-inpulse-200-mapping-and-manual/"
ORIGINAL200_SOURCES = [
    ("Hercules_DJControl_Inpulse_200.midi.xml", "c0927a1bbc75c1c1727034d2bd0f0f01d018ee264c1c63c203d3f9d8e06b6587"),
    ("Hercules-DJControl-Inpulse-200-script.js", "67b2a81ee4a0e9a9bb88de2f6ce61f0fb078d5f8d1e446e148b2cef5f921553d"),
]
ORIGINAL200_REFERENCES = {"Hercules DJControl Inpulse 200": {
    "url": ORIGINAL200_GUIDE, "sha256": "7be2dd081f87210ec86a80e632748f527b81fe681770a8ccfe020b2c4e6470fb",
    "pages": [3, 4, 5, 8, 9, 10, 12, 13, 14, 15, 16, 17, 27],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in ORIGINAL200_SOURCES]
                      + [{"url": ORIGINAL200_MANUAL, "reviewed": "2026-11-17", "sha256": "ee1005af7d6099bae30042476a323eac69d066391932f0716c9c6528d2879362"}],
    "review": "The factory table supplies physical Shift, separate pad pages and paired mixer controls. The official DJUCED guide supplies manual loop In, Out/Exit, long-In four-beat activation and master 1/2/headphones 3/4. Master and headphone knobs are hardware-driven, so their MIDI messages do not also change software gain. The script supplies 248-count scratch scale and four-times shifted search. Factory relative jog magnitudes take precedence over the script's single-step clamp. The factory shifted B note rows repeat A's channel and contain conflicting PFL/Load/long-press numbers. Existing XML dispatch and channel-based handlers retain confirmed right-channel controls. Conflicting shifted PFL/Load/long-press rows remain unmapped. Cue delete, rolls, effects, Assistant, guide lights, full feedback, cleanup, firmware capture and physical calibration remain open.",
}}


def original200_profiles():
    result = profile("Hercules DJControl Inpulse 200", ORIGINAL200_GUIDE)
    result["audioOutput"] = "masterAndHeadphones"
    result["scope"] = "Automatic original-model native core with paired mixer controls, manual In/Out/Exit, long-In four-beat loop, 248/62-count jogs and documented master/headphone outputs. Conflicting shifted PFL/Load/long-press rows, other modes, full feedback, cleanup and physical calibration remain open."
    result["startup"] = [[0x91, 3, 127], [0x92, 3, 127], [0x90, 4, 5], [0xB0, 127, 127]]
    result["shutdown"] = [[0xB0, 127, 126], [0x90, 4, 0]]
    for channel in [1, 2]:
        for scope in [channel, 0]:
            add(result, "shift", channel, 4)
            result["inputs"][-1]["shiftChannel"] = scope
    for channel, deck in enumerate("ab", 1):
        shifted = channel + 3

        def control(action, ch, number, kind="note", encoding="absolute", is_shifted=False, feedback=False, **extra):
            add(result, action, ch, number, kind, encoding, deck, feedback)
            result["inputs"][-1].update(shifted=is_shifted, shiftChannel=channel, **extra)

        for action, number in [("play", 7), ("cuePreview", 6), ("sync", 5)]:
            control(action, channel, number, feedback=action != "cuePreview")
            control(action, shifted, number, is_shifted=True, releaseOnly=True)
        for action, number in [("cue", 12), ("load", 13), ("loopIn", 9), ("loopOutOrExit", 10)]:
            control(action, channel, number, feedback=action == "cue")
        control("fixedLoop", channel, 11, argument=4)
        control("loopIn", channel, 11, releaseOnly=True)
        for action, normal, alternate in [("loopIn", 9, "loopDown"), ("loopOutOrExit", 10, "loopUp")]:
            control(alternate, shifted, normal, is_shifted=True)
            control(action, shifted, normal, is_shifted=True, releaseOnly=True)
            control(alternate, channel, normal, releaseOnly=True)
        control("jogTouch", channel, 8)
        control("jogTouch", shifted, 8, is_shifted=True)
        for action, ch, number, resolution in [("jog", channel, 10, 248), ("wheelJog", channel, 9, 248), ("jog", shifted, 10, 62)]:
            control(action, ch, number, "control", "twosComplement", ch == shifted, argument=resolution)
        for action, number in [("level", 0), ("filterKnob", 1), ("low", 2), ("high", 4), ("gain", 5), ("tempo", 8)]:
            control(action, channel, number, "control", "paired14Bit", inverted=action == "tempo")
        for slot in range(4):
            control(f"hotcue{slot + 1}", channel + 5, slot, feedback=True)
            control(f"hotcue{slot + 1}", channel + 5, slot + 8, is_shifted=True, releaseOnly=True, feedback=True)
    add(result, "crossfader", 0, 0, "control", "paired14Bit")
    add(result, "browse", 0, 1, "control", "twosComplement")
    result["inputs"][-1].update(shifted=False, shiftChannel=0)
    add(result, "openGroup", 0, 0)
    result["inputs"][-1].update(shifted=False, shiftChannel=0)
    return [result]
