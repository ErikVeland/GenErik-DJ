"""Original Inpulse 300 core with factory pairs and the pinned native loop layout."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

ORIGINAL300_GUIDE = "https://ts.hercules.com/download/sound/manuals/DJC_Inpulse300/DJControlInpulse300_MIDI_Commands_V_1_2.pdf"
ORIGINAL300_SOURCES = [
    ("Hercules_DJControl_Inpulse_300.midi.xml", "43c8c84c8832af0c26d038851be8280ffb8b9a9c7c0e8b1d9811b520333114c4"),
    ("Hercules-DJControl-Inpulse-300-script.js", "bada98bf9c806879113612c10422d96c582473f67502fc14b9bafedc12c28af4"),
]
ORIGINAL300_REFERENCES = {"Hercules DJControl Inpulse 300": {
    "url": ORIGINAL300_GUIDE, "sha256": "213e2aecc7cb39df99edb79f43f39519a58dfce9a9e44f54b6841d8cb79cb06c", "pages": [2, 3, 9, 10, 15, 21, 29, 30, 31, 32, 33, 34, 35, 36, 37, 43, 57, 58],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in ORIGINAL300_SOURCES],
    "review": "Factory wire formats supply paired crossfader/mixer/pitch and full signed normal/Shift jog magnitude. Pinned source supplies248-count scale, four-times Shift scratching, safe analogue query and the custom In-to-four-beat/Out-to-disable loop layout. Native loop disable is idempotent. Eight distinct Hot Cue input addresses retain native one-press behaviour and shifted-clear release aliases; other hardware pad pages remain inactive. Native fixed scratching ignores source Vinyl toggle, backspin inertia and Scratch2 callbacks. Physical Shift is source-local per deck, rearms paired pickup and preserves old contact/Cue releases. Shifted B contact follows the working source channel5, correcting the factory table's channel4 typo. The factory shifted PFL/Load A rows conflict with normal mode numbers; these disputed alternatives remain unmapped rather than inferring a byte layout. Shifted transport release aliases cover undisputed Cue/Play/Sync. Source-supported direct Load and source basic transport LEDs remain separate from native pad feedback. Master/headphone gain, PFL Master, beatmatch guide, FX, other pad modes, original manual/adjustable loops, complete feedback/cleanup, audio routing and physical calibration remain open. MK2 is a separate recipe.",
}}


def original300_profiles():
    result = profile("Hercules DJControl Inpulse 300", ORIGINAL300_GUIDE)
    result["excludedAliases"] = ["DJControl Inpulse 300 MK2", "Hercules DJControl Inpulse 300 MK2"]
    result["scope"] = "Automatic original Inpulse 300 core with paired mixer/pitch, full signed248/62-count fixed scratch, eight Hot Cues, source four-beat In/disable Out layout and physical Shift. Disputed Shift rows, manual loop adjustment, other modes, full feedback/routing and physical acceptance remain open."
    for side, deck in enumerate("ab"):
        channel, shifted, pads = 1 + side, 4 + side, 6 + side
        add(result, "shift", channel, 4)
        result["inputs"][-1].update(shiftChannel=channel, shiftInput=side)
        for action, number in [("play", 7), ("cuePreview", 6), ("sync", 5), ("cue", 12), ("load", 13)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "cuePreview", "sync", "cue"})
            result["inputs"][-1].update(shifted=False, shiftChannel=channel)
            if action in {"play", "cuePreview", "sync"}:
                release = deepcopy(result["inputs"][-1])
                release.update(channel=shifted, shifted=True, releaseOnly=True)
                result["inputs"].append(release)
        for ch, is_shifted in [(channel, False), (shifted, True)]:
            add(result, "jogTouch", ch, 8, deck=deck)
            result["inputs"][-1].update(shifted=is_shifted, shiftChannel=channel)
            for action, number in [("level", 0), ("filterKnob", 1), ("low", 2), ("mid", 3), ("high", 4), ("gain", 5), ("tempo", 8)]:
                add(result, action, ch, number, "control", "paired14Bit", deck)
                result["inputs"][-1].update(shifted=is_shifted, shiftChannel=channel)
                if action == "tempo":
                    result["inputs"][-1]["inverted"] = True
            for action, number in [("jog", 10), ("wheelJog", 9)]:
                add(result, action, ch, number, "control", "twosComplement", deck)
                result["inputs"][-1].update(argument=62 if is_shifted else 248, shifted=is_shifted, shiftChannel=channel)
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", pads, slot, deck=deck)
            release = deepcopy(result["inputs"][-1])
            release.update(number=slot + 8, releaseOnly=True)
            result["inputs"].append(release)
        for action, ch, number in [("fixedLoop", channel, 9), ("loopDisable", channel, 10), ("loopDown", shifted, 9), ("loopUp", shifted, 10)]:
            add(result, action, ch, number, deck=deck)
            result["inputs"][-1].update(shifted=ch == shifted, shiftChannel=channel)
            if action == "fixedLoop":
                result["inputs"][-1]["argument"] = 4
        result["startup"].append([0x90 + channel, 3, 127])
        result["shutdown"].append([0x90 + channel, 3, 0])
    add(result, "crossfader", 0, 0, "control", "paired14Bit")
    add(result, "browse", 0, 1, "control", "twosComplement")
    add(result, "browseGroups", 3, 1, "control", "twosComplement")
    add(result, "openGroup", 0, 0)
    result["startup"] += [[0x90, 4, 5], [0xB0, 127, 127]]
    result["shutdown"] += [[0x90, 4, 0]] + [[0x90 + r["channel"], r["number"], 0] for r in result["outputs"]]
    return [result]
