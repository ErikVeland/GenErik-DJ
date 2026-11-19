"""Shared Spin2/XW-J1 input facts from the author's explicitly compatible mapping."""
from curated import add, profile

SPIN2_SOURCE = "https://gist.github.com/samba2/5af83e947297ab99a4745a5be3e13d55/a8c441c832affebb59415abdc80872967bc8c0e6"
SPIN2_FILES = [
    {"url":"https://gist.githubusercontent.com/samba2/5af83e947297ab99a4745a5be3e13d55/raw/dc830e0e72e89999f0074d60a8e0aa6f6e5b93aa/Casio-XW-J1-scripts.js",
     "sha256":"83599154b1356378bd0335cdbc2ac256694b6511991ccd30ee5c979cd6ea8b5b"},
    {"url":"https://gist.githubusercontent.com/samba2/5af83e947297ab99a4745a5be3e13d55/raw/8c6c20bd87042e63cb44a7eeae014788d6647912/Casio_MIDI_In.midi.xml",
     "sha256":"770fce8365eb28a6cc542046fba4aa5a55735685ddbbe98d3517e191d6b7959e"},
]
SPIN2_REFERENCES = {name:{
    "url":SPIN2_SOURCE,"relatedSources":SPIN2_FILES,
    "review":"Pinned author-owned XML and script explicitly name both Casio XW-J1 and Vestax Spin2. Independent native30-input manual layouts retain deck-channel1/2 Play46, held Cue47, Sync49, PFL50, loop36/size35/37, Hot Cues2/3 at43/44 and full-value contact59. Shared channel3 CC16/17 jogs use raw-minus64. The author's375-position estimate is a provisional native scale, not manufacturer calibration. Fixed native touch scratch does not reproduce the script's software Scratch toggle; mode button45 retires the deck contact. Shared Shift channel3 Note32 guards normal controls and both transitions retire contacts. Native Shift-Left/Right loads only once per press, correcting the source handlers' missing release guard. Plain Left/Right map to native group navigation. Shared crossfader is explicitly channel5 CC16. Conflicting/asymmetric learned mixer, EQ and pitch rows remain inactive. Hot Cue1 references an undefined handler and remains inactive. No source startup lamp clear, FX/filter software mode, output list, audio route or sibling protocol is inferred. No executable source is copied, executed or bundled. Desktop/exposed MIDI port, device-specific USB/audio, complete modes/lifecycle/calibration, distribution review and physical/A10X acceptance remain open."
} for name in ["Vestax Spin2","Casio XW-J1"]}


def spin2_xwj1_profiles():
    results = []
    for name in SPIN2_REFERENCES:
        result = profile(name,SPIN2_SOURCE)
        result.update(autoSelect=False,definition="reviewed:"+("spin2" if name.startswith("Vestax") else "xwj1")+"-shared-input-facts",
                      aliases=[name,"Spin2","Vestax Spin 2","Spin 2"] if name.startswith("Vestax") else [name,"XW-J1","Casio XWJ1"],
                      excludedAliases=["Vestax Spin","Typhoon","XW-DJ1","Casio XW-DJ1"],
                      hardwareMode="Manual fixed native input layout through an exposed MIDI port. Deck notes use channels1/2; shared jogs and Shift/navigation use channel3; crossfader uses channel5. Touch always selects native scratch. Use separate app audio.",
                      scope="Manual transport, touch jogs, PFL, Hot Cues2/3, loop/size, browsing, Shift-Load and crossfader from explicitly shared author facts. Provisional375-count native jog scale.",
                      gaps=["Conflicting/asymmetric mixer/EQ/pitch rows and undefined Hot Cue1 handler stay inactive. Fixed native touch scratch replaces software Scratch mode. Source375-count estimate is provisional. Shared Shift wire cannot identify simultaneous physical modifiers separately. Full FX/filter modes, feedback/lifecycle, device USB/audio routing/calibration, distribution review and physical/A10X acceptance remain open. No original Spin, Typhoon or XW-DJ1 inheritance. No downloaded code, setting, startup lamp clear or output command runs."])
        result["bankChanges"] = [dict(channel=2,number=32,onValue=127,decks=["a","b"],releaseShiftChannels=[])]
        add(result,"shift",2,32)
        for channel,deck in enumerate("ab"):
            result["bankChanges"].append(dict(channel=channel,number=45,onValue=127,decks=[deck]))
            for action,number in [("play",46),("cuePreview",47),("sync",49),("cue",50),
                                  ("loop",36),("loopDown",35),("loopUp",37),("hotcue2",43),("hotcue3",44)]:
                add(result,action,channel,number,deck=deck)
                result["inputs"][-1]["shifted"] = False
            add(result,"jogTouch",channel,59,encoding="fullVelocityGate",deck=deck)
            result["inputs"][-1]["shifted"] = False
            add(result,"jog",2,16+channel,"control","binaryOffset",deck)
            result["inputs"][-1].update(shifted=False,argument=375)
        add(result,"crossfader",4,16,"control")
        result["inputs"][-1]["shifted"] = False
        for action,number in [("browsePrevious",33),("browseNext",34),("browsePreviousGroup",35),("openGroup",36)]:
            add(result,action,2,number)
            result["inputs"][-1]["shifted"] = False
        for deck,number in [("a",35),("b",36)]:
            add(result,"load",2,number,deck=deck)
            result["inputs"][-1]["shifted"] = True
        results.append(result)
    return results
