"""Separate Slate protocol facts from public software-author mappings."""
from curated import add, profile

SLATE_SOURCE = "https://pcdj.com/downloads/djcontrollers/Gemini__Slate.zip"
SLATE_DISCUSSION = "https://pcdj.com/dj-controllers-gemini-slate/"
SLATE4_SOURCE = "https://community.algoriddim.com/uploads/short-url/pYMYB13dHQw7Rccw8pdbs3mdsgz.djayMidiMa"
SLATE4_DISCUSSION = "https://community.algoriddim.com/t/gemini-slate-4-midi-mapping/37308"
SLATE_SOURCES = [
    ("Gemini-Slate.zip", "53f4ccbfca7c1c9a58f4afed956f1b5a444a28555a9d8f760a45b1fc09f7e7bf"),
    ("Gemini__Slate.js", "53a40dbf0dd23659a88968d8c255a09af36264b07d02d4c62da1c8c773e0ee61"),
    ("Slate4.djayMidiMapping", "5f99dd156c5c2ee57c61cee6a5abd15ae16223b0905d8abac8a4cfce12eaed5f"),
]
SLATE_REFERENCES = {
    "Gemini Slate": {"url": SLATE_SOURCE, "sha256": SLATE_SOURCES[0][1],
        "relatedSources": [{"url": SLATE_DISCUSSION}, {"url": SLATE4_SOURCE, "sha256": SLATE_SOURCES[2][1]}],
        "review": "PCDJ states its team mapped and tested the original two-channel Slate. Active source identity is SLATE Audio andUSB23C7:0468; the Pioneer header and commented Pioneer SysEx are stale and unused. Explicit deck channels0/1 supply Play1, held Cue2, Sync3, Key4, inverted seven-bit pitchCC1 and centre64 jogCC4. Touch57 supplies fixed native touch scratch; source software Vinyl56 toggle is not copied. Source scratch/move denominator150 is app-specific, not a measured ticks/revolution claim; retain native default calibration. Global channel3 supplies direct Load1/2, PFL5/6 and Shift13; its mixer CCs and centre64 jog values are independently corroborated by the different Slate4 file. Eight Hot Cues use6+3*slot; distinct fixed loop notes8+3*slot carry1/8..16 beats. Source Shift+cue clear remains inactive. Ambiguous combined manual-loop commands, saved loops, sampler, FX and gain stay unmapped. Browse uses source greater-than64 direction with native64 neutral. Published127/0 transport/PFL/cue lights become steady feedback; source Sync beat flashes and loop animation stay open. Native fixed Vinyl lights56 are set at startup and cleared with source FX lamps at shutdown. Commented application-connect and identity strings never become setup. Slate4 has a different USB product and no automatic alias. Full modes, lights, audio routing, calibration and physical acceptance remain open. No downloaded script runs in the app."},
    "Gemini Slate 4": {"url": SLATE4_SOURCE, "sha256": SLATE_SOURCES[2][1],
        "relatedSources": [{"url": SLATE4_DISCUSSION}],
        "review": "DJ_MKB's corrected1.01 two-deck custom mapping identifies USB23C7:0467 andSLATE4-4 decks, without a custom app class. Normal A/B transport, global-channel3 Load/PFL/mixer and explicit rotary64 jog/browse facts enter a separate manual subset. Both source touch rows address channel1 Note57 while naming different decks; neither is imported. Pitch is absent. Outer EQs control Neural Mix, not ordinary C/D EQ. Shared pad/deck modes, full four-deck dispatch, lights with unspecified ranges, startup/shutdown, original-Slate aliases and audio routing remain unqualified. Manual application requires separate input enabling and runs no lifecycle. No downloaded code runs in the app."},
}


def slate_profiles():
    results = []
    for manual in [False, True]:
        name = "Gemini Slate 4" if manual else "Gemini Slate"
        result = profile(name, SLATE_REFERENCES[name]["url"])
        result["autoSelect"] = not manual
        result["aliases"].append("SLATE4-4 decks" if manual else "SLATE Audio")
        if manual:
            result["hardwareMode"] = "Manual two-deck custom-map subset. Enable input separately; full four-deck dispatch is unqualified."
            result["gaps"] = ["Conflicting source touch row, absent pitch, outer Neural Mix EQ, shared pad/deck state, full four-deck dispatch, unspecified light ranges, lifecycle and audio routing remain open. No original-Slate alias is inferred. Physical acceptance remains open."]
            result["scope"] = "Manual normal A/B transport, held Cue, direct Load/PFL, channel mixer/filter, wheel bend and centre64 browsing. Touch/pitch, shared pads, C/D, lights, lifecycle and routing remain open."
        else:
            result["excludedAliases"] = ["Gemini Slate 4", "Slate 4", "SLATE4", "SLATE4-4 decks"]
            result["gaps"] = ["Native fixed touch scratch keeps the app's default jog calibration; source150 is not a measured revolution resolution. Source Vinyl toggle, shifted cue clear, combined manual loops, saved loops, full pad/FX/sampler modes, full feedback/lifecycle, audio routing and physical acceptance remain open."]
            result["scope"] = "Automatic original Slate A/B core with held Cue, inverted source seven-bit pitch, centre64 touch/jog, mixer, eight cues, fixed loop notes, direct Load, browsing and steady lights. Full modes/routing and physical acceptance remain open."
        add(result, "shift", 3, 13)
        for channel, deck in enumerate("ab"):
            for action, number in [("play", 1), ("cuePreview", 2), ("sync", 3)] + ([] if manual else [("keylock", 4)]):
                add(result, action, channel, number, deck=deck, feedback=not manual)
            add(result, "load", 3, 1 + channel, deck=deck)
            add(result, "cue", 3, 5 + channel, deck=deck, feedback=not manual)
            add(result, "wheelJog" if manual else "jog", channel, 4, "control", "binaryOffset", deck)
            if not manual:
                add(result, "jogTouch", channel, 57, deck=deck)
                add(result, "tempo", channel, 1, "control", deck=deck)
                result["inputs"][-1]["inverted"] = True
                for slot in range(8):
                    add(result, f"hotcue{slot + 1}", channel, 6 + 3 * slot, deck=deck, feedback=True)
                    result["inputs"][-1]["shifted"] = False
                    add(result, "toggleFixedLoop", channel, 8 + 3 * slot, deck=deck)
                    result["inputs"][-1]["argument"] = 0.125 * 2 ** slot
                add(result, "loopDown", channel, 16, deck=deck)
            for action, number in [("high", 9), ("mid", 5), ("low", 13), ("filterKnob", 17), ("level", 21)]:
                add(result, action, 3, number + channel, "control", deck=deck)
        for action, number in [("crossfader", 25), ("cueMix", 26), ("master", 27)]:
            add(result, action, 3, number, "control")
        add(result, "browse", 3, 30, "control", "binaryOffset" if manual else "binaryDirection")
        if not manual:
            add(result, "openGroup", 3, 9)
            result["startup"] = [[0x90 + ch, 56, 127] for ch in range(2)]
            result["shutdown"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
            result["shutdown"] += [[0x90 + ch, note, 0] for ch in range(2) for note in [54, 56, 60, 62]]
        results.append(result)
    return results
