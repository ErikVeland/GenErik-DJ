"""Tweaker fixed A/B core with source-programmed absolute EQ encoders."""
from curated import add, profile
from numark import UPSTREAM

TWEAKER_GUIDE = "https://manual.mixxx.org/2.5/en/hardware/controllers/electrix_tweaker"
TWEAKER_SOURCES = [
    ("Electrix Tweaker.midi.xml", "fba75aac5f2870b235c0103f2188749b41ddaa7384256201a143b41e5f0cc04f"),
    ("Electrix-Tweaker-scripts.js", "40fb3b9f73c83810c02714c03008dc5c1493b39a34fe83ab4991504ab95de667"),
]
TWEAKER_REFERENCES = {"Electrix Tweaker": {
    "url": UPSTREAM + TWEAKER_SOURCES[0][0].replace(" ", "%20"), "sha256": TWEAKER_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in TWEAKER_SOURCES]
        + [{"url": TWEAKER_GUIDE}],
    "review": "Class-compliant USB MIDI1 is distinct from DIN MIDI2. Pinned XML/script define fixed physical A/B addresses and software deck/EQ/loop/cue-page states. Native core fixes A/B, EQ and first eight-cue page. Program EQ CC57..62 via channel15 value118 (70+8*source sensitivity6) and local rings79..84 value70. Commented default-reset/query SysEx is not sent. Composite Shift groups0/1 combine Top with that side, group2 is pure Top, groups3/4 pure deck Shift. Physical Shift identities prevent one release clearing another. Normal Play needs composite Shift off; held Cue needs pure deck Shift on, retaining source deck-Shift priority over Top. Native release returns to Cue, rather than copying source continue-playing-on-Shift-release. EQ and cues block both modifiers; Load blocks only Top, and PFL/Sync/Keylock follow deck Shift. Source shifted PFL exits loops; shifted Sync resets tempo; shifted Slip/Deck keys set loop In/Out. Native fixed4-beat and shifted1-beat jumps use app grid timing. Source Quantize-off wind/bend, software banks, Slip, extra cue pages, encoder modes/kills, sampler/DVS, Top controls and full light states remain open. Browser uses strict1/127 steps. EQ feedback CCs restore native normalised positions. Playing lights use steady green only; loaded red/Cue yellow and other animations remain open. Source fader/EQ nonlinear curves are not asserted as native calibration. Startup25 and shutdown37 total62 packets. Shutdown restores EQ positions to64 and clears owned indicators only. No built-in sound card or automatic audio route is inferred. No downloaded script runs in the app.",
}}


def tweaker_profiles():
    result = profile("Electrix Tweaker", TWEAKER_REFERENCES["Electrix Tweaker"]["url"])
    result["portAliases"] = ["Tweaker MIDI 1"]
    result["hardwareMode"] = "Factory MIDI assignments on Tweaker MIDI1. Native fixed A/B, EQ and first cue page; software bank/mode keys remain inactive."
    result["scope"] = "Automatic fixed A/B core with programmed absolute EQ/rings, composite Shift, held Cue, native transport/filter/levels, eight cues, beat jumps and manual loop boundaries. Software banks, full modes/feedback, external audio and physical acceptance remain open."
    result["gaps"] = ["Fixed A/B, EQ and eight cues only. Software deck/encoder/cue banks, Slip, Quantize-off wind/bend, sampler/DVS, EQ kills, other Top controls, source fader/EQ curves, loaded/Cue light states, full lifecycle and physical acceptance remain open. Native Cue release returns to its saved point; source continue-playing-on-Shift-release is not implemented. A separate audio interface is required."]
    for number, identity, groups in [(19, 0, [0, 3]), (23, 1, [1, 4]), (40, 2, [0, 1, 2])]:
        for group in groups:
            add(result, "shift", 0, number)
            result["inputs"][-1].update(shiftInput=identity, shiftChannel=group)
    for side, deck in enumerate("ab"):
        composite, local = side, side + 3

        def button(action, number, group, shifted=False, feedback=False, colour=127, argument=None):
            add(result, action, 0, number, deck=deck, feedback=feedback)
            result["inputs"][-1].update(shiftChannel=group, shifted=shifted)
            if argument is not None:
                result["inputs"][-1]["argument"] = argument
            if feedback:
                result["outputs"][-1]["onValue"] = colour

        play, pfl, sync, key = [(35, 34, 28, 27), (38, 37, 32, 31)][side]
        button("play", play, composite, feedback=True, colour=1)
        button("cuePreview", play, local, shifted=True)
        button("cue", pfl, local, feedback=True, colour=1)
        button("loopDisable", pfl, local, shifted=True)
        button("sync", sync, local, feedback=True, colour=16)
        button("tempoReset", sync, local, shifted=True)
        button("keylock", key, local, feedback=True, colour=16)
        button("load", 42 + side, 2)
        for action, number in [("level", 53 + side), ("filterKnob", 51 + side)]:
            add(result, action, 0, number, "control", "absolute" if action == "level" else "centreDetent", deck)
        for index, action in enumerate(["high", "mid", "low"]):
            add(result, action, 0, 57 + side * 3 + index, "control", "centreDetent", deck, feedback=True)
            result["inputs"][-1].update(shiftChannel=composite, shifted=False)
        for slot, number in enumerate(([1, 2, 3, 4, 9, 10, 11, 12], [5, 6, 7, 8, 13, 14, 15, 16])[side], 1):
            button(f"hotcue{slot}", number, composite, feedback=True, colour=32)
        forward, back = [(17, 25), (21, 29)][side]
        for direction, number in [(1, forward), (-1, back)]:
            button("fixedJump", number, local, argument=direction * 4)
            button("fixedJump", number, local, shifted=True, argument=direction)
        button("loopIn", 18 + side * 4, local, shifted=True)
        button("loopOut", 20 + side * 4, local, shifted=True)
    add(result, "crossfader", 0, 55, "control")
    add(result, "browse", 0, 56, "control", "signedStep")
    result["inputs"][-1].update(shiftChannel=2, shifted=False)
    for action, number in [("browsePreviousGroup", 39), ("browseNextGroup", 41)]:
        add(result, action, 0, number)
        result["inputs"][-1].update(shiftChannel=2, shifted=False)
        add(result, "openGroup", 0, number)
        result["inputs"][-1].update(shiftChannel=2, shifted=True)
    indicators = [(33, 127), (36, 127), (20, 16), (24, 16), (19, 8), (23, 8), (40, 127)]
    result["startup"] = [[0xBF, number, 118] for number in range(57, 63)]
    result["startup"] += [[0xBF, number, 70] for number in range(79, 85)]
    result["startup"] += [[0x90, number, 0] for number in range(45, 51)]
    result["startup"] += [[0x90, number, value] for number, value in indicators]
    result["shutdown"] = [[0xB0 if row["kind"] == "control" else 0x90, row["number"],
                           64 if row["kind"] == "control" else 0] for row in result["outputs"]]
    result["shutdown"] += [[0x90, number, 0] for number, _ in indicators]
    return [result]
