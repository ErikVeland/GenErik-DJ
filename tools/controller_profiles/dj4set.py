"""Independent 4Set default virtual MIDI controls behind a manual driver boundary."""
from curated import add, profile

DJ4SET_NAME = "Hercules DJ 4Set"
DJ4SET_SPEC = "https://ts.hercules.com/download/sound/manuals/4Set/01_Eng_DJ4Set.pdf"
DJ4SET_REFERENCES = {DJ4SET_NAME:{
    "url":DJ4SET_SPEC,"sha256":"38fc31cec1597c245693389bc87fcb3c2770b7cceda6cf844f5b9518022d672e","pages":[31,32,33,34,35,36,37,38],
    "relatedSources":[{"url":"https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg","sha256":"55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030","member":"Applications/DEX4.app/Contents/Resources/controllers/Hercules__DJ4set.js","memberSHA256":"b5316177a990f043630cacac171da920d708e26f0a74c57cda3b0c2bcd6bde7d"},
                      {"url":"https://support.hercules.com/en/product/dj4set-en/"}],
    "review":"All eight official MIDI appendix pages31-38 visually reviewed. Manual defaults are channels1/2, four-deck mode and7-bit pitch; VirtualDJ changes the latter while running. Buttons A/B use channel1 and C/D channel2, while all four mixer/jog/pitch CC sets stay on the first channel. Independent 4Set-specific DEX handlers corroborate these addresses,250 positions per revolution and ordinary raw EQ/master/blend/crossfader polarity over the table's inconsistent CW/CCW wording. Do not copy DEX raw64-forward jog boundary; the factory64-reverse boundary governs. Native manual core supports transport/PFL/Load, owned bends and full-value jog contact,250-count normal/contact-only scratch streams,7-bit pitch/level/EQ and shared mixer/browser. Physical and reported Shift guard side-local A/C or B/D contacts across note-channel banks. Deck-state reports retire both directions without changing app deck capacity. C/D require app opt-in. Native USB access is not established: use an exposed desktop-driver or external-bridge MIDI port. No automatic selection/audio routing, driver installation, state query, Shift/deck/jog-lock/sensitivity/curve setting or sibling protocol is inferred. K pages/loops/FX, mode/seek/library-focus behaviour, microphone/recording,8-bit pitch alternate, complete lamp/lifecycle/audio ownership and physical/A10X acceptance remain open. Sixteen explicit steady Play/Cue/Sync/PFL lamp recipes are available through separate manual feedback selection. Downloaded DEX code is not copied, run or bundled.",
}}


def dj4set_profiles():
    result = profile(DJ4SET_NAME,DJ4SET_SPEC)
    result.update(autoSelect=False,aliases=[DJ4SET_NAME,"Hercules DJ4Set","DJ 4Set","DJ4Set","Hercules DJ 4Set MIDI"],
                  excludedAliases=["DJ Console 4-Mx","DJ Console MK4","DJControl AIR+"],
                  hardwareMode="Manual exposed desktop-driver or external-bridge MIDI port. Default channels1/2, four-deck mode and7-bit pitch. C/D require app opt-in. Native iPad USB/audio access remains unqualified.",
                  scope="Manual four-target transport/PFL/Load, held bends, fixed250-count touch scratch and normal jog,7-bit mixer/pitch, browsing and16 steady lamps. No direct iPad USB or automatic audio route.",
                  gaps=["Desktop driver/bridge and native iPad USB/audio access remain open. Default channels1/2, four-deck mode and7-bit pitch only. Eight-bit pitch alternate, K/Shifted-K pages, loops/FX, modifiers/search, library focus, microphone/recording, full feedback/lifecycle/hardware audio ownership/calibration and physical/A10X acceptance remain open. Feedback requires separate manual selection. No query, Shift/deck/jog/sensitivity/curve setting, driver installation or sibling wire protocol is inferred."])
    result["bankChanges"] = [{"channel":0,"number":61,"onValue":127,"decks":list("abcd")}]
    for side in [0,1]:
        result["bankChanges"].append({"channel":0,"number":72+side,"onValue":127,"decks":["a","c"] if side==0 else ["b","d"],"releaseShiftChannels":[]})
    for index,deck in enumerate("abcd"):
        channel,side = index//2,index%2
        pair = ["a","c"] if side==0 else ["b","d"]
        base = side*32
        for number,key in [(28 if side==0 else 66,side),(27+base,side+2)]:
            for scope in [side,None]:
                add(result,"shift",channel,number)
                result["inputs"][-1]["shiftInput"] = key
                if scope is not None:result["inputs"][-1]["shiftChannel"] = scope
            result["bankChanges"].append({"channel":channel,"number":number,"onValue":127,"decks":pair,"releaseShiftChannels":[]})
        result["bankChanges"].append({"channel":channel,"number":18+base,"onValue":127,"decks":pair})
        for action,number in [("play",14+base),("cuePreview",13+base),("sync",17+base),("cue",15+base),("load",74+side),("pitchBendDown",29 if side==0 else 67),("pitchBendUp",30 if side==0 else 68)]:
            add(result,action,channel,number,deck=deck,feedback=action in {"play","cuePreview","sync","cue"})
            result["inputs"][-1].update(shifted=False,shiftChannel=side)
        add(result,"jogTouch",channel,26+base,encoding="fullVelocityGate",deck=deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side)
        for number,contact in [(1+8*index,False),(36+index,True)]:
            add(result,"jog",0,number,"control","twosComplement",deck)
            result["inputs"][-1].update(shifted=False,shiftChannel=side,argument=250,requiresTouch=contact)
        for action,number in [("tempo",5+8*index),("level",3+8*index),("high",6+8*index),("mid",7+8*index),("low",8+8*index)]:
            add(result,action,0,number,"control",deck=deck)
            result["inputs"][-1].update(shifted=False,shiftChannel=side,inverted=action=="tempo")
    for action,number in [("master",33),("crossfader",34),("cueMix",35),("monitor",4)]:
        add(result,action,0,number,"control")
    for action,number in [("browsePrevious",64),("browseNext",65)]:
        add(result,action,0,number)
        result["inputs"][-1]["shifted"] = False
    return [result]
