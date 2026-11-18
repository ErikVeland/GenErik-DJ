"""Distinct STUDIO 2a normal MIDI controls and documented split audio."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

STUDIO2A_SCRIPT_SHA = "3212396251cba387cb75a40ce2e787e189a76164a741272b6ec7a304b5ff5df7"
STUDIO2A_WIKI = "https://github.com/mixxxdj/mixxx/wiki/Behringer-Cmd-Studio-2A"
STUDIO2A_WIKI_SHA = "7126f052cfe5acf5ba52dd81fd9492d9d6418181ad79bf9e5cd25c24fee15954"
STUDIO2A_REFERENCES = {"Behringer CMD STUDIO 2a": {
    "url": FOUR_SOURCE, "sha256": FOUR_PACKAGE_SHA,
    "archiveMember": "Applications/DEX4.app/Contents/Resources/controllers/Behringer__CMD_Studio_2A.js",
    "memberSha256": STUDIO2A_SCRIPT_SHA,
    "relatedSources": [{"url":STUDIO2A_WIKI,"sha256":STUDIO2A_WIKI_SHA}],
    "review": "Independent STUDIO 2a script identifies MIDI name Studio 2A and primary USB1397:00C7. Its secondary PID contains literal0x????; no script executes and no secondary identifier is adopted. The original Mixxx mapping guide independently confirms default MIDI channel0, physical touch and master1/2 plus headphones3/4. User-changed channels require reset to the documented default; no unqualified channel-change packet is emitted. On channel0, A/B address offset48 supplies held Cue1/49, Play2/50, contact3/51, Sync4/52, bends6/7 and54/55, PFL22/70 and Load23/71. JogCC3/51 and relative pitchCC5/53 use raw-minus64. Native fixed touch replaces the software Vinyl toggleNote34; its source lamp uses1/on and0/off. Native encoder adjustment is retained; source jog170 is software calibration, not measured counts. High/mid/lowCC19/20/21 plus48 and level24/72 are separate from crossfader32 and monitor33. Four cue notes10..13 and58..61 use source127-valued input, with1/0 lamp output. NavigationNotes36/39 move previous/next track;38 toggles selection. Folder37 semantics remain inactive. Play/Cue/PFL and Hot Cue lights use1/0, not127/on. Sync is on-beat output and is not replaced by a steady lamp. Sampler, Mode/Assign alternate software layouts, full lifecycle/output, non-default channels, native pitch/jog calibration and direct iPad USB/audio acceptance remain open. STUDIO 4a is not an alias.",
}}


def studio2a_profiles():
    result = profile("Behringer CMD STUDIO 2a", FOUR_SOURCE)
    result["aliases"].extend(["CMD Studio 2A","Studio 2A"])
    result["excludedAliases"] = ["CMD STUDIO 4a","STUDIO 4a","CMD MICRO"]
    result["definition"] = "reviewed:behringer-cmd-studio-2a"
    result["audioOutput"] = "masterAndHeadphones"
    result["hardwareMode"] = "Default MIDI channel1 (wire0). User-changed channels require the documented factory reset."
    result["scope"] = "Automatic normal two-deck core, held Cue/bend, fixed touch/jog, relative pitch, EQ/level, four cues per deck, browsing, source-valued lamps and documented split output."
    for side, deck in enumerate("ab"):
        offset = 48*side
        for action, number in [("cuePreview",1),("play",2),("jogTouch",3),("sync",4),
                               ("pitchBendDown",6),("pitchBendUp",7),("cue",22),("load",23)]:
            add(result, action, 0, number+offset, deck=deck, feedback=action in {"cuePreview","play","cue"})
        for action, number in [("high",19),("mid",20),("low",21),("level",24)]:
            add(result, action, 0, number+offset, "control", deck=deck)
        for action, number in [("jog",3),("tempo",5)]:
            add(result, action, 0, number+offset, "control", "binaryOffset", deck)
        for slot in range(4):
            add(result, f"hotcue{slot+1}", 0, 10+slot+offset, deck=deck, feedback=True)
    for action, number in [("crossfader",32),("monitor",33)]:
        add(result, action, 0, number, "control")
    for action, number in [("browsePrevious",36),("browseNext",39),("openGroup",38)]:
        add(result, action, 0, number)
    for output in result["outputs"]:
        output["onValue"] = 1
    result["startup"] = [[0x90,34,1]]
    result["shutdown"] = [[0x90,34,0]]+[[0x90,r["number"],0] for r in result["outputs"]]
    result["gaps"] = ["User-changed MIDI channels are not reset automatically. Sampler, Assign/Mode alternate layouts, folder focus, software Vinyl toggle, on-beat Sync lamps, full lifecycle/output and native pitch/jog calibration remain open. No STUDIO 4a protocol is inherited. Direct iPad USB/audio and physical acceptance remain unverified."]
    return [result]
