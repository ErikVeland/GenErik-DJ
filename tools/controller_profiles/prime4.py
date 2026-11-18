"""Manual PRIME 4 contracts from a pinned public owner mapping."""
from copy import deepcopy
from curated import add, profile

PRIME4_REVISION="83701fd73dd1339bd4f9b7ce56ab00436adb68ac"
PRIME4_BASE="https://raw.githubusercontent.com/RattyDAVE/mixxx-Denon-Prime-4-controller/"+PRIME4_REVISION+"/"
PRIME4_SOURCES=[
    ("Denon-Prime-4.midi.xml","d03623af76b4f49c60866d012e11d5490695d5a85c079abd339e1d6ecc8b62c7"),
    ("Denon-Prime-4-scripts.js","a19c8158076da9951f59179b8b452677d2e2f8fc53feaa7857b620cee57daf43"),
    ("prime4-README.md","2e6d381a38ad7798b7d4db88cb88a3abca781db0057031dc26d3306fc3bcbebb"),
]
PRIME4_REFERENCES={name:{
    "url":PRIME4_BASE+"Denon-Prime-4.midi.xml","sha256":PRIME4_SOURCES[0][1],"revision":PRIME4_REVISION,
    "relatedSources":[{"url":PRIME4_BASE+"Denon-Prime-4-scripts.js","sha256":PRIME4_SOURCES[1][1]},
                      {"url":PRIME4_BASE+"README.md","sha256":PRIME4_SOURCES[2][1]},
                      {"url":"https://github.com/ultra-vi-olet/denon-prime-4-analysis"}],
    "review":"Public repository explicitly covers PRIME4 and4+ and reports Mac/Linux testing. XML declares physical deck channels4/5 and shared Load channel15 Notes1/2. Script independently defines deck selection channel15 Notes28..31, starts software A/B and retains per-deck pad mode. Native source-local adapter routes normal Play10/Cue9/Sync8/Keylock34/bends29/30/loop-in37/out38, paired pitchCC31/75 with source inversion, exact loop-sizeCC32 values1/127 and HotCue raw pads15..22 only in mode11. Modes12..14 disable pads. Logical deck channels4..7 and Load126 cannot be injected through raw sibling channels. Each held button retains original deck/address and unsupported held pads cannot activate after a mode change. Both Shift buttons become one last-message global identity, as in source; normal buttons have shifted release aliases. Source all-in-one mixer ownership, browse direction, held beatloop trigger39, jog/touch/calibration, other pad/Shift/FX modes and screen protocols are not inferred. No source JavaScript executes. No reset, setup, output or motor packet is sent. Complete lifecycle/audio and physical/A10X acceptance remain open. Automatic selection stays off.",
} for name in ["Denon DJ PRIME 4","Denon DJ PRIME 4+"]}


def prime4_profiles():
    results=[]
    for name in PRIME4_REFERENCES:
        short=name.removeprefix("Denon DJ ")
        result=profile(name,PRIME4_REFERENCES[name]["url"])
        result.update(definition="reviewed:"+short.lower().replace(" ","-")+"-public-core",autoSelect=False,
                      aliases=[name,"Denon "+short,short],
                      excludedAliases=["PRIME 4+" if short=="PRIME 4" else "PRIME 4","PRIME 2","PRIME GO","SC LIVE 4","PRIME 4 G2"],
                      inputProtocol="denonPrime4",
                      hardwareMode="Manual raw "+short+" Computer-mode MIDI input. Software targets start A/B; hardware deck buttons select A/C and B/D. C/D need app opt-in. Only Hot Cue pad mode is active. Configure audio separately.",
                      scope="Manual source-local four-target transport, held Cue/bend, native loop-in/out, loop sizing, paired pitch, shared Load and Hot Cue1–8. Full modes/output/lifecycle/audio and physical acceptance remain open.")
        add(result,"shift",14,28)
        result["inputs"][-1]["shiftInput"]=0
        for index,deck in enumerate("abcd"):
            channel=4+index
            for action,number in [("play",10),("cuePreview",9),("sync",8),("keylock",34),
                                  ("pitchBendDown",29),("pitchBendUp",30),("loopIn",37),("loopOut",38),("load",126)]:
                add(result,action,channel,number,deck=deck)
                result["inputs"][-1]["shifted"]=False
                if action not in {"cuePreview","pitchBendDown","pitchBendUp"}:
                    release=deepcopy(result["inputs"][-1]);release.update(shifted=True,releaseOnly=True)
                    result["inputs"].append(release)
            for slot in range(8):
                add(result,f"hotcue{slot+1}",channel,64+slot,deck=deck)
                result["inputs"][-1]["shifted"]=False
                release=deepcopy(result["inputs"][-1]);release.update(shifted=True,releaseOnly=True)
                result["inputs"].append(release)
            add(result,"tempo",channel,31,"control","paired14Bit",deck)
            result["inputs"][-1].update(lowNumber=75,inverted=True,shifted=False)
            add(result,"loopSize",channel,32,"control","twosComplement",deck)
            result["inputs"][-1]["shifted"]=False
        result["gaps"]=["Manual raw Computer-mode only. Public owner export supports PRIME4/4+ but is not a complete manufacturer SDK. Mixer/software audio ownership and routing, browse encoding, held loop trigger, jog/touch/calibration, other pad/Shift/FX modes, screens, full output/setup/lifecycle and physical/A10X acceptance remain open. No sibling model or firmware compatibility is inferred."]
        results.append(result)
    return results
