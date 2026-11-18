"""Radius 2000 player core from its factory chart and pinned native-control source."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

RADIUS_SOURCES = [
    ("American Audio RADIUS 2000 CH1.midi.xml", "d9ad4e954b96723daeb9add18222b54dad0d66a5872f34f62d197c01aed9c079"),
    ("American Audio RADIUS 2000 CH2.midi.xml", "817c72207fbc863251f26bbda46915a90701081432879b5eaca8bb8ffdb03fec"),
    ("American-Audio-RADIUS-2000-scripts.js", "e316793c0c91378ff31d87a60ba495fb38b7f25d2c04dd9ddfc27deceee367e9"),
]
RADIUS_REFERENCES = {"American Audio Radius 2000 CH1": {
    "url": "https://www.adj.eu/mwdownloads/download/link/id/49",
    "sha256": "5568fd27da6157d2e546e785768887374bd23897f509de937bf9268f1cfe68ef", "pages": [20, 35, 36],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in RADIUS_SOURCES],
    "review": "Factory default is MIDI channel1, relative CC encoders and pitch-bend pitch. CH1/CH2 source variants use the same wire channel; native player assignment replaces their hard-coded deck groups. Normal chart and TAP alternative addresses provide release aliases without invoking alternate presses. Source raw-minus64 wheel decoding uses binaryOffset. Fixed native physical-touch scratch preserves the source100-count/330RPM time response through effective990 native counts; factory sensor1024/512 pulse settings do not prove that response and require calibration. Native Play acts on press rather than the source's release. The chart's Track encoder press is direct Load; source USB Source Select Load alias is omitted. Folder press enters a native group. Source BPM button remains native Sync, and source sample-loop button enables a four-beat native loop. Normal In/Out/Reloop and Halve/Double retain published addresses. Seven steady states use factory primary light addresses, with all31 primary SW/LED addresses cleared and fixed Scratch/Pitch indication. Secondary cue lights, rings, display, full FX/modes/feedback/reset, source nudge sensitivity, other hardware channel/encoder settings, audio routing and physical acceptance remain open.",
}}


def radius_profiles():
    result = profile("American Audio Radius 2000 CH1", RADIUS_REFERENCES["American Audio Radius 2000 CH1"]["url"])
    result["aliases"] += ["American Audio Radius 2000", "Radius 2000", "Radius 2000 MIDI 1", "American Audio Radius 2000 CH2"]
    result["excludedAliases"] = ["Radius 1000", "American Audio Radius 1000", "Radius 3000", "American Audio Radius 3000"]
    result["role"] = "player"
    result["gaps"] = ["Rings, displays, secondary cue lights, full feedback/modes/reset, other hardware channel settings, scratch/nudge calibration and audio routing remain open."]
    result["hardwareMode"] = "MIDI mode; factory channel1, relative CC and pitch-bend pitch. Fixed native Scratch."
    result["scope"] = "Automatic default-channel player core with separate native deck assignment, fixed physical-touch scratch, full pitch, held Cue/bend, four cues, loops, browse/Load and seven steady lights. Other settings, full feedback/modes, calibration and audio remain open."
    for action, number in [("play", 0x2A), ("cuePreview", 0x30), ("keylock", 6), ("sync", 0x12),
                           ("load", 0x1F), ("pitchBendDown", 7), ("pitchBendUp", 0x0D),
                           ("loopIn", 0x0B), ("loopOut", 5), ("reloop", 0x17),
                           ("loopDown", 0x0E), ("loopUp", 8), ("fixedLoop", 2),
                           ("jogTouch", 0x26)]:
        add(result, action, 0, number, encoding="fullVelocityGate" if action == "jogTouch" else "absolute", deck="a",
            feedback=action in {"play", "cuePreview", "keylock"})
        if action == "fixedLoop":
            result["inputs"][-1]["argument"] = 4
        release = deepcopy(result["inputs"][-1])
        release.update(number=number + 0x3F, releaseOnly=True)
        result["inputs"].append(release)
    for slot, number in enumerate([0x16, 0x10, 0x0A, 0x22], 1):
        add(result, f"hotcue{slot}", 0, number, deck="a", feedback=True)
        release = deepcopy(result["inputs"][-1])
        release.update(number=number + 0x3F, releaseOnly=True)
        result["inputs"].append(release)
    add(result, "jog", 0, 0x35, "control", "binaryOffset", "a")
    result["inputs"][-1]["argument"] = 990
    add(result, "tempo", 0, 0, "pitch", deck="a")
    result["inputs"][-1]["inverted"] = True
    add(result, "browse", 0, 0x38, "control", "binaryStep")
    add(result, "browseGroups", 0, 0x36, "control", "binaryStep")
    add(result, "openGroup", 0, 0x19)
    numbers = [0x19, 0x1F, 0x0B, 5, 0x30, 0x2A, 0x2F, 0x1B, 0x15, 0x0F, 9, 0x21, 0x27, 0x2D,
               3, 4, 2, 0x1C, 1, 6, 0x0C, 0x2E, 0x28, 0x24, 0x1E, 0x18, 0x13, 0x16, 0x10, 0x0A, 0x22]
    result["startup"] = [[0x90, number, 127 if number in {1, 0x1E} else 0] for number in numbers]
    result["shutdown"] = [[0x90, number, 0] for number in numbers]
    return [result]
