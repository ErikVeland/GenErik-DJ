"""Independent Euphonia fixed mixer inputs from the manufacturer E10 table."""
from curated import add, profile

EUPHONIA_NAME="AlphaTheta Euphonia"
EUPHONIA_MANUAL="https://downloads.support.alphatheta.com/software_info/dj-mixers/euphonia/euphonia_MIDI_Message_List_E10.pdf"
EUPHONIA_SHA="45631b77a6806762fe4b5a3231037672ba707f55177a7717f5ac2b04bd88840b"
EUPHONIA_STRIPS=[(1,2,3,4,17,10),(6,7,8,9,18,11),(12,14,15,21,19,12),(80,81,92,82,20,13)]
EUPHONIA_REFERENCES={EUPHONIA_NAME:{
    "url":EUPHONIA_MANUAL,"sha256":EUPHONIA_SHA,"pages":[2,3],
    "relatedSources":[{"url":"https://alphatheta.com/en/product/dj-mixer/euphonia/black/"},
                      {"url":"https://device.report/m/217fbf926569a640321f6ef342d7fa9ba90f26bc2fdc649cbac24fc5f8eb54e0_optim.pdf"}],
    "review":"Independent E10 manufacturer table, visually checked pages2/3. All messages use wire channel0. Physical CH1/2/3/4 independently retain gain/high/mid/low/rotary-level CC tuples01/02/03/04/11,06/07/08/09/12,0C/0E/0F/15/13,50/51/5C/52/14. In particular CH4 Mid is5C and its Low is52. PFL notes0A/0B/0C/0D are explicitly Toggle00:OFF/7F:ON, so native direct cue state preserves both on and off without toggle edge priming or pickup. MasterCC18, headphone level1A and blend1B are separate from booth level19. Map physical CH1-4 to app A-D only for manual app mixer control through separate audio; C/D retain app opt-in. The USB/MIDI section requires configured desktop software and dedicated audio software; it does not qualify a native iPad audio route. Hardware audio still responds to its controls. No implicit double hardware/software mixer path or source-selector change is configured. The table contains MIDI-IN to computer only and is not LED-output proof. Mic/source selectors, booth EQ/level, isolator/send/FX, display/brightness/master insert/mono and timing clock remain inactive. Full hardware/software audio ownership, driver/platform setup, lifecycle and physical/A10X acceptance remain open. No stored setting, reset or output packet is sent.",
}}


def euphonia_profiles():
    result=profile(EUPHONIA_NAME,EUPHONIA_MANUAL)
    result.update(definition="manufacturer:euphonia-e10",role="accessory",autoSelect=False,
                  excludedAliases=["DJM-A9","DJM-A7","DJM-V10","MP2015","MP2014"],
                  hardwareMode="Manual Euphonia app mixer control through separate audio. Physical CH1-4 map to A-D; C/D require app opt-in. Hardware/software audio ownership, driver/platform setup and routing remain unqualified.",
                  scope="Manual fixed four-strip gain/EQ/rotary-level and latched PFL state, with master/headphone blend/level. Isolator/send/FX, other hardware modes, output/lifecycle/audio and physical acceptance remain open.")
    for deck,addresses in zip("abcd",EUPHONIA_STRIPS):
        for action,number in zip(["gain","high","mid","low","level","cueState"],addresses):
            add(result,action,0,number,"note" if action=="cueState" else "control",deck=deck)
    for action,number in [("master",24),("monitor",26),("cueMix",27)]:
        add(result,action,0,number,"control")
    result["gaps"]=["Manual fixed app mixer controls through separate audio only. Hardware/software ownership, driver/platform setup, complete routing, isolator/send/FX, display/settings, full output/lifecycle and physical/A10X acceptance remain open. No automatic route, source-selector change, MIDI clock, stored setting, reset or output command is inferred."]
    return [result]
