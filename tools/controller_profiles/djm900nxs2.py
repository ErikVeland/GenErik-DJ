"""Independent DJM-900NXS2 MIDI facts for a manually selected app mixer."""
from curated import add, profile

NXS2_NAME = "Pioneer DJM-900NXS2"
NXS2_SPEC = "https://impact-even.com/wp-content/uploads/2022/03/pioneer_djm900nexus2_midimessages.pdf"
NXS2_REFERENCES = {NXS2_NAME: {
    "url": NXS2_SPEC,
    "sha256": "48fc203ca395e6449311f021ec61119e0401e26e0389c9f0aadf4209bebe0a0c",
    "pages": [1,2,3,4],
    "relatedSources": [{"url":"https://c3.zzounds.com/media/DJM-900NXS2_manual_EN-0703f22a06f23c5041e63da3db269aa6.pdf","page":20}],
    "review": "All four pages of the manufacturer-authored Version1.00 wire table were visually checked through a public rental-company mirror. The operating manual independently specifies MIDI channel1 and BUTTON TYPE TOGGLE as defaults. Four fixed CH1-4 strips map to native A-D gain, three-band EQ, Color/filter, channel level and direct PFL state. Cue uses CC70-73, not sibling A7/A9 Note10-13. All four faders are unambiguous CC17-20 in this source. Master24, headphones26/blend27 and crossfader11 use seven-bit normalisation. Physical taper/range calibration remains open. Manual selection and C/D opt-in remain required. Use separate app audio because the hardware retains its own processing. Input/assign/curve switches, master/Link Cue, booth, FX/X-PAD, microphone, clock, full lifecycle/output, external mixer ownership/routing and physical/A10X acceptance remain open. X-PAD touch and Beat FX ON/OFF share CC114 in the source and remain inactive. No stored-setting, output, audio route or sibling protocol is inferred.",
}}


def nxs2_profiles():
    result = profile(NXS2_NAME,NXS2_SPEC)
    result.update(autoSelect=False,role="accessory",
                  aliases=[NXS2_NAME,"Pioneer DJ DJM-900NXS2","DJM-900NXS2","DJM-900NXS2 MIDI 1"],
                  excludedAliases=["DJM-900NXS","DJM-900SRT","DJM-A9","DJM-V10","DJM-TOUR1"],
                  hardwareMode="Manual MIDI channel1 and BUTTON TYPE TOGGLE, with separate app audio. Enable MIDI ON for the connected USB port. Physical CH1-4 map to A-D; C/D require app opt-in. Hardware/software audio ownership and external mixer routing remain unqualified.",
                  scope="Manual independent four-strip gain/EQ/filter/fader and direct CC PFL-state core with master/headphone/crossfader app controls. No automatic audio route or complete hardware mixer emulation.",
                  gaps=["Manual default MIDI channel1/TOGGLE only. TRIGGER mode, physical taper/calibration, hardware/software audio ownership, external deck routing, source/assign/curve switches, master/Link Cue, booth, effects/X-PAD, microphone/clock, full output/lifecycle and physical/A10X acceptance remain open. No output, setting write, sibling protocol or audio route is inferred."])
    strips = [(1,2,3,4,5,17),(6,7,8,9,10,18),(12,14,15,21,22,19),(80,81,92,82,83,20)]
    for index,(deck,numbers) in enumerate(zip("abcd",strips)):
        for action,number in zip(["gain","high","mid","low","filterKnob","level"],numbers):
            add(result,action,0,number,"control",deck=deck)
        add(result,"cueState",0,70+index,"control",deck=deck)
    for action,number in [("master",24),("monitor",26),("cueMix",27),("crossfader",11)]:
        add(result,action,0,number,"control")
    return [result]
