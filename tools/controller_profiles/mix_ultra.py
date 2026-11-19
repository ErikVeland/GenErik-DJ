"""Independent Mix Ultra capture facts with conservative modifier and state boundaries."""
from curated import add, profile

ULTRA_NAME = "Hercules DJControl Mix Ultra"
ULTRA_REV = "93a097e7641512bd026b9d1b5d129b2e5f009f87"
ULTRA_SPEC = f"https://raw.githubusercontent.com/v6ry876z77-bit/yt-dj-mix/{ULTRA_REV}/mixultra-midi.md"
ULTRA_ANALYSIS_REV = "068845a128ab2311dde6378a1d195a77522b7eb0"
ULTRA_CAPTURE_REV = "7174fda021e6f5f3791ac6fbf169ceb7f94ad3fa"
ULTRA_REFERENCES = {ULTRA_NAME: {
    "url": ULTRA_SPEC,"revision":ULTRA_REV,
    "sha256":"a06dcddf1c98baed578a1b907e0864c9cc5b0cf1a4ead25dce26af6e4c757a8f",
    "relatedSources":[
        {"url":f"https://raw.githubusercontent.com/mlcmgmt/control-mix-ultra-jog-fix/{ULTRA_ANALYSIS_REV}/docs/reverse-engineering.md","sha256":"e582208ebc567b7c63d53c94e792633261e43cba7445bdfa2197830127b5d2a9","revision":ULTRA_ANALYSIS_REV},
        {"url":f"https://raw.githubusercontent.com/aurabirb/djercula/{ULTRA_CAPTURE_REV}/inputmap.py","sha256":"3acb23497cd483d6b9b8e8086f3ad2c3dbb755cb604c41760ca5710f075b489d","revision":ULTRA_CAPTURE_REV},
        {"url":"https://ts.hercules.com/download/sound/manuals/DJC_Mix_Ultra/DJControl_Mix_Ultra_user_manual_EN.pdf","sha256":"98fbf1f45114310c100ecb6f28ec6957ca63a52801f8b1f712cd808eb05f214c","pages":[9,13,14]},
        {"url":"https://support.hercules.com/en/kb/1806-en/"}],
    "review":"Three pinned independent owner sources corroborate normal channels1/2, Play7, Cue6, Load13, touch8, top jog CC10, ring CC9, volume CC0, pitch CC8, filter/EQ CC1-4, global crossfaderCC0/masterCC3/browserCC1/pressNote0 and normal Hot Cue pads0-7 on6/7. Capture facts explicitly pair level0/32, pitch8/40 and crossfader0/32. Other absolute controls use only qualified MSBs; their low-byte pairing stays unqualified. Native tempo uses raw-max positive at the app's8% range; the manufacturer makes direction app-dependent. The manufacturer Cue contract is set/return/stop, not held preview, so use cueReturn. Independent sources disagree on which physical Shift key emits channel1/2 Note4. Both known Shift wires therefore share an OR guard for the whole source, with distinct input identities. Either transition retires source-local contacts. Mode15-18 presses retire contacts on their reported deck; releases preserve new contacts. Shifted touch8 on4/5 is release-only. Normal top jog needs contact. Sync5 has unresolved state/edge behaviour and remains inactive, preserving saved Sync. PFL12, gain/Neural Mix, other pads/modes, service/calibration flows, complete LED/lifecycle/audio and physical/A10X acceptance remain open. Service-mode pads overlap normal pads; keep service mode off. Stock firmware can suppress slow ring packets, which the app cannot reconstruct. Physical jog resolution/taper remains uncalibrated. No owner firmware, patch, executable mapping code, output, setting write, sibling Mix/Starlight protocol, BLE pairing or audio route is imported.",
}}


def ultra_profiles():
    result = profile(ULTRA_NAME,ULTRA_SPEC)
    result.update(definition="reviewed:hercules-mix-ultra-corroborated",
                  aliases=[ULTRA_NAME,"DJControl Mix Ultra","DJCONTROL MIX ULTRA","DJControl Mix Ultra MIDI 1"],
                  excludedAliases=["DJControl Mix","DJControl Starlight","DJControl Inpulse 200 MK2"],
                  hardwareMode="Normal operation after Bluetooth MIDI connection. Keep service/calibration mode off. Both Shift keys conservatively guard the whole source. Cue sets/returns/stops. Native tempo raw-max is positive. Sync/PFL and other modes remain unqualified. No automatic pairing or audio route.",
                  scope="Automatic captured two-deck MIDI core: Play, Cue return, Load, contact jogs, high-resolution level/pitch/crossfader, seven-bit EQ/filter/master, browsing and eight Hot Cues per deck. Full modes, Sync/PFL and output remain open.",
                  gaps=["Sync5 state/edge and PFL12 semantics remain unqualified. Conflicting physical Shift-side attribution uses a source-wide OR guard. Other absolute low bytes, jog resolution/taper, gain/Neural Mix, other pad modes, service-mode pad overlap, full LED/lifecycle/audio and physical/A10X acceptance remain open. Stock firmware may suppress slow ring packets. No firmware patch, executable map, setting/output write, sibling protocol, BLE pairing or audio route is imported."])
    result["bankChanges"] = []
    for index,deck in enumerate("ab"):
        channel = index+1
        add(result,"shift",channel,4)
        result["inputs"][-1]["shiftInput"] = index
        result["bankChanges"].append({"channel":channel,"number":4,"onValue":127,"decks":["a","b"],"releaseShiftChannels":[]})
        result["bankChanges"] += [{"channel":channel,"number":number,"onValue":127,"decks":[deck]} for number in range(15,19)]
        for action,number in [("play",7),("cueReturn",6),("load",13),("jogTouch",8)]:add(result,action,channel,number,deck=deck)
        add(result,"jogTouch",4+index,8,deck=deck)
        result["inputs"][-1].update(shifted=True,releaseOnly=True)
        for action,number in [("jog",10),("wheelJog",9)]:
            add(result,action,channel,number,"control","twosComplement",deck)
            if action=="jog":result["inputs"][-1]["requiresTouch"] = True
        for action,number in [("tempo",8),("level",0)]:add(result,action,channel,number,"control","paired14Bit",deck)
        for action,number in [("filterKnob",1),("low",2),("mid",3),("high",4)]:add(result,action,channel,number,"control",deck=deck)
        for slot in range(8):add(result,f"hotcue{slot+1}",6+index,slot,deck=deck)
    for action,number,encoding in [("crossfader",0,"paired14Bit"),("master",3,"absolute"),("browse",1,"twosComplement")]:add(result,action,0,number,"control",encoding)
    add(result,"openGroup",0,0)
    for row in result["inputs"]:
        if row["action"] != "shift" and "shifted" not in row:row["shifted"] = False
    return [result]
