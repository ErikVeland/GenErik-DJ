"""SLAB general MIDI facts and an explicit fixed GenErik DJ performance layout."""
from curated import add, profile

SLAB_NAME = "AlphaTheta SLAB"
SLAB_SPEC = "https://downloads.support.alphatheta.com/midi-mapping/music-production/SLAB/SLAB_MIDI_Message_List_en.pdf"
SLAB_REFERENCES = {SLAB_NAME: {
    "url": SLAB_SPEC,
    "sha256": "aaba912538403e712fb73554a4e30fff8b467e115e91f9455718711fd1b29a0c",
    "pages": [1,2,3,4],
    "relatedSources": [{"url":"https://support.alphatheta.com/en-US/articles/52774134882841?product=50303541909785"}],
    "review": "Current four-page manufacturer MIDI list independently defines all128 normal pad addresses on channel8, Shift on channel9 and aftertouch as separate poly-pressure. Physical row-major order is12-15,8-11,4-7,0-3 within each16-note page. Define an explicit fixed GenErik DJ layout, not Serato Studio emulation: pages1/2 eight cues per A/B or C/D; pages3/4 eight fixed loops; pages5/6 eight signed beat jumps; pages7/8 Play, held Cue, Sync, Keylock, PFL, loop toggle, Load and tempo reset per deck. Top eight physical pads address the first deck; bottom eight the second. Native normal Play controls A. DIAL-mode knob sends1/65 on CC60 for browsing; its press opens a group. Arrows browse one track. Encoders CC16-19 use1/65 for A level/filter and B filter/level. Mode1 strip is channel7 CC14/46 paired14-bit crossfader. Four page-change button variants on channel7 Notes83-86 retire source-local holds and reset deck edges on press. Both physical Shift transitions on channel1 Note70 retire holds and gate native inputs, avoiding stranded Cue when its release arrives on the unsupported Shift pad channel. Page-button releases do not retire new holds. C/D retain app opt-in. Source application/encoder modes, record/undo/redo, shifted functions, aftertouch, Mode2 strip, touch interpretation, colour feedback, screens, full lifecycle and physical/A10X acceptance remain open. No Serato handshake, HID mouse command, setting write, firmware or audio route is inferred.",
}}


def slab_profiles():
    result = profile(SLAB_NAME,SLAB_SPEC)
    result.update(role="accessory",aliases=[SLAB_NAME,"SLAB","SLAB MIDI 1"],
                  hardwareMode="Fixed GenErik DJ layout in general MIDI operation. OCTAVE-/+ selects pages1-8. Pages1/2 cues,3/4 loops,5/6 jumps,7/8 transport; top/bottom eight pads address A/B or C/D. C/D require app opt-in. Press DIAL MODE to browse with the knob. Shift gates native controls.",
                  scope="Automatic fixed native DJ layout: all eight normal pad pages, A-D cue/loop/jump/transport, A/B relative level/filter, browsing and Mode1 crossfader strip. This does not emulate Serato Studio or its device modes.",
                  gaps=["Fixed native layout, not factory Serato Studio semantics. Shift transitions retire held actions; shifted pads/functions and aftertouch stay inactive. Record/undo/redo, application/encoder/piano modes, touch interpretation, Mode2 strip, complete output/colour/screen/lifecycle/audio and physical/A10X acceptance remain open. No mode/setting write, HID mouse command, Serato handshake or audio route is inferred."])
    result["bankChanges"] = [
        {"channel":6,"number":number,"onValue":127,"decks":list("abcd")}
        for number in [83,84,85,86]
    ] + [{"channel":0,"number":70,"onValue":127,"decks":list("abcd"),"releaseShiftChannels":[]}]
    add(result,"shift",0,70)
    result["inputs"][-1]["shiftInput"] = 0
    for page in range(8):
        decks = "ab" if page % 2 == 0 else "cd"
        for physical in range(16):
            deck = decks[physical // 8]
            slot = physical % 8
            number = page * 16 + (3 - physical // 4) * 4 + physical % 4
            if page < 2:
                action,argument = f"hotcue{slot + 1}",None
            elif page < 4:
                action,argument = "toggleFixedLoop",[0.25,0.5,1,2,4,8,16,32][slot]
            elif page < 6:
                action,argument = "fixedJump",[-1,1,-2,2,-4,4,-8,8][slot]
            else:
                action,argument = ["play","cuePreview","sync","keylock","cue","loop","load","tempoReset"][slot],None
            add(result,action,7,number,deck=deck)
            if argument is not None:result["inputs"][-1]["argument"] = argument
    for action,number,deck in [("level",16,"a"),("filterKnob",17,"a"),("filterKnob",18,"b"),("level",19,"b")]:
        add(result,action,0,number,"control","signedBit",deck)
    add(result,"crossfader",6,14,"control","paired14Bit")
    add(result,"browse",0,60,"control","signedBit")
    for action,number,deck in [("browsePrevious",100,None),("browseNext",101,None),("openGroup",98,None),("play",94,"a")]:
        add(result,action,0,number,deck=deck)
    for row in result["inputs"]:
        if row["action"] != "shift":row["shifted"] = False
    return [result]
