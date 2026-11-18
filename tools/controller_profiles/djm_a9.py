"""Unambiguous DJM-A9 MIDI mirror controls, separate from hardware audio mixing."""
from curated import add, profile

A9_NAME = "Pioneer DJM-A9"
A9_SPEC = "https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-A9/DJM-A9_MIDI_Message_List_E_10.pdf"
A9_REFERENCES = {A9_NAME: {
    "url": A9_SPEC,
    "sha256": "4bca4d93965d669e8a22bd58a9582ce2fdd23fc3cc29a576203f8e2df819c76f",
    "pages": [2, 3, 4],
    "relatedSources": [
        {"url": "https://support.alphatheta.com/en-US/articles/16006872025369"},
        {"url": "https://manualzz.com/doc/79710198/pioneer-djm-a9-dj-mixer-owner-s-manual", "page": 80,
         "review": "Web-reviewed manufacturer-authored manual: MIDI channel1 and TOGGLE button transmission are the defaults. The current official manual article links an unavailable download. No local PDF hash is claimed for this secondary-hosted manual text."},
        {"url": "https://virtualdj.com/manuals/hardware/pioneer/djma9/setup.html"},
        {"url": "https://support.alphatheta.com/en-US/articles/15997858603545"},
    ],
    "review": "The current E10 MIDI table was downloaded through the migrated support article and pages2-4 visually checked. CH2 CUE B is explicitly printed as CC17, colliding with CH1 fader CC17. CH2 fader is explicitly printed as Note18 with binary values, colliding with CH3 CUE B Note18. Do not silently repair these fields from sibling mixers or apparent address sequences. CH1/2 faders, both candidate CC17/18 faders and all CUE B buttons remain inactive. Independently unambiguous gain/EQ/Color controls cover four fixed native A-D strips. Only C/D faders remain mapped. CUE A notes10-13 use direct PFL state in default TOGGLE mode; TRIGGER mode needs another qualified contract. Headphones A blend/level, master and crossfader control the separate app mixer. Headphones B, source/assign/curve switches, microphone/FX, clock, dual-bus audio and native external mixer routing remain open. The hardware retains its own audio processing; use separate app audio to avoid unqualified double processing. No MIDI receive, feedback, setup, stored setting or audio route is inferred. Manual selection and C/D opt-in remain required. Physical/A10X acceptance remains open.",
}}


def a9_profiles():
    result = profile(A9_NAME, A9_SPEC)
    result.update(autoSelect=False, role="accessory",
                  aliases=[A9_NAME,"Pioneer DJ DJM-A9","DJM-A9","DJM-A9 MIDI 1"],
                  excludedAliases=["DJM-A7","DJM-V5","DJM-V10","Euphonia"],
                  hardwareMode="Manual MIDI channel1, BUTTON TYPE TOGGLE, separate app audio. Physical CH1-4 map to A-D. C/D require app opt-in. CH1/2 faders and CUE B remain inactive because of published table conflicts.",
                  scope="Manual unambiguous four-strip gain/EQ/filter, C/D levels, latched CUE A state and global app mixer controls. CH1/2 faders, CUE B, hardware audio ownership and full mixer routing remain open.",
                  gaps=["Manufacturer E10 CH2 CUE B CC17 overlaps CH1 fader; CH2 fader Note18 overlaps CH3 CUE B. Both candidate CC17/18 faders and all CUE B controls stay inactive pending independent wire evidence. Manual default channel1/TOGGLE only. TRIGGER mode, Headphones B, hardware/software audio ownership, external deck routing, source/assign/curve switches, FX/microphone/clock, full lifecycle/calibration and physical/A10X acceptance remain open. The mixer does not receive MIDI. No output, stored setting or audio route is inferred."])
    strips = [(1,2,3,4,5),(6,7,8,9,10),(12,14,15,21,22),(80,81,92,82,83)]
    for index, (deck,numbers) in enumerate(zip("abcd",strips)):
        for action,number in zip(["gain","high","mid","low","filterKnob"],numbers):
            add(result,action,0,number,"control",deck=deck)
        if index >= 2:
            add(result,"level",0,19+index-2,"control",deck=deck)
        add(result,"cueState",0,10+index,deck=deck)
    for action,number in [("master",24),("monitor",26),("cueMix",27),("crossfader",11)]:
        add(result,action,0,number,"control")
    return [result]
