"""Independent fixed PRIME GO and PRIME 2 Computer-mode input contracts."""
from copy import deepcopy
from curated import add, profile
from prime_players import PRIME_BASE, PRIME_REVISION

GO_BASE="https://community.algoriddim.com/uploads/short-url/"
GO_EXPORTS=[
    ("PRIME-GO-JiPenade.djayMidiMapping","rAIfzO9LTEQ9yieTC9G0gXh03N3.djayMidiMa","31fcd153a66777006aad2d7763112e13cb1fa1d131ec1724f24be6e9345c7254"),
    ("PrimeGo-djGeronimo2.1.djayMidiMapping","43E6f5rpFAlDsjHKSg5MuaWUmvp.djayMidiMa","17472eba26eb0eb2ce1ca05c804d1748ceb580d55dd5dd4ce7defa6655ec6d3a"),
]
AIO_MODELS=[("Denon DJ PRIME GO","JP11","f504676a2fe5db4b606c7c76e5a6a003b6322f735d52edda612ee3e0e3ec751b"),
            ("Denon DJ PRIME 2","JC16","332f4d329cbdba26117684179d2efc2c125854959e921fb23cf2748c70396468")]
PRIME_AIO_SOURCES=[("TestBuilds/r348/upstream",name,digest) for name,_,digest in GO_EXPORTS]+[
    ("TestBuilds/r340/upstream",model+"-assignments.qml",digest) for _,model,digest in AIO_MODELS]
GO_OWNER_ROWS=[]
for index in range(2):
    GO_OWNER_ROWS += [(f"turntable{index+1}.playPause",index+2,10,1),
                      (f"turntable{index+1}.cuePositionOrJumpConsideringPlayState1",index+2,9,1),
                      (f"turntable{index+1}.speed",index+2,31,3),
                      (f"musicLibrary.load{index+1}",15,index+1,1)]
    for key,number in [("gain",3),("highEQ",4),("midEQ",6),("lowEQ",8)]:
        GO_OWNER_ROWS.append((f"turntable{index+1}."+key,index,number,3))
GO_OWNER_ROWS.append(("musicLibrary.libraryRotary",15,5,3))
PRIME_AIO_REFERENCES={}
for name,model,digest in AIO_MODELS:
    is_go=model=="JP11"
    PRIME_AIO_REFERENCES[name]={
        "url":PRIME_BASE+model+"/"+model+"_Controller_Assignments.qml","sha256":digest,"revision":PRIME_REVISION,
        "relatedSources":([{"url":GO_BASE+url,"sha256":sha} for _,url,sha in GO_EXPORTS]+[
            {"url":"https://community.algoriddim.com/t/add-support-for-denon-prime-go/16241?page=3"},
            {"url":"https://virtualdj.com/manuals/hardware/denon/primego/setup.html"},
            {"url":"https://virtualdj.com/manuals/hardware/denon/primego/layout/mixer.html"},
        ]) if is_go else [],
        "review":"Independent "+model+" factory assignment explicitly names this model, global channel15, deck channels2/3 and mixer channels0/1. Normal Play10/Cue9/Sync8/bends29/30 and loop-sizeCC32 are distinct from mixer PFL Note13 and gain/high/mid/low/level CC3/4/6/8/14. Global cue-mix12/monitor13/crossfader14 are separate CC. "+(
            "Two public owner exports agree on fixed Play/Cue/Load/normal mixer/browse addresses and contain no customClassName. Later export also corroborates PFL, bends, Sync and loop39. Factory PlayCue component independently identifies held main Cue9; the numbered owner cue key alone is not that proof. Factory SpeedSlider explicitly pairsCC31/75 and inverts it. Import one paired input per deck instead of the later export's erroneous two independent speed assignments; owner comments report bouncing tempo. Browser is flipped standard rotary CC5 as in both owner exports. Shared Shift is global Note8. Hot Cue/Loop/Roll/Bank pads, hardware dual Color FX and jog touch/counter sensitivity remain unqualified and inactive. Automatic core input applies only to the exact original GO Computer-mode source. Output, screen SDK, full lifecycle/audio and physical/A10X acceptance remain open. " if is_go else
            "JC16 independently declares per-side Shift28, Keylock34, manual LoopIn37/Out38 and paired speed31/75. No original GO Shift/pitch polarity, four-pad Bank behaviour, four-deck Prime4 routing or different wheel sensitivity is inherited. Both physical Shift buttons keep independent held identities. Fixed mixer inputs mirror the app through separate audio; hardware/software ownership is unqualified. Tempo, browse direction, pads, jog/touch and held auto-loop trigger remain inactive. Manual selection stays explicit because this is a firmware assignment rather than a complete host implementation. ")+"No downloaded code, reset, motor, setup or output packet executes. No GO+, PRIME4 or SC-player alias is added.",
    }


def prime_aio_profiles():
    results=[]
    for name,model,_ in AIO_MODELS:
        is_go=model=="JP11"
        short=name.removeprefix("Denon DJ ")
        result=profile(name,PRIME_AIO_REFERENCES[name]["url"])
        result.update(definition="reviewed:prime-aio-"+model.lower(),autoSelect=is_go,
                      aliases=[name,"Denon "+short,short],
                      excludedAliases=[x for x in ["PRIME GO","PRIME GO+","PRIME 2","PRIME 4","PRIME 4+","SC LIVE 2","SC LIVE 4"] if x!=short],
                      hardwareMode="Original "+short+" Computer-mode raw USB MIDI core. "+("Fixed A/B controls select automatically. " if is_go else "Select manually with a separate software audio path. ")+"Pads, jogs, displays and automatic audio routing remain unavailable.",
                      scope=("Automatic" if is_go else "Manual")+" fixed A/B transport, held Cue/bends, source-defined mixer/loops. "+("Paired inverted tempo and browser. " if is_go else "Tempo/browse remain unqualified. ")+"Full modes/output/lifecycle/audio and physical acceptance remain open.")
        if is_go:add(result,"shift",15,8)
        else:
            for side in range(2):
                add(result,"shift",side+2,28)
                result["inputs"][-1]["shiftInput"]=side
        for index,deck in enumerate("ab"):
            channel=index+2
            buttons=[("play",10),("cuePreview",9),("sync",8),("pitchBendDown",29),("pitchBendUp",30)]
            buttons += [("loop",39)] if is_go else [("keylock",34),("loopIn",37),("loopOut",38)]
            for action,number in buttons+[("load",index+1)]:
                add(result,action,15 if action=="load" else channel,number,deck=deck)
                result["inputs"][-1]["shifted"]=False
                if action not in {"cuePreview","pitchBendDown","pitchBendUp"}:
                    release=deepcopy(result["inputs"][-1]);release.update(shifted=True,releaseOnly=True)
                    result["inputs"].append(release)
            add(result,"loopSize",channel,32,"control","twosComplement",deck)
            result["inputs"][-1]["shifted"]=False
            if is_go:
                add(result,"tempo",channel,31,"control","paired14Bit",deck)
                result["inputs"][-1].update(lowNumber=75,inverted=True,shifted=False)
            for action,number in [("gain",3),("high",4),("mid",6),("low",8),("level",14)]:
                add(result,action,index,number,"control",deck=deck)
            add(result,"cue",index,13,deck=deck)
        for action,number in [("cueMix",12),("monitor",13),("crossfader",14)]:
            add(result,action,15,number,"control")
        if is_go:
            add(result,"browse",15,5,"control","twosComplement")
            result["inputs"][-1].update(inverted=True,shifted=False)
        result["gaps"]=["Original "+short+" only. "+("Automatic core input after Computer-mode selection, not full zero-config. " if is_go else "Manual firmware-defined subset; host setup and audio ownership remain unqualified. ")+"Pads/Bank/mode selectors, dual Color FX, jog/touch/calibration, displays, full output/setup/lifecycle/audio and physical/A10X acceptance remain open. No sibling protocol or persistent setting is inferred."]
        results.append(result)
    return results
