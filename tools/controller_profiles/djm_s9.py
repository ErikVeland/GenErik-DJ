"""Unambiguous DJM-S9 manual MIDI controls without pad-channel repairs."""
from curated import add, profile

S9_NAME = "Pioneer DJM-S9"
S9_SPEC = "https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-S9/DJM-S9_List_of_MIDI_Message_E.pdf"
S9_REFERENCES = {S9_NAME: {
    "url": S9_SPEC,
    "sha256": "ff942101be3328acf0b9fa90d54c15f5a02a9d8efc494ca5a8142fe308e4badd",
    "pages": [1,2,3,4],
    "relatedSources": [{"url":"https://support.alphatheta.com/en-US/articles/4405086271129"}],
    "review": "All four official Version1.00 wire pages were visually checked. The manufacturer article requires the utility setting for DJ software other than Serato DJ Pro and a power cycle when switching software. Four explicitly documented deck channels1-4 retain native gain/EQ/filter/level using14-bit pairs4/36,7/39,11/43,15/47,1/33,19/51. Channel7 supplies crossfader31/63, master8/40, headphones13/45 and blend12/44. Browser64 uses signed counts; press65, Back101 and normal Load70/71 address the native browser/A-B. Shared Shift63 guards normal actions. Loop half18/double19 retain deck channels. The 4BEAT LOOP row lists both69 and20 against an incomplete PC utility preference; neither becomes a guessed Loop or tempo-reset action. The channel header assigns performance pads8/9/10/11 but every pad row says8/8/10/11; no duplicate second channel is repaired. Additional mode rows use undefined9q. Pads/modes remain inactive. Headphone Cuefader14 blends physical channels, not the native cue/master blend, and remains inactive. Fader-start notes81/82/102, source/reverse/curve controls, microphone, FX/levers/sampler, complete output/lifecycle/audio routing and physical/A10X acceptance remain open. Manual separate app audio only. No feedback, setup, stored-setting, audio-route write or sibling protocol is inferred.",
}}


def s9_profiles():
    result = profile(S9_NAME,S9_SPEC)
    result.update(autoSelect=False,role="accessory",
                  aliases=[S9_NAME,"Pioneer DJ DJM-S9","DJM-S9","DJM-S9 MIDI 1"],
                  excludedAliases=["DJM-S5","DJM-S7","DJM-S11"],
                  hardwareMode="Manual utility setting for DJ software other than Serato DJ Pro, with separate app audio. Power-cycle when switching DJ software. Deck channels1-4 map to A-D; C/D require app opt-in. Pads/modes and utility-dependent 4BEAT LOOP remain inactive.",
                  scope="Manual four-deck mixer/loop-size controls, normal A/B Load, signed browsing and global app mixer controls. No guessed pad-channel repair, PFL fader emulation, automatic audio route or hardware FX ownership.",
                  gaps=["The header says pad channels8/9/10/11 but rows say8/8/10/11. Mode status9q has no definition. Pads/modes stay inactive. Utility-dependent 4BEAT LOOP69/20, fader-start contacts, headphone channel Cuefader14, hardware/audio ownership, source/reverse/curve controls, microphone/FX/levers/sampler, full output/lifecycle/calibration and physical/A10X acceptance remain open. No setting, output, sibling protocol or audio route is inferred."])
    add(result,"shift",6,63)
    for channel,deck in enumerate("abcd"):
        for action,number in [("gain",4),("high",7),("mid",11),("low",15),("filterKnob",1),("level",19)]:
            add(result,action,channel,number,"control","paired14Bit",deck)
        for action,number in [("loopDown",18),("loopUp",19)]:
            add(result,action,channel,number,deck=deck)
            result["inputs"][-1]["shifted"] = False
    for action,number in [("master",8),("monitor",13),("cueMix",12),("crossfader",31)]:
        add(result,action,6,number,"control","paired14Bit")
    add(result,"browse",6,64,"control","twosComplement")
    result["inputs"][-1]["shifted"] = False
    for action,number in [("openGroup",65),("browsePreviousGroup",101)]:
        add(result,action,6,number)
        result["inputs"][-1]["shifted"] = False
    for deck,number in [("a",70),("b",71)]:
        add(result,"load",6,number,deck=deck)
        result["inputs"][-1]["shifted"] = False
    return [result]
