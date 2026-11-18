"""Digital Jockey 2 Controller Edition native wheel core from pinned MIDI facts."""
from curated import add, profile
from numark import UPSTREAM

RDJ2_CONTROLLER_SOURCES = [
    ("Reloop Digital Jockey 2 Controller Edition.midi.xml", "e76490f9f1d88f54fca76d66080d57207f8916178bbc3cc314ac2fde0807606c"),
    ("Reloop-Digital-Jockey2-Controller-scripts.js", "411d3b8482ed33d401d1aa051df9a8bb89ac56b7cd8c4d4810ddaf7c7865cd81"),
]
RDJ2_CONTROLLER_MANUAL = "https://www.reloop.com/media/catalog/product/pdf/2/2/2/222725_Reloop_IM.pdf"
RDJ2_CONTROLLER_REFERENCES = {"Reloop Digital Jockey 2 Controller": {
    "url": UPSTREAM + RDJ2_CONTROLLER_SOURCES[0][0].replace(" ", "%20"),
    "sha256": RDJ2_CONTROLLER_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in RDJ2_CONTROLLER_SOURCES]
        + [{"url": RDJ2_CONTROLLER_MANUAL}],
    "review": "Pinned Controller Edition XML supplies two-deck addresses, separate E0/E1 full pitch and no working touch handler. Factory manual B6 reserves touch sensitivity for Interface Edition. Native fixed wheel seek/nudge replaces latched desktop Search/Scratch timers; raw-minus-64 motion uses binaryOffset including negative raw0. Wheel resolution is not published and retains native default calibration. Source pitch formula is raw/8192-1; native full-range pitch uses 16383 endpoint normalisation and inverse Mixxx rate polarity, with pickup. Source Load has duplicate XML routes and an unguarded script; native one-press Load retains existing safety. Native Auto Loop enables the current loop length; source fixed-four-beat and ReloopExit become native loop enable/toggle. Only published loop-size CC10/69 values63/65 act. Native Play/Cue/PFL/Key/Loop feedback is steady; no Sync output is inferred. Thirty reviewed light addresses fit60 lifecycle messages, with fixed Search+Scratch lamps indicating wheel nudge. Source right flanger output conflicts with a loop-size CC number only by kind; live flanger/FX/reset are not implemented. No hardware touch, C/D, audio interface, shifted addresses or EQ kill is inferred. Shifted releases, full modes, CUP, FX/feedback/reset, wheel/pitch/gain calibration and physical acceptance remain open.",
}}


def rdj2_controller_profiles():
    result = profile("Reloop Digital Jockey 2 Controller", RDJ2_CONTROLLER_REFERENCES["Reloop Digital Jockey 2 Controller"]["url"])
    result["aliases"] += ["DIGITAL JOCKEY", "Reloop Digital Jockey 2 Controller Edition", "Digital Jockey 2 Controller Edition"]
    result["excludedAliases"] = ["Reloop Digital Jockey 2 Interface Edition", "Reloop Digital Jockey 2 Master Edition", "DIGITALJOCKEY2"]
    result["hardwareMode"] = "Native fixed wheel seek/nudge. Desktop jog modes and physical Shift layer remain inactive."
    result["scope"] = "Automatic Controller Edition two-deck core with native wheel seek/nudge, full pitch, held Cue/bend, direct Load, mixer and loops. Shift releases, Scratch, CUP, EQ kill, full FX/feedback/reset and calibration remain open."
    for side, deck in enumerate("ab"):
        base = side * 0x3C
        for action, number in [("play", 0x19), ("cuePreview", 0x18), ("sync", 1), ("keylock", 2),
                               ("cue", 5), ("load", 0x13), ("pitchBendDown", 3), ("pitchBendUp", 4),
                               ("loopIn", 0x0F), ("loopOut", 0x10), ("loopEnable", 0x11), ("loop", 0x12)]:
            add(result, action, 0, base + number, deck=deck,
                feedback=action in {"play", "cuePreview", "keylock", "cue", "loop"})
        add(result, "wheelJog", 0, base + 0x0B, "control", "binaryOffset", deck)
        add(result, "tempo", side, 0, "pitch", deck=deck)
        result["inputs"][-1]["inverted"] = True
        for action, number in [("gain", 2), ("high", 3), ("mid", 4), ("low", 5), ("level", 6)]:
            add(result, action, 0, base + number, "control", deck=deck)
        add(result, "loopSize", 0, 10 if side == 0 else 69, "control", "binaryStep", deck)
    for action, number in [("master", 15), ("monitor", 16), ("cueMix", 17), ("crossfader", 18)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 19, "control", "binaryStep")
    numbers = sorted({base + number for base in [0, 0x3C]
                      for number in [2, 5, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25, 26, 27, 28]})
    result["startup"] = [[0x90, number, 127 if number in {26, 27, 86, 87} else 0] for number in numbers]
    result["shutdown"] = [[0x90, number, 0] for number in numbers]
    return [result]
