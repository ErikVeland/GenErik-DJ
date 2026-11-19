"""Bounded manual NV controls from an independent prototype mapping."""
from curated import add, profile

NV_REVISION = "6e999daaf62322e351169b364f071dfb1df4e4c1"
NV_BASE = "https://raw.githubusercontent.com/manzyun/mixxx/"+NV_REVISION+"/res/controllers/"
NV_SOURCES = [
    ("Numark-NV.midi.xml","269d5f698e58464fb9b4d884427b7c0b9f65166daf29d6dec050a1d358b7ed9d"),
    ("Numark-NV-controller-scripts.js","f02dc7dbc8078d83d8f0a8fed6905a12288ec5b3c3e2c8bb1f0b556eccb2c834"),
]
NV_REFERENCES = {"Numark NV": {
    "url":NV_BASE+NV_SOURCES[0][0],"sha256":NV_SOURCES[0][1],
    "relatedSources":[{"url":NV_BASE+NV_SOURCES[1][0],"sha256":NV_SOURCES[1][1]},
                      {"url":"https://www.numark.com/product/nv"}],
    "review":"Independent manzyun mapping at the pinned commit has192 input rows and no outputs. The script identifies itself as version0.1.0. Deck channels1..4 supply Play33, held Cue32, Sync31, Load5, held bends16/17 and coarse pitchCC1. The source normal handlers toggle Play, drive cue_default/cue_preview, enable Sync and LoadSelectedTrack. Global ShiftNote13 switches all normal handlers to alternate software actions. Native Shift guards block alternate presses while allowing owned releases; same-side bank release aliases clear held Cue/bends and rearm Play/Sync/Load. Source rate uses setParameter(rate,raw/127); native polarity follows the established Mixxx rate normalisation. Mixer channel0 has levels8/13/19/24, gains12/17/23/28, low9/14/20/25, mid10/15/21/26 and high11/16/22/27. Globals are crossfaderCC7, monitor68 and cue-mix18. The prototype's startup emits CC100 value255 with a 'maybe' display comment; that non-seven-bit packet and status SysEx are not emitted. Jog decoding shares previous state across all decks and has unfinished touch/scratch behaviour. Jogs/contact, pads, undefined PFL handler, misspelled loop-half control, full loops, screens and setup remain inactive. This is manual normal MIDI only, not a released or hardware-accepted upstream mapping. No downloaded code runs in the app. NVII is not an alias. Full modes, calibration, feedback/lifecycle, audio routing and physical acceptance remain open.",
}}
NV_AUDIT = {
    "source":{"url":NV_BASE+NV_SOURCES[0][0],"sha256":NV_SOURCES[0][1]},
    "relatedSources":[{"url":NV_BASE+NV_SOURCES[1][0],"sha256":NV_SOURCES[1][1]}],
    "format":"Mixxx XML and prototype JavaScript","upstreamRevision":NV_REVISION,
    "inputRows":192,"outputRows":0,"scriptVersion":"0.1.0","automaticSupportAdded":False,
    "gaps":["Unmerged prototype has shared cross-deck jog state, unfinished modes and invalid startup CC value255. No downloaded script or startup packet executes. The bounded manual subset does not qualify automatic setup, full controller support or NVII byte compatibility."],
}


def nv_profiles():
    result = profile("Numark NV",NV_BASE+NV_SOURCES[0][0])
    result["definition"] = "reviewed:numark-nv"
    result["autoSelect"] = False
    result["excludedAliases"] = ["Numark NVII","NVII","Numark NV2","NV2"]
    result["hardwareMode"] = "Manual normal MIDI subset. Enable input separately. Default normal modes and exposed MIDI port are required. C/D need app opt-in."
    result["scope"] = "Manual normal four-target transport, held Cue/bend, coarse source pitch and three-band mixer. Global Shift guards preserve owned releases. Jogs, pads, PFL, loops, screens, setup and audio routing remain open."
    for side, deck in enumerate("abcd"):
        channel = side+1
        add(result,"shift",channel,13)
        for action,number in [("play",33),("cuePreview",32),("sync",31),("load",5)]:
            add(result,action,channel,number,deck=deck)
            result["inputs"][-1]["shifted"] = False
        for action,number in [("pitchBendDown",16),("pitchBendUp",17)]:
            add(result,action,channel,number,deck=deck)
        for action,number in [("play",33),("cuePreview",32),("sync",31),("load",5),("pitchBendDown",16),("pitchBendUp",17)]:
            add(result,action,(side+2)%4+1,number,deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        add(result,"tempo",channel,1,"control",deck=deck)
        result["inputs"][-1]["inverted"] = True
        for action,numbers in [("level",[8,13,19,24]),("gain",[12,17,23,28]),
                               ("low",[9,14,20,25]),("mid",[10,15,21,26]),("high",[11,16,22,27])]:
            add(result,action,0,numbers[side],"control",deck=deck)
    for action,number in [("crossfader",7),("monitor",68),("cueMix",18)]:
        add(result,action,0,number,"control")
    result["gaps"] = ["Manual subset requires normal modes and separate input enabling. The unmerged version0.1.0 prototype does not qualify jog/contact decoding, shared pads, PFL, loops, screens or cold-start setup. No invalid CC255/status SysEx or unqualified output is emitted. Native pitch polarity/calibration, full modes/lifecycle, audio routing and physical acceptance remain open. NVII is separate."]
    return [result]
