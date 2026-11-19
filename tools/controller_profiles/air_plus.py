"""Independent Hercules AIR+ default MIDI core and owned lamp packets."""
from curated import add, profile

AIR_PLUS_NAME = "Hercules DJControl AIR+"
AIR_PLUS_SPEC = "https://ts.hercules.com/download/sound/manuals/DJ_Air%2B/DJAIR%2B_Spec_MIDI.pdf"
AIR_PLUS_REFERENCES = {AIR_PLUS_NAME:{
    "url":AIR_PLUS_SPEC,"sha256":"bc214fc30440d5aa8ed40ea2e788ce1141c04cf657a2a9c3064b171032f8d4a5","pages":[1,2,3,4,5,6,7,8],
    "relatedSources":[{"url":"https://ts.hercules.com/download/sound/TDJS/current/TP2_DJ_AirPlus.zip","sha256":"d6128274aae24bbe7cd6df6fafd0d371c61726cbbe52ab29e4e1231161f20dac","member":"AIR+-TP2_Config_MAC_v268.pdf","memberSHA256":"4f5284aff77697e6484a1e43a22043a5dfb6a6a0938fbd00a35ed0379bae99cf"},
                      {"url":"https://github.com/mixxxdj/mixxx/wiki/Hercules-Djcontrol-Air-Plus"},
                      {"url":"https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg","sha256":"55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030","member":"Applications/DEX4.app/Contents/Resources/controllers/Hercules__DJ_Control_Air+.js","memberSHA256":"39ba734e1fcd15b7c7930fc829f611ede3bca36357f7ac421f872981876a5bd8"}],
    "review":"All eight official specification pages visually reviewed. Manufacturer Traktor guide explicitly gives default MIDI channel1,14-bit resolution and headphone channels3/4. Specification independently defines master1/2 and headphones3/4. Mixxx's developer wiki confirms class-compliant MIDI/audio. This is not original AIR protocol reuse. Native A/B Play17/44, held Cue18/45, Sync19/46, PFL25/52, Load26/53 and four separate velocity Hot Cues68-71/76-79 retain channel1. Full-value contact27/54 gates signed Scratch CC104/105; normal CC102/103 supports both touch scratching and untouched wheel movement. Signed values1..63 are forward,64..127 reverse, zero neutral. Independent AIR+-specific DEX handlers give765 positions per revolution for both streams. Native preserves this scale; physical calibration remains open. Physical Shift20/47 and reported Shift-state84/87 each guard the side and the shared browser through source-local OR ownership. All normal buttons/knobs are guarded. Shift and mode changes retire only that side's contacts; Vinyl changes retire both sides. Dedicated Sampler/pressure/FX pages stay inactive. Mixer/pitch/crossfader use explicit14-bit MSB+32 pairs. The independent DEX mapping uses ordinary raw EQ/gain values, contradicting the manufacturer CW/CCW wording. Keep normal EQ/gain polarity, as with the independently reviewed original MK4 discrepancy. Do not copy DEX raw64-forward boundary; the factory64-reverse boundary governs. Pitch raw0 positive at the native8percent range is an explicit native direction choice; physical taper/range remains open. HP Cue/Mix, filter/gain reassignment, Vinyl switching, Air/proximity, microphone, recording/Magic, full mode/output/lifecycle and physical/A10X acceptance remain open. Sixteen owned Play/Cue/Sync/PFL/Hot Cue lamps use127/0 and clear individually on shutdown. No unqualified Update_All_Controls CC127 query/reset, stored setting, firmware or driver command is sent. Downloaded TSI files are not executed or bundled.",
}}


def air_plus_profiles():
    result = profile(AIR_PLUS_NAME,AIR_PLUS_SPEC)
    result.update(aliases=[AIR_PLUS_NAME,"Hercules DJControl AIR Plus","Hercules DJ Control AIR+","DJControl AIR+","DJControl AIR Plus","DJ Control AIR+"],
                  excludedAliases=["Hercules DJ Control AIR","DJControl AIR","DJ Control AIR"],audioOutput="masterAndHeadphones",
                  hardwareMode="Default MIDI channel1 and14-bit resolution. Native fixed touch scratch and four Hot Cues per side. Master1/2 and headphones3/4. Physical USB/iPad attachment and calibration remain unverified.",
                  scope="Automatic independent AIR+ two-deck transport, fixed contact scratch,14-bit mixer/pitch/crossfader, four Hot Cues per side, browsing, owned lamps and documented split audio.",
                  gaps=["Default channel1/14-bit only. Native fixed scratch retains the independent765-count scale. EQ/gain uses corroborated normal polarity over the conflicting manufacturer CW/CCW wording; physical taper/range needs calibration. Pitch raw0 positive is the native choice. HP Cue/Mix, filter/gain reassignment, Vinyl switching, Air/proximity, FX/loop/sample/pressure pages, microphone/recording/Magic, full mode/output/lifecycle and physical/A10X acceptance remain open. Status-only bank recovery remains unqualified. Update_All_Controls CC127, settings, firmware and driver commands stay unused."])
    result["bankChanges"] = [{"channel":0,"number":57,"onValue":127,"decks":["a","b"]}]
    for side,deck in enumerate("ab"):
        base = side * 27
        for shift,index in [(20+base,side),(84+3*side,side+2)]:
            for scope in [side,None]:
                add(result,"shift",0,shift)
                result["inputs"][-1]["shiftInput"] = index
                if scope is not None:result["inputs"][-1]["shiftChannel"] = scope
            result["bankChanges"].append({"channel":0,"number":shift,"onValue":127,"decks":[deck],"releaseShiftChannels":[]})
        for action,number in [("play",17),("cuePreview",18),("sync",19),("cue",25),("load",26)]:
            add(result,action,0,number+base,deck=deck,feedback=action!="load")
            result["inputs"][-1].update(shifted=False,shiftChannel=side)
        add(result,"jogTouch",0,27+base,encoding="fullVelocityGate",deck=deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side)
        add(result,"jog",0,102+side,"control","twosComplement",deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side,argument=765)
        add(result,"jog",0,104+side,"control","twosComplement",deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side,requiresTouch=True,argument=765)
        for action,number in [("tempo",4+side*6),("level",2+side*7),("high",5+side*6),("mid",6+side*6),("low",7+side*6),("gain",8+side*6)]:
            add(result,action,0,number,"control","paired14Bit",deck)
            result["inputs"][-1].update(shifted=False,shiftChannel=side,inverted=action=="tempo")
        for slot in range(4):
            add(result,f"hotcue{slot+1}",0,68+8*side+slot,deck=deck,feedback=True)
            result["inputs"][-1].update(shifted=False,shiftChannel=side)
        result["bankChanges"] += [{"channel":0,"number":number+base,"onValue":127,"decks":[deck]} for number in [21,22,24]]
    add(result,"crossfader",0,1,"control","paired14Bit")
    add(result,"browse",0,106,"control","twosComplement")
    result["inputs"][-1]["shifted"] = False
    add(result,"openGroup",0,67)
    result["inputs"][-1]["shifted"] = False
    result["shutdown"] = [[0x90,output["number"],0] for output in result["outputs"]]
    return [result]
