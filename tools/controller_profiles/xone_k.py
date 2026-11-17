"""Factory-layout Xone K1/K2/K3 core from shared published dispatch."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

XONE_SOURCES = [
    ("Allen and Heath Xone K2.midi.xml", "76973fcf90ec72922de052f5a2813281f8cfb16f2358302d67b2b249e0c5ff79"),
    ("Allen-and-Heath-Xone-K2-scripts.js", "edce0138d4782e4c2d9ca28bac478697041288031f2d1ca5759cb92238b646f9"),
]
XONE_K1_GUIDE = "https://www.allen-heath.com/content/uploads/2023/07/XoneK1_UG_AP9694_2.pdf"
XONE_K2_GUIDE = "https://allen-heath.com/content/uploads/2023/06/XoneK2_UG_AP8509_3.pdf"
XONE_K3_GUIDE = "https://support.allen-heath.com/hc/en-gb/articles/39744774067985-Xone-K3-User-Guide"
XONE_NAME = "Allen & Heath Xone:K1/K2/K3"
XONE_REFERENCES = {XONE_NAME: {
    "url": XONE_K1_GUIDE, "sha256": "9f8a46ba9f88c850b6a7873d594d85c1f0a5b838d64ca3e86770530e13d3434c", "pages": [8, 12, 13, 14],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in XONE_SOURCES] + [
        {"url": XONE_K2_GUIDE, "sha256": "de0621425801bdb47eea6deee8efa1bfd883244fe9dcc6b53c7be532975daf74", "pages": [11, 12, 14, 15, 17, 18]},
        {"url": XONE_K3_GUIDE, "review": "Factory map is pre-installed and matches K2/K1 MIDI values and colours. Global MIDI channel defaults to 15."},
        {"url": "https://manual.mixxx.org/2.5/en_gb/hardware/controllers/allen_heath_xone_k2_k1", "review": "K2 latching layers must be off. K3 requires firmware v1.0.4 r 93846 or later for the shared mapping."},
    ],
    "review": "Factory default MIDI channel 15 and the source's two middle deck columns establish this core. Native fixed four-cue pads replace the source's application-side intro/outro/loop pages. The right large button is Shift; hold the lower-right encoder and press a deck's Play button to Load. Combined modifier scope blocks ordinary Play during either modifier, while an independent scope permits direct Load. Source Note Off velocity 127 is retained for red Play/PFL/Sync/cue feedback and cleanup. Native Shift is momentary; the source's persistent low-EQ/quick-effect latch is not copied. Other channel layouts, user maps, hardware latching layers, X-Link qualification, outer FX columns, full modes/feedback, audio routing and physical acceptance remain open.",
}}


def xone_k_profiles():
    result = profile(XONE_NAME, XONE_K1_GUIDE)
    result["catalogueName"] = "Allen&Heath Xone K1/K2/K3"
    result["aliases"] = [XONE_NAME] + [name for model in [1, 2, 3] for name in [f"Allen & Heath Xone:K{model}", f"Allen and Heath Xone K{model}", f"XONE:K{model}"]]
    result.update(role="accessory", scope="Automatic factory-channel-15 two-deck core for K1/K2/K3 factory maps. Native fixed Hot Cue page; right large button is Shift. Hold the lower-right encoder and press Play to Load. K2/K3 hardware latching layers must be off; K3 shared firmware must be compatible. Other layouts, FX, full modes/feedback, routing and physical acceptance remain open.")
    channel = 14
    for number, scope, key in [(15, 0, 0), (15, 2, 0), (14, 1, 1), (14, 2, 1)]:
        add(result, "shift", channel, number)
        result["inputs"][-1].update(shiftChannel=scope, shiftInput=key)

    def guarded(action, number, deck, scope=0, shifted=False, momentary=False, feedback=False):
        add(result, action, channel, number, deck=deck, feedback=feedback)
        result["inputs"][-1].update(shiftChannel=scope, shifted=shifted)
        if not momentary:
            release = deepcopy(result["inputs"][-1])
            release.update(shifted=not shifted, releaseOnly=True)
            result["inputs"].append(release)

    for offset, deck in [(1, "a"), (2, "b")]:
        guarded("play", 40 + offset, deck, scope=2, feedback=True)
        guarded("load", 40 + offset, deck, scope=1, shifted=True)
        guarded("cuePreview", 44 + offset, deck, momentary=True)
        guarded("cue", 48 + offset, deck, feedback=True)
        guarded("sync", 52 + offset, deck, feedback=True)
        for action, shifted in [("wheelJog", False), ("gain", True)]:
            add(result, action, channel, offset, "control", "signedStep", deck)
            result["inputs"][-1].update(shiftChannel=0, shifted=shifted)
        for action, number in [("high", 4 + offset), ("mid", 8 + offset), ("low", 12 + offset), ("level", 16 + offset)]:
            add(result, action, channel, number, "control", deck=deck)
            if action == "low":
                result["inputs"][-1].update(shiftChannel=0, shifted=False)
        for slot in range(4):
            guarded(f"hotcue{slot + 1}", 36 - slot * 4 + offset, deck, feedback=True)
    for action, number, shifted in [("browse", 21, False), ("master", 21, True), ("monitor", 20, True)]:
        add(result, action, channel, number, "control", "signedStep")
        result["inputs"][-1].update(shiftChannel=0, shifted=shifted)
    for output in result["outputs"]:
        output.update(offValue=127, offUsesNoteOn=False)
    result["startup"] = [[0x9E, 12, 127]]
    result["shutdown"] = [[0x8E, output["number"], 127] for output in result["outputs"]] + [[0x8E, 12, 127]]
    return [result]
