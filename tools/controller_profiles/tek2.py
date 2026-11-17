"""TEK2 source preset with separate native scratch and unheld wheel paths."""
from curated import add, profile
from numark import UPSTREAM

TEK2_GUIDE = "https://manual.mixxx.org/2.5/en/hardware/controllers/intech_tek2"
TEK2_SOURCES = [
    ("Intech TEK2.midi.xml", "83b5467bc8197cfe9c7289118f17c5ba4dc074598ae71f6fee31e4dbfb82c734"),
    ("Intech TEK2.scripts.js", "2cc6528d68ad4b79cb8b31503af78704831dc5fc099ff59587f5040895161f4c"),
]
TEK2_REFERENCES = {"Intech TEK2": {
    "url": UPSTREAM + TEK2_SOURCES[0][0].replace(" ", "%20"), "sha256": TEK2_SOURCES[0][1],
    "relatedSources": [{"url": UPSTREAM + name.replace(" ", "%20"), "sha256": digest} for name, digest in TEK2_SOURCES],
    "review": "Manual TEK2 DJ setup preset only. Author guide requires loading/storing this configuration in Grid Editor; endpoint name cannot identify the installed preset. Source raw-64 turn data and exact127 contact threshold drive100-count native fixed scratch. Separate requiresTouch jog and unheld wheel bindings share each wire address; native playback suppresses the wheel path while touch owns the deck. Unheld paused seek uses160 effective counts to retain source1.6 sensitivity ratio. Playing nudge uses shared native response, not the source runtime's velocity model. Native held Cue/Play cover the configured upper keys. Bottom row, five-point LED feedback, preset transfer/query, exact source nudge model and physical acceptance remain open. Source init/shutdown are empty. No audio, Load, EQ or tempo controls are invented. Manual apply does not activate an input.",
}}


def tek2_profiles():
    result = profile("Intech TEK2", TEK2_REFERENCES["Intech TEK2"]["url"])
    result["role"] = "accessory"
    result["autoSelect"] = False
    result["hardwareMode"] = "TEK2 DJ setup preset loaded and stored through Grid Editor. Manual selection required."
    result["scope"] = "Manual configured preset:100-count fixed touch scratch, separate unheld wheel stream, Play and held Cue. Preset identity/transfer, remaining keys/LEDs, exact playing nudge response and physical acceptance remain open."
    result["gaps"] = ["TEK2 DJ setup must be installed through Grid Editor. Automatic preset transfer/identity, bottom-row keys, five-point LEDs, exact source playing-nudge model and physical calibration remain open. No automatic selection or audio interface is claimed. Manual apply does not activate the input."]
    for side, deck in enumerate("ab"):
        add(result, "play", 0, 32 + side * 2, deck=deck)
        add(result, "cuePreview", 0, 33 + side * 2, deck=deck)
        add(result, "jogTouch", 0, 40 + side, "note", "fullVelocityGate", deck)
        add(result, "jog", 0, 8 + side, "control", "binaryOffset", deck)
        result["inputs"][-1].update(argument=100, requiresTouch=True)
        add(result, "wheelJog", 0, 8 + side, "control", "binaryOffset", deck)
        result["inputs"][-1]["argument"] = 160
    return [result]
