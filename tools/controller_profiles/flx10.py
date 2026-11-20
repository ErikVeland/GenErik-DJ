"""FLX10 core facts from the factory message list and function diagram."""
from curated import BASE, add, profile
from pioneer_pad_clears import add_pioneer_pad_clears

FLX10_TABLE = BASE + "dj-controllers/DDJ-FLX10/DDJ-FLX10_MIDI_Message_List_E1.pdf"
FLX10_DIAGRAM = BASE + "dj-controllers/DDJ-FLX10/DDJ-FLX10_HardwareDiagram_rekordbox_E1.pdf"
FLX10_REFERENCES = {"DDJ-FLX10": {
    "url": FLX10_TABLE,
    "sha256": "c6fbe89c909bdabed911d315a35fc6c00c5af45ec4dd66ef20f49e86e90ac26c",
    "pages": [1, 2, 4, 5, 6, 7],
    "relatedSources": [{"url": FLX10_DIAGRAM, "sha256": "9e1d1357c28e5eddfecfe0d646bf579a2a09e0e4b6a602bf47978e72919fbf35", "pages": [2]}],
    "review": "Four transport channels 0/1/2/3 target A/B/C/D, with normal pad channels 7/9/11/13. Normal loop buttons set in/out while no loop is active and halve/double an active loop. The four-beat button toggles a four-beat loop. Beat Jump uses four beats, or sixteen with Shift. Shifted jog reports edit the beat grid and do not inherit scratch or bend. Bank Note 60 positive reports protect the corresponding physical side. The existing profile ID, exact aliases and saved custom mappings remain stable. Full pad modes, grid editing, stem controls, screens, complete feedback, lifecycle cleanup and audio routing remain open. Jog resolution is not published in the table, so native default sensitivity still needs calibration.",
}}


def flx10_profiles():
    result = profile("Pioneer DDJ-FLX10", FLX10_TABLE)
    result.update(id="DDJ-FLX10", catalogueName="Pioneer DDJ-FLX10")
    result["aliases"].append("AlphaTheta DDJ-FLX10")
    result["scope"] = "Four-deck native core MIDI with held Cue, context-dependent loop buttons, four/sixteen-beat jumps, Load and Hot Cues. Four decks retain the app opt-in. Grid editing, remaining modes, stems, screens, full feedback, cleanup and audio routing remain open. Jog calibration remains open."
    result["bankChanges"] = []
    for channel, deck in enumerate("abcd"):
        scope = channel % 2
        for action, number in [("play", 11), ("cuePreview", 12), ("sync", 88), ("tempoReset", 65),
                               ("loopInOrHalve", 16), ("loopOutOrDouble", 17), ("toggleFixedLoop", 20)]:
            add(result, action, channel, number, deck=deck, feedback=action in {"play", "sync"})
            result["inputs"][-1].update(shifted=False, shiftChannel=scope)
            if action == "toggleFixedLoop":
                result["inputs"][-1]["argument"] = 4
        for number, beats, shifted in [(94, -4, False), (95, 4, False), (97, -16, True), (98, 16, True)]:
            add(result, "fixedJump", channel, number, deck=deck)
            result["inputs"][-1].update(argument=beats, shifted=shifted, shiftChannel=scope)
        for number, shifted in [(0, False), (5, True)]:
            add(result, "tempo", channel, number, "control", "paired14Bit", deck)
            result["inputs"][-1].update(shifted=shifted, shiftChannel=scope)
        for action, number in [("gain", 4), ("high", 7), ("mid", 11), ("low", 15), ("level", 19)]:
            add(result, action, channel, number, "control", "paired14Bit", deck)
        for number, shifted in [(84, False), (57, True)]:
            add(result, "cue", channel, number, deck=deck, feedback=not shifted)
            result["inputs"][-1].update(shifted=shifted, shiftChannel=scope)
        for action, number in [("jog", 34), ("wheelJog", 35), ("wheelJog", 33)]:
            add(result, action, channel, number, "control", "binaryOffset", deck)
            result["inputs"][-1].update(shifted=False, shiftChannel=scope)
        add(result, "jogTouch", channel, 54, deck=deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=scope)
        add(result, "jogTouch", channel, 103, deck=deck)
        result["inputs"][-1].update(shifted=True, shiftChannel=scope, releaseOnly=True)
        for slot in range(8):
            add(result, f"hotcue{slot + 1}", 7 + 2 * channel, slot, deck=deck, feedback=True)
            result["inputs"][-1].update(shifted=False, shiftChannel=scope)
        add(result, "load", 6, 70 + channel, deck=deck)
        result["inputs"][-1].update(shifted=False, shiftChannel=scope)
        add(result, "shift", channel, 63)
        result["inputs"][-1].update(shiftChannel=scope, shiftInput=scope)
        result["bankChanges"].append({"channel": channel, "number": 60, "onValue": 127,
                                      "decks": ["a", "c"] if scope == 0 else ["b", "d"]})
    for action, number in [("crossfader", 31), ("master", 8), ("cueMix", 12), ("monitor", 13)]:
        add(result, action, 6, number, "control", "paired14Bit")
    add(result, "browse", 6, 64, "control", "twosComplement")
    return [add_pioneer_pad_clears(result)]
