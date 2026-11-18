"""Original RANE ONE manual inputs from its independent public iPad owner export."""
from copy import deepcopy
from curated import add, profile

ONE_NAME="Rane ONE"
ONE_URL="https://community.algoriddim.com/uploads/short-url/vo8FDgWWHvGsLvDLlam7YEsosU6.djayMidiMa"
ONE_SHA="a13eaa48a39d93db5b7868896017b4f8f79bba8182ef09604262acd0716dfe60"
ONE_BUTTONS=[("play","playPause",0,0),("load","load",0,6),("sync","bpmSync",0,2),("keylock","key",0,13),
             ("pitchBendDown","pitchBendMinus",0,12),("pitchBendUp","pitchBendPlus",0,11),
             ("loop","autoLoopOnOff",4,63),("reloop","reloop",4,65),
             ("loopDown","autoLoopDurationHalf",4,52),("loopUp","autoLoopDurationDouble",4,53),("loopIn","loopIn",4,54)]
ONE_ROWS=[dict(keyPath="application.modifier",midiChannel=15,midiData=50,midiMessageType=1)]
for index in range(2):
    for action,key,offset,number in ONE_BUTTONS:
        ONE_ROWS.append(dict(keyPath=("musicLibrary.load"+str(index+1) if action=="load" else f"turntable{index+1}."+key),
                             midiChannel=index+offset,midiData=number,midiMessageType=1))
    ONE_ROWS.append(dict(keyPath="musicLibrary.libraryRotary",midiChannel=index,midiData=0,midiMessageType=3,controlType="rotary-64",flipped=True))
ONE_REFERENCES={ONE_NAME:{
    "url":ONE_URL,"sha256":ONE_SHA,
    "relatedSources":[{"url":"https://community.algoriddim.com/t/sharing-my-edited-rane-one-mapping-for-ipad/15719"},
                      {"url":"https://community.algoriddim.com/t/rane-one-midi-mapping/26978"}],
    "review":"Independent original RANE ONE owner export:180495 bytes,462 control rows, version4, endpoint RANE One and customClassName RaneOne. Source author states iPad use and describes custom pad/stem/mic remaps; another owner reports testing. Import only25 explicit unconditional rows: global Shift channel15 Note50; Play0/Load6/Sync2/Keylock13/held bends12 and11 on0/1; loop63/reloop65/half52/double53/in54 on4/5; rotary-64 flipped BrowseCC0 on0/1. Numbered cuePositionOrJumpConsideringPlayState1 does not prove held main Cue. Sync3 has no buttonMode off, unlike MKII, and is inactive. Original loopOutAndReloopOrUnloop55 is not silently converted to MKII's out-or-double action and stays inactive. Motor/platter, CC9 pitch pairing/polarity/range, scrubbing43, custom pads/stems/mic remaps, mixer/audio ownership and full RaneOne lifecycle remain unimplemented. Native normal controls use global Shift and shifted release aliases. No source class/XML code executes. No output/setup/motor packet is sent. Original ONE and ONE MKII remain separate manual profiles. Full lifecycle/audio and physical/A10X acceptance remain open.",
}}


def rane_one_profiles():
    result=profile(ONE_NAME,ONE_URL)
    result.update(definition="reviewed:rane-one-owner-core",autoSelect=False,
                  aliases=[ONE_NAME,"RANE One","RANE ONE Control"],
                  excludedAliases=["RANE ONE MKII","RANE ONE MK2","RANE FOUR","RANE PERFORMER","RANE SYSTEM ONE"],
                  hardwareMode="Manual original RANE ONE normal MIDI subset. Motor/platter, main Cue, complete pitch and RaneOne setup remain inactive. Configure audio separately. ONE MKII is a separate model.",
                  scope="Manual original-model Play/Load/Sync/keylock, held bends, known loops and browser. Motor/platter, main Cue/pitch, full modes/output/lifecycle/audio and physical acceptance remain open.")
    add(result,"shift",15,50)
    for index,deck in enumerate("ab"):
        for action,_,offset,number in ONE_BUTTONS:
            add(result,action,index+offset,number,deck=deck)
            result["inputs"][-1]["shifted"]=False
            if action not in {"pitchBendDown","pitchBendUp"}:
                release=deepcopy(result["inputs"][-1]);release.update(shifted=True,releaseOnly=True)
                result["inputs"].append(release)
        add(result,"browse",index,0,"control","binaryOffset")
        result["inputs"][-1].update(inverted=True,shifted=False)
    result["gaps"]=["Manual original ONE only. RaneOne class/setup, motor/platter, held main Cue, exact pitch, ambiguous Sync3/loop-out55, custom pads/stems/mic mappings, mixer/audio ownership, full output/lifecycle and physical/A10X acceptance remain open. No motor, persistent setting or output command is sent. ONE MKII is not an alias."]
    return [result]
