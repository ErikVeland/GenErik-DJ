"""Independent DJM-A7 EN100 MIDI mirror facts for a separate app audio path."""
from curated import add, profile

A7_NAME = "AlphaTheta DJM-A7"
A7_SPEC = "https://downloads.support.alphatheta.com/software_info/dj-mixers/DJM-A7/djm-A7_midi_message_list_EN_100.pdf"
A7_REFERENCES = {A7_NAME: {
    "url": A7_SPEC,
    "sha256": "c3ccdb2f61be9f94ce6c6b22027736184d1a24709121c8952d1c8f95b979caee",
    "pages": [1,2,3],
    "relatedSources": [{"url":"https://support.alphatheta.com/en-US/articles/53214453591428"}],
    "review": "The current A7 EN100 document independently specifies four fixed physical CH1-4 strips. All three pages were visually checked. Unlike the A9 E10 document, its CH2 fader is unambiguously CC18, with no second CUE bus overlapping another fader. These A7 facts do not repair the different A9 source. Use native A-D gain/EQ/Color/level, TOGGLE CUE state and master/headphone/crossfader controls on manually selected MIDI channel1. PFL notes10-13 are explicit state in TOGGLE mode, not software edge toggles. The table supports Trigger/Toggle button types; no factory type default is inferred. Native absolute values use MIDI's seven-bit normalisation, with physical taper/range calibration open. C/D require app opt-in. The hardware still processes its own audio, so this manual mirror uses a separate app audio path until external mixer ownership/routing is implemented. Link Cue/SonicLink, master Texture, source/assign/curve switches, effects, microphone/clock, complete setup/output/lifecycle and physical/A10X acceptance remain open. No A9/V5/Euphonia protocol alias, MIDI receive behaviour, feedback, setting write, reset or audio route is inferred.",
}}


def a7_profiles():
    result = profile(A7_NAME,A7_SPEC)
    result.update(autoSelect=False,role="accessory",
                  aliases=[A7_NAME,"DJM-A7","DJM-A7 MIDI 1"],
                  excludedAliases=["DJM-A9","DJM-V5","DJM-V10","Euphonia"],
                  hardwareMode="Manual MIDI channel1 and BUTTON TYPE TOGGLE, with separate app audio. Physical CH1-4 map to A-D; C/D require app opt-in. Hardware/software audio ownership and external mixer routing remain unqualified.",
                  scope="Manual independent four-strip gain/EQ/filter/fader and direct PFL-state core with master/headphone/crossfader app controls. No automatic audio route or complete hardware mixer emulation.",
                  gaps=["Manual MIDI channel1/TOGGLE only; no factory button-type default is inferred. TRIGGER mode, physical taper/calibration, hardware/software audio ownership, external deck routing, Link Cue/SonicLink, master Texture, source/assign/curve switches, effects/microphone/clock, full setup/output/lifecycle and physical/A10X acceptance remain open. No sibling protocol, MIDI receive behaviour, output or stored-setting write is inferred."])
    strips = [(1,2,3,4,5,17),(6,7,8,9,10,18),(12,14,15,21,22,19),(80,81,92,82,83,20)]
    for index,(deck,numbers) in enumerate(zip("abcd",strips)):
        for action,number in zip(["gain","high","mid","low","filterKnob","level"],numbers):
            add(result,action,0,number,"control",deck=deck)
        add(result,"cueState",0,10+index,deck=deck)
    for action,number in [("master",24),("monitor",26),("cueMix",27),("crossfader",11)]:
        add(result,action,0,number,"control")
    return [result]
