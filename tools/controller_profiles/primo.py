"""Unambiguous PRIMO manufacturer inputs with conflicting appendix rows quarantined."""
from curated import add, profile

PRIMO_NAME = "Mixars PRIMO"
PRIMO_SPEC = "https://mixars.com/wp-content/uploads/2022/11/primo-manual-en-fr-d-it-es.pdf"
PRIMO_REFERENCES = {PRIMO_NAME:{
    "url":PRIMO_SPEC,"sha256":"9006025f242280f2f339991eb3004c4ef961b39c8466c915273a9586f3f3471c",
    "relatedSources":[{"url":"https://mixars.com/support-download/"}],
    "review":"All three MIDI appendix pages44-46 visually reviewed. Four N transport/mixer channels1-4 are distinct from P loop channels5-8, E FX9/10 and G global16. Native retains only63 unambiguous manual inputs: Play0, Sync2, Keylock13, held bend-up12, coarse tempoCC9, gain22/high23/mid24/low25/filter26/level28, P loop50/down52/up53 and G cross8/master10/monitor12/blend13. Global Shift Note0 guards normal rows. The library description gives normal encoder press as next level and shifted press as previous; native uses G Note6/7 for these group actions. All conflicting note rows stay inactive: N Cue1 versus Hot Cue mode1, Vinyl7 versus Roll mode7, bend-down11 versus Sampler mode11, PFL27 with an unqualified channel key versus Pad8 on N27, and shifted overlaps40/41. Pad channels are not silently corrected to P. Relative platter and library encoder values/counts are not specified, so jog/contact/browse remain inactive. Source selector CC34/50 reports retire the physical side's transient bends and pickup for any value without interpreting unknown state values. Global Load A/B needs selected-deck state and stays inactive. Firmware1.12 adds14-bit pitch but this older table gives onlyCC9; no unqualified low byte is invented. Native uses the explicit seven-bit MSB with inverted app direction pending calibration. Manual FILTER texture selection and separate app audio keep hardware processing/audio ownership explicit. No LED velocities, meter/ring animation, output, query, setting, driver, firmware or startup/shutdown command is inferred. Full modes/lifecycle, audio ownership/calibration and physical/A10X acceptance remain open."
}}


def primo_profiles():
    result = profile(PRIMO_NAME,PRIMO_SPEC)
    result.update(autoSelect=False,definition="reviewed:primo-unambiguous-factory-inputs",
                  aliases=[PRIMO_NAME,"PRIMO","Mixars Primo MIDI"],excludedAliases=["Mixars DUO","Mixars DUO MKII","Mixars QUATTRO"],
                  hardwareMode="Manual exposed MIDI port with channel source set to the intended software deck and Sound Texture FX set to FILTER. N channels1-4 map A-D; P channels5-8 carry loops; global channel16. Use separate app audio. C/D require app opt-in.",
                  scope="Manual63-input Play/Sync/Keylock/bend-up, coarse pitch, mixer/filter, loops, global sound controls and library group actions. Conflicting Cue/PFL/pad rows and unspecified jog/browser formats remain inactive.",
                  gaps=["Factory appendix collides Cue/Hot Cue mode, Vinyl/Roll mode, bend-down/Sampler mode on the same N note addresses, plus unqualified PFL channel versus Pad8 on N27. These rows, all pads, shifted overlaps, jog/contact/library encoder, banked Load and undefined LED velocities remain inactive. Firmware1.12 high-resolution pitch low-byte pairing is unqualified. Manual FILTER texture selection and separate app audio required. Full features/lifecycle/audio ownership/calibration and physical/A10X acceptance remain open. No sibling wires, guessed packets, output/query/settings, firmware or driver command."])
    result["bankChanges"] = [dict(channel=15,number=0,onValue=127,decks=list("abcd"),releaseShiftChannels=[])]
    add(result,"shift",15,0)
    for channel,deck in enumerate("abcd"):
        for number in [34,50]:
            result["bankChanges"].append(dict(kind="control",channel=channel,number=number,decks=["a","c"] if deck in "ac" else ["b","d"]))
        for action,number in [("play",0),("sync",2),("keylock",13),("pitchBendUp",12)]:
            add(result,action,channel,number,deck=deck)
            result["inputs"][-1]["shifted"] = False
        for action,number in [("gain",22),("high",23),("mid",24),("low",25),("filterKnob",26),("level",28),("tempo",9)]:
            add(result,action,channel,number,"control",deck=deck)
            result["inputs"][-1].update(shifted=False,inverted=action=="tempo")
        for action,number in [("loop",50),("loopDown",52),("loopUp",53)]:
            add(result,action,channel+4,number,deck=deck)
            result["inputs"][-1]["shifted"] = False
    for action,number in [("crossfader",8),("master",10),("monitor",12),("cueMix",13)]:
        add(result,action,15,number,"control")
        result["inputs"][-1]["shifted"] = False
    for action,number,shifted in [("openGroup",6,False),("browsePreviousGroup",7,True)]:
        add(result,action,15,number)
        result["inputs"][-1]["shifted"] = shifted
    return [result]
