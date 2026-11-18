"""Original BeatMix facts resolved against the manufacturer's used TSI bindings."""
from curated import add, profile

ORIGINAL_BEATMIX = "Reloop BeatMix"
BEATMIX_MANUAL = "https://www.reloop.com/media/catalog/product/pdf/2/2/5/225067_Reloop_IM.pdf"
BEATMIX_TSI = "https://www.reloop.com/media/custom/upload/225067/225067%20Mapping%201.0%202D%20Traktor%201.2.7%2B%20FW%201.1.4%2B%20Win.zip"
BEATMIX_ORIGINAL_REFERENCES = {ORIGINAL_BEATMIX:{
    "url":BEATMIX_MANUAL,"sha256":"099af480f3932e39d4112cd88f414828f35ea8f8c447cd4f38126eaaceb994ca",
    "relatedSources":[{"url":BEATMIX_TSI,"sha256":"e65e3361a71716b8ccf6560486d3688eb4d24a2ae84f3d06b65485bb7492ee25",
                       "member":"Beatmix_V1_(2-Deck)-WIN.tsi","memberSHA256":"7ac250dc0b18f5b63580790a5bd4fd262e25d0b17e4c6f313a2d2159bf8b27f8"}],
    "review":"Printed page20 visually reviewed. Manufacturer TSI version1.0 requires firmware1.1.4 or later. Its182 used mapping rows resolve right Low to Ch02.CC.069 and global controls to Ch05, correcting the older table's CH1/CH4 labels. Used pitch pairs are118+54 and118+70; native retains their qualified MSBs only until packet order is established. The literal cell36/76 is hexadecimal, not decimal. Used jogCC36/42 and browserCC24 definitions explicitly select3F/41 encoder mode0. Native maps only those qualified jog streams with touch Note63 and requires hardware Scratch mode. Unused generic MIDI templates do not qualify normal jogCC32/34 or search/shift streams. Source positions per revolution are unspecified; native scale and physical direction remain uncalibrated. Deck Shift40 has independent local and global OR identities. Mode presses retire side holds; releases preserve new holds. Three Hot Cues, Play47, held Cue46, Sync44, PFL35, Load50, asymmetric AutoLoop34/33 and held bends38/39 retain their own channels. Same-wire linefaders and global sound controls remain usable during Shift. No master MIDI control, LED velocities, reset, source software actions, startup/shutdown or audio route is inferred. No TSI is executed or bundled. Full modes/output/lifecycle, fourteen-bit pitch order, audio routing/calibration and physical/A10X acceptance remain open."
}}


def original_beatmix_profiles():
    result = profile(ORIGINAL_BEATMIX,BEATMIX_MANUAL)
    result.update(definition="reviewed:original-beatmix-factory-tsi-core",aliases=[ORIGINAL_BEATMIX,"BeatMix"],
                  excludedAliases=["BeatMix 2","Beatmix2","Beatmix 4","Beatmix4","Beatmix 2 MK2"],
                  hardwareMode="Original BeatMix with firmware1.1.4 or later. Enable Scratch mode on both decks for the qualified jog streams. Deck MIDI channels1/2 and global channel5 follow the factory TSI. Use a separately configured app audio route.",
                  scope="Automatic50-input original BeatMix transport/mixer core from manufacturer MIDI facts and used TSI bindings. Scratch-mode jogs and coarse pitch only. Full output/audio and calibration remain open.",
                  gaps=["Requires firmware1.1.4+ and hardware Scratch mode. Normal jog32/34, search/shift streams, loop/FX encoders, Beat Mash, CUP, other shifted functions, master MIDI, LED velocities and full output/lifecycle remain inactive. Pitch uses qualified seven-bit MSBs; packet order for full14-bit pairs remains unqualified. Native jog scale/direction and physical/audio/A10X acceptance remain open. No Beatmix2/4 inheritance, generic-template guessing, firmware/reset/query/settings or automatic audio command."])
    result["bankChanges"] = []
    for channel,deck in enumerate("ab"):
        for scope in [channel,None]:
            add(result,"shift",channel,40)
            result["inputs"][-1]["shiftInput"] = channel
            if scope is not None:result["inputs"][-1]["shiftChannel"] = scope
        result["bankChanges"].append(dict(channel=channel,number=40,onValue=127,decks=[deck],releaseShiftChannels=[]))
        for number in [36,37]:result["bankChanges"].append(dict(channel=channel,number=number,onValue=127,decks=[deck]))
        for action,number in [("play",47),("cuePreview",46),("sync",44),("cue",35),("load",50),
                              ("loop",34 if channel==0 else 33),("pitchBendDown",38),("pitchBendUp",39)]+[(f"hotcue{i+1}",41+i) for i in range(3)]:
            add(result,action,channel,number,deck=deck)
            result["inputs"][-1].update(shifted=False,shiftChannel=channel)
        add(result,"jogTouch",channel,63,deck=deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=channel)
        add(result,"jog",channel,36 if channel==0 else 42,"control","binaryOffset",deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=channel)
        add(result,"tempo",channel,54 if channel==0 else 70,"control",deck=deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=channel,inverted=True)
        for action,number in [("gain",50+16*channel),("high",51+16*channel),("mid",52+16*channel),("low",53+16*channel),("filterKnob",49 if channel==0 else 64),("level",55+16*channel)]:
            add(result,action,channel,number,"control",deck=deck)
            if action!="level":result["inputs"][-1].update(shifted=False,shiftChannel=channel)
    for action,number in [("monitor",81),("cueMix",82),("crossfader",83)]:add(result,action,4,number,"control")
    add(result,"browse",4,24,"control","binaryOffset")
    result["inputs"][-1]["shifted"] = False
    for number,shifted in [(32,False),(64,True)]:
        add(result,"openGroup",4,number)
        result["inputs"][-1]["shifted"] = shifted
    return [result]
