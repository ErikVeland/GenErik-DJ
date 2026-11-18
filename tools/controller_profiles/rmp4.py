"""RMP-4 player MIDI facts from its independent public PCDJ mapping."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

RMP4_SCRIPT_SHA = "e8dc654b7d2659428d882cc6f498c58f984034ba57bf8dda66e138c36e441c29"
RMP4_REFERENCES = {"Reloop RMP-4": {
    "url": FOUR_SOURCE, "sha256": FOUR_PACKAGE_SHA,
    "archiveMember": "Applications/DEX4.app/Contents/Resources/controllers/Reloop__RMP4.js",
    "memberSha256": RMP4_SCRIPT_SHA,
    "relatedSources": [{"url":"https://pcdj.com/dj-controllers-reloop-rmp4-map/"},
                       {"url":"https://www.reloop.com/reloop-rmp-4"}],
    "review": "RMP-4-specific source input/output identity is RMP-4. Channels0..3 are independently assignable native players instead of source hard-coded deck indices. Normal Play76, held Cue75, Sync72, Keylock73, PFL104, direct Load90, contact91 and bends88/89 are reviewed. Source normal jogCC1 is raw-minus64 with a1024 software denominator; it does not establish measured physical resolution. Native fixed touch replaces source software Vinyl toggle70. Standard non-inverted pitch-bend uses native linear MIDI normalisation; the source reads MSB only, so finer hardware resolution is not claimed. Normal cue notes0..7 and explicit shifted clear32..39 provide eight cues and release-only cleanup. Fixed-loop notes79..85 select1/8,1/4,1/2,1,2,4,8 beats. Normal In64/Out65 use native boundaries and Reloop66 remains separate; source combined/edit variants are open. BrowseCC3/4 is raw-minus64; Info78 and shifted Enter122 toggle selection. Shift+SearchCC7 supplies filter. Source states buttons add32 with Shift; release-only aliases for Cue/Play/contact/bends clear held normal actions without performing shifted actions. Hardware pad-mode buttons124..127 stay inactive; Hot Loop/Sampler/Roll pages are not mapped to Hot Cue. Source output/lifecycle depends on active wire-channel ownership; no lamp or display output is emitted. MIDI mode/default addresses are required. RMP-3 and other players are not aliases. Full modes, display, output/lifecycle, audio routing, native jog calibration and physical acceptance remain open. No downloaded code runs in the app.",
}}


def rmp4_profiles():
    result = profile("Reloop RMP-4", FOUR_SOURCE)
    result["aliases"].extend(["Reloop RMP4","RMP4"])
    result["excludedAliases"] = ["RMP-3","RMP3","RMP-2.5 Alpha","RMP-2"]
    result["role"] = "player"
    result["definition"] = "reviewed:reloop-rmp-4"
    result["hardwareMode"] = "USB-MIDI mode with default addresses, channels1..4. Native player assignment is separate."
    result["scope"] = "Automatic normal player input core with held Cue/bend, fixed touch/jog, pitch, eight cues, seven fixed loops, normal loop boundaries, Load and browsing."
    for channel in range(4):
        for action, number in [("play",76),("cuePreview",75),("sync",72),("keylock",73),("cue",104),
                               ("load",90),("jogTouch",91),("pitchBendDown",88),("pitchBendUp",89),
                               ("loopIn",64),("loopOut",65),("reloop",66)]:
            add(result, action, channel, number, deck="a")
        for action, number in [("play",108),("cuePreview",107),("jogTouch",123),("pitchBendDown",120),("pitchBendUp",121)]:
            add(result, action, channel, number, deck="a")
            result["inputs"][-1]["releaseOnly"] = True
        for slot in range(8):
            add(result, f"hotcue{slot+1}", channel, slot, deck="a")
            add(result, f"hotcue{slot+1}", channel, 32+slot, deck="a")
            result["inputs"][-1]["releaseOnly"] = True
        for slot, beats in enumerate([.125,.25,.5,1,2,4,8]):
            add(result, "toggleFixedLoop", channel, 79+slot, deck="a")
            result["inputs"][-1]["argument"] = beats
        add(result, "jog", channel, 1, "control", "binaryOffset", "a")
        add(result, "tempo", channel, 0, "pitch", deck="a")
        add(result, "filterKnob", channel, 7, "control", deck="a")
        for number in [3,4]:
            add(result, "browse", channel, number, "control", "binaryOffset")
        for number in [78,122]:
            add(result, "openGroup", channel, number)
    result["gaps"] = ["Wire-channel output ownership, display/meters/lights, full lifecycle, Vinyl toggle, native jog calibration, finer pitch resolution, Hot Loop/Sampler/Roll, cue deletion, combined loop/edit and search/FX modes remain open. No automatic audio route is inferred. Default MIDI mode is required. Direct iPad attachment and physical acceptance remain unverified."]
    return [result]
