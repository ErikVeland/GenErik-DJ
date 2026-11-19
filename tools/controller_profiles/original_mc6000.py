"""Original MC6000 manufacturer facts for an explicit manual PC MIX layout."""
from curated import add, profile

ORIGINAL_MC6000_NAME = "Denon DJ MC6000"
ORIGINAL_MC6000_SPEC = "https://cdn.inmusicbrands.com/denondj/legacy/dnmc6000/DN-MC6000_ownersmanual.pdf"
ORIGINAL_MC6000_REFERENCES = {ORIGINAL_MC6000_NAME: {
    "url": ORIGINAL_MC6000_SPEC,
    "sha256": "2f7d75c1973fdc752699ab4dc90f3fcf5bbe316b51f57b060687194815d2b45f",
    "relatedSources": [{"url":"https://pcdj.com/downloads/dex4/setup_dex4.0_mac.pkg",
        "sha256":"55aaca2c33e7f1b84b420ab20f2c261f1c98ee73b62b3c012e25616f39070030",
        "member":"Applications/DEX4.app/Contents/Resources/controllers/Denon__MC6000.js",
        "memberSHA256":"bf2c260eaf1ede588d7fd40998d40d8e954bcdfdac39694011303acdf14f049d"}],
    "review":"Manufacturer printed pages19-21 visually reviewed. Explicit channel block1-4 uses deck order A/C/B/D, with mixer/global bus1. PC MIX and MIDI/USB source selectors are required. Native manual layout explicitly assigns physical mixer CH1-4 to A-D, independently of the downloaded application's different strip order. Normal deck transport, four Hot Cues, loop controls, side-scoped Shift, raw64 touch and CC81 raw-minus64 jogs retain their own addresses. Independent original-MC6000 DEX handler gives2000 positions per revolution. Pitch uses the documented pitch message with native inverted direction pending calibration. Shared PAN is not inferred as cue/master blend. Forty steady lamp recipes retain CC74/75 or PFL80/81 trigger identifiers. No ALL SLIDER/VOLUME/FADER REQUEST, dimmer, meter, startup/reset, driver or stored-setting command is imported. The source's touch-toggle handler and nonzero browser fallback are not copied. Native uses release-aware contact and strict0/127 browsing. Fixed channel block, full FX/sample/shifted features, audio ownership/routing, calibration and physical/A10X acceptance remain open. No downloaded code runs or is bundled."
}}


def original_mc6000_profiles():
    result = profile(ORIGINAL_MC6000_NAME, ORIGINAL_MC6000_SPEC)
    result.update(autoSelect=False,definition="reviewed:original-mc6000-pc-mix",
                  aliases=[ORIGINAL_MC6000_NAME,"Denon DN-MC6000","DN-MC6000","MC6000"],
                  excludedAliases=["MC6000MK2","MC6000 MK2","MC6000MkII"],
                  hardwareMode="Manual PC MIX, MIDI/USB channel source selectors and MIDI block1-4 (SHIFT+BROWSE). Deck channels1-4 map A/C/B/D. Physical mixer CH1-4 explicitly map A/B/C/D. Use separate app audio. C/D require app opt-in.",
                  scope="Manual original MC6000 four-deck transport, fixed2000-count touch jogs, four Hot Cues, loops, pitch, mixer, browsing and40 separately selected steady lamp recipes.",
                  gaps=["Manual fixed channel block1-4 and explicit PC MIX/source selectors. Physical mixer CH1-4 use native A-D order. No MK2 inheritance or automatic hardware setting/audio route. Alternate channel blocks, FX/sample pages, shifted functions, PAN/blend ownership, full lifecycle/output/calibration and physical/A10X acceptance remain open. No fader request, meter/dimmer, reset, driver or downloaded executable source is sent or run."])
    result["bankChanges"] = []
    for channel,deck in enumerate("acbd"):
        side = 0 if deck in "ac" else 1
        pair = ["a","c"] if side==0 else ["b","d"]
        for scope in [side,None]:
            add(result,"shift",channel,96+side)
            result["inputs"][-1]["shiftInput"] = side
            if scope is not None:result["inputs"][-1]["shiftChannel"] = scope
        result["bankChanges"].append(dict(channel=channel,number=96+side,onValue=64,decks=pair,releaseShiftChannels=[]))
        result["bankChanges"].append(dict(channel=channel,number=3,onValue=64,decks=pair))
        for action,number in [("play",67),("cuePreview",66),("sync",107),("keylock",6),
                              ("pitchBendUp",12),("pitchBendDown",13),
                              ("loop",29),("loopIn",55),("loopOut",57),("loopDown",105),("loopUp",106)]:
            add(result,action,channel,number,deck=deck)
            result["inputs"][-1].update(shifted=False,shiftChannel=side)
        for slot,number in enumerate([23,24,25,32]):
            add(result,f"hotcue{slot+1}",channel,number,deck=deck)
            result["inputs"][-1].update(shifted=False,shiftChannel=side)
        add(result,"jogTouch",channel,81,encoding="touchGate",deck=deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side)
        add(result,"jog",channel,81,"control","denonJog",deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side,argument=2000)
        add(result,"tempo",channel,0,"pitch",deck=deck)
        result["inputs"][-1].update(shifted=False,shiftChannel=side,inverted=True)
        for action,identifier in [("play",39),("cuePreview",38),("sync",9),("keylock",8),("loop",43)]+[(f"hotcue{slot+1}",17+2*slot) for slot in range(4)]:
            _lamp(result,action,channel,identifier,deck)
    for deck,number in [("a",98),("b",99)]:
        add(result,"load",0,number,deck=deck)
        result["inputs"][-1]["shifted"] = False
    for index,deck in enumerate("abcd"):
        for action,numbers in [("gain",[1,7,12,17]),("high",[2,8,13,18]),("mid",[3,9,14,19]),("low",[4,10,15,20]),("level",[5,11,16,21])]:
            add(result,action,0,numbers[index],"control",deck=deck)
        add(result,"cue",0,[1,2,5,7][index],deck=deck)
        _lamp(result,"cue",0,[69,75,81,87][index],deck,True)
    for action,number in [("crossfader",22),("master",25),("monitor",68)]:
        add(result,action,0,number,"control")
    add(result,"browse",0,84,"control","zeroForward")
    result["inputs"][-1]["shifted"] = False
    for action,number in [("openGroup",40),("browsePreviousGroup",48)]:
        add(result,action,0,number)
        result["inputs"][-1]["shifted"] = False
    return [result]


def _lamp(result,action,channel,identifier,deck,pfl=False):
    suffix = "A" if deck in "ac" else "B"
    result["outputs"].append(dict(action=action+suffix,kind="control",channel=channel,
                                  number=80 if pfl else 74,offNumber=81 if pfl else 75,
                                  onValue=identifier,offValue=identifier,offUsesNoteOn=True,targetDeck=deck))
