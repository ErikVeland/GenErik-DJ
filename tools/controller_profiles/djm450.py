"""Independent DJM-450 manufacturer MIDI facts for manual app mixing."""
from curated import add, profile

DJM450_NAME = "Pioneer DJM-450"
DJM450_SPEC = "https://www.recordcase.de/media/pdf/84/26/2c/Pioneer-DJM-450-Addendum-EN.pdf"
DJM450_REFERENCES = {DJM450_NAME: {
    "url":DJM450_SPEC,"sha256":"eca0374d463ab83b30716a775b584579485eef1f6033a5abf0063d5150d75c49","pages":[1,2,3],
    "review":"All three manufacturer-authored Version1.00 wire pages visually reviewed through a public retailer mirror. Physical CH1/2 independently specify gain/EQ/Color/fader and CC70/71 Cue state. Channel1 is an explicit manual choice; no factory channel or button-type default is inferred. Select TOGGLE for direct Cue state. Crossfader11, master24 and headphones26/blend27 retain seven-bit normalisation. Only native A/B are targeted. Hardware keeps its own processing; use separate app audio until external mixer ownership/routing is implemented. Master Cue, EQ/curve/reverse switches, FX/time/send-return, AUX/microphone, clock, complete output/lifecycle/calibration and physical/A10X acceptance remain open. No sibling wires, feedback, setting write or audio route are inferred.",
}}


def djm450_profiles():
    result = profile(DJM450_NAME,DJM450_SPEC)
    result.update(autoSelect=False,role="accessory",aliases=[DJM450_NAME,"Pioneer DJ DJM-450","DJM-450","DJM-450 MIDI 1"],
                  excludedAliases=["DJM-250","DJM-250MK2","DJM-S3","DJM-750MK2","DJM-900NXS2"],
                  hardwareMode="Manual MIDI channel1 and BUTTON TYPE TOGGLE, with separate app audio. Physical CH1/2 map to native A/B. No factory channel/button-type default is inferred.",
                  scope="Manual independent two-strip gain/EQ/filter/fader and direct CC PFL-state core with master/headphone/crossfader app controls. No automatic audio routing or hardware FX emulation.",
                  gaps=["Manual MIDI channel1/TOGGLE only; no factory defaults inferred. Physical taper/calibration, hardware/software audio ownership, external deck routing, master Cue, EQ/curve/reverse switches, FX/time/send-return, AUX/microphone/clock, complete output/lifecycle and physical/A10X acceptance remain open. No output, stored-setting write, sibling protocol or audio route is inferred."])
    for index,(deck,numbers) in enumerate(zip("ab",[(1,2,3,4,5,17),(6,7,8,9,10,18)])):
        for action,number in zip(["gain","high","mid","low","filterKnob","level"],numbers):
            add(result,action,0,number,"control",deck=deck)
        add(result,"cueState",0,70+index,"control",deck=deck)
    for action,number in [("master",24),("monitor",26),("cueMix",27),("crossfader",11)]:
        add(result,action,0,number,"control")
    return [result]
