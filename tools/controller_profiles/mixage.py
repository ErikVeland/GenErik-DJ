"""Mixage family core from the pinned model list, layout and measured jog scale."""
from copy import deepcopy
from curated import add, profile
from numark import UPSTREAM

MIXAGE_SOURCES = [
    ("Reloop-Mixage.midi.xml", "0d164d8bb64df6b9a0593b2b0110b5a5182591c1f47abe187cd2e4dd9fd114cc"),
    ("Reloop-Mixage.scripts.js", "131e6b630cd6e3cdc79dff4dd3380accc11bb4c4cc6e478d01674356c2b62f44"),
]
MIXAGE_MODELS = ["Reloop Mixage Interface Edition", "Reloop Mixage Interface Edition MK2", "Reloop Mixage Controller Edition"]
MIXAGE_REFERENCES = {"Reloop Mixage": {
    "url": UPSTREAM + MIXAGE_SOURCES[0][0], "sha256": MIXAGE_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name, "sha256": digest} for name, digest in MIXAGE_SOURCES[1:]],
    "review": "Pinned XML explicitly supports Interface Edition MK1, Interface Edition MK2 and Controller Edition. Native default hardware channel1 layout preserves normal/Shift addresses, separate per-side physical Shift, full pitch messages, duplicated gain/EQ/level addresses and measured620-count fixed touch scratch. Shift Cue/Play/Sync/PFL/Load and bend releases rearm or release existing base controls without invoking source alternatives. Four shifted cue keys retain explicit addresses and native one-press semantics. Loop Enable is idempotent; Reloop, shifted In/Out and sign-only loop-size rotation use native actions. Shift Filter keeps pickup and source label. Native browsing uses track/group encoder addresses and immediate Open Group, without source multi-click delays. Startup/shutdown clear only the26known LED/meter addresses rather than the source's invalid0..254note loop; fixed scratch indicators are armed. Full meter values, CUP, scroll/scratch toggles, source brake/soft-start, loop adjustment/removal, FX, held cue semantics, browser hierarchy/preview, alternate hardware channel2, family-specific audio routing and physical acceptance stay open. The Controller Edition has no inferred audio route.",
}}


def mixage_profiles():
    result = profile("Reloop Mixage", MIXAGE_REFERENCES["Reloop Mixage"]["url"])
    result["aliases"] += MIXAGE_MODELS + [name.replace("Reloop ", "") for name in MIXAGE_MODELS]
    result.update(hardwareMode="Hardware MIDI channel1. Alternate hardware channel2 is not implemented.", scope="Automatic Mixage family default-channel core with620-count fixed touch scratch, full pitch, per-side Shift, native cues/loops/filter and bounded LED cleanup. Alternate modes/channel, complete feedback/routing, calibration and physical acceptance remain open.")
    for side, deck in enumerate("ab"):
        base = side * 14
        add(result, "shift", 0, 42 + side)
        result["inputs"][-1].update(shiftChannel=side, shiftInput=side)

        def button(action, number, alternate=None, shifted=False):
            add(result, action, 0, number, deck=deck)
            result["inputs"][-1].update(shifted=shifted, shiftChannel=side)
            if alternate is not None:
                release = deepcopy(result["inputs"][-1])
                release.update(number=alternate, shifted=not shifted, releaseOnly=True)
                result["inputs"].append(release)

        for action, number in [("play", 12), ("cuePreview", 11), ("sync", 9), ("cue", 14), ("load", 13),
                               ("pitchBendDown", 1), ("pitchBendUp", 2)]:
            button(action, base + number, base + number + 63)
        button("loopEnable", base + 5, base + 68)
        button("reloop", base + 6, base + 69)
        button("loopIn", base + 68, base + 5, shifted=True)
        button("loopOut", base + 69, base + 6, shifted=True)
        button("keylock", base + 71, base + 8, shifted=True)
        for slot in range(4):
            button(f"hotcue{slot + 1}", base + 72 + slot, base + 9 + slot, shifted=True)
        for number in [36 + side, 99 + side]:
            add(result, "jogTouch", 0, number, encoding="fullVelocityGate", deck=deck)
            add(result, "jog", 0, number, "control", "binaryOffset", deck)
            result["inputs"][-1]["argument"] = 620
        for channel in [side, side + 2]:
            add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
            result["inputs"][-1]["inverted"] = True
        for action, number in [("gain", 51), ("high", 53), ("mid", 54), ("low", 55), ("level", 56)]:
            for alternate in [0, 63]:
                add(result, action, 0, number + side * 6 + alternate, "control", deck=deck)
        add(result, "loopSize", 0, 32 + side * 2, "control", "binaryDirection", deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=side)
        add(result, "filterKnob", 0, 115 + side * 6, "control", deck=deck)
        result["inputs"][-1].update(shifted=True, shiftChannel=side)
        for action, number in [("play", 12), ("cuePreview", 11), ("sync", 9), ("cue", 14), ("loop", 5), ("loop", 6)]:
            result["outputs"].append({"action": action + deck.upper(), "targetDeck": deck, "kind": "note", "channel": 0,
                                      "number": number + base, "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
    add(result, "crossfader", 0, 49, "control")
    add(result, "cueMix", 0, 50, "control")
    add(result, "browse", 0, 31, "control", "binaryOffset")
    add(result, "browseGroups", 0, 94, "control", "binaryOffset")
    add(result, "openGroup", 0, 31)
    add(result, "openGroup", 0, 94)
    led_notes = list(range(3, 15)) + list(range(17, 31))
    result["startup"] = [[0x90, number, 0] for number in led_notes] + [[0x90, 4, 127], [0x90, 18, 127]]
    result["shutdown"] = [[0x90, number, 0] for number in led_notes]
    return [result]
