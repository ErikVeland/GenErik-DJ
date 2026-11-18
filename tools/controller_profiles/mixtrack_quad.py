"""Mixtrack Quad native core from manufacturer-hosted device and mapping files."""
from curated import add, profile

QUAD_BASE = "https://www.numark.com/images/product_downloads/"
QUAD_SOURCES = [
    ("Mixtrack_Quad_VDJ_Pro.zip", "4585d896f9758f8bfea34565f6b7a1e55890755d1a8820be9dbe36d6da97738c"),
    ("MixTrack_Quad_Traktor_Pro_Map.zip", "435e7af3053634be1f8822224fa0ec7c63154a63992aba228b2675293bb7cdee"),
]
QUAD_REFERENCES = {"Numark Mixtrack Quad": {
    "url": QUAD_BASE + QUAD_SOURCES[0][0], "sha256": QUAD_SOURCES[0][1],
    "relatedSources": [{"url": QUAD_BASE + QUAD_SOURCES[1][0], "sha256": QUAD_SOURCES[1][1]},
        {"url": "https://www.numark.com/product/mixtrack-quad"}],
    "review": "Manufacturer-hosted MIXTRACKQUAD.xml defines VID15E4/PID004C, four wire deck channels1..4, normal jog CC37 with full600, touch77, separate Load75/76 and dedicated four-channel mixer CCs on global0. Native600-count scratch and wheel seek/nudge preserve that published scale. Factory Traktor DCDT confirms 7Fh/01h encoder format for jogs/browser; native signed decoding does not reuse centre64 siblings. XML inverted pitch/crossfader and raw64-centred EQ retain polarity/centre. Guide restores held transport Cue, independent PFL, normal held bend, shifted Key Lock and Halve/Shift-Double. Native fixed Scratch replaces software mode switching. Physical Shift identities persist across A/C and B/D. Only normal bank-key presses reset that side's contacts/pickup; source colour-selection and deletion latches remain inactive. Four distinct cue notes and manual-loop notes retain hardware page separation. Native Out-or-Exit follows the factory guide; reloop creation fallback, sampler, rolls, FX, full mode/feedback/reset and calibration remain open. Factory cue LED value5/off0 and loop value8/off0 replace generic127 RGB values. Published initialisation SysEx and explicit CC60-zero commands use valid three-byte CC packets rather than copying trailing zero padding from the source strings. Fixed Scratch lamps and bounded owned/mode/jog cleanup total61 lifecycle messages. Traktor guide page1 explicitly gives Mac Master1/2 Front and Monitor3/4 Back, also numbered on Windows; the shared split route is declared. Factory public class-compliance does not establish iPad physical acceptance. No gain knobs or automatic four-deck opt-in is inferred.",
}}


def quad_profiles():
    result = profile("Numark Mixtrack Quad", QUAD_REFERENCES["Numark Mixtrack Quad"]["url"])
    result["audioOutput"] = "masterAndHeadphones"
    result["scope"] = "Automatic four-target core with source600-count fixed touch scratch, held Cue/bend, side Shift/bank cleanup, mixer/EQ, direct Load, four cue pads, native manual-loop page, source-coloured feedback and documented split audio. Full modes/FX/reset, calibration and physical acceptance remain open."
    result["bankChanges"] = [{"channel": 0, "number": number, "onValue": 127, "decks": decks}
                             for number, decks in [(78, ["a", "c"]), (93, ["b", "d"])]]
    for index, deck in enumerate("abcd"):
        channel, side = index + 1, index % 2
        add(result, "shift", channel, 97 + side)
        result["inputs"][-1].update(shiftChannel=side, shiftInput=side)

        def button(action, number, shifted=None, feedback=False):
            add(result, action, channel, number, deck=deck, feedback=feedback)
            if shifted is not None:
                result["inputs"][-1].update(shifted=shifted, shiftChannel=side)

        for action, number in [("play", 66), ("cuePreview", 51), ("sync", 64), ("cue", 71), ("load", 75 + side)]:
            button(action, number, shifted=False if action == "sync" else None, feedback=action != "load")
        for action, number in [("pitchBendDown", 67), ("pitchBendUp", 68)]:
            button(action, number, shifted=False)
        button("keylock", 67, shifted=True)
        button("jogTouch", 77, shifted=False)
        add(result, "jog", channel, 37, "control", "twosComplement", deck)
        result["inputs"][-1].update(argument=600, shifted=False, shiftChannel=side)
        add(result, "tempo", channel, 13, "control", deck=deck)
        result["inputs"][-1]["inverted"] = True
        eq = [16, 21, 26, 31][index]
        for action, number in [("high", eq), ("mid", eq + 1), ("low", eq + 2), ("level", eq + 4)]:
            add(result, action, 0, number, "control", "absolute" if action == "level" else "centreDetent", deck)
        for slot in range(4):
            button(f"hotcue{slot + 1}", 109 + slot, shifted=False, feedback=True)
            result["outputs"][-1]["onValue"] = 5
        for action, number, shifted in [("loopIn", 83, False), ("loopOutOrExit", 84, False), ("reloop", 85, False),
                                        ("loopDown", 99, False), ("loopUp", 99, True)]:
            button(action, number, shifted=shifted)
        result["outputs"].append({"action": "loop" + ("A" if side == 0 else "B"), "targetDeck": deck,
                                  "kind": "note", "channel": channel, "number": 85,
                                  "onValue": 8, "offValue": 0, "offUsesNoteOn": True})
    for action, number in [("crossfader", 10), ("monitor", 11), ("cueMix", 12), ("master", 42)]:
        add(result, action, 0, number, "control")
        if action == "crossfader":
            result["inputs"][-1]["inverted"] = True
    add(result, "browse", 0, 36, "control", "twosComplement")
    add(result, "openGroup", 0, 82)
    result["startup"] = [[0xF0, 0, 1, 0x3F, 0x7F, 0x4C, 0x60, 0, 4, 4, 1, 7, 4, 0xF7]]
    result["startup"] += [[0xB0 + channel, 60, 0] for channel in range(1, 5)]
    result["startup"] += [[0x90 + channel, 72, 127] for channel in range(1, 5)]
    result["shutdown"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
    result["shutdown"] += [[0x90 + channel, number, 0] for channel in range(1, 5) for number in [72, 74]]
    result["shutdown"] += [[0xB0 + channel, number, 0] for channel in range(1, 5) for number in [60, 61]]
    return [result]
