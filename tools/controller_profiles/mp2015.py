"""MP2015 manual mixer controls from the manufacturer's published MIDI tables."""
from curated import add, profile

MP2015_NAME="Rane MP2015"
MP2015_URL="https://www.ranecommercial.com/legacy/pdf/mp2015_manual.pdf"
MP2015_SHA="f1d3d5c30e867dff0d204477638d1b985b50fe216a56a062f726b1ebb67010ea"
MP2015_STRIPS=[(1,3,5,7,4,19),(8,11,13,15,12,20),(16,18,20,22,19,17),(23,25,27,29,26,11)]
MP2015_REFERENCES={MP2015_NAME:{
    "url":MP2015_URL,"sha256":MP2015_SHA,"pages":[14,16,17,18,19,20,21,22],
    "relatedSources":[{"url":"https://support.serato.com/hc/en-us/articles/205333010-DVS-control-with-the-Rane-MP2015"}],
    "review":"Manufacturer pages20/22 independently define four ordered strips. Gain/high/mid/low/level CC tuples are1/3/5/7/4,8/11/13/15/12,16/18/20/22/19 and23/25/27/29/26. PFL momentary input Notes19/20/17/11 are separate from same-number CC mixer controls. PFL LED NoteOn velocities0..42 mean off and43..127 on; native optional feedback uses0/127. Master39, headphone level41 and cue/main blend43 are absolute CC. Pages16/17 state class-compliant USB MIDI/audio, stored control-panel settings, default MIDI disabled and default channel1. Manual profile requires MIDI enable for the connected port and channel1. No persistent enableCC90/92, channel/configuration, reset or startup packet is sent. Page14 gives five stereo playback pairs: decks1..4 use1-2/3-4/5-6/7-8; session uses9-10. This does not implement those routes. App mixer control requires separate audio so hardware and software EQ/levels do not process the same deck twice. No filter mapping is inferred across HP/LP/LP-HP selectors. Isolator/crossover/resonance/submix, mic/session, source selectors and control-panel settings remain inactive. Complete output/lifecycle/audio and physical/A10X acceptance remain open. No other RANE model is an alias.",
}}


def mp2015_profiles():
    result=profile(MP2015_NAME,MP2015_URL)
    result.update(definition="manufacturer:mp2015-midi",role="accessory",autoSelect=False,
                  aliases=[MP2015_NAME,"RANE MP2015","MP2015"],excludedAliases=["MP2014","MP2016","RANE FOUR"],
                  hardwareMode="Manual USB MIDI mixer on channel1. Enable MIDI for the connected USB port in the Rane control panel first. The mixer saves these settings. Use separate audio for app mixer control to avoid processing EQ/levels twice. C/D require app opt-in.",
                  scope="Manual four-strip gain/EQ/level/PFL, master/headphone level/blend and optional PFL lights. Hardware/software audio ownership, filter modes, full output/lifecycle and physical acceptance remain open.")
    for deck,addresses in zip("abcd",MP2015_STRIPS):
        for action,number in zip(["gain","high","mid","low","level","cue"],addresses):
            add(result,action,0,number,"note" if action=="cue" else "control",deck=deck)
            if action=="cue":
                result["outputs"].append(dict(action="cue"+("A" if deck in "ac" else "B"),kind="note",channel=0,number=number,
                                              targetDeck=deck,onValue=127,offValue=0,offUsesNoteOn=True))
    for action,number in [("master",39),("monitor",41),("cueMix",43)]:
        add(result,action,0,number,"control")
    result["gaps"]=["Manual MIDI enable/channel1 setup is required and stays stored in the mixer. No settings are rewritten. Use separate audio for app mixer control. Hardware USB deck/session routing, filter type/enable/resonance, isolator/submix, mic/session/source controls, complete output/lifecycle and physical/A10X acceptance remain open. Published class compliance is not iPad acceptance."]
    return [result]
