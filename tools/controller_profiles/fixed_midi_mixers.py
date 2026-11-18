"""Independent default-layer mixer facts for two distinct USB-MIDI controllers."""
from curated import add, profile
from numark import UPSTREAM

FIXED_MIXER_SOURCES = {
    "M-Vave SMC-Mixer": [
        ("MVave-SMC-Mixer.midi.xml", "daca4d1f4600618c49e8b253bd542fec939d1339288009e0de5283a3f3f54638"),
        ("MVave-SMC-Mixer-scripts.js", "606e2bf0aa7a5a4a7256dd59fc96cf2d3f4868ebc0c102e8fed40d80d3cf535c"),
    ],
    "Icon iControls": [
        ("Icon-iControls.midi.xml", "9f2f635393abc48434938e2ac5fc84b209fdaf54ef4a36745c9e97c40b460df0"),
        ("Icon-iControls-scripts.js", "6e44c621405cc6efe0c315c8f8c5d45cbf46ced39012aa08823667fc98f9078e"),
    ],
}
FIXED_MIXER_REFERENCES = {name: {
    "url": UPSTREAM+sources[0][0], "sha256": sources[0][1],
    "relatedSources": [{"url": UPSTREAM+sources[1][0], "sha256": sources[1][1]},
                       {"url": "https://manual.mixxx.org/2.5/en/hardware/controllers/"+
                        ("mvave_smc_mixer" if name.startswith("M-Vave") else "icon_icontrols")}],
    "review": "Independent pinned XML/script and upstream manual confirm physical C/A/B/D strip order. Pitch-bend channels0..3 control levels and4..7 control tempo; native uses standard MIDI normalisation and the established reversed Mixxx rate direction. No extra physical fader or EQ pot is invented. " + (
        "SMC-Mixer default gain encoders are CC16..19. Their literal handler decrements0.01 only for raw65; every other seven-bit value increments0.01. Master20, headphone level22 and cue mix23 share that handler. Note4..7 toggles keylock; Note28..31 toggles headphone PFL. Note96/97 move up/down in the library. Long-press EQ/filter knob reassignment, kill buttons, Slip/Quantize, selected-deck transport, recording, focus, balance and blinking pickup LEDs remain inactive. No invalid source LED packet is inherited. Use one USB-C connection; Bluetooth pairing/duplicate-route handling remains unqualified."
        if name.startswith("M-Vave") else
        "iControls layer1 gain encoders are CC16..19 and filter encoders20..23. Their literal handler uses raw<=64 positive, otherwise raw-minus128, divided by100. Counts retain their magnitude, not only their sign. PFL is Note8..11 and filter enable is Note20..23. Pitch-bend channel8 controls crossfader, while master gain is ordinary CC12. XML wire facts override unused component MIDI descriptors. The upstream manual states that only hardware layer1 is distinguishable in the default configuration. Shared transport/deck selection, other hardware layers, Slip, effect selection, recording and joystick mouse behaviour remain inactive. No iControls Pro alias is inferred.") +
        " Both initialisers construct software state without an input handshake. Native input cores execute no downloaded script and emit no unqualified feedback/reset/audio packet. Named ports only. Full modes/output/lifecycle, calibration, direct USB attachment and physical/A10X acceptance remain open.",
} for name,sources in FIXED_MIXER_SOURCES.items()}


def fixed_mixer_profiles():
    results = []
    for name,reference in FIXED_MIXER_REFERENCES.items():
        smc = name.startswith("M-Vave")
        result = profile(name,reference["url"])
        result["definition"] = "reviewed:"+("smc-mixer" if smc else "icon-icontrols")
        result["hardwareMode"] = "Named USB-MIDI endpoint, fixed default C/A/B/D strips. " + (
            "USB-C only; Bluetooth pairing remains unqualified." if smc else "Default hardware layer1 only.")
        result["scope"] = "Automatic fixed four-target mixer input core, independent level/tempo faders, default encoders and PFL. Shared transport, alternate modes/output and physical acceptance remain open."
        result["excludedAliases"] = ["SMK-25 II", "SMC-PAD"] if smc else ["iControls Pro", "Icon iControls Pro", "iControl"]
        for strip,deck in enumerate("cabd"):
            for action,channel in [("level",strip),("tempo",strip+4)]:
                add(result,action,channel,0,"pitch",deck=deck)
                if action == "tempo": result["inputs"][-1]["inverted"] = True
            add(result,"gain",0,16+strip,"control","smcMixerEncoder" if smc else "iconVelocity",deck)
            add(result,"cue",0,(28 if smc else 8)+strip,deck=deck)
            if smc:
                add(result,"keylock",0,4+strip,deck=deck)
            else:
                add(result,"filterKnob",0,20+strip,"control","iconVelocity",deck)
                add(result,"filterToggle",0,20+strip,deck=deck)
        if smc:
            for action,number in [("master",20),("monitor",22),("cueMix",23)]:
                add(result,action,0,number,"control","smcMixerEncoder")
            for action,number in [("browsePrevious",96),("browseNext",97)]:
                add(result,action,0,number)
        else:
            add(result,"master",0,12,"control")
            add(result,"crossfader",8,0,"pitch")
        result["gaps"] = ["Fixed default C/A/B/D mixer only. Shared transport/deck selection, full software layers, Slip/Quantize, recording, feedback/lifecycle and native calibration remain open. " + (
            "Long-press EQ/filter reassignment and kill buttons remain inactive; default encoder action is gain. Balance, focus, Bluetooth pairing/duplicate routes and LEDs remain unqualified."
            if smc else "Only distinguishable default hardware layer1 is qualified. Other layers, effect selection, joystick mouse and iControls Pro remain separate.") +
            " No unqualified output/reset/audio packet executes. Physical USB and A10X acceptance remain open."]
        results.append(result)
    return results
