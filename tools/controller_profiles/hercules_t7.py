"""T7 ordinary MIDI controls with motor/platter handling deliberately excluded."""
from curated import add, profile

T7_REVISION = "1ec59320c4ccf5681d5a989d9b7d0447da48aa69"
T7_BASE = "https://raw.githubusercontent.com/Infinite-Grok/mixxx-hercules-t7/" + T7_REVISION + "/"
T7_SOURCES = [
    ("res/controllers/Hercules_DJControl_Inpulse_T7.midi.xml", "285962420de30720a60f189724ae362fdef9fdd0c25b1ffcb9f63798771e8044"),
    ("res/controllers/Hercules-DJControl-Inpulse-T7-script.js", "8a5759845aaf950c442b43a4913caeb65e2da797bdf4fae96210317a6e643602"),
    ("res/controllers/Hercules-DJControl-Inpulse-T7-platter.js", "0de09789ac951c63ffba71685e570bd9e1fe357501c99cde06ebd88ad2072daf"),
    ("README.md", "5d15459fcd60d382f8f1257799e05f9dac6a8726150cc40d0922bdb03d2690d6"),
]
T7_PROTOCOL_SOURCES = [{"url": T7_BASE + path, "sha256": digest} for path, digest in T7_SOURCES]
T7_REFERENCES = {"Hercules DJControl Inpulse T7": {
    "url": T7_BASE + T7_SOURCES[0][0], "sha256": T7_SOURCES[0][1], "relatedSources": T7_PROTOCOL_SOURCES,
    "review": "Independent public0.9-beta source, pinned at1ec59320c4ccf5681d5a989d9b7d0447da48aa69. Author reports hardware checks on Windows; Mac/Linux, current reconnect/shutdown changes and main speaker output remain unverified. Earlier djay XML corroborates normal Play/Cue/Sync/level/gain/EQ addresses. Native manual subset maps deck channels1/2 and shifted4/5, paired14-bit controls with explicit low=high+32, native held Cue/bend and distinct pad channels6/7. Tempo faders are incoming CC8/40, not PitchBend: E1/E2/E4/E5 carry platter timestamps. Platter CC9 and timestamp packets remain unmapped. Output motor Note127, motor-speed CC8/40 and source setup SysEx are never emitted. Native motor/velocity handover requires a separate clock-aware adapter before automatic selection. Normal Play is an audio transport command only. Loop encoder uses the source's1/127 direction via inverted binaryDirection, treating64 as neutral; browse uses strict signed1/127. Eight Hot Cues and distinct quarter-to32-beat toggle loops retain page addresses; shifted clear/roll and other pages stay inactive. Cross-layer release aliases rearm normal buttons without firing unsupported shifted presses. Source shifted Load and PARAM bend remain active on both planes. Source Shift-Range supplies Keylock; full tempo ranges remain open. Source normal/shift steady Play/Cue/Sync/PFL and loop-enabled In/Out lights use127/0. Pad lights are omitted because source output depends on current page. Crossfader stays unmapped until curve/disable ownership exists. FX, stems, shared page state, live meters/rings, full lifecycle and audio routing remain open. Manual input/feedback require separate loading/enabling; applying a manual recipe runs no automatic lifecycle. No downloaded source code runs in the app.",
}}


def t7_profiles():
    result = profile("Hercules DJControl Inpulse T7", T7_REFERENCES["Hercules DJControl Inpulse T7"]["url"])
    result["autoSelect"] = False
    result["hardwareMode"] = "Manual ordinary MIDI subset only. Native motor/velocity handover and cold-start lifecycle remain unimplemented."
    result["scope"] = "Manual two-deck audio transport, paired mixer/tempo, held Cue/bend, eight cue pads, fixed loop pads, native loops/browse and steady button feedback. Platter/motor, crossfader modes, full pad/FX/stem modes, lifecycle and audio routing remain open."
    result["gaps"] = ["Platter/motor handling is unimplemented. T7 pitch-bend packets are2.4MHz timestamps, not tempo. Motor control, speed feedback and timestamp-aware velocity/transport handover require a separate adapter before automatic selection. No motor or setup command is emitted. Crossfader curve/disable ownership, FX/stems, full tempo ranges, shared pad/feedback state, live meters/rings, full lifecycle and audio routing remain open. Manual MIDI input and light mappings require separate loading/enabling. Physical acceptance is open."]
    for channel, deck in [(1, "a"), (2, "b")]:
        shifted = channel + 3

        def button(action, number, wire=channel, feedback=False):
            add(result, action, wire, number, deck=deck, feedback=feedback)
            if feedback:
                mirror = dict(result["outputs"][-1], channel=shifted)
                result["outputs"].append(mirror)
            add(result, action, shifted if wire == channel else channel, number, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True

        for action, number in [("play", 7), ("cuePreview", 6), ("sync", 5), ("cue", 12)]:
            button(action, number, feedback=True)
        for wire in [channel, shifted]:
            button("load", 13, wire)
            button("pitchBendUp", 83, wire)
            button("pitchBendDown", 84, wire)
        for action, number in [("loopIn", 9), ("loopOut", 10), ("loop", 44)]:
            button(action, number)
        for action, number in [("loopDown", 9), ("loopUp", 10), ("keylock", 82)]:
            button(action, number, shifted)
        for number in [9, 10]:
            for wire in [channel, shifted]:
                result["outputs"].append({"action": "loopA" if deck == "a" else "loopB", "targetDeck": deck,
                    "kind": "note", "channel": wire, "number": number, "onValue": 127, "offValue": 0, "offUsesNoteOn": True})
        for wire in [channel, shifted]:
            for action, number in [("level", 0), ("tempo", 8)]:
                add(result, action, wire, number, "control", "paired14Bit", deck)
                result["inputs"][-1]["lowNumber"] = number + 32
        for action, number in [("filterKnob", 1), ("low", 2), ("mid", 3), ("high", 4), ("gain", 5)]:
            add(result, action, channel, number, "control", "paired14Bit", deck)
            result["inputs"][-1]["lowNumber"] = number + 32
        add(result, "loopSize", channel, 14, "control", "binaryDirection", deck)
        result["inputs"][-1]["inverted"] = True
        add(result, "browse", channel, 15, "control", "signedStep")
        add(result, "openGroup", channel, 80)
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", channel + 5, slot, deck=deck)
            add(result, f"hotcue{slot + 1}", channel + 5, slot + 8, deck=deck)
            result["inputs"][-1]["releaseOnly"] = True
            add(result, "toggleFixedLoop", channel + 5, slot + 16, deck=deck)
            result["inputs"][-1]["argument"] = 0.25 * 2 ** slot
            add(result, "toggleFixedLoop", channel + 5, slot + 24, deck=deck)
            result["inputs"][-1].update(argument=0.25 * 2 ** slot, releaseOnly=True)
    add(result, "cueMix", 0, 5, "control", "paired14Bit")
    result["inputs"][-1]["lowNumber"] = 37
    result["shutdown"] = [[0x90 + row["channel"], row["number"], 0] for row in result["outputs"]]
    return [result]
