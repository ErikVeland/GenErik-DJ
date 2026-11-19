"""Factory RMX-90 DVS MIDI mirror with explicit manual setup."""
from curated import add, profile

RMX90_SOURCES = [
    ("RMX90-MIDI.pdf", "https://www.reloop.com/media/custom/upload/Reloop-RMX-90DVS_MIDI-Map.pdf",
     "3b4fff2305692b6015ceeb4dea896b7af795ddae156a72666442353677ff8760"),
    ("RMX90-manual.pdf", "https://www.reloop.com/media/catalog/product/pdf/2/3/2/232554_Reloop_IM.pdf",
     "aeb6263cfbb46285441cd9f2cd89f66e6469853284b19b76083e59ac03169473"),
]
RMX90_REFERENCES = {"Reloop RMX-90 DVS": {
    "url": RMX90_SOURCES[0][1], "sha256": RMX90_SOURCES[0][2], "pages": [1],
    "relatedSources": [{"url": RMX90_SOURCES[1][1], "sha256": RMX90_SOURCES[1][2], "pages": [21,46]}],
    "review": "Factory map uses configurable Bn/9n messages. Manual page21 independently confirms MIDI on/off, channels1..15 and TRIGGER/TOGGLE selection; channel16 is reserved for external USB OUT control. This manual recipe explicitly requires MIDI on, channel1 (wire0) and TRIGGER. These are required settings, not assumed defaults. Physical mixer CH1..4 map to native A/B/C/D: gain CC1/7/13/19, high2/8/14/20, mid3/9/15/21, low4/10/16/22, filter5/11/17/23, level6/12/18/24. Note2/5/8/11 are headphone PFL, not held main Cue. Global crossfader25, master26, headphone mix39 and level40 are absolute0..127. Source and crossfader assignment selectors are not buttons; no transport is invented. Booth28 is not headphone level. FX encoder rows print63~54 and do not qualify a decoder. No pickup SysEx, lamp output, setup packet or automatic audio routing is inferred. Hardware mixer routing/bypass, alternate MIDI settings, full modes, native calibration and physical acceptance remain open. Use a separate software audio path.",
}}


def rmx90_profiles():
    result = profile("Reloop RMX-90 DVS", RMX90_SOURCES[0][1])
    result["aliases"] += ["RMX-90DVS", "Reloop RMX-90DVS", "RMX90DVS"]
    result["autoSelect"] = False
    result["hardwareMode"] = "Manual MIDI mirror: set MIDI on, MIDI CH1 and MIDI TYPE TRIGGER. Enable input separately. Use a separate software audio path. C/D require app opt-in."
    result["scope"] = "Manual four-target gain/EQ/filter/level/PFL, crossfader, master and headphone blend/level. External mixer routing/bypass, FX, output/lifecycle and physical acceptance remain open."
    result["excludedAliases"] = ["Reloop RMX-80", "RMX-80", "Reloop RMX-60", "RMX-60", "RMX-95"]
    for side, deck in enumerate("abcd"):
        for offset, action in enumerate(["gain", "high", "mid", "low", "filterKnob", "level"], 1):
            add(result, action, 0, side*6+offset, "control", deck=deck)
        add(result, "cue", 0, side*3+2, deck=deck)
    for action, number in [("crossfader",25), ("master",26), ("cueMix",39), ("monitor",40)]:
        add(result, action, 0, number, "control")
    result["gaps"] = ["Explicit manual MIDI on/channel1/TRIGGER setup required. Other MIDI channels and toggle mode remain inactive. Use a separate software audio path; external deck routing and hardware/software mixer bypass are unavailable. Selectors, Booth, microphone, fader starts, FX, pickup SysEx, lamps, full lifecycle, calibration and physical/A10X acceptance remain open."]
    return [result]
