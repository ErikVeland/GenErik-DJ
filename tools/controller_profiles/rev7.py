"""Independent DDJ-REV7 E2 manual MIDI core without motor ownership."""
from curated import add, profile

REV7_NAME = "Pioneer DDJ-REV7"
REV7_SPEC = "https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-REV7/DDJ-REV7_MIDI_message_List_E2.pdf"
REV7_REFERENCES = {REV7_NAME: {
    "url": REV7_SPEC,
    "sha256": "a2d33045fc28017d48ba8e9409e0586d0f753ce426e7f955c0c56460b7dbf905",
    "pages": [1,2,3,4,5,6,7],
    "relatedSources": [{"url":"https://support.alphatheta.com/en-US/articles/4414574284697?product=4416585726873"}],
    "review": "All seven E2 manufacturer pages were visually reviewed. Add a manual two-deck MIDI core, not motorised compatibility. Deck channels1/2, upper four SLOT/PAD hot cues channels3/4 and eight performance hot cues channels8/10 remain independent. START/STOP Note11, Sync88, Keylock26, tempo reset69, Auto Loop20 with Utility LOOP options OFF, half18/double19 and held pitch bends57/58 retain their own addresses. Shifted bend89/93 are release-only aliases. Tempo CC0/32 is non-inverted14-bit; hardware ranges remain uncalibrated. Gain/EQ/level retain deck CC4/7/11/15/19 pairs. Filters use channel7 CC23/55 and24/56. Crossfader31/63, master8/40, headphones13/45 and blend12/44 are channel7. Browse CC64 uses signed counts, press65 opens a group, Back101 selects the previous group, Load70/71 addresses A/B. Shared Shift is channel7 Note63. Shift transitions retire holds. Normal pad/slot mode and input-source changes retire side-local holds. Main held Cue is absent from the hardware table. SILENT CUE115 is not headphone PFL or held main Cue and stays inactive. Motor/platter count stream34/41 is deliberately unmapped until motor speed/contact/ownership are implemented. Utility LOOP-options ON Note35 encodes seven lengths and is not treated as a binary toggle. Other pads/FX/stems, Stop Time, hardware source/reverse/curve controls, colour palette, screens, complete output/lifecycle/audio routing and physical/A10X acceptance remain open. No motor, setup, lamp, stored-setting or audio-route command is sent. REV1/REV5 have no inherited alias.",
}}


def rev7_profiles():
    result = profile(REV7_NAME,REV7_SPEC)
    result.update(autoSelect=False,
                  aliases=[REV7_NAME,"Pioneer DJ DDJ-REV7","DDJ-REV7","DDJ-REV7 MIDI 1"],
                  excludedAliases=["DDJ-REV1","DDJ-REV5"],
                  hardwareMode="Manual general MIDI core. Select this computer's USB source, turn Instant Scratch off and use Utility LOOP options OFF. Use a separate app audio path. Motor/platter, Silent Cue, full audio ownership and automatic support remain unimplemented.",
                  scope="Manual independent two-deck Play/Sync/Keylock/pitch/loop, mixer, browsing and both hot-cue banks. No motor/platter, held main Cue, Silent Cue/PFL or automatic audio routing.",
                  gaps=["Manual partial core only. Motor/platter34/41, physical resolution/contact/speed, Silent Cue, main held Cue, Utility LOOP-options ON35, hardware tempo range, other pads/FX/stems, source/reverse/curve ownership, screens, full output/lifecycle/audio routing and physical/A10X acceptance remain open. No output, motor, setup or stored-setting write is inferred."])
    add(result,"shift",6,63)
    result["bankChanges"] = [{"channel":6,"number":63,"onValue":127,"decks":["a","b"],"releaseShiftChannels":[]}]
    for channel,deck in enumerate("ab"):
        for action,number in [("play",11),("sync",88),("keylock",26),("tempoReset",69),("loop",20),("loopDown",18),("loopUp",19),("pitchBendDown",57),("pitchBendUp",58)]:
            add(result,action,channel,number,deck=deck)
            result["inputs"][-1]["shifted"] = False
        for action,number in [("pitchBendDown",89),("pitchBendUp",93)]:
            add(result,action,channel,number,deck=deck)
            result["inputs"][-1].update(shifted=True,releaseOnly=True)
        add(result,"tempo",channel,0,"control","paired14Bit",deck)
        result["inputs"][-1]["shifted"] = False
        for action,number in [("gain",4),("high",7),("mid",11),("low",15),("level",19)]:
            add(result,action,channel,number,"control","paired14Bit",deck)
        add(result,"filterKnob",6,23+channel,"control","paired14Bit",deck)
        for wire,count in [(2+channel,4),(7+2*channel,8)]:
            for slot in range(count):
                add(result,f"hotcue{slot+1}",wire,slot,deck=deck)
                result["inputs"][-1]["shifted"] = False
        add(result,"load",6,70+channel,deck=deck)
        result["inputs"][-1]["shifted"] = False
        result["bankChanges"] += [{"channel":channel,"number":number,"onValue":127,"decks":[deck]} for number in [27,30,32,34,73,90,67,85,86,87]]
    for action,number in [("crossfader",31),("master",8),("monitor",13),("cueMix",12)]:
        add(result,action,6,number,"control","paired14Bit")
    add(result,"browse",6,64,"control","twosComplement")
    result["inputs"][-1]["shifted"] = False
    for action,number in [("openGroup",65),("browsePreviousGroup",101)]:
        add(result,action,6,number)
        result["inputs"][-1]["shifted"] = False
    return [result]
