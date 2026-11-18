"""Original NS6 protocol facts with the existing cyclic counter decoder."""
from curated import add, profile

NS6_NAME = "Numark NS6"
NS6_SPEC = "https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg"
NS6_REFERENCES = {NS6_NAME:{
    "url":NS6_SPEC,"sha256":"55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030",
    "member":"Applications/DEX4.app/Contents/Resources/controllers/Numark__NS6.js",
    "memberSHA256":"c6c3b21dcbdafd73e6802d43619af04466abd742a5a3259effc7e3ed063d6d42",
    "relatedSources":[{"url":"https://www.numark.com/product/ns6"}],
    "review":"Read-only review of the pinned original NS6-specific DEX member. Native reuses its own existing cyclic14BitJog decoder for deck-channel1-4 CC0/32 counter pairs, priming the first fresh pair and wrapping16384. The manufacturer independently specifies3600 positions per revolution and a desktop MIDI driver. No NS6II wire map is inherited. Manual fixed touch scratch uses Note44, with normal Play17, held Cue16, Sync15, Keylock27, bends24/25, five Hot Cues19-23 and side-specific Load14/12. Physical Shift18 shares A/C or B/D identity but guards sides independently, replacing the source's left-only delete guard bug. Shared channel0 mixer retains the explicit per-deck MSB addresses and C/A/B/D physical strip order; master67, monitor66, blend18/crossfader7 and strict1/127 browse68 stay separate. Tempo1 uses only the source-qualified inverted seven-bit MSB; a14-bit low-byte pairing is not inferred from the product's general resolution claim. Control reports80/81 retire side contacts/pickup/counters for any value, without guessing their value-to-deck semantics or writing a deck choice. Thirty-two steady Play/Cue/Keylock/Hot Cue outputs use the source's distinct CC addresses. Source setup contains a TEST-labelled platter mode and unrelated output writes/sleeps; none are imported. Strip Search, loops/sampler pages, FX, reverse/Slip, range switching, full lifecycle/audio ownership/calibration and physical/A10X acceptance remain open. Use an exposed desktop-driver/bridge MIDI port and separate app audio, with PC sources. No driver installation, device mode write, screen/platter animation, startup/shutdown or audio route is inferred. No downloaded executable source is copied, run or bundled.",
}}


def ns6_profiles():
    result = profile(NS6_NAME,NS6_SPEC)
    result.update(autoSelect=False,definition="reviewed:original-ns6-public-core",aliases=[NS6_NAME,"NS6","Numark NS6 MIDI"],excludedAliases=["Numark NS6II","NS6II","NS7","NS7II","NS7III"],
                  hardwareMode="Manual exposed desktop-driver/bridge MIDI port. Select PC sources and use separate app audio. Deck channels2-5 on the wire (zero-based1-4); shared global/mixer channel1 (zero-based0). Physical strip order C/A/B/D. C/D require app opt-in.",
                  scope="Manual independent four-deck transport, fixed3600-count cyclic touch jogs, five Hot Cues, coarse pitch/mixer, browsing and32 steady lamp recipes. No NS6II alias, direct iPad driver or automatic audio route.",
                  gaps=["Desktop driver/bridge, direct iPad USB/audio and hardware/software source ownership remain unqualified. Manual core only; tempo/mixer use qualified seven-bit MSBs. Strip Search, loops/sampler pages, FX, reverse/Slip, tempo ranges, full output/lifecycle/calibration and physical/A10X acceptance remain open. Separate manual feedback selection. No TEST-labelled platter mode, device-layer/setting write, driver install, startup/shutdown or audio-route command is sent."])
    result["bankChanges"] = [{"kind":"control","channel":0,"number":80+side,"decks":["a","c"] if side==0 else ["b","d"]} for side in [0,1]]
    for index,deck in enumerate("abcd"):
        channel,side = index+1,index%2
        pair = ["a","c"] if side==0 else ["b","d"]
        for scope in [side,None]:
            add(result,"shift",channel,18)
            result["inputs"][-1]["shiftInput"] = side
            if scope is not None:result["inputs"][-1]["shiftChannel"] = scope
        result["bankChanges"].append({"channel":channel,"number":18,"onValue":127,"decks":pair,"releaseShiftChannels":[]})
        for action,number in [("play",17),("cuePreview",16),("sync",15),("keylock",27),("pitchBendDown",24),("pitchBendUp",25),("load",14 if side==0 else 12)]:
            add(result,action,channel,number,deck=deck)
            result["inputs"][-1].update(shifted=False,shiftChannel=side)
        add(result,"jogTouch",channel,44,encoding="fullVelocityGate",deck=deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side)
        add(result,"jog",channel,0,"control","cyclic14BitJog",deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side,argument=3600,lowNumber=32)
        add(result,"tempo",channel,1,"control",deck=deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side,inverted=True)
        for slot in range(5):
            add(result,f"hotcue{slot+1}",channel,19+slot,deck=deck)
            result["inputs"][-1].update(shifted=False,shiftChannel=side)
        for action,numbers in [("level",[8,13,19,24]),("gain",[12,17,23,28]),("high",[11,16,22,27]),("mid",[10,15,21,26]),("low",[9,14,20,25])]:
            add(result,action,0,numbers[index],"control",deck=deck)
        add(result,"cue",0,49+index,deck=deck)
        for action,number in [("play",9),("cuePreview",8),("keylock",16)]+[(f"hotcue{slot+1}",11+slot) for slot in range(5)]:
            suffix = "A" if side==0 else "B"
            result["outputs"].append(dict(action=action+suffix,kind="control",channel=channel,number=number,onValue=127,offValue=0,offUsesNoteOn=False,targetDeck=deck))
    for action,number in [("master",67),("monitor",66),("cueMix",18),("crossfader",7)]:
        add(result,action,0,number,"control")
    add(result,"browse",0,68,"control","signedStep")
    result["inputs"][-1]["shifted"] = False
    for action,number in [("openGroup",8),("browsePreviousGroup",6)]:
        add(result,action,0,number)
        result["inputs"][-1]["shifted"] = False
    return [result]
