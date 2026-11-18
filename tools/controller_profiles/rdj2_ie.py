"""Digital Jockey 2 Interface Edition core from the pinned two-deck mapping."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

RDJ2_IE_GUIDE = "https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_digital_jockey_2_interface_edition"
RDJ2_IE_SOURCES = [
    ("Reloop-Digital-Jockey-2-IE.midi.xml", "aaf1eb35bccb967a9453cfdb36a6098c383f2cb0af11263add4c8794a33106a4"),
    ("Reloop-Digital-Jockey-2-IE.scripts.js", "69ee3a9c98af5e6081966f42c5464da201d576c436594712e8d4ced9a5b9e5f3"),
]
RDJ2_IE_REFERENCES = {"Reloop Digital Jockey 2 Interface Edition": {
    "url": UPSTREAM + RDJ2_IE_SOURCES[0][0], "sha256": RDJ2_IE_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name, "sha256": digest} for name, digest in RDJ2_IE_SOURCES]
        + [{"url": RDJ2_IE_GUIDE}],
    "review": "Pinned XML gives channel-zero two-deck addresses with asymmetric right FX/loop encoder numbers and separate pitch E0/E1. The source forces rate_dir=-1; native centred pitch applies inversion once. Source normal jog delta returns zero for raw0 and raw64, otherwise raw-64; the existing Denon jog codec matches exactly. Native fixed physical-touch scratch uses the author's measured/estimated148-count scale. Only source-listed hardware Shift addresses get release aliases; positive shifted eject/delete/roll/reloop-and-stop operations remain inactive. Native Auto Loop enables the current loop idempotently; Loop Active toggles it. Normal In/Out and shifted loop-size controls retain physical intent. Source gain/headGain knobs use native master/headphone level ranges. Native group navigation replaces desktop library focus/expansion commands. The author guide documents driver-free Interface Edition and master1/2/headphones3/4; Master Edition requires a desktop driver and is not an alias. Fixed Scratch indication and reviewed output/unused loop/kill/CUP/mode cleanup fit exactly64 lifecycle messages. Source latched jog/library modes, CUP release-to-play, EQ kill, full FX/feedback/reset, paused held search, gain/calibration and physical acceptance remain open. No C/D or Hot Cues are inferred.",
}}


def rdj2_ie_profiles():
    result = profile("Reloop Digital Jockey 2 Interface Edition", RDJ2_IE_REFERENCES["Reloop Digital Jockey 2 Interface Edition"]["url"])
    result["aliases"].append("DIGITALJOCKEY2")
    result["excludedAliases"] = ["Reloop Digital Jockey 2 Master Edition", "Digital Jockey 2 Master Edition", "Reloop Digital Jockey 2 Controller Edition"]
    result["audioOutput"] = "masterAndHeadphones"
    result["scope"] = "Automatic two-deck Interface Edition core with native held Cue/bend, source-scaled fixed touch scratch, centred pitch, loops, mixer/filter, direct Load and documented split audio. Latched jog/library modes, shifted destructive actions, CUP, EQ kill, full FX/feedback/reset and physical calibration remain open."
    for side, deck in enumerate("ab"):
        base = 0x3C * side
        for action, number in [("play", 0x19), ("cuePreview", 0x18), ("sync", 0x01),
                               ("keylock", 0x02), ("cue", 0x05), ("load", 0x13),
                               ("pitchBendDown", 0x03), ("pitchBendUp", 0x04),
                               ("loopIn", 0x0F), ("loopOut", 0x10), ("loopEnable", 0x11), ("loop", 0x12)]:
            add(result, action, 0, base + number, deck=deck,
                feedback=action in {"play", "cuePreview", "sync", "keylock", "cue", "loop"})
            if action not in {"keylock", "cue"}:
                release = deepcopy(result["inputs"][-1])
                release.update(number=base + number + 0x1E, releaseOnly=True)
                result["inputs"].append(release)
        add(result, "jogTouch", 0, base + 0x1D, encoding="fullVelocityGate", deck=deck)
        add(result, "jog", 0, base + 0x0B, "control", "denonJog", deck)
        result["inputs"][-1]["argument"] = 148
        add(result, "tempo", side, 0, "pitch", "centredPitch", deck)
        result["inputs"][-1]["inverted"] = True
        for action, number in [("gain", 2), ("high", 3), ("mid", 4), ("low", 5), ("level", 6)]:
            add(result, action, 0, base + number, "control", deck=deck)
        add(result, "filterKnob", 0, base + 0x21, "control", deck=deck)
        add(result, "filterToggle", 0, base + 0x32, deck=deck)
        add(result, "loopSize", 0, 0x28 if side == 0 else 0x63, "control", "binaryStep", deck)
    for action, number in [("master", 15), ("monitor", 16), ("cueMix", 17), ("crossfader", 18)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 0x13, "control", "binaryOffset")
    add(result, "browseGroups", 0, 0x31, "control", "binaryOffset")
    for number in [0x1E, 0x21, 0x22, 0x5D, 0x5E]:
        add(result, "openGroup", 0, number)
    numbers = {row["number"] for row in result["outputs"]}
    numbers.update(number + base for base in [0, 0x3C] for number in [0x0F, 0x10, 0x11, 0x14, 0x15, 0x16, 0x17, 0x1A, 0x1B, 0x1C])
    result["startup"] = [[0x90, number, 127 if number in {0x1B, 0x57} else 0] for number in sorted(numbers)]
    result["shutdown"] = [[0x90, number, 0] for number in sorted(numbers)]
    return [result]
