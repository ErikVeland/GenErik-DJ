"""Beatpad 2 native core from its separate factory chart and Traktor mapping."""
from curated import add, profile

BEATPAD2_TABLE = "https://www.jaytec.de/media/custom/upload/Reloop-Beatpad2_MIDI-Map.pdf"
BEATPAD2_MAPPING = "https://www.reloop.com/media/custom/upload/234963/234963%20Mapping%201.1%202D%20Traktor%202.6.8%2B%20FW%200.17%2B%20Uni.zip"
BEATPAD2_SOURCES = [
    ("beatpad2-midi.pdf", "56bb3e138b54971647750e7b9e3c8cb781610439a7cb73d51955938b5f3f2819"),
    ("beatpad2-traktor.zip", "1308840223e5ad3892804a6bebaafb1d31898feb62876e1b3be7bd943310181d"),
    ("Traktor_Setup_BP2_FINALV1-1.tsi", "bcfd73589b13acd97cfa7a81efc0494bd92d10704483f6e3b05837bc66500702"),
]
BEATPAD2_REFERENCES = {"Reloop Beatpad 2": {
    "url": BEATPAD2_TABLE, "sha256": BEATPAD2_SOURCES[0][1], "pages": [1, 2],
    "relatedSources": [{"url": BEATPAD2_MAPPING, "sha256": BEATPAD2_SOURCES[1][1],
        "archiveMember": {"path": BEATPAD2_SOURCES[2][0], "sha256": BEATPAD2_SOURCES[2][1]}},
        {"url": "https://www.reloop.com/reloop-beatpad-2"},
        {"url": "https://www.reloop.com/media/custom/upload/Reloop-Beatpad2_MIDI-Map.pdf"}],
    "review": "Separate Beatpad2 chart supplies eight distinct pad pages on channels2/3, shifted pad clear64..71, EQ Classic/Filter semantic CCs and fader-start Note96 collision. Factory mapping requires firmware0.17+. Its BP2 Deck A/B normal rows supply Play96, Cue94, Sync93, PFL97, Load98, Keylock1, contact99 and unflipped PitchBend. Each active deck's input DCDT sets its own jogCC99 to3Fh/41h; unrelated device copies retain stale7Fh/01h and are not followed. Mixer device DCDT sets global browseCC66 to3Fh/41h. Native centre64 decoders use those active definitions. No original-Beatpad sensor count or shifted transport address is inferred. Native default1024 scratch calibration, speed response and physical direction remain open. Factory Shift Note28 reports have distinct physical identities and global OR. Shift presses and explicit NoteOff releases clear contacts and reset pickup/debounce on both decks, preventing stuck normal inputs and fader-start Play96 from firing while Shift is held. EQ addresses follow their physical function in both layouts; automatic neutralisation of the previous Mid/Filter on EQ preset change remains open. Native source loop page keeps four-beat toggle8, selected-size toggle11, In12/Out13 and Halve14/Double15; source move9/10, full factory automatic loop lengths, roll/slicer/sampler/FX modes remain inactive. Normal cue pads0..7 use factory-source blue11/off0, transport steady127/off0. Source has no startup SysEx; no sibling query is copied. Shutdown clears26 owned outputs only. Rings, pad-mode LEDs, unsupported shifted lights, complete lifecycle, numbered split audio, live meters and physical acceptance remain open. Master/headphone knobs remain hardware controls. No vendor settings/code run in the app.",
}}


def beatpad2_profiles():
    result = profile("Reloop Beatpad 2", BEATPAD2_TABLE)
    result["excludedAliases"] = ["Beatpad", "Reloop Beatpad", "Beatpad 1", "Reloop Beatpad 1"]
    result["hardwareMode"] = "Factory MIDI configuration, firmware0.17 or later. Original Beatpad is a separate adapter."
    result["scope"] = "Automatic Beatpad2 normal core with explicit deck/pad/global channels, native touch/jog, full pitch, eight cues, source loop page, mixer/filter and bounded steady feedback. Full EQ-mode reset, pad/shift modes, lifecycle/routing and physical calibration remain open."
    result["gaps"] = ["Default1024-count jog calibration and native nudge response need physical qualification. EQ Classic/Filter controls retain their own MIDI meanings; automatic reset of the previous Mid/Filter value on preset changes is not implemented. Source loop-page subset is not the full factory automatic-loop layout. Other shifted transport/pad modes, cue deletion, sampler/slicer/rolls/FX, fader start, ring/mode/live-meter feedback, complete lifecycle, numbered audio route and physical USB/audio acceptance remain open."]
    result["bankChanges"] = [{"channel": channel, "number": 28, "onValue": 127, "decks": ["a", "b"], "releaseShiftChannels": []}
                             for channel in range(2)]
    for channel, deck in enumerate("ab"):
        add(result, "shift", channel, 28)
        result["inputs"][-1]["shiftInput"] = channel
        for action, number in [("play", 96), ("cuePreview", 94), ("sync", 93), ("cue", 97), ("load", 98), ("keylock", 1)]:
            add(result, action, channel, number, deck=deck, feedback=action != "load")
            result["inputs"][-1]["shifted"] = False
        add(result, "jogTouch", channel, 99, deck=deck)
        result["inputs"][-1]["shifted"] = False
        add(result, "jog", channel, 99, "control", "binaryOffset", deck)
        result["inputs"][-1]["shifted"] = False
        add(result, "tempo", channel, 0, "pitch", "centredPitch", deck)
        for action, number in [("gain", 75), ("high", 76), ("mid", 77), ("low", 78), ("filterKnob", 73), ("level", 79)]:
            add(result, action, channel, number, "control", "absolute" if action == "level" else "centreDetent", deck)
            result["inputs"][-1]["shifted"] = False
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", channel + 2, slot, deck=deck, feedback=True)
            result["inputs"][-1]["shifted"] = False
            result["outputs"][-1]["onValue"] = 11
            add(result, f"hotcue{slot + 1}", channel + 2, slot + 64, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
        for action, number in [("loop", 8), ("loop", 11), ("loopIn", 12), ("loopOut", 13), ("loopDown", 14), ("loopUp", 15)]:
            add(result, action, channel + 2, number, deck=deck)
            result["inputs"][-1]["shifted"] = False
            if number == 8:
                result["inputs"][-1]["argument"] = 4
            add(result, action, channel + 2, number + 64, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
            if number == 8:
                result["inputs"][-1]["argument"] = 4
    for action, number in [("crossfader", 69), ("cueMix", 67)]:
        add(result, action, 4, number, "control")
        result["inputs"][-1]["shifted"] = False
    add(result, "browse", 4, 66, "control", "binaryOffset")
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 4, 70)
    result["inputs"][-1]["shifted"] = False
    add(result, "openGroup", 4, 6)
    result["inputs"][-1]["releaseOnly"] = True
    result["shutdown"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
    return [result]
