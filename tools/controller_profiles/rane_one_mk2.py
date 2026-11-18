"""RANE ONE MKII manual controls corroborated by independent public exports."""
from copy import deepcopy
from curated import add, profile

ONE2_NAME="Rane ONE MKII"
ONE2_REVISION="59a2b6a81451edb71b0a3c8947d09c9472c3c4d1"
ONE2_BASE="https://raw.githubusercontent.com/Reign-712/Rane-MKII-djay/"+ONE2_REVISION+"/"
ONE2_URL=ONE2_BASE+"Rane-MKII-djay-Midi-Map.zip"
ONE2_SHA="64de686e2100a2718bcbcda4f3fbd87290ee35be00e17d6008ee1c80b778e6b8"
ONE2_ROWS=[]
for index in range(2):
    for key,channel,number,extra in [
        ("libraryRotary",index,0,{"flipped":True}), ("loadTrack",index,6,{}),
        ("bpmSync",index,2,{}), ("bpmSync",index,3,{"buttonMode":"off"}),
        ("key",index,13,{}), ("pitchBendMinus",index,12,{}), ("pitchBendPlus",index,11,{}),
        ("autoLoopOnOff",index+4,63,{}), ("reloop",index+4,65,{}),
        ("autoLoopDurationHalf",index+4,52,{}), ("autoLoopDurationDouble",index+4,53,{}),
        ("loopIn",index+4,54,{}), ("loopOutOrDouble",index+4,55,{}),
    ]:
        ONE2_ROWS.append(dict(keyPath=f"turntable{index+1}."+key,midiChannel=channel,midiData=number,
                              midiMessageType=3 if key=="libraryRotary" else 1,**extra))
ONE2_REFERENCES={ONE2_NAME:{
    "url":ONE2_URL,"sha256":"360b582fbcb9963318d61f4b1d6d62a75900ef03c6b24b518e0c764dbcc8f0c6",
    "revision":ONE2_REVISION,"archiveMember":"Rane-MKII-djay/RANE One MK2 Edit 1.djayMidiMapping","memberSha256":ONE2_SHA,
    "relatedSources":[{"url":ONE2_BASE+"README.md","sha256":"65b7489accd82b6281aa65d4300266696ff299b90d9e900adb647e57a81e2742"},
                      {"url":"https://drive.google.com/file/d/1yBQ4jeM7oBpswsmKOf5WhgFYFqGWDQxc/view"}],
    "review":"Independent public owner export version1/606 rows and earlier staff version3/667 rows agree exactly on26 selected unconditional deck control rows. Both depend on absent RaneOneMK2 class and omit normal Play. Native manual subset uses Load6/Sync2/explicit Sync-off3/Keylock13/held bend12 and11 on channels0/1, loops63/65/52/53/54/55 on4/5 and flipped rotary64 BrowseCC0 on0/1. Loop Out retains out-or-double. The explicit Sync-off row has buttonMode off and remains layer-independent; no ordinary Sync press is inferred to mean off. Shared Shift comes from the explicit Shift heading's Note50/channel15. Normal controls are guarded and shifted release aliases rearm their known actions. Numbered cuePositionOrJumpConsideringPlayState1 is not assumed to establish held main Cue. No missing normal Play, motor/platter timestamps/counters, CC9/LSB pitch pair, external mixer level/EQ, conditional pads/stems/FX or complete output/lifecycle/audio route is inferred. Downloaded map/class code does not execute in the app. Automatic selection stays off. Original ONE, FOUR, PERFORMER and SYSTEM ONE stay separate. Physical/A10X acceptance remains open.",
}}


def rane_one_mk2_profiles():
    result=profile(ONE2_NAME,ONE2_URL)
    result.update(definition="reviewed:rane-one-mkii-corroborated",autoSelect=False,
                  aliases=[ONE2_NAME,"RANE ONE MKII","Rane ONE MK2","Rane ONE MKII Control"],
                  excludedAliases=["RANE ONE","RANE FOUR","RANE PERFORMER","RANE SYSTEM ONE"],
                  hardwareMode="Manual unconditional ONE MKII MIDI subset through the connected USB source. Native Play/main Cue, motor/platter, paired pitch and custom-class lifecycle remain unimplemented. Separate external mixer audio required.",
                  scope="Manual independently corroborated Load, Sync/explicit off, keylock, held bend, loops and browser. No normal Play/main Cue/motor or automatic support is claimed.")
    add(result,"shift",15,50)
    for channel,deck in enumerate("ab"):
        for action,wire,number in [("load",channel,6),("sync",channel,2),("keylock",channel,13),
                                   ("pitchBendDown",channel,12),("pitchBendUp",channel,11),
                                   ("loop",channel+4,63),("reloop",channel+4,65),("loopDown",channel+4,52),
                                   ("loopUp",channel+4,53),("loopIn",channel+4,54),("loopOutOrDouble",channel+4,55)]:
            add(result,action,wire,number,deck=deck)
            result["inputs"][-1]["shifted"]=False
            if action not in {"pitchBendDown","pitchBendUp"}:
                release=deepcopy(result["inputs"][-1]);release.update(shifted=True,releaseOnly=True)
                result["inputs"].append(release)
        add(result,"syncDisable",channel,3,deck=deck)
        result["inputs"][-1]["layerIndependent"]=True
        add(result,"browse",channel,0,"control","binaryOffset")
        result["inputs"][-1].update(inverted=True,shifted=False)
    result["gaps"]=["Manual unconditional controls only. RaneOneMK2 class, normal Play, held main Cue, motor/platter, complete pitch pairing/polarity/range, hardware/software mixer ownership and separate deck audio, conditional pads/stems/FX, full output/lifecycle and physical/A10X acceptance remain open. Source custom assignments are not factory compatibility for other RANE models. No motor, setup or output command is sent."]
    return [result]
