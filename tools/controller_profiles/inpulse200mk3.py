"""Inpulse 200 MK3 facts from its separate user-visible factory MIDI document."""
from curated import add, profile

MK3_NAME = "Hercules DJControl Inpulse 200 MK3"
MK3_FACTORY = "https://ts.hercules.com/download/djuced/6.8/DJUCED_6.8.1.dmg"
MK3_MANUAL = "https://ts.hercules.com/download/sound/manuals/DJC_Inpulse_200_MK3/DJControl_Inpulse_200_MK3_User_Manual_-_21_Languages.pdf"
MK3_GUIDE = "https://www.djuced.com/kb/hercules-djcontrol-inpulse-200-mk3-2026-mapping-and-manual/"
MK3_REFERENCES = {MK3_NAME: {
    "url": MK3_FACTORY, "sha256": "a76200de7cc2fced9b765d83edd02c8a07aa302d77c87c81ddf2f4c91330e2a2",
    "member": "djuced_6.8.1.pkg/djuced.pkg/Payload/Applications/DJUCED/DJUCED.app/Contents/Resources/midi/DJControl Inpulse 200 Mk3.djm",
    "memberSHA256": "2a0f05ea95b8a643d5d0735255cd86d28b109debb21c678ba888f2672cb6624b",
    "relatedSources": [{"url": MK3_MANUAL, "sha256": "9a45c2ec9a9598f364caa63be1d1d3a8349dc8adf6617fd5f9c2279f4446958c"}, {"url": MK3_GUIDE}],
    "review": "Distinct manufacturer factory XML has172 device controls and172 mapping actions. Native reads hardware facts only. No package, app, script, mapping command, source onexit B07F7E or installer is executed or bundled. Normal deck channels2/3, shifted5/6, pad7/8 and global1/4 stay separate. MK3 GAIN_A/B map HighCC5, HIGH_A/B map MidCC4, LowCC2 and filterCC1. ShiftCC5 maps gain while ShiftCC4 maps High. Shifted volume controls target sampler decks3/4 and are not duplicated onto A/B. Jogs CC9/10 declare512 steps/turn with1-3F positive and40-7F negative. Native reuses twosComplement magnitude, not MK2 single-step or provisional scale. Coarse seven-bit pitchCC8 is explicitly inverted. Shifted Cue and pad deletion releases retire/rearm native holds without source stop/delete actions. No physical Shift note is established by this factory file. Known wire channels supply modifier separation. Hardware master/headphone levels are not software CC knobs. Factory MASTER_VOL_L/R are output-only and remain inactive. Normal18 steady lamp recipes omit the conflicting B-Cue shifted output. OEM guide qualifies class-compliant USB, master1/2 and headphones3/4. Complete modes, scratch-mode semantics, shifted seek, firmware, lifecycle, calibration and physical/A10X acceptance remain open."
}}


def inpulse200mk3_profiles():
    result = profile(MK3_NAME, MK3_FACTORY)
    result.update(definition="reviewed:hercules-inpulse-200-mk3-factory",
                  aliases=[MK3_NAME, "DJControl Inpulse 200 MK3"],
                  excludedAliases=["DJControl Inpulse 200", "DJControl Inpulse 200 MK2", "DJControl Inpulse 300 MK2"],
                  audioOutput="masterAndHeadphones",
                  hardwareMode="Default MK3 factory MIDI layout. Native fixed touch scratch uses512-count jog facts. Hardware Shift selects separate wire channels. Audio uses master1/2 and headphones3/4 when the documented wired route is exposed.",
                  scope="Automatic65-input native core with independent MK3 three-band EQ, shifted gain/High, coarse pitch,512-count jogs, held Cue, four Hot Cues, loops, native browsing and18 steady lamps.",
                  gaps=["No physical Shift note, source reset, query, firmware or application mapping code is inferred. Hardware master/headphone levels are not duplicated. Shifted volume controls target samplers and remain inactive. Native touch always scratches rather than reproducing software Vinyl mode. Stem controls, held loop adjustment, shifted seek, cue deletion, FX/sample/beatmatch modes, conflicting shifted B-Cue lamp, complete lifecycle/calibration and physical iPad USB/audio/A10X acceptance remain open."])
    for channel, deck in enumerate("ab", 1):
        shifted = channel + 3
        pads = channel + 5
        result.setdefault("bankChanges", []).append(dict(channel=shifted, number=3, onValue=127, decks=[deck]))
        for action, number in [("play", 7), ("cuePreview", 6), ("sync", 5), ("cue", 12), ("load", 13), ("loop", 3)]:
            add(result, action, channel, number, deck=deck, feedback=action != "load")
        add(result, "cuePreview", shifted, 6, deck=deck)
        result["inputs"][-1]["releaseOnly"] = True
        for action, number in [("loopDown", 9), ("loopUp", 10)]:
            add(result, action, shifted, number, deck=deck)
        for slot in range(4):
            add(result, f"hotcue{slot + 1}", pads, slot, deck=deck, feedback=True)
            add(result, f"hotcue{slot + 1}", pads, slot + 8, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        add(result, "jogTouch", channel, 8, encoding="fullVelocityGate", deck=deck)
        for action, number in [("jog", 10), ("wheelJog", 9)]:
            add(result, action, channel, number, "control", "twosComplement", deck)
            result["inputs"][-1]["argument"] = 512
        for action, number in [("level", 0), ("filterKnob", 1), ("low", 2), ("mid", 4), ("high", 5), ("tempo", 8)]:
            add(result, action, channel, number, "control", deck=deck)
            result["inputs"][-1]["inverted"] = action == "tempo"
        for action, number in [("filterKnob", 1), ("low", 2), ("high", 4), ("gain", 5)]:
            add(result, action, shifted, number, "control", deck=deck)
    add(result, "crossfader", 0, 0, "control")
    add(result, "browse", 0, 1, "control", "twosComplement")
    add(result, "browse", 3, 1, "control", "twosComplement")
    add(result, "openGroup", 0, 0)
    add(result, "browsePreviousGroup", 3, 0)
    return [result]
