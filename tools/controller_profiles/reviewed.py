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
