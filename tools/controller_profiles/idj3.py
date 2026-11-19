"""Independent iDJ3 MIDI facts from its public PCDJ mapping."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

IDJ3_SCRIPT_SHA = "11cb4a65733aee90d47b65e441687943552d288f2ff9b3c6d8c3244624be5e2a"
IDJ3_REFERENCES = {"Numark iDJ3": {
    "url": FOUR_SOURCE, "sha256": FOUR_PACKAGE_SHA,
    "archiveMember": "Applications/DEX4.app/Contents/Resources/controllers/Numark__iDJ3.js",
    "memberSha256": IDJ3_SCRIPT_SHA,
    "relatedSources": [{"url":"https://www.numark.com/product/idj3"}],
    "review": "Independent iDJ3 source identifies SysEx00013F780019 and uses output channel0. Input handlers share normal channel0 addresses. A/B Play59/66, held Cue51/60, Sync64/71, Keylock81/82, PFL101/102, Load75/52, contact78/77 and bends67/68 versus69/70 are reviewed. Source jogCC25/24 and browserCC26 use raw<=64 positive, otherwise raw-minus128; native dj2go2Jog decoding preserves this boundary. Manufacturer confirms touch-sensitive platters. Native fixed touch replaces source software Scratch toggle72/80. The source600 denominator is software calibration, not measured physical resolution. A/B levelCC8/9, high16/17, mid18/19, low20/21 and non-inverted pitch13/14 are separate controls. Crossfader10, monitor11 and cue-mix12 are normal. Browse press79/105 toggles selection. Fixed-loop notes97/83/84/85 versus98/86/87/88 select1/2/4/8 beats. Play/Cue/Keylock/PFL lamps use127/0 NoteOn. Sync is on-beat output, not a steady lamp. Bounded startup/shutdown clears cover only reviewed steady lamps. CC23 Master uses data2/2 in the source and stays inactive rather than inheriting full-range gain. CUP, reverse, EQ kills, FX, full lifecycle/lights, iPod/dock routing, native calibration, direct iPad attachment and physical acceptance remain open. No Mixtrack or iDJ Live alias is inferred. No downloaded code runs in the app.",
}}


def idj3_profiles():
    result = profile("Numark iDJ3", FOUR_SOURCE)
    result["definition"] = "reviewed:numark-idj3"
    result["excludedAliases"] = ["iDJ Live","iDJ Live II","iDJ Live 2","Mixtrack","Mixtrack Pro"]
    result["scope"] = "Automatic normal two-deck MIDI core, held Cue/bend, fixed touch/jog, source pitch, mixer, browsing, four fixed loops per deck and bounded steady lamps."
    for side, deck in enumerate("ab"):
        for action, numbers in [("play",[59,66]),("cuePreview",[51,60]),("sync",[64,71]),
                                ("keylock",[81,82]),("cue",[101,102]),("load",[75,52]),
                                ("jogTouch",[78,77]),("pitchBendDown",[67,69]),("pitchBendUp",[68,70])]:
            add(result, action, 0, numbers[side], deck=deck, feedback=action in {"play","cuePreview","keylock","cue"})
        for action, number in [("level",8),("high",16),("mid",18),("low",20),("tempo",13)]:
            add(result, action, 0, number+side, "control", deck=deck)
        add(result, "jog", 0, 25-side, "control", "dj2go2Jog", deck)
        for number, beats in zip([[97,83,84,85],[98,86,87,88]][side],[1,2,4,8]):
            add(result, "toggleFixedLoop", 0, number, deck=deck)
            result["inputs"][-1]["argument"] = beats
    for action, number in [("crossfader",10),("monitor",11),("cueMix",12)]:
        add(result, action, 0, number, "control")
    add(result, "browse", 0, 26, "control", "dj2go2Jog")
    for number in [79,105]:
        add(result, "openGroup", 0, number)
    result["startup"] = [[0x90,r["number"],0] for r in result["outputs"]]
    result["shutdown"] = list(result["startup"])
    result["gaps"] = ["Scaled Master CC23, CUP, reverse, EQ kills, FX, software Scratch toggle, on-beat Sync lights, folder/file lights and complete lifecycle remain open. Native jog calibration, iPod/dock/audio routing and direct iPad attachment need qualification. Physical acceptance remains open. No iDJ Live/Mixtrack sibling protocol is inherited."]
    return [result]
