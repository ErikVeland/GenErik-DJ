"""XDJ-AN E1 MIDI facts with explicit deck and mixer ownership."""
from curated import add, profile

AN_NAME = "AlphaTheta XDJ-AN"
AN_SPEC = "https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-AN/XDJ-AN_MIDI_Massage_List_E1.pdf"
AN_REFERENCES = {AN_NAME: {
    "url": AN_SPEC,
    "sha256": "8862a83688206ffe0bf7736a0235f1318b07185b467444a6bad2d49e7733c4bd",
    "pages": [1,2,3],
    "relatedSources": [{"url":"https://support.alphatheta.com/en-US/articles/53214453591205?product=51352009960347"},
                       {"url":"https://downloads.support.alphatheta.com/manuals/all-in-one-dj-systems/XDJ-AN/html/en/000_EP169_en/Using_DJ_software/Using_DJ_software.htm"},
                       {"url":"https://downloads.support.alphatheta.com/manuals/all-in-one-dj-systems/XDJ-AN/html/en/000_EP169_en/Settings/Settings.htm"}],
    "review": "All three E1 pages were visually reviewed. Decks use channels1/2; mixer channel5; normal pads channels6/7; Shift pads channels8/9. Input-only PC Control CC100 must report127 independently from both decks before one paired-output Mixer Mode CC101=0 requests MIDI Control. The decoder marks local readiness only after the send succeeds, without claiming a device acknowledgement. Any deck leaving PC mode gates controls and releases holds. Nonzero mixer mode gates controls without fighting the physical choice. The user can restore MIDI Control explicitly or re-enter PC mode. No guessed XDJ-AN mode value or shutdown write is sent. Source-selected Software Control and LOAD1/2 are physical steps. Current manual explicitly describes USB-C iPhone/iPad, not Lightning/A10X qualification. Tempo uses non-inverted paired14-bit CC0/32; jogs use documented centre64 difference counts, with physical resolution/range calibration open. Main Cue is held; both Shift transitions retire side-local holds. Normal hot cues, fixed native eight-pad loops and signed jumps are distinct pages; mode presses retire held actions. Mixer/PFL and exact127/0 Play/Cue/Sync/Keylock lamps use independently listed addresses. Remaining pad/effect/keyboard modes, ambiguous binary BeatLoop rotation, source tempo range switches, touch interpretation, meters/screens, audio routes, ownership timing/cold notifications, full lifecycle and physical acceptance remain open. No sibling profile, HID, SDK or audio route is inferred.",
}}


def an_profiles():
    result = profile(AN_NAME,AN_SPEC)
    result.update(inputProtocol="xdjAN",aliases=[AN_NAME,"XDJ-AN","XDJ-AN MIDI 1"],
                  hardwareMode="Select SOURCE, Software Control, then LOAD1 and LOAD2 after connecting the app. Both deck PC-mode notifications and a paired output are required. The app then requests MIDI Control mixer mode. USB-C iPad support does not qualify Lightning/A10X.",
                  scope="Automatic paired MIDI core after physical Software Control entry: two decks, held Cue, jogs, tempo, mixer/PFL, browsing, hot cues and native fixed loop/jump pad pages. Local send success is not device acknowledgement.",
                  gaps=["Physical Software Control entry remains required. Cold PC-mode notifications, mode-command timing, jog resolution, tempo range/taper, remaining pad/FX modes, ambiguous BeatLoop rotation, screens/meters/full feedback, audio routes and physical/A10X acceptance remain open. No shutdown mode write or audio route is inferred."])
    result["bankChanges"] = []
    for channel,deck in enumerate("ab"):
        add(result,"shift",channel,63)
        result["inputs"][-1].update(shiftInput=channel,shiftChannel=channel)
        result["bankChanges"].append({"channel":channel,"number":63,"onValue":127,"decks":[deck],"releaseShiftChannels":[]})
        result["bankChanges"] += [{"channel":channel,"number":number,"onValue":127,"decks":[deck],"releaseShiftChannels":[]} for number in range(80,88)]
        for action,number in [("play",0),("cuePreview",1),("sync",31),("keylock",17),("load",64),("loop",67),("jumpBack",45),("jumpForward",44),("jogTouch",32)]:
            add(result,action,channel,number,deck=deck,feedback=action in {"play","cuePreview","sync","keylock"})
            if action != "play":result["inputs"][-1].update(shifted=False,shiftChannel=channel)
        add(result,"cuePreview",channel,5,deck=deck)
        result["inputs"][-1].update(releaseOnly=True,shifted=True,shiftChannel=channel)
        for action,number,encoding in [("tempo",0,"paired14Bit"),("jog",34,"binaryOffset"),("wheelJog",33,"binaryOffset"),("seek",28,"needlePosition")]:
            add(result,action,channel,number,"control",encoding,deck)
            result["inputs"][-1].update(shifted=False,shiftChannel=channel)
        for page in [0,2,6]:
            for slot in range(8):
                action = f"hotcue{slot+1}" if page == 0 else "fixedJump" if page == 2 else "toggleFixedLoop"
                add(result,action,5+channel,page*8+slot,deck=deck)
                result["inputs"][-1].update(shifted=False,shiftChannel=channel)
                if page != 0:result["inputs"][-1]["argument"] = ([-1,1,-2,2,-4,4,-8,8] if page == 2 else [.25,.5,1,2,4,8,16,32])[slot]
        for action,numbers in [("gain",[1,6]),("high",[2,7]),("mid",[3,8]),("low",[4,9]),("filterKnob",[5,10]),("level",[17,18])]:
            add(result,action,4,numbers[channel],"control",deck=deck)
        add(result,"cue",4,70+channel,"control",deck=deck,feedback=True)
    for action,number in [("crossfader",11),("master",24),("monitor",26),("cueMix",27)]:
        add(result,action,4,number,"control")
    add(result,"browse",0,79,"control","twosComplement")
    result["inputs"][-1].update(shifted=False,shiftChannel=0)
    for action,number in [("openGroup",51),("browsePreviousGroup",50)]:
        add(result,action,0,number)
        result["inputs"][-1].update(shifted=False,shiftChannel=0)
    return [result]
