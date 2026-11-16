"""Reviewed protocol facts from the hash-locked controller references."""


def hercules_handlers(prefix, jog_name="scratchWheel"):
    return {prefix + "." + name: fact for name, fact in {
        "wheelTouch": ("jogTouch", "absolute"),
        "wheelTouchShift": ("jogTouch", "absolute"),
        jog_name: ("jog", "twosComplement"),
        "bendWheel": ("wheelJog", "twosComplement"),
    }.items()}


REVIEWED = {
    "Hercules_DJControl_Inpulse_200.midi.xml": {
        "script": "Hercules-DJControl-Inpulse-200-script.js",
        "handlers": hercules_handlers("DJCi200"),
        "startup": [[0x91, 3, 127], [0x92, 3, 127], [0x90, 4, 5], [0xB0, 127, 127]],
        "shutdown": [[0xB0, 127, 126], [0x90, 4, 0]],
    },
    "Hercules_DJControl_Inpulse_300.midi.xml": {
        "script": "Hercules-DJControl-Inpulse-300-script.js",
        "handlers": hercules_handlers("DJCi300", "jogWheel"),
        "startup": [[0x91, 3, 127], [0x92, 3, 127], [0x90, 4, 5], [0xB0, 127, 127]],
        "shutdown": [[0xB0, 127, 0]],
    },
    "Hercules DJControl Starlight.midi.xml": {
        "script": "Hercules-DJControl-Starlight-scripts.js",
        "handlers": hercules_handlers("DJCStarlight"),
        "startup": [[0x90, 36, 0], [0x91, 3, 127], [0xB0, 127, 127]],
        "shutdown": [[0x90, 36, 127]],
    },
}


def numark_classic_review(model):
    return {
        "script": f"Numark-{model}-Control-scripts.js",
        "handlers": {
            "NumarkTotalControl.jogWheel": ("wheelJog", "twosComplement", 128),
            "NumarkTotalControl.selectKnob": ("browse", "twosComplement"),
        },
        "startup": [],
        "shutdown": [[0x90, number, 0] for number in [53, 64, 62, 78, 54, 65]],
        "scope": "Automatic native core controls from pinned XML and reviewed normal-mode jog/browser handlers. Scratch/directory modes, cue preview, extended/manual loop script semantics, fine pitch, FX, remaining feedback and audio routing remain open.",
    }


for model in ["Total", "Omni"]:
    REVIEWED[f"Numark {model} Control.midi.xml"] = numark_classic_review(model)


REVIEWED["Hercules DJControl MIX.midi.xml"] = {
    "script": "Hercules-DJControl-MIX-scripts.js",
    "handlers": {
        "DJCMIX.wheelTouch": ("jogTouch", "absolute"),
        "DJCMIX.wheelTouchShift": ("jogTouch", "absolute"),
        "DJCMIX.scratchWheel": ("jog", "twosComplement", 248),
        "DJCMIX.scratchWheelShift": ("jog", "twosComplement", 62, {4: "a", 5: "b"}),
        "DJCMIX.bendWheel": ("wheelJog", "twosComplement", 248),
    },
    "startup": [[0x91, 3, 127], [0xB0, 127, 127]],
    "shutdown": [[0xB0, 127, 0]],
    "scope": "Automatic native core controls from pinned XML and reviewed jog/lifecycle facts. Shifted jog channel 5 follows the script's right deck despite the XML group typo. Vinyl remains enabled. Cue/master modes, pad loops, samplers, FX, full feedback and audio routing remain open.",
}
