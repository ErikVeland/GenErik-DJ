"""Independently normalised public V10 and V10-LF protocol facts."""
from curated import add, profile

V10_NAME = "Pioneer DJM-V10"
LF_NAME = "Pioneer DJM-V10-LF"
V10_SPEC = "https://raw.githubusercontent.com/heronarts/LX/a950c548db00b1d3b72db3b5ac4a80f2b8519415/src/main/java/heronarts/lx/midi/surface/DJMV10.java"
LF_SPEC = "https://blt-guide.deepsymmetry.org/beat-link-trigger/next/_attachments/ExtendedOnAirV10.bls"
V10_REFERENCES = {
    V10_NAME: {"url":V10_SPEC,"sha256":"e274c95db5223e6a757aa52c8882ca78c65e3e18c230863b6ba923fd7ee31a8a","revision":"a950c548db00b1d3b72db3b5ac4a80f2b8519415",
               "relatedSources":[{"url":LF_SPEC,"sha256":"36f6fde121bb83330beefeff74f3ebd00a30090946f6965ad6ddc2700ea82b11"}],
               "review":"Public LX declares channel1 as its initial channel and requires My Settings MIDI Button Type Toggle. Independently normalise declared gain/high/low/level, CUE A state and master/headphones A/crossfader addresses. Beat Link Trigger independently confirms gain/level/master/crossfader for all six strips, but native has only four decks. Physical CH1-4 map to A-D; CH5/6 stay inactive. Four-band mid-high/mid-low cannot share the single native mid control and remain inactive. Unipolar filter cutoff with LPF/HPF selection is not a bipolar Color knob and stays inactive. Compression/send, CUE B, master isolator/filter, source/assign/curve controls, FX, full lifecycle/output/audio ownership and physical/A10X acceptance remain open. Manual separate app audio only. No downloaded code is copied, executed or bundled. LX has a non-commercial source licence; this recipe contains independently normalised protocol facts only. Source-reuse/distribution review remains required."},
    LF_NAME: {"url":LF_SPEC,"sha256":"36f6fde121bb83330beefeff74f3ebd00a30090946f6965ad6ddc2700ea82b11",
              "relatedSources":[{"url":"https://blt-guide.deepsymmetry.org/beat-link-trigger/next/Integration_ExtendedOnAirV10.html"}],
              "review":"The public Beat Link Trigger show uses one explicit MIDI map for both V10 and V10-LF. Selecting LF hides the crossfader and assignment controls; the remaining trim/fader/master map stays shared. Independently normalise only those directly supported LF facts. Four native decks use physical CH1-4, with CH5/6 inactive. No LF EQ/filter/PFL/headphone protocol is inherited from the separate LX V10 declarations. Manual MIDI channel1 and separate app audio only. No example code is executed or bundled. Complete hardware/software audio ownership, other controls, output/lifecycle and physical/A10X acceptance remain open."},
}


def v10_profiles():
    results = []
    for name in [V10_NAME,LF_NAME]:
        lf = name == LF_NAME
        result = profile(name,V10_REFERENCES[name]["url"])
        model = name.split(" ",1)[1]
        result.update(autoSelect=False,role="accessory",definition="reviewed:"+model.lower()+"-public-facts",
                      aliases=[name,"Pioneer DJ "+model,model,model+" MIDI 1"],
                      excludedAliases=["DJM-V10" if lf else "DJM-V10-LF","DJM-V5"],
                      hardwareMode="Manual MIDI channel1, MIDI ON, separate app audio. Physical CH1-4 map to A-D; CH5/6 remain inactive. C/D require app opt-in."+("" if lf else " Select My Settings MIDI Button Type Toggle."),
                      scope="Manual four-strip gain/level and master." if lf else "Manual four-strip gain/high/low/level/CUE A state and global app mixer. Four-band mid EQ and mode-dependent filter stay inactive.",
                      gaps=["Manual separate app audio only. Physical CH5/6, full hardware/software audio ownership and external deck routing, taper/calibration, source/assign/curve controls, effects/microphone, full output/lifecycle and physical/A10X acceptance remain open. "+("LF EQ/filter/PFL/headphone wires are not independently qualified by this example and stay inactive. No crossfader exists on LF." if lf else "Four-band mid-high/mid-low, unipolar LPF/HPF filter, compression/send, CUE B and master isolator/filter remain inactive. LX declares protocol facts under a non-commercial source licence; no executable source is copied or bundled. Distribution review remains open.")])
        for index,deck in enumerate("abcd"):
            add(result,"gain",0,[1,6,12,80][index],"control",deck=deck)
            add(result,"level",0,17+index,"control",deck=deck)
            if not lf:
                add(result,"high",0,[2,7,14,81][index],"control",deck=deck)
                add(result,"low",0,[4,9,21,82][index],"control",deck=deck)
                add(result,"cueState",0,7+index,deck=deck)
        add(result,"master",0,24,"control")
        if not lf:
            for action,number in [("monitor",26),("cueMix",27),("crossfader",11)]:
                add(result,action,0,number,"control")
        results.append(result)
    return results
