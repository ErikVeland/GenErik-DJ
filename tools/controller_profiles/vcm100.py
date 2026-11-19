"""VCM-100 manufacturer MIDI facts from its preserved service note."""
from curated import add, profile

VCM100_NAME = "Vestax VCM-100"
VCM100_SPEC = "https://www.kevinchant.com/uploads/7/1/0/8/7108231/vsm-vcm-100.pdf"
VCM100_REFERENCES = {VCM100_NAME:{
    "url":VCM100_SPEC,"sha256":"69b1c3066fdb1653bf0f547dd323838a2dc681f0fa3df310ba66c16a8cdeb59b",
    "review":"Manufacturer service note pages6,15,16,19,20 visually reviewed. The full MIDI table gives shared normal notes/CC for rear modes A/B/C, default MIDI channel1 and optional channel2 selected by holding PGM1 LOOP during power-on. PGM1/2 are two app decks on the same selected MIDI channel, not separate MIDI channels. Native accepts both documented channel choices on an explicitly selected endpoint. Play50/54, CuePause52/56 as native held Cue, SetCue53/57, PFL72/73, Sync70/71, Loop66/67, Fine78-81 as native held bends, rotary level12/13, tempo14/15, high20/24, mid21/25, low23/27 and trim28/29 retain independent wires. Global Load96/97, Up92/Down93, master7, cross8, monitor88 and cueMix89 are explicit. Centre-detent notes are mode-A-only and include a conflicting trim-B decimal/hex value; all remain inactive. No centre note, balance, F1-F4 search, CUP/Preview, output, mode/power write, setting, driver or audio route is inferred. The manufacturer's Mac identity is generic Vestax PC-CONTROLLER. Native does not auto-select or alias that identity to one model. Core MIDI is manual, with separate app audio and physical/iPad USB/audio/calibration acceptance open. No downloaded code is copied or run."
}}


def vcm100_profiles():
    result = profile(VCM100_NAME,VCM100_SPEC)
    result.update(autoSelect=False,definition="reviewed:vcm100-manufacturer-midi",
                  aliases=[VCM100_NAME,"VCM-100","VCM100"],excludedAliases=["VCM-600","Vestax VCI-100","Vestax PC-CONTROLLER","Vestax PC CONTROLLER"],
                  hardwareMode="Manual VCM-100 selection on its exposed MIDI endpoint. Rear modes A/B/C share these core packets. Accept default MIDI channel1 or optional channel2. PGM1/2 map A/B on the selected channel. Use separate app audio.",
                  scope="Manual72-input contract across both documented MIDI channel choices. Rotary deck levels, transport, native held Cue/bends, Set Cue, PFL, pitch/EQ/gain, loops, Load, browsing and global sound. No jog wheels are invented.",
                  gaps=["Generic Vestax PC-CONTROLLER endpoint cannot identify this model safely. Manual model selection required. Mode-A centre notes, conflicting trim-B centre value, balance, F1-F4 search, CUP/Preview and output remain inactive. Native CuePause/Fine buttons use held Cue/bend behaviour. Native tempo direction and physical taper/calibration remain unverified. Device-specific iPad USB/audio, complete lifecycle/feedback and physical/A10X acceptance remain open. No mode/power, driver, setup/output or automatic audio command."])
    for channel in [0,1]:
        for side,deck in enumerate("ab"):
            for action,number in [("play",50+4*side),("cuePreview",52+4*side),("cueSet",53+4*side),
                                  ("cue",72+side),("sync",70+side),("loop",66+side),
                                  ("pitchBendUp",78+2*side),("pitchBendDown",79+2*side)]:
                add(result,action,channel,number,deck=deck)
                if action in {"cuePreview","pitchBendUp","pitchBendDown"}:
                    result["inputs"][-1]["holdInput"] = channel
            for action,number in [("level",12+side),("tempo",14+side),("high",20+4*side),
                                  ("mid",21+4*side),("low",23+4*side),("gain",28+side)]:
                add(result,action,channel,number,"control",deck=deck)
                result["inputs"][-1]["inverted"] = action=="tempo"
        for deck,number in [("a",96),("b",97)]:add(result,"load",channel,number,deck=deck)
        for action,number in [("browsePrevious",92),("browseNext",93)]:add(result,action,channel,number)
        for action,number in [("master",7),("crossfader",8),("monitor",88),("cueMix",89)]:add(result,action,channel,number,"control")
    return [result]
