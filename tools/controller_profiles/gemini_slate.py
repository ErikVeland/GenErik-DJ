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


SLATE4_PCDJ_SOURCE = "https://pcdj.com/downloads/djcontrollers/Gemini__Slate_4.zip"
SLATE4_PCDJ_SOURCES = [
    ("Gemini-Slate4.zip", "2bdc1a80f407ad1232291f2a14e52b976355eea63ff4ae92202fa7399143b22a"),
    ("Gemini__Slate_4.js", "f991dc957d25dc86f58cc0bc3ec2ed79e385549a6638e6b09575c2455b81c14c"),
]
SLATE_REFERENCES["Gemini Slate 4"] = {
    "url": SLATE4_PCDJ_SOURCE, "sha256": SLATE4_PCDJ_SOURCES[0][1],
    "relatedSources": [{"url": "https://pcdj.com/dj-controllers-download-the-gemini-slate-4/"},
                       {"url": SLATE4_SOURCE, "sha256": SLATE_SOURCES[2][1]}],
    "review": "Independent PCDJ four-deck map identifies SLATE4 Audio andUSB23C7:0467. Explicit channel remap0/1/4/5 supplies A/B/C/D transport, inverted seven-bit pitchCC1, centre64 jogCC4 and touchNote57; the earlier custom file's duplicate channel1 touch assignment is not imported. Global channel3 Load1..4 and PFL5..8 retain all four targets. Its CC5..8 Mid,9..12 High,13..16 Low,17..20 filter and21..24 level are native per-deck controls; outer EQs are not Neural Mix. Cross-bank NoteOff aliases release Cue/touch holds and rearm transport even if hardware changes its wire channel before release. They never trigger another bank on a positive press. C/D keep the app's existing opt-in. Eight distinct cue/fixed-loop note sets retain source Shift clear guards, with native fixed touch scratch and default calibration. Software Vinyl toggles, complete bank/contact handover, combined manual loops, FX/sampler, source Sync flashes, complete lifecycle and audio routing remain open. Published four-bank transport/PFL/cue feedback uses127/0. Four fixed Vinyl startup lights and56 shutdown packets stay within the64-packet bound; unowned FX cleanup is not copied. No source script, stale Pioneer header/identity comment or commented application-connect packet runs in the app.",
}


def slate_profiles():
    results = []
    for four in [False, True]:
        name = "Gemini Slate 4" if four else "Gemini Slate"
        result = profile(name, SLATE_REFERENCES[name]["url"])
        result["aliases"] += ["SLATE4 Audio", "SLATE4-4 decks"] if four else ["SLATE Audio"]
        if four:
            result["excludedAliases"] = ["Gemini Slate", "Slate", "SLATE Audio"]
            result["gaps"] = ["Native fixed touch scratch keeps default calibration. Source Vinyl toggle, complete bank/contact handover, shifted cue clear, combined manual loops, saved loops, full pad/FX/sampler modes, complete feedback/lifecycle and audio routing remain open. Cross-bank release aliases prevent stuck Cue/contact after a changed-channel release. C/D require four-deck opt-in. Physical acceptance remains open."]
            result["scope"] = "Automatic Slate4 four-target core with channels0/1/4/5, native held Cue/touch, source inverted pitch, mixer, direct Load/PFL, eight cue/fixed-loop sets and steady feedback. C/D require opt-in. Full modes/routing and acceptance remain open."
        else:
            result["excludedAliases"] = ["Gemini Slate 4", "Slate 4", "SLATE4", "SLATE4-4 decks"]
            result["gaps"] = ["Native fixed touch scratch keeps the app's default jog calibration; source150 is not a measured revolution resolution. Source Vinyl toggle, shifted cue clear, combined manual loops, saved loops, full pad/FX/sampler modes, full feedback/lifecycle, audio routing and physical acceptance remain open."]
            result["scope"] = "Automatic original Slate A/B core with held Cue, inverted source seven-bit pitch, centre64 touch/jog, mixer, eight cues, fixed loop notes, direct Load, browsing and steady lights. Full modes/routing and physical acceptance remain open."
        add(result, "shift", 3, 13)
        channels = [0, 1, 4, 5] if four else [0, 1]
        for index, (channel, deck) in enumerate(zip(channels, "abcd")):
            def bank_release(action, number):
                if four:
                    add(result, action, channel ^ 4, number, deck=deck)
                    result["inputs"][-1]["releaseOnly"] = True

            for action, number in [("play", 1), ("cuePreview", 2), ("sync", 3), ("keylock", 4)]:
                add(result, action, channel, number, deck=deck, feedback=True)
                bank_release(action, number)
            add(result, "load", 3, 1 + index, deck=deck)
            add(result, "cue", 3, 5 + index, deck=deck, feedback=True)
            add(result, "jog", channel, 4, "control", "binaryOffset", deck)
            add(result, "jogTouch", channel, 57, deck=deck)
            bank_release("jogTouch", 57)
            add(result, "tempo", channel, 1, "control", deck=deck)
            result["inputs"][-1]["inverted"] = True
            for slot in range(8):
                add(result, f"hotcue{slot + 1}", channel, 6 + 3 * slot, deck=deck, feedback=True)
                result["inputs"][-1]["shifted"] = False
                add(result, "toggleFixedLoop", channel, 8 + 3 * slot, deck=deck)
                result["inputs"][-1]["argument"] = 0.125 * 2 ** slot
            add(result, "loopDown", channel, 16, deck=deck)
            for action, number in [("high", 9), ("mid", 5), ("low", 13), ("filterKnob", 17), ("level", 21)]:
                add(result, action, 3, number + index, "control", deck=deck)
        for action, number in [("crossfader", 25), ("cueMix", 26), ("master", 27)]:
            add(result, action, 3, number, "control")
        add(result, "browse", 3, 30, "control", "binaryDirection")
        add(result, "openGroup", 3, 9)
        result["startup"] = [[0x90 + ch, 56, 127] for ch in channels]
        result["shutdown"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
        result["shutdown"] += [[0x90 + ch, note, 0] for ch in channels for note in ([56] if four else [54, 56, 60, 62])]
        results.append(result)
    return results
