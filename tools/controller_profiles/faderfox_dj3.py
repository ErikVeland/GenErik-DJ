"""Independent DJ3 input core without shared-pot or copied lamp assumptions."""
from curated import add, profile
from rane_four import FOUR_SOURCE, FOUR_PACKAGE_SHA

DJ3_MANUAL = "https://www.faderfox.de/PDF/Manual%20DJ3%20V01.PDF"
DJ3_SETUP = "https://www.faderfox.de/settings/faderfox%20DJ3%20V01.zip"
DJ3_SOURCES = [
    ("TestBuilds/r301/upstream/controllers/Faderfox__DJ3.js","4a3541994ae993386a2c764627ccf5a14ba727903fe3d00598e84b3202f11825"),
    ("TestBuilds/r319/upstream/Manual-DJ3-V01.pdf","e71553130dbb8b14ded5fb458846a61d027f969900c87e370867598d6e75a1eb"),
    ("TestBuilds/r319/upstream/faderfox-DJ3-V01.zip","f6a5ab7914a9fe15642dccbe9d980a35daad35aeab4a992acd684a9a20a04477"),
    ("TestBuilds/r319/upstream/faderfox-DJ3-V01.tsi","f44a4f1fb7764e55fd5e8f9f3b3d99d7cf1e30a4e6b2f4293eac32feea0c10a3"),
]
DJ3_REFERENCES = {"Faderfox DJ3": {
    "url":FOUR_SOURCE,"sha256":FOUR_PACKAGE_SHA,
    "archiveMember":"Applications/DEX4.app/Contents/Resources/controllers/Faderfox__DJ3.js",
    "memberSha256":DJ3_SOURCES[0][1],
    "relatedSources":[{"url":DJ3_MANUAL,"sha256":DJ3_SOURCES[1][1],"pages":[4,5]},
                      {"url":DJ3_SETUP,"sha256":DJ3_SOURCES[2][1],"archiveMember":{"path":"faderfox DJ3 V01.tsi","sha256":DJ3_SOURCES[3][1]}}],
    "review":"Manufacturer manual confirms named Faderfox DJ3 or generic USB Audio Device, class-compliant USB, four selectable MIDI channels and persistent deck assignments. Only the named DJ3 endpoint matches automatically; generic USB Audio Device is not an alias. The manufacturer's TSI has269 bindings on Ch04 (wire3). Bound Play/Cue NoteF5/F#5 corroborate89/90, and DCDT CC64/66/96/97 inputs select encoder mode1 (7Fh/01h). Independent PCDJ handlers ignore channel; native accepts only the four manufacturer-selectable channels0..3. They define separate A/B/C/D Play89/93/105/109, held Cue90/94/106/110, Sync88/92/104/108, held bends72/73,74/75,80/81,82/83; distinct Load/Keylock aliases and four Hot Cues per target. LevelCC112..115 and PFL104/105/108/109 remain distinct across banks. Gain/pitch encoder pairs and global cue-mix97/monitor98/master99/browser96 preserve literal raw<=64 positive, otherwise raw-minus128; native per-target accumulation replaces source shared software variables. CrossfaderCC120 is normal and Note64 opens a group. Opposite-bank release-only aliases clear held Cue/bends and rearm Play. Manufacturer shared/separate EQ/filter pot modes are not inferred, so all CC0..15 pots stay inactive. PCDJ startup/feedback contains unrelated deck-channel lamp addresses and is not emitted. Encoder mode pages, full shifted releases, loops, FX, mode/sys lights, generic-port discovery, native calibration and physical acceptance remain open. This MIDI-only controller has no inferred audio route. No downloaded code runs in the app.",
}}


def dj3_profiles():
    result = profile("Faderfox DJ3",FOUR_SOURCE)
    result["definition"] = "reviewed:faderfox-dj3"
    result["excludedAliases"] = ["USB Audio Device","Faderfox DJ2","DJ2","Faderfox DJ4","DJ4"]
    result["hardwareMode"] = "Named Faderfox DJ3 MIDI port, outside system mode. All four selectable MIDI channels are accepted. C/D need app opt-in. Shared EQ/filter pots remain inactive."
    result["scope"] = "Automatic named-port four-target transport, held Cue/bend, relative gain/pitch, distinct level/PFL controls, four cues and global controls. Shared pots, full modes/output/lifecycle and physical acceptance remain open."
    notes = {
        "play":[[89],[93],[105],[109]],"cuePreview":[[90],[94],[106],[110]],
        "sync":[[88],[92],[104],[108]],"pitchBendDown":[[72],[74],[80],[82]],
        "pitchBendUp":[[73],[75],[81],[83]],"load":[[32,48],[40,56],[33,49],[41,57]],
        "keylock":[[34,50],[42,58],[35,51],[43,59]],
    }
    cues = [[76,77,98,99],[78,79,102,103],[84,85,114,115],[86,87,118,119]]
    for channel in range(4):
        for side,deck in enumerate("abcd"):
            for action,addresses in notes.items():
                for number in addresses[side]:
                    add(result,action,channel,number,deck=deck)
            for action in ["play","cuePreview","pitchBendDown","pitchBendUp"]:
                add(result,action,channel,notes[action][(side+2)%4][0],deck=deck)
                result["inputs"][-1]["releaseOnly"] = True
            for slot,number in enumerate(cues[side]):
                add(result,f"hotcue{slot+1}",channel,number,deck=deck)
            for action,addresses in [("gain",[[64,80],[72,88],[65,81],[73,89]]),
                                     ("tempo",[[66,82],[74,90],[67,83],[75,91]])]:
                for number in addresses[side]:
                    add(result,action,channel,number,"control","dj2go2Jog",deck)
            add(result,"level",channel,112+side,"control",deck=deck)
            add(result,"cue",channel,[104,105,108,109][side],"control",deck=deck)
        add(result,"crossfader",channel,120,"control")
        for action,number in [("cueMix",97),("monitor",98),("master",99),("browse",96)]:
            add(result,action,channel,number,"control","dj2go2Jog")
        add(result,"openGroup",channel,64)
    result["gaps"] = ["Named DJ3 endpoint only; generic USB Audio Device naming requires manual identification. Shared/separate EQ/filter pot mode ownership, full Shift and non-critical button release cleanup, loop/FX/key modes, LED/sys feedback, complete lifecycle and native encoder calibration remain open. No copied Pioneer-style lamp/reset packet or audio route is emitted. Physical USB and A10X acceptance remain unverified."]
    return [result]
