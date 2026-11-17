"""N4 native core facts from the pinned XML and script."""
from curated import add, profile
from numark import UPSTREAM

N4_SOURCES = [
    ("Numark N4.midi.xml", "a09cdf0b03f2f35227b0a2890b0ab4890a92d9c1932ba0510dc3209d8300b583"),
    ("Numark-N4-scripts.js", "996aa0b3e06af496a7322e26fe6cd864d0ab85276f5754832c0c3dd7f8169d8a"),
]
N4_REFERENCES = {"Numark N4": {
    "url": UPSTREAM + N4_SOURCES[1][0], "sha256": N4_SOURCES[1][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in N4_SOURCES],
    "review": "Actual XML dispatch establishes jog CC32 despite the constructor's CC44. Script facts establish 600-count two's-complement jogs, paired CC1/33 tempo and source inversion. Native pitch accounts for Mixxx rate_dir once. Mixer CC pairs retain XML dispatch and deck targets. Raw Control Change bank reports reset contacts and pickup on their side for either selector state. PFL notes report latched state, including zero. Native momentary physical-side Shift replaces software power-window latches. Stable Shift identities survive bank changes and also guard the shared browser. The four upper buttons use the published custom native loop layout. Four lower buttons provide the initial Hot Cue page. Hardware PFL lights are not echoed. Author-specific EQ calibration, extra cue pages, remaining modes, FX, full cleanup, routing and physical calibration remain open.",
}}


def n4_profiles():
    result = profile("Numark N4", N4_REFERENCES["Numark N4"]["url"])
    result["aliases"].append("N4 MIDI 1")
    result["scope"] = "Automatic four-target native core with momentary Shift and the published loop-button layout. Other cue pages, modes, FX, full feedback, cleanup, routing and calibration remain open."
    result["startup"] = [[0xB0 + channel, 18, 127] for channel in range(1, 5)] + [
        [0xF0, 0, 1, 63, 127, 71, 96, 0, 1, 84, 1, 0, 0, 0, 0, 0xF7]]
    result["shutdown"] = [[0xB0 + channel, 18, 0] for channel in range(1, 5)]
    result["bankChanges"] = [
        {"kind": "control", "channel": 0, "number": 80 + side,
         "decks": ["a", "c"] if side == 0 else ["b", "d"]} for side in range(2)]
    for index, deck in enumerate("abcd"):
        channel, side = index + 1, index % 2 + 1
        for scoped in [False, True]:
            add(result, "shift", channel, 18)
            result["inputs"][-1]["shiftInput"] = side
            if scoped:
                result["inputs"][-1]["shiftChannel"] = side
        for action, number in [("play", 17), ("cuePreview", 16), ("sync", 15), ("jogTouch", 44), ("keylock", 27),
                               ("load", 6), ("loopIn", 19), ("loopOut", 20), ("loopEnable", 21), ("reloop", 22)]:
            add(result, action, channel, number, deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
        add(result, "jog", channel, 32, "control", "twosComplement", deck)
        result["inputs"][-1].update(argument=600, shifted=False, shiftChannel=side)
        add(result, "tempo", channel, 1, "control", "paired14Bit", deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=side)
        for action, number in [("level", 8), ("low", 9), ("mid", 10), ("high", 11), ("gain", 12)]:
            add(result, action, 0, number + [0, 5, 11, 16][index], "control", "paired14Bit", deck)
            if action == "gain":
                result["inputs"][-1].update(shifted=False, shiftChannel=side)
        add(result, "cueState", 0, 49 + index, deck=deck)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", channel, 39 + slot, deck=deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=side)
        for action, number in [("play", 9), ("sync", 7), ("keylock", 16), ("loop", 13), ("loop", 14)] + [
                (f"hotcue{slot + 1}", 24 + slot) for slot in range(4)]:
            result["outputs"].append({"action": action + ("A" if deck in "ac" else "B"), "kind": "control",
                                      "channel": channel, "number": number, "onValue": 127, "offValue": 0,
                                      "offUsesNoteOn": True, "targetDeck": deck})
    add(result, "crossfader", 0, 7, "control", "paired14Bit")
    add(result, "browse", 0, 68, "control", "signedStep")
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 0, 8)
    result["inputs"][-1]["shifted"] = False
    return [result]
