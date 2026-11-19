"""nanoKONTROL2 transient native-mode mixer contract from Korg's protocol."""
from curated import add, profile
from numark import UPSTREAM

NANO2_NAME="Korg nanoKONTROL2"
NANO2_SPEC="https://cdn.korg.com/us/support/download/files/aeb2862daf0cb7db826d8c62f51ec28d.txt"
NANO2_SPEC_SHA="87d1d5cbd25bdfce29b77a4b7ce1ebb1e53683a5cd22ab41913df8fb1a54d250"
NANO2_SOURCES=[
    ("Korg nanoKONTROL 2.midi.xml","a19c7e408bc1f1045988c9e4c0ef55fc9d7eab3fd0ff1d12ed6e41bb092c5422"),
    ("Korg-nanoKONTROL-2-scripts.js","285927c6c799aab43b9ee2f5e01939c8c98c9f463b1edbf883f0065c0a093de9"),
]
NANO2_REFERENCES={NANO2_NAME:{
    "url":NANO2_SPEC,"sha256":NANO2_SPEC_SHA,
    "relatedSources":[{"url":UPSTREAM+name.replace(" ","%20"),"sha256":digest} for name,digest in NANO2_SOURCES]+[
        {"url":"https://www.korg.com/us/support/download/manual/0/159/2710/"}],
    "review":"Korg revision1.00 defines Search Device F0/42/50/00/echo/F7 and a15-byte model reply carrying global channel, echo and family13/01/member00/00. The configured global channel addresses an11-byte native-mode request. Only a matching Command40/00/03 reply enables controls. Native mode fixes input/output to channel16 regardless of saved scenes; no scene-data dump/write, factory reset or persistent programming is sent. Exit uses the discovered global channel and native Out request. The reviewed upstream default N layout independently supplies dedicated A/B/C/D volume CC0..3, PFL buttons64..67 and headphone blend knob18. Native CC buttons become logical notes, preserving their first press and release. Marker60/61/62 are held guards; faders remain independent. This is a fixed native mixer, not the upstream latched NSMR/selected-deck software layout. Other buttons/sliders/knobs and DAW/custom traffic are inactive. Four PFL lamps use native BF64..67 with127/on and0/off, after acknowledgement only. Missing/malformed/foreign replies or paired send failure cannot enable input or ordinary output. No original nanoKONTROL/nanoPAD/Studio sibling protocol or audio interface is inferred. Full software layers, timeout/recovery/lifecycle and physical/A10X acceptance remain open.",
}}


def nanokontrol2_profiles():
    result=profile(NANO2_NAME,NANO2_SPEC)
    result.update(definition="reviewed:nanokontrol2-native-fixed-mixer",role="accessory",inputProtocol="nanoKontrol2Native",
                  aliases=[NANO2_NAME,"nanoKONTROL2","nanoKONTROL2 SLIDER/KNOB","nanoKONTROL2 1 SLIDER/KNOB","nanoKONTROL2 CTRL","nanoKONTROL2 1 CTRL"],
                  excludedAliases=["nanoKONTROL","nanoKONTROL Studio","nanoPAD2","nanoKEY2"],
                  hardwareMode="Automatic native KORG mode through a paired output after model/channel acknowledgement. Fixed native A/B/C/D volume/PFL and headphone blend. C/D requires app opt-in. Saved scene data stays unchanged.",
                  scope="Automatic acknowledged native-mode fixed four-strip mixer core and PFL lights. Complete software layers/output/lifecycle and physical acceptance remain open.")
    result["startup"]=[[0xF0,0x42,0x50,0,0x2D,0xF7]]
    for number in [60,61,62]: add(result,"shift",0,number)
    for index,deck in enumerate("abcd"):
        add(result,"level",0,index,"control",deck=deck)
        result["inputs"][-1]["layerIndependent"]=True
        add(result,"cue",0,64+index,deck=deck)
        result["inputs"][-1]["shifted"]=False
        result["outputs"].append(dict(action="cue"+("A" if deck in "ac" else "B"),kind="control",channel=15,
                                      number=64+index,targetDeck=deck,onValue=127,offValue=0,offUsesNoteOn=False))
    add(result,"cueMix",0,18,"control")
    result["inputs"][-1]["shifted"]=False
    result["gaps"]=["Fixed native mixer only. Latched NSMR/selected-deck layers, mute/slip/transport, sampler channels, selected EQ/key/FX controls, full lighting, response timeout/recovery and complete lifecycle remain open. Native-mode exit restores normal operation without writing scenes. USB and physical/A10X acceptance remain open. No audio interface is inferred."]
    return [result]
