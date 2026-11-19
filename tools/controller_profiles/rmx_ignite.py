"""RMX-IGNITE public MIDI facts for an explicit manual native DJ layout."""
from curated import add, profile

IGNITE_NAME = "AlphaTheta RMX-IGNITE"
IGNITE_SPEC = "https://downloads.support.alphatheta.com/firmwares/dj-effectors/RMX-IGNITE/RMX-IGNITE_midi_message_list_en.pdf"
IGNITE_MANUAL = "https://downloads.support.alphatheta.com/manuals/dj-effectors/RMX-IGNITE/HTML/en/RMX-IGNITE/"
IGNITE_REFERENCES = {IGNITE_NAME: {
    "url": IGNITE_SPEC,
    "sha256": "11d27b45729126db68c927c7234597d8400806381ac6a81fcf3f074811ae9bc1",
    "pages": [2,3],
    "relatedSources": [{"url":"https://support.alphatheta.com/en-US/articles/53214453590764"},
                       {"url":IGNITE_MANUAL+"USB_MIDI/USB_MIDI.htm"},
                       {"url":IGNITE_MANUAL+"Settings/Settings.htm"}],
    "review": "Both manufacturer wire pages were visually reviewed. USB/MIDI chapter explicitly sends MIDI through USB for MULTI I/O and always sends timing clock. Utility MIDI CH defaults to1 but can be changed. Define an explicit manual GenErik DJ deck-A accessory layout using a separate app audio path, not hardware FX emulation. Sample triggers A-D Notes12-15 become native Hot Cues1-4. Supported straight Sample Roll buttons52-56/61 choose native latched loops1/8,1/4,1/2,1,2/4 beats; these are not held sample rolls. Triplet/dotted roll buttons57-60 remain inactive because the native loop-size contract does not support those lengths. Isolate LOW/MID/HI knobs CC21/22/23 control native EQ; Sampler Volume24 controls deck level; Sampler Color25 controls native filter; Lever Sub Parameter29 controls the selected native effect amount. Shared phase nudge buttons3/4 provide held native pitch bends; Beat Sync7 toggles native Sync. Browse CC63 uses signed counts, encoder press81 opens a group and Back9 selects the previous group. Hardware source/FX selectors, sampler edit/hold, Echo Time, Release/Echo switching, connection switch, complete effects/sampler/PRO DJ LINK, output/lifecycle/audio routing and physical/A10X acceptance remain open. The DRIVE selector status is printed as s and is not interpreted. Clock does not change app Sync or transport. No output, setting write, hardware processing bypass, USB audio or RMX-500/1000 sibling protocol is inferred.",
}}


def ignite_profiles():
    result = profile(IGNITE_NAME,IGNITE_SPEC)
    result.update(autoSelect=False,role="accessory",aliases=[IGNITE_NAME,"RMX-IGNITE","RMX-IGNITE MIDI 1"],
                  excludedAliases=["RMX-500","RMX-1000"],
                  hardwareMode="Manual fixed GenErik DJ deck-A accessory layout on MIDI channel1, through USB for MULTI I/O. Sample A-D trigger Hot Cues1-4. Straight roll buttons toggle latched native loops. Use separate app audio; the unit's hardware FX remain independent.",
                  scope="Manual native layout: A Hot Cues1-4, six fixed loop sizes, held bends, Sync, level/EQ/filter/effect amount and browsing. No hardware FX/sampler emulation or held sample rolls.",
                  gaps=["Manual MIDI channel1 only. Native loops latch rather than emulate held hardware sample rolls. Triplet/dotted lengths, source/FX selectors, sampler edit/hold, Echo Time, Release/Echo, hardware processing/audio ownership, PRO DJ LINK, full output/lifecycle and physical/A10X acceptance remain open. No setting, output, clock-driven transport, sibling protocol or audio route is inferred."])
    add(result,"browse",0,63,"control","twosComplement")
    for action,number in [("openGroup",81),("browsePreviousGroup",9)]:add(result,action,0,number)
    for action,number in [("sync",7),("pitchBendDown",3),("pitchBendUp",4)]:add(result,action,0,number,deck="a")
    for slot in range(4):add(result,f"hotcue{slot+1}",0,12+slot,deck="a")
    for action,number in [("low",21),("mid",22),("high",23),("level",24),("filterKnob",25),("fx",29)]:
        add(result,action,0,number,"control",deck="a")
    for number,beats in [(52,.125),(53,.25),(54,.5),(55,1),(56,2),(61,4)]:
        add(result,"toggleFixedLoop",0,number,deck="a")
        result["inputs"][-1]["argument"] = beats
    return [result]
