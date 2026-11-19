"""Separate manual console subsets from independently pinned Engine assignments."""
from copy import deepcopy
from curated import add, profile
from prime_all_in_one import prime_aio_profiles
from prime_players import PRIME_BASE, PRIME_REVISION

ENGINE_FIXED_MODELS=[
    ("Denon DJ SC Live 2","JP20","f40fad7cad69da02a3dee2c04c39d8010495d56d8151d493180df9b1190cfd53"),
    ("Denon DJ SC Live 4","JP21","86a3a1a6f8731b8126c4442355f3519cee2a0cf7d50a8aad4ea3d2e496fb3f5d"),
    ("Numark Mixstream Pro Go","NH10","a9061eddd0d8f599fcf883832af4dc5fc99302ac9766019aae9e8fa895edafb8"),
]
ENGINE_FIXED_REFERENCES={}
for name,hardware,digest in ENGINE_FIXED_MODELS:
    ENGINE_FIXED_REFERENCES[name]={
        "url":PRIME_BASE+hardware+"/"+hardware+"_Controller_Assignments.qml","sha256":digest,"revision":PRIME_REVISION,
        "relatedSources":[{"url":"https://deathcamel58.github.io/denon-reverse-engineering/firmware.html"},
                          {"url":"https://deathcamel58.github.io/denon-reverse-engineering/engine-midi-devices.html"}],
        "review":"Independent "+hardware+" assignment and the public firmware researcher's hardware-ID table identify this model. Fixed mixer channels use gain/high/mid/low/level CC3/4/6/8/14 and PFL Note13, with explicit channel0/1"+("/2/3" if hardware=="JP21" else "")+". "+(
            "JP20 names SCX-2 and separately declares physical deck channels2/3, normal Play10/Cue9/Sync8/Keylock34/bends29/30/manual LoopIn37/Out38/loop-sizeCC32, per-side Shift28 and global Load1/2. Its explicit SpeedSlider pair31/75 has invert true. Global crossfader14, cue-mix18/headphone19/master20 differ from Prime2 and original GO. Jogs useCC17/49, not Prime2's55/77. Reuse only the independently agreed fixed transport/mixer fields. " if hardware=="JP20" else
            "JP21 names SCX-4 and declares deck channels4/5, Layer31 and four mixer channels. Host layer routing, initial selected deck and shared Load ownership are unqualified, so the profile exposes only the fixed four-strip mixer and global crossfader14/cue-mix18/headphone19/master20. No Prime4 four-button selector or decoder is inherited. " if hardware=="JP21" else
            "NH10 is independently identified as Mixstream Pro Go. Its objectName still says MIXSTREAM PRO, which alone is not model identity proof. Fixed deck channels2/3 declare Play10/Cue9/Sync8/bends29/30 and Shift28; global Load1/2 and crossfader14/cue-mix9/headphone10/master15 stay separate from SC Live. Tempo polarity is not explicit in NH10 and stays inactive. No original Pro jog codec/calibration, pad modes or light values are inherited. NH09's two-band MIXSTREAM is not Pro+; actual Pro+ is NH08S. ")+
        "Firmware assignments are protocol references, not a complete host SDK. Manual raw Computer-mode selection and separate app mixer audio remain required. No reset, motor, setup, output or stored-setting packet is sent. Full pads/FX, jog/touch/calibration, screens, host lifecycle/audio and physical/A10X acceptance remain open.",
    }


def fixed_engine_profiles():
    results=[]
    for name,hardware,_ in ENGINE_FIXED_MODELS:
        if hardware=="JP21":
            result=profile(name,ENGINE_FIXED_REFERENCES[name]["url"])
            result["role"]="accessory"
            for channel,deck in enumerate("abcd"):
                for action,number in [("gain",3),("high",4),("mid",6),("low",8),("level",14)]:
                    add(result,action,channel,number,"control",deck=deck)
                add(result,"cue",channel,13,deck=deck)
            for action,number in [("crossfader",14),("cueMix",18),("monitor",19),("master",20)]:
                add(result,action,15,number,"control")
        else:
            result=deepcopy(next(p for p in prime_aio_profiles() if p["id"]=="Denon DJ PRIME 2"))
            if hardware=="JP20":
                for record in result["inputs"]:
                    if record["action"]=="cueMix":record["number"]=18
                    if record["action"]=="monitor":record["number"]=19
                for index,deck in enumerate("ab"):
                    add(result,"tempo",index+2,31,"control","paired14Bit",deck)
                    result["inputs"][-1].update(lowNumber=75,inverted=True,shifted=False)
                add(result,"master",15,20,"control")
            else:
                result["inputs"]=[i for i in result["inputs"] if not i["action"].startswith(("loop","keylock"))]
                for record in result["inputs"]:
                    if record["action"]=="cueMix":record["number"]=9
                    if record["action"]=="monitor":record["number"]=10
                add(result,"master",15,15,"control")
        short=name.removeprefix("Denon DJ ").removeprefix("Numark ")
        result.update(id=name,source=ENGINE_FIXED_REFERENCES[name]["url"],definition="reviewed:engine-fixed-"+hardware.lower(),autoSelect=False,
                      aliases=[name,short],excludedAliases=[x for x in ["SC Live 2","SC Live 4","Mixstream Pro","Mixstream Pro +","Mixstream Pro+","Mixstream Pro Go","PRIME 2","PRIME GO","PRIME GO+"] if x!=short],
                      hardwareMode="Manual original "+short+" raw Computer-mode input with separate app mixer audio. "+("Fixed four-strip mixer only; C/D require app opt-in. Deck Layer/transport/Load remain inactive. " if hardware=="JP21" else "Fixed A/B controls only. ")+"Pads, jogs, displays, automatic audio routing and complete host lifecycle remain unqualified.",
                      scope="Manual independently sourced "+("fixed four-strip mixer and globals" if hardware=="JP21" else "normal A/B transport, held Cue/bends, fixed mixer and globals"+(" with explicit inverted paired tempo and manual loop controls" if hardware=="JP20" else ""))+". Other modes/output/lifecycle/audio and physical acceptance remain open.")
        result["gaps"]=["Manual "+short+" only with separate app mixer audio. "+("Deck Layer31, cold target and shared Load ownership stay unqualified; no deck control is active. " if hardware=="JP21" else "")+("Tempo polarity remains unqualified. " if hardware=="NH10" else "")+"Pads, modes/FX, jog/touch/calibration, screens, complete host setup/output/lifecycle/audio and physical/A10X acceptance remain open. No sibling model, persistent setting or firmware-update command is inferred."]
        results.append(result)
    return results
