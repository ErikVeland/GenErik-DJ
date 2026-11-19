"""Buddy normal manual controls from the author's public djay mapping."""
from curated import add, profile

BUDDY_SOURCE = "https://community.algoriddim.com/uploads/short-url/5FGS5zbolFu2YI0qzC2hVKsZP3K.djayMidiMa"
BUDDY_DISCUSSION = "https://community.algoriddim.com/t/midi-mapping-for-reloop-buddy/15528"
BUDDY_SHA = "d25b406cf6e0c63cf88dbeecbbd31df45b370971abf87d930f21087fb5bb3836"
BUDDY_CONFLICT = "https://raw.githubusercontent.com/suitux/Backspn/e0e7048e970af5d623e63a3557b1545369ce2a08/crates/control/profiles/reloop/buddy.json"
BUDDY_AUDIT = {
    "source": {"url": BUDDY_SOURCE, "sha256": BUDDY_SHA}, "discussion": BUDDY_DISCUSSION,
    "format": "Apple property list", "mappingVersion": 2, "inputRows": 331,
    "declaredCustomClass": "ReloopBuddy", "automaticSupportAdded": False,
    "relatedSources": [{"url": BUDDY_CONFLICT, "sha256": "b332b2a9bdaf6ffe1aa2dffeeaf65a15ea8da8a04eb92997a40b5fd3eefd7a8e"}],
    "gaps": ["Author mapping changes EQ, shifted gain and some cues. Missing ReloopBuddy class leaves shared pad/EQ state, jog/pitch dispatch, cold-start setup and lifecycle unqualified. Backspn's Buddy profile conflicts on Play/Cue and pitch pairing and is not imported. Only unconditional normal controls enter the manual recipe."],
}
BUDDY_REFERENCES = {"Reloop Buddy": {
    "url": BUDDY_SOURCE, "sha256": BUDDY_SHA,
    "relatedSources": [{"url": BUDDY_DISCUSSION}, {"url": "https://www.reloop.com/reloop-buddy"}] + BUDDY_AUDIT["relatedSources"],
    "review": "Maurizio T's hardware-owned custom map, shared31January2022, declares ReloopBuddy and331 control rows. Only unconditional normal Play0, held Cue1, Sync2, PFL27, levelCC28, global Load2/3, crossfaderCC8, cue-mixCC13 and flipped rotary64 browseCC0 enter the native manual recipe. Per-deck channels0/1 and global14 stay distinct. Alternate Play16/Cue5/Sync3 addresses are release-only so modifier transitions cannot leave normal transport held or trigger unsupported shifted presses. No EQ/gain/filter is inferred from the author's changed assignments and shared Neural Mix modes. Source PFL/Sync lights have only minima and other outputs omit explicit ranges; no light value is guessed. Ten-bit pitch includes absent class-specific offset handling; jog and loop encodings remain unqualified. Shared pads, modes, FX, master/headphone hardware knobs, source/back browsing, cold-start, complete lifecycle and audio routing remain open. Backspn's pinned Buddy profile disagrees with this primary source and does not supply an alternative qualified protocol. Automatic selection stays off. Manual input requires separate enabling; no lifecycle packet runs and no downloaded code executes in the app.",
}}


def buddy_profiles():
    result = profile("Reloop Buddy", BUDDY_SOURCE)
    result["autoSelect"] = False
    result["hardwareMode"] = "Manual reviewed normal-control subset. Enable input separately; missing custom-class setup and mode ownership remain open."
    result["scope"] = "Manual normal transport, held Cue, direct Load, channel levels, crossfader, cue mix and inverted rotary64 browsing. Jog/pitch, shared EQ/pads, lights, setup, audio routing and physical acceptance remain open."
    result["gaps"] = BUDDY_AUDIT["gaps"] + ["Jog/pitch, shared EQ/pad modes, shifted presses, loop/FX, full browsing, light ranges, startup/shutdown and audio routing remain unqualified. Master/headphone knobs are not mapped. No Ready alias is inferred. Physical acceptance remains open."]
    for channel, deck in enumerate("ab"):
        for action, number, alternate in [("play", 0, 16), ("cuePreview", 1, 5), ("sync", 2, 3)]:
            add(result, action, channel, number, deck=deck)
            add(result, action, channel, alternate, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        add(result, "cue", channel, 27, deck=deck)
        add(result, "level", channel, 28, "control", deck=deck)
        add(result, "load", 14, channel + 2, deck=deck)
    add(result, "crossfader", 14, 8, "control")
    add(result, "cueMix", 14, 13, "control")
    add(result, "browse", 14, 0, "control", "binaryOffset")
    result["inputs"][-1]["inverted"] = True
    return [result]
