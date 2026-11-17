"""iDJ Live II facts from pinned XML and its companion script."""
from curated import add, profile
from numark import UPSTREAM

IDJ2_SOURCES = [
    ("Numark iDJ Live II.midi.xml", "ff382e3e7b227ce8aa5639f0ec21df82de1ebed2d7dc6569a4fa8312b4624c34"),
    ("Numark-iDJ-Live-II-scripts.js", "2474aa5e02de51744cd9ccf7fbea53f9f5f6ce338479da16d0a8369bbb9c0166"),
]
IDJ2_REFERENCES = {"Numark iDJ Live II": {
    "url": UPSTREAM + IDJ2_SOURCES[0][0].replace(" ", "%20"), "sha256": IDJ2_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in IDJ2_SOURCES],
    "review": "Published dispatch separates Cue Set from Cue Goto, has held pitch buttons and requires physical touch for every jog tick. Native fixed scratching retains 640 counts per revolution. Touch uses the script's midpoint threshold, including low-velocity release. Startup retains the exact state-query SysEx and scratch indicator. Play/Sync feedback and shutdown follow script bytes. Scratch-mode toggle, skin-only library expansion, remaining feedback, routing and physical acceptance remain open. Original iDJ Live and iDJ Pro are separate identities.",
}}


def idj_live2_profiles():
    result = profile("Numark iDJ Live II", IDJ2_REFERENCES["Numark iDJ Live II"]["url"])
    result["scope"] = "Automatic two-deck core with touch-gated 640-count jogs, separate Cue Set/Goto, held pitch buttons, browsing and Load. Native fixed scratch mode. Remaining modes, feedback, audio routing and physical acceptance remain open."
    result["startup"] = [[0xF0, 0, 1, 0x3F, 0x7F, 0x2E, 0x60, 0, 1, 1, 0xF7], [0x90, 72, 127]]
    for deck, play, sync, load, touch, jog, level, low, high, goto, cue_set, up, down in [
        ("a", 74, 64, 75, 77, 25, 8, 20, 16, 59, 51, 67, 68),
        ("b", 76, 71, 52, 78, 24, 9, 21, 17, 66, 60, 69, 70),
    ]:
        for action, number in [("play", play), ("sync", sync), ("load", load), ("cueGoto", goto),
                               ("cueSet", cue_set), ("pitchBendUp", up), ("pitchBendDown", down)]:
            add(result, action, 0, number, deck=deck, feedback=action in {"play", "sync"})
        add(result, "jogTouch", 0, touch, encoding="touchGate", deck=deck)
        add(result, "jog", 0, jog, "control", "twosComplement", deck)
        result["inputs"][-1].update(argument=640, requiresTouch=True)
        for action, number in [("level", level), ("low", low), ("high", high)]:
            add(result, action, 0, number, "control", deck=deck)
        result["shutdown"].extend([[0x90, play, 0], [0x90, sync, 0]])
    add(result, "master", 0, 23, "control")
    add(result, "crossfader", 0, 10, "control")
    result["inputs"][-1]["inverted"] = True
    add(result, "browse", 0, 26, "control", "twosComplement")
    result["shutdown"].append([0x90, 72, 0])
    return [result]
