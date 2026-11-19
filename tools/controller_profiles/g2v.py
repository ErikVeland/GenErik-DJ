"""Independent G2V MIDI facts from the public PCDJ mapping."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

G2V_SCRIPT_SHA = "955e8f79b7ee3b98d341a2b7dfc7f729f1665ea6bdf27f0b8e66f9e3f53f8a13"
G2V_REFERENCES = {"Gemini G2V": {
    "url": FOUR_SOURCE, "sha256": FOUR_PACKAGE_SHA,
    "archiveMember": "Applications/DEX4.app/Contents/Resources/controllers/Gemini__G2V.js",
    "memberSha256": G2V_SCRIPT_SHA,
    "relatedSources": [{"url": "https://pcdj.com/dj-controllers-gemini-g2v/"}],
    "review": "Independent G2V Audio script identifies USB23C7:0466. Its copied header names another controller; G2V function identities, USB identifiers, handlers and publisher page establish this model. Deck channels0/1 provide Play1, held Cue2, Sync4, Keylock5, contact37, CC6 jog raw-minus64 and inverted CC1 pitch. Source scratch500 and wheel150 denominators are software calibration, not measured counts. Native fixed touch replaces the source software Scratch toggle. Mixer channel3 provides A/B gain1/2, high9/10, mid5/6, low13/14, filter17/18, level21/22, Load1/2 and PFL13/14. Channel3 crossfaderCC25 is inverted, cue-mix26, master27 and monitor28 are normal. BrowserCC30 uses raw>64 forward, otherwise reverse, including64; pushNote17 toggles selection. ModeNotes27/28/29/30 select Cue/AutoLoop/Sampler/ManualLoop independently per deck. Pads9..16 provide eight cues or1/8..16-beat loops. Shift40 suppresses normal cue recall; explicit clear-address17..24 releases only rearm normal cues. Sampler/manual-loop and deletion actions stay inactive. Mode lights and steady Play/Cue/Keylock/PFL lamps use127/0. Startup/shutdown contain bounded source lamp clears only; Sync is an on-beat pulse, not a steady state. No source software runs in the app. Higher-resolution alternatives, full modes/feedback/lifecycle, native jog calibration, audio routing and direct iPad attachment remain unqualified.",
}}


def g2v_profiles():
    result = profile("Gemini G2V", FOUR_SOURCE)
    result["aliases"].append("G2V Audio")
    result["excludedAliases"] = ["Gemini G4V", "G4V", "G4V Audio"]
    result["definition"] = "reviewed:gemini-g2v"
    result["scope"] = "Automatic two-deck normal MIDI core, fixed touch/jog, coarse source pitch, mixer/filter, browsing, eight Hot Cues and eight fixed loops per deck. Bounded steady transport and mode lights."
    for channel, deck in enumerate("ab"):
        add(result, "shift", channel, 40)
        result["inputs"][-1].update(shiftInput=channel, shiftChannel=channel)
        for action, number in [("play",1),("cuePreview",2),("sync",4),("keylock",5),("jogTouch",37)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play","cuePreview","keylock"})
        for action, number in [("cue",13+channel),("load",1+channel)]:
            add(result, action, 3, number, deck=deck, feedback=action == "cue")
        for action, number in [("gain",1),("high",9),("mid",5),("low",13),("filterKnob",17),("level",21)]:
            add(result, action, 3, number+channel, "control", deck=deck)
        add(result, "tempo", channel, 1, "control", deck=deck)
        result["inputs"][-1]["inverted"] = True
        add(result, "jog", channel, 6, "control", "binaryOffset", deck)
        result.setdefault("inputModes", []).append({"channel":channel,"initial":27,"numbers":[27,28,29,30],"onValue":127,"offValue":0})
        for slot, beats in enumerate([.125,.25,.5,1,2,4,8,16]):
            add(result, f"hotcue{slot+1}", channel, 9+slot, deck=deck)
            result["inputs"][-1].update(requiredMode=27, shifted=False, shiftChannel=channel)
            add(result, f"hotcue{slot+1}", channel, 17+slot, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
            add(result, "toggleFixedLoop", channel, 9+slot, deck=deck)
            result["inputs"][-1].update(requiredMode=28, argument=beats)
        result["startup"].extend([[0x90+channel, number, 0] for number in [1,2,5,27,28,29,30]])
    for action, number in [("crossfader",25),("cueMix",26),("master",27),("monitor",28)]:
        add(result, action, 3, number, "control")
        result["inputs"][-1]["inverted"] = action == "crossfader"
    add(result, "browse", 3, 30, "control", "g2vBrowse")
    add(result, "openGroup", 3, 17)
    result["startup"].extend([[0x93,13,0],[0x93,14,0]])
    result["shutdown"] = list(result["startup"])
    result["gaps"] = ["Sampler/manual-loop, cue deletion, CUP, FX, pitch range and high-resolution alternatives, software Scratch toggle, pad/meters and full lifecycle remain open. Native fixed touch/jog calibration and audio routing need qualification. Direct iPad attachment and physical acceptance remain unverified. G4V is a separate model."]
    return [result]
