"""Original nanoKONTROL read-only scene contract; this model has no native mode."""
from curated import add, profile

SCENE_NAME="Korg nanoKONTROL"
SCENE_SPEC="https://cdn.korg.com/us/support/download/files/2f509a92db41920e950a23cbe5edb481.txt"
SCENE_SPEC_SHA="dcd048e21fe8c4ab580a929df86bb25c8a764710e770d38b1a31e027b4a6c242"
SCENE_REFERENCES={SCENE_NAME:{
    "url":SCENE_SPEC,"sha256":SCENE_SPEC_SHA,
    "review":"Korg original model04 revision1.00 explicitly provides Search Device, current Scene Data Request and Scene Change notifications. It has no native mode. Discover model/global channel before sending only the11-byte1F/10 current-scene query. Validate the307-byte response, unpack293 seven-bit bytes into256 parameter bytes, and read channels/ranges/assignment types. Never send native mode, scene change14, scene write11 or a host data dump40. Serialise requests and discard replies when another scene notification arrived while waiting, because dumps carry no scene number. Duplicate wire assignments, including collisions with unused strips/transport controls, are inactive. Constant ranges, ramped buttons, disabled/unknown controls and transport/MMC do not become app actions. A fixed native layout uses physical strips1-4 for A-D level/filter/PFL/keylock, strips5-8 faders for master/headphone level/blend/crossfader and their knobs for A-D gain. Buttons retain momentary software toggles or explicit latched PFL/keylock state. Custom channels and reversed/limited ranges retain physical direction through logical normalisation. Ninth strip and other switches remain inactive. Existing saved raw mappings take priority until explicit profile replacement. Current scenes are read without modifying stored data. Full transport/layers/output/timeout recovery and physical/A10X acceptance remain open. No audio interface or nanoKONTROL2 native protocol is inferred.",
}}


def nanokontrol_scene_profiles():
    result=profile(SCENE_NAME,SCENE_SPEC)
    result.update(definition="manufacturer:nanokontrol-current-scene",role="accessory",inputProtocol="nanoKontrolScene",
                  aliases=[SCENE_NAME,"nanoKONTROL","nanoKONTROL MIDI 1","nanoKONTROL 1 SLIDER/KNOB","nanoKONTROL SLIDER/KNOB"],
                  excludedAliases=["nanoKONTROL2","nanoKONTROL 2","nanoKONTROL Studio","nanoPAD","nanoKEY"],
                  hardwareMode="Automatic read-only current-scene mixer through a paired output. Strips1-4: A-D level/filter/PFL/keylock. Strips5-8: global faders and A-D gain knobs. Existing raw custom mappings remain in use until replaced. No scene or mode write is sent.",
                  scope="Automatic scene-aware fixed mixer preserving physical assignments, custom channels/ranges and button types. Duplicate wires and unimplemented controls stay inactive. Full layers/transport/lifecycle and physical acceptance remain open.")
    result["startup"]=[[0xF0,0x42,0x50,0,0x2D,0xF7]]
    for index,deck in enumerate("abcd"):
        for action,number in [("level",index),("filterKnob",4+index),("gain",8+index),
                              ("cueState",64+index),("keylockState",68+index)]:
            add(result,action,0,number,"control",deck=deck)
        add(result,"cue",0,32+index,deck=deck)
        add(result,"keylock",0,36+index,deck=deck)
    for action,number in [("master",12),("monitor",13),("cueMix",14),("crossfader",15)]:add(result,action,0,number,"control")
    result["gaps"]=["Read-only fixed physical mixer layout, not the upstream downloadable custom scene. Paired output and valid requested scene are required. Ninth strip, transport/MMC, ramped buttons, extra switches, disabled/duplicate assignments, full layers/output, response timeout/recovery and physical/A10X acceptance remain open. No native mode, scene change/write, reset, firmware or audio route is sent."]
    return [result]
